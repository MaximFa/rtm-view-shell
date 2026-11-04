using System.Text.Json;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.Interfaces;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.HistoricalReports.Validators;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Handlers;

/// <summary>
/// Single entry point for report widgets.
/// SF-BI-001: All scope resolution + validation happens HERE, server-side, NON-BYPASSABLE.
/// </summary>
public class RunReportWidgetQueryHandler(
    IHistoricalReportRepository repo,
    IReportWidgetScopeService scopeService,
    ICurrentUserAccessor currentUser,
    ILogger<RunReportWidgetQueryHandler> logger,
    IDisplayTimeZone? displayZone = null)
    : IRequestHandler<RunReportWidgetQuery, ReportWidgetResult>
{
    // BL-234-INTERACTION-TIME-AHEAD-01: DB holds true UTC; report days and interval starts are in the display zone.
    // Without a registered zone (unit tests of other concerns) it is UTC, i.e. no conversion.
    private TimeZoneInfo Zone => displayZone?.Zone ?? TimeZoneInfo.Utc;

    private const int ExportRowCap = 50000;

    private static readonly HashSet<ReportWidgetType> AgentWidgetTypes = new()
    {
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail
    };

    public async Task<ReportWidgetResult> Handle(RunReportWidgetQuery query, CancellationToken ct)
    {
        // Superadmin-gated tenant resolution: non-Superadmin's TenantId param IGNORED (own tenant only)
        var tenantId = currentUser.Role == "Superadmin"
            ? (query.TenantId ?? currentUser.TenantId!.Value)
            : currentUser.TenantId!.Value;

        ReportWidgetConfig config;
        try
        {
            config = ReportWidgetConfig.Parse(query.ConfigJson);
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "RunReportWidgetQuery: invalid ConfigJson");
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, "Invalid ConfigJson: " + ex.Message);
        }

        var validator = new ReportWidgetConfigWithTypeValidator();
        var validationResult = await validator.ValidateAsync((config, query.WidgetType), ct);
        if (!validationResult.IsValid)
        {
            var errors = string.Join("; ", validationResult.Errors.Select(e => e.ErrorMessage));
            logger.LogWarning("RunReportWidgetQuery: validation failed: {Errors}", errors);
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, errors);
        }

        // FEAT-REPORT-EOS-*-01: an end-of-shift report is one date plus shift hours; every other type takes whole days
        // and must not carry shift hours.
        // PR234-V4-EOS-WIDGETS-NO-SHIFT-HOURS-01: hours on the query win; without them an end-of-shift widget runs with the
        // hours saved in its own config. Other types never take hours from the config.
        if (IsEndOfShift(query.WidgetType) && query.ShiftStartHour is null && query.ShiftEndHour is null)
            query = query with { ShiftStartHour = config.ShiftStartHour, ShiftEndHour = config.ShiftEndHour };

        var shiftError = ValidateShift(query);
        if (shiftError != null)
        {
            logger.LogWarning("RunReportWidgetQuery: shift validation failed: {Error}", shiftError);
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.ShiftHours, shiftError);
        }

        // The picked days are days in the display zone: local midnight -> UTC instant.
        var from = Zone.WallToUtc(query.From.Date);
        var toExclusive = Zone.WallToUtc(query.To.Date.AddDays(1));
        if (IsEndOfShift(query.WidgetType))
        {
            // Shift hours are site wall-clock hours on the picked date; whole hours fall on the 30-minute bucket edges.
            from = Zone.WallToUtc(query.From.Date.AddHours(query.ShiftStartHour!.Value));
            toExclusive = Zone.WallToUtc(query.From.Date.AddHours(query.ShiftEndHour!.Value));
        }

        // Compute effective columns: config.Columns if non-empty, else DefaultColumns per WidgetType
        var effectiveColumns = config.GetEffectiveColumns(query.WidgetType);

        return query.WidgetType switch
        {
            ReportWidgetType.QueueInterval => await RunQueueIntervalAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.QueueWaitTime => await RunQueueWaitTimeAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.AgentMonthly => await RunAgentMonthlyAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.AgentShiftDetail => await RunAgentShiftDetailAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.Distribution => await RunDistributionAsync(tenantId, config, effectiveColumns, from, toExclusive, ct),
            ReportWidgetType.EndOfShiftAgents => await RunAgentSummaryAsync(query.WidgetType, null, tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.AgentPerformance => await RunAgentSummaryAsync(query.WidgetType, config.Mode, tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            ReportWidgetType.EndOfShiftQueues => await RunQueueSummaryAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, ct),
            _ => ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, $"Unknown widget type: {query.WidgetType}")
        };
    }

    private async Task<ReportWidgetResult> RunQueueIntervalAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.QueueInterval);

        var intervals = await ScopedQueueIntervalsAsync(tenantId, from, toExclusive, scopeResult.EffectiveWorkgroups, ct);

        // BU-AGGREGATED: GROUP BY IntervalStart only, SUM components, recompute metrics from sums
        var rows = intervals
            .GroupBy(i => Zone.ToDisplay(i.IntervalStart))
            .Select(g =>
            {
                var offered      = g.Sum(i => i.Offered);
                var answered     = g.Sum(i => i.Answered);
                var abandoned    = g.Sum(i => i.Abandoned);
                var answeredInSl = g.Sum(i => i.AnsweredInSl);
                var sumWait      = g.Sum(i => i.SumWaitAnswered);
                var sumTalk      = g.Sum(i => i.SumTalk);
                return new QueueIntervalRow(
                    g.Key,
                    null,                       // Workgroup: BU-aggregated, no single queue
                    null,                       // QueueId: aggregated
                    offered, answered, abandoned, answeredInSl, sumWait, sumTalk,
                    offered  == 0 ? null : abandoned * 100.0 / offered,        // AbandonPct from SUMS
                    answered == 0 ? null : answeredInSl * 100.0 / answered,    // SlPct
                    answered == 0 ? null : (double)sumWait / answered,         // Asa
                    answered == 0 ? null : (double)sumTalk / answered);        // QueueAht
            })
            .OrderBy(r => r.IntervalStart)
            .ToList();

        var totalCount = rows.Count;
        List<QueueIntervalRow> resultRows;
        int pageSize;

        if (allRows)
        {
            resultRows = rows.Take(ExportRowCap).ToList();
            pageSize = resultRows.Count;
        }
        else
        {
            pageSize = config.PageSize;
            resultRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();
        }

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.QueueInterval,
            EffectiveColumns = effectiveColumns,
            QueueInterval = new QueueIntervalReportResult(resultRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunQueueWaitTimeAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.QueueWaitTime);

        var intervals = await ScopedQueueIntervalsAsync(tenantId, from, toExclusive, scopeResult.EffectiveWorkgroups, ct);

        // BU-AGGREGATED: GROUP BY IntervalStart only, SUM components, recompute metrics from sums
        var rows = intervals
            .GroupBy(i => Zone.ToDisplay(i.IntervalStart))
            .Select(g =>
            {
                var answered     = g.Sum(i => i.Answered);
                var sumWait      = g.Sum(i => i.SumWaitAnswered);
                var answeredInSl = g.Sum(i => i.AnsweredInSl);
                return new QueueWaitTimeRow(
                    g.Key, null, answered, sumWait,
                    answered == 0 ? null : (double)sumWait / answered,        // Asa
                    answeredInSl,
                    answered == 0 ? null : answeredInSl * 100.0 / answered);  // SlPct
            })
            .OrderBy(r => r.IntervalStart)
            .ToList();

        var totalAnswered = rows.Sum(r => r.Answered);
        var totalWait = rows.Sum(r => r.SumWaitAnswered);
        var overallAsa = totalAnswered == 0 ? null : (double?)totalWait / totalAnswered;

        var totalCount = rows.Count;
        List<QueueWaitTimeRow> resultRows;
        int pageSize;

        if (allRows)
        {
            resultRows = rows.Take(ExportRowCap).ToList();
            pageSize = resultRows.Count;
        }
        else
        {
            pageSize = config.PageSize;
            resultRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();
        }

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.QueueWaitTime,
            EffectiveColumns = effectiveColumns,
            QueueWaitTime = new QueueWaitTimeReportResult(resultRows, totalCount, page, pageSize, overallAsa)
        };
    }

    private async Task<ReportWidgetResult> RunAgentMonthlyAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        var axis = config.Scope.AgentAxis ?? AgentReportAxis.Detail;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, axis, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.AgentMonthly);

        var intervals = await ScopedAgentIntervalsAsync(tenantId, from, toExclusive, scopeResult.EffectiveAgentIds, ct);

        var rows = intervals
            .GroupBy(x => new { YearMonth = Zone.ToDisplay(x.IntervalStart).ToString("yyyy-MM"), x.AgentExternalId })
            .Select(g =>
            {
                var sumAvailable = g.Sum(x => x.SumAvailableMs);
                var sumOnphone = g.Sum(x => x.SumOnphoneMs);
                var sumHold = g.Sum(x => x.SumHoldMs);
                var sumPaperwork = g.Sum(x => x.SumPaperworkMs);
                var sumBreak = g.Sum(x => x.SumBreakMs);
                var sumTraining = g.Sum(x => x.SumTrainingMs);
                var sumLoggedIn = g.Sum(x => x.SumLoggedInMs);
                var handled = g.Sum(x => x.Handled);
                var displayName = g.First().AgentDisplayName;

                var occupancyDenom = sumAvailable + sumOnphone + sumPaperwork;
                double? occupancyPct = occupancyDenom == 0 ? null : (sumOnphone + sumPaperwork) * 100.0 / occupancyDenom;
                double? agentAht = handled == 0 ? null : (sumOnphone + sumPaperwork) / 1000.0 / handled;
                double? holdPct = sumOnphone == 0 ? null : sumHold * 100.0 / sumOnphone;

                return new AgentMonthlyRow(
                    g.Key.YearMonth,
                    g.Key.AgentExternalId,
                    displayName,
                    sumAvailable,
                    sumOnphone,
                    sumHold,
                    sumPaperwork,
                    sumBreak,
                    sumTraining,
                    sumLoggedIn,
                    handled,
                    occupancyPct,
                    agentAht,
                    holdPct);
            })
            .OrderBy(x => x.YearMonth)
            .ThenBy(x => x.AgentExternalId)
            .ToList();

        var totalCount = rows.Count;
        List<AgentMonthlyRow> resultRows;
        int pageSize;

        if (allRows)
        {
            resultRows = rows.Take(ExportRowCap).ToList();
            pageSize = resultRows.Count;
        }
        else
        {
            pageSize = config.PageSize;
            resultRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();
        }

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.AgentMonthly,
            EffectiveColumns = effectiveColumns,
            AgentMonthly = new AgentMonthlyReportResult(resultRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunAgentShiftDetailAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        var axis = config.Scope.AgentAxis ?? AgentReportAxis.Detail;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, axis, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.AgentShiftDetail);

        var intervals = await ScopedAgentIntervalsAsync(tenantId, from, toExclusive, scopeResult.EffectiveAgentIds, ct);

        var rows = intervals.Select(i =>
        {
            var occupancyDenom = i.SumAvailableMs + i.SumOnphoneMs + i.SumPaperworkMs;
            return new AgentShiftDetailRow(
                Zone.ToDisplay(i.IntervalStart),
                i.AgentExternalId,
                i.AgentDisplayName,
                i.SumAvailableMs,
                i.SumOnphoneMs,
                i.SumHoldMs,
                i.SumPaperworkMs,
                i.SumBreakMs,
                i.SumTrainingMs,
                i.SumLoggedInMs,
                i.Handled,
                occupancyDenom == 0 ? null : (i.SumOnphoneMs + i.SumPaperworkMs) * 100.0 / occupancyDenom,
                i.Handled == 0 ? null : (i.SumOnphoneMs + i.SumPaperworkMs) / 1000.0 / i.Handled,
                i.SumOnphoneMs == 0 ? null : i.SumHoldMs * 100.0 / i.SumOnphoneMs,
                i.SumOnphoneMs - i.SumHoldMs);
        }).ToList();

        var totalCount = rows.Count;
        List<AgentShiftDetailRow> resultRows;
        int pageSize;

        if (allRows)
        {
            resultRows = rows.Take(ExportRowCap).ToList();
            pageSize = resultRows.Count;
        }
        else
        {
            pageSize = config.PageSize;
            resultRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();
        }

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.AgentShiftDetail,
            EffectiveColumns = effectiveColumns,
            AgentShiftDetail = new AgentShiftDetailReportResult(resultRows, totalCount, page, pageSize)
        };
    }

    // ── PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01 ──────────────────────────────────────────────────────────────────
    // A widget's rows are exactly its effective set (the BUs picked, intersected with the PG). The repository reads an
    // empty set under FullScope as "no filter", so a Superadmin who picked a BU without agents/queues got the WHOLE
    // tenant. Widgets therefore never pass FullScope and never query with an empty set: empty set -> no rows, no query.

    private async Task<IReadOnlyList<CcDashboard.Domain.Domain.Historical.HistQueueInterval>> ScopedQueueIntervalsAsync(
        Guid tenantId, DateTime from, DateTime toExclusive, IReadOnlySet<string> workgroups, CancellationToken ct)
    {
        if (workgroups.Count == 0)
            return Array.Empty<CcDashboard.Domain.Domain.Historical.HistQueueInterval>();
        var rows = await repo.GetQueueIntervalsAsync(tenantId, from, toExclusive,
            new ReportScope { FullScope = false, AllowedWorkgroups = workgroups }, workgroups, ct);
        return rows.Where(i => workgroups.Contains(i.Workgroup)).ToList();
    }

    private async Task<IReadOnlyList<CcDashboard.Domain.Domain.Historical.HistAgentInterval>> ScopedAgentIntervalsAsync(
        Guid tenantId, DateTime from, DateTime toExclusive, IReadOnlySet<string> agentIds, CancellationToken ct)
    {
        if (agentIds.Count == 0)
            return Array.Empty<CcDashboard.Domain.Domain.Historical.HistAgentInterval>();
        var rows = await repo.GetAgentIntervalsAsync(tenantId, from, toExclusive,
            new ReportScope { FullScope = false, AllowedAgentExternalIds = agentIds }, agentIds, ct);
        return rows.Where(i => agentIds.Contains(i.AgentExternalId)).ToList();
    }

    // ── FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-EOS-QUEUES-01 / FEAT-REPORT-AGENT-PERF-01 ─────────────────────────

    /// <summary>
    /// hist_agent_intervals puts a status duration into the half-hour in which the status STARTED (aggregation by
    /// status start). At the edges of a shift window a status that began before the start is missing, and one that began
    /// inside the window counts in full even past its end. Shown to the user as the report hint.
    /// </summary>
    public const string AgentBoundaryCaveat =
        "Status durations are counted in the half-hour in which the status started: at the edges of the window a status " +
        "that began before the start is not counted, and one that began inside is counted in full.";

    internal static bool IsEndOfShift(ReportWidgetType t) =>
        t is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;

    internal static string? ValidateShift(RunReportWidgetQuery q)
    {
        if (!IsEndOfShift(q.WidgetType))
            return q.ShiftStartHour.HasValue || q.ShiftEndHour.HasValue
                ? "Shift hours apply only to the end-of-shift reports"
                : null;

        if (!q.ShiftStartHour.HasValue || !q.ShiftEndHour.HasValue)
            return "Shift start and end hours are required";
        if (q.From.Date != q.To.Date)
            return "An end-of-shift report covers one date";
        if (q.ShiftStartHour < 0 || q.ShiftStartHour > 23 || q.ShiftEndHour < 1 || q.ShiftEndHour > 24)
            return "Shift hours must be 0-23 (start) and 1-24 (end)";
        if (q.ShiftEndHour <= q.ShiftStartHour)
            return "The shift must end after it starts; a shift across midnight is not supported";
        return null;
    }

    private async Task<(DateTime? Through, bool Incomplete)> FreshnessAsync(Guid tenantId, DateTime toExclusive, CancellationToken ct)
    {
        var wm = await repo.GetWatermarkAsync(tenantId, ct);
        var through = wm?.AggregatedThrough;
        return (through, through is null || toExclusive > through.Value);
    }

    private static (List<T> Rows, int PageSize) PageOf<T>(List<T> rows, int pageSize, int page, bool allRows)
    {
        if (allRows)
        {
            var all = rows.Take(ExportRowCap).ToList();
            return (all, all.Count);
        }
        return (rows.Skip((page - 1) * pageSize).Take(pageSize).ToList(), pageSize);
    }

    private async Task<ReportWidgetResult> RunAgentSummaryAsync(
        ReportWidgetType type, AgentPerformanceMode? mode, Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns,
        DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);

        // The agent filter only narrows the scope (SF-BI-001); requested ids outside it are dropped and logged (SF-BI-002).
        var effective = new HashSet<string>(scopeResult.EffectiveAgentIds);
        if (config.AgentIds is { Count: > 0 })
        {
            var requested = new HashSet<string>(config.AgentIds);
            var dropped = requested.Where(id => !effective.Contains(id)).ToList();
            if (dropped.Count > 0)
                logger.LogWarning(
                    "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} agents in {Type}, {DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                    currentUser.UserId, currentUser.PermissionGroupId, requested.Count, type, dropped.Count, string.Join(", ", dropped.Take(5)));
            effective.IntersectWith(requested);
        }

        var intervals = await ScopedAgentIntervalsAsync(tenantId, from, toExclusive, effective, ct);

        var byDate = type == ReportWidgetType.AgentPerformance && mode == AgentPerformanceMode.ByDate;
        var rows = intervals
            .Where(i => effective.Contains(i.AgentExternalId))
            .GroupBy(i => (Date: byDate ? Zone.ToDisplay(i.IntervalStart).Date : (DateTime?)null, i.AgentExternalId))
            .Select(g =>
            {
                long Sum(Func<CcDashboard.Domain.Domain.Historical.HistAgentInterval, long> f) => g.Sum(f);
                var available = Sum(x => x.SumAvailableMs);
                var onphone = Sum(x => x.SumOnphoneMs);
                var hold = Sum(x => x.SumHoldMs);
                var paperwork = Sum(x => x.SumPaperworkMs);
                var handled = g.Sum(x => x.Handled);
                var occDenom = available + onphone + paperwork;
                return new AgentSummaryRow(
                    g.Key.Date,
                    g.Key.AgentExternalId,
                    g.Select(x => x.AgentDisplayName).LastOrDefault(n => !string.IsNullOrEmpty(n)),
                    Sum(x => x.SumLoggedInMs),
                    available,
                    onphone,
                    hold,
                    paperwork,
                    Sum(x => x.SumBreakMs),
                    Sum(x => x.SumTrainingMs),
                    Sum(x => x.SumUnavailableMs),
                    handled,
                    occDenom == 0 ? null : (onphone + paperwork) * 100.0 / occDenom,
                    handled == 0 ? null : (onphone + paperwork) / 1000.0 / handled,
                    onphone == 0 ? null : hold * 100.0 / onphone,
                    onphone - hold);
            })
            .OrderBy(r => r.Date)
            .ThenBy(r => r.AgentDisplayName ?? r.AgentExternalId, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(r => r.AgentExternalId, StringComparer.Ordinal)
            .ToList();

        var (pageRows, pageSize) = PageOf(rows, config.PageSize, page, allRows);
        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);

        return new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = effectiveColumns,
            AgentSummary = new AgentSummaryReportResult(pageRows, rows.Count, page, pageSize),
            DataThroughUtc = through,
            Incomplete = incomplete,
            Caveat = AgentBoundaryCaveat
        };
    }

    private async Task<ReportWidgetResult> RunQueueSummaryAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns,
        DateTime from, DateTime toExclusive, int page, bool allRows, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.EndOfShiftQueues;
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);

        var effective = new HashSet<string>(scopeResult.EffectiveWorkgroups);
        var intervals = await ScopedQueueIntervalsAsync(tenantId, from, toExclusive, effective, ct);

        // One row per queue: sums of the half-hour buckets that start inside the window (whole shift hours are bucket
        // edges); derived values are recomputed from the sums, as in the BU-aggregated QueueInterval.
        var rows = intervals
            .Where(i => effective.Contains(i.Workgroup))
            .GroupBy(i => i.Workgroup)
            .Select(g =>
            {
                var offered = g.Sum(i => i.Offered);
                var answered = g.Sum(i => i.Answered);
                var abandoned = g.Sum(i => i.Abandoned);
                var inSl = g.Sum(i => i.AnsweredInSl);
                var wait = g.Sum(i => i.SumWaitAnswered);
                var talk = g.Sum(i => i.SumTalk);
                return new QueueSummaryRow(
                    g.Key,
                    g.Select(i => i.QueueId).FirstOrDefault(q => q.HasValue),
                    offered, answered, abandoned, inSl, wait, talk,
                    offered == 0 ? null : abandoned * 100.0 / offered,
                    answered == 0 ? null : inSl * 100.0 / answered,
                    answered == 0 ? null : (double)wait / answered,
                    answered == 0 ? null : (double)talk / answered);
            })
            .OrderBy(r => r.Workgroup, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

        var (pageRows, pageSize) = PageOf(rows, config.PageSize, page, allRows);
        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);

        return new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = effectiveColumns,
            QueueSummary = new QueueSummaryReportResult(pageRows, rows.Count, page, pageSize),
            DataThroughUtc = through,
            Incomplete = incomplete
        };
    }

    private async Task<ReportWidgetResult> RunDistributionAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.Distribution);

        var intervals = await ScopedQueueIntervalsAsync(tenantId, from, toExclusive, scopeResult.EffectiveWorkgroups, ct);

        var totalAnswered = intervals.Sum(x => x.Answered);
        var totalWait = intervals.Sum(x => x.SumWaitAnswered);
        var overallAsa = totalAnswered == 0 ? null : (double?)totalWait / totalAnswered;

        var buckets = BuildDistributionBuckets(intervals, config.Metric);

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.Distribution,
            EffectiveColumns = effectiveColumns,
            Distribution = new DistributionReportResult(buckets, totalAnswered, overallAsa)
        };
    }

    private static List<DistributionBucket> BuildDistributionBuckets(
        IReadOnlyList<Domain.Domain.Historical.HistQueueInterval> intervals, string? metric)
    {
        var answeredInSl = intervals.Sum(x => x.AnsweredInSl);
        var answered = intervals.Sum(x => x.Answered);
        var abandoned = intervals.Sum(x => x.Abandoned);
        var total = answered + abandoned;

        if (total == 0)
            return new List<DistributionBucket>();

        return new List<DistributionBucket>
        {
            new("Answered in SL", 0, null, answeredInSl, total == 0 ? 0 : answeredInSl * 100.0 / total),
            new("Answered out of SL", 0, null, answered - answeredInSl, total == 0 ? 0 : (answered - answeredInSl) * 100.0 / total),
            new("Abandoned", 0, null, abandoned, total == 0 ? 0 : abandoned * 100.0 / total)
        };
    }
}
