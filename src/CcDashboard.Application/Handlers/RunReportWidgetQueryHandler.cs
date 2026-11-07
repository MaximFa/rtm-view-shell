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

        // FEAT-REPORT-EOS-CONFIGURABLE-01: a widget of a retired type (saved before the change) says so instead of running
        if (RetiredReports.IsRetired(query.WidgetType))
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.Retired, $"Report type {query.WidgetType} is retired");

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
        if (TakesShiftHours(query.WidgetType) && query.ShiftStartHour is null && query.ShiftEndHour is null)
            query = query with { ShiftStartHour = config.ShiftStartHour, ShiftEndHour = config.ShiftEndHour };

        var stepError = ValidateStep(query);
        if (stepError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, stepError);

        var sortError = ValidateSort(query);
        if (sortError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, sortError);

        var filterError = ValidateFilters(query);
        if (filterError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, filterError);

        var shiftError = ValidateShift(query);
        if (shiftError != null)
        {
            logger.LogWarning("RunReportWidgetQuery: shift validation failed: {Error}", shiftError);
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.ShiftHours, shiftError);
        }

        // The picked days are days in the display zone: local midnight -> UTC instant.
        var from = Zone.WallToUtc(query.From.Date);
        var toExclusive = Zone.WallToUtc(query.To.Date.AddDays(1));
        if (TakesShiftHours(query.WidgetType))
        {
            // Shift hours are site wall-clock hours on the picked date; whole hours fall on the 30-minute bucket edges.
            from = Zone.WallToUtc(query.From.Date.AddHours(query.ShiftStartHour!.Value));
            toExclusive = Zone.WallToUtc(query.From.Date.AddHours(query.ShiftEndHour!.Value));
        }

        // Compute effective columns: config.Columns if non-empty, else DefaultColumns per WidgetType
        var effectiveColumns = config.GetEffectiveColumns(query.WidgetType);

        return query.WidgetType switch
        {
            ReportWidgetType.AgentMonthly => await RunAgentMonthlyAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.AgentShiftDetail => await RunAgentShiftDetailAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.EndOfShiftAgents => await RunAgentSummaryAsync(query.WidgetType, null, tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.AgentPerformance => await RunAgentSummaryAsync(query.WidgetType, config.Mode, tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.EndOfShiftQueues => await RunQueueSummaryAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            _ => ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, $"Unknown widget type: {query.WidgetType}")
        };
    }

    private async Task<ReportWidgetResult> RunAgentMonthlyAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, RunReportWidgetQuery query, CancellationToken ct)
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

        var (filtered, columnValues) = ApplyFilters(query.WidgetType, rows, query);
        rows = filtered;
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
            ColumnValues = columnValues,
            AgentMonthly = new AgentMonthlyReportResult(resultRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunAgentShiftDetailAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, bool allRows, RunReportWidgetQuery query, CancellationToken ct)
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

        var (filtered, columnValues) = ApplyFilters(query.WidgetType, rows, query);
        rows = filtered;
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
            ColumnValues = columnValues,
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

    // The agent summary types carry ReportCaveatCodes.StatusStartBucket (status time sits in the half-hour the status
    // started); the screen owns the sentence and its three translations (PR234-V4-EOS-CAVEAT-NOT-LOCALIZED-01).

    /// <summary>
    /// Only the end-of-shift AGENTS report still takes shift hours. FEAT-REPORT-EOS-CONFIGURABLE-01: the end-of-shift queues
    /// report covers whole local days From..To with a Step; hours saved in an old widget's config are ignored.
    /// </summary>
    internal static bool TakesShiftHours(ReportWidgetType t) => t is ReportWidgetType.EndOfShiftAgents;

    internal static string? ValidateStep(RunReportWidgetQuery q)
    {
        if (q.Step is not null && q.WidgetType != ReportWidgetType.EndOfShiftQueues)
            return "The interval step applies only to the end-of-shift queues report";
        if (q.Step is not null && !Enum.IsDefined(q.Step.Value))
            return "Unknown interval step";
        if (q.WidgetType == ReportWidgetType.EndOfShiftQueues && (q.ShiftStartHour.HasValue || q.ShiftEndHour.HasValue))
            return "The end-of-shift queues report takes dates from-to, not shift hours";
        return null;
    }

    internal static string? ValidateShift(RunReportWidgetQuery q)
    {
        if (!TakesShiftHours(q.WidgetType))
            return q.ShiftStartHour.HasValue || q.ShiftEndHour.HasValue
                ? "Shift hours apply only to the end-of-shift agents report"
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

    // ── FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01 (contract 07:23:21Z) ──────────────────────────────────────────────────
    // The rows are computed in memory, so a filter is an ordinary value test on the final row (after grouping and derived
    // values): no SQL is built from it, "%" / "_" are plain characters, and it only removes rows of the scoped result -
    // it can never add one. The checkbox list is built from the same scoped rows, so it cannot show a value from outside.
    // Column kinds and which columns take a funnel: ReportColumns (one rule with the screen).

    /// <summary>Longest filter text / picked value accepted (a login or a name is at most 100 characters in the source).</summary>
    public const int FilterMaxLength = 100;

    /// <summary>Most picked values in one column filter (= the AgentIds limit of the report config).</summary>
    public const int FilterMaxValues = 500;

    /// <summary>Longest checkbox list returned for one column; beyond it Truncated is set and the user narrows by text.</summary>
    public const int ColumnValuesLimit = 1000;

    private static readonly HashSet<string> TextOps = new(StringComparer.OrdinalIgnoreCase) { "contains", "equal", "startsWith", "endsWith" };
    private static readonly HashSet<string> RangeOps = new(StringComparer.OrdinalIgnoreCase) { "greater", "less", "between" };

    private static bool IsNumber(ReportColumnKind k) =>
        k is ReportColumnKind.Count or ReportColumnKind.DurationMs or ReportColumnKind.DurationSec or ReportColumnKind.Percent;

    private static bool IsTime(ReportColumnKind k) => k is ReportColumnKind.DateTime or ReportColumnKind.Date;

    /// <summary>FEAT-REPORT-QUEUE-COLUMN-SORT-01: a sort column of the queues report must be one of its columns (a white list,
    /// never an arbitrary name into reflection). Other types ignore the sort.</summary>
    internal static string? ValidateSort(RunReportWidgetQuery q)
    {
        if (q.SortColumn is null || q.WidgetType != ReportWidgetType.EndOfShiftQueues)
            return null;
        return ReportColumns.Find(q.WidgetType, q.SortColumn) is null ? "Unknown sort column" : null;
    }

    internal static string? ValidateFilters(RunReportWidgetQuery q)
    {
        var filters = q.Filters ?? Array.Empty<ReportColumnFilter>();
        var columns = ReportColumns.For(q.WidgetType);
        if (columns.Count == 0 && (filters.Count > 0 || q.ValuesForColumn != null))
            return "This report type takes no column filters";
        if (filters.Count > columns.Count)
            return "More filters than columns";

        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var f in filters)
        {
            if (f is null) return "Empty filter";
            var col = ReportColumns.Find(q.WidgetType, f.Column);
            if (col is null) return "Unknown filter column";
            if (!col.Filterable) return $"Column {col.Name} takes no filter";
            if (!seen.Add(col.Name)) return $"Column {col.Name} is filtered twice";

            if (col.Kind == ReportColumnKind.Text)
            {
                if (f.Op is not null && !TextOps.Contains(f.Op)) return $"{col.Name}: operator does not fit a text column";
                if (f.Number is not null || f.NumberTo is not null || f.Time is not null || f.TimeTo is not null)
                    return $"{col.Name}: a text column takes text or picked values";
                if (f.Text is { Length: > FilterMaxLength }) return $"{col.Name}: filter cannot exceed {FilterMaxLength} characters";
                if (f.Values is { Count: > 0 } && !string.IsNullOrWhiteSpace(f.Text)) return $"{col.Name}: either text or picked values, not both";
                if (f.Values is { Count: > FilterMaxValues }) return $"{col.Name}: cannot pick more than {FilterMaxValues} values";
                if (f.Values is not null && f.Values.Any(v => v is null || v.Length > FilterMaxLength))
                    return $"{col.Name}: a picked value is empty or longer than {FilterMaxLength} characters";
                continue;
            }

            // number and time columns
            if (f.Op is null || !RangeOps.Contains(f.Op)) return $"{col.Name}: operator does not fit a {col.Kind} column";
            if (f.Text is not null || f.Values is not null) return $"{col.Name}: a {col.Kind} column takes no text";
            var between = f.Op.Equals("between", StringComparison.OrdinalIgnoreCase);
            if (IsNumber(col.Kind))
            {
                if (f.Time is not null || f.TimeTo is not null) return $"{col.Name}: a number column takes a number";
                if (f.Number is null || (between && f.NumberTo is null)) return $"{col.Name}: bound missing";
                if (!double.IsFinite(f.Number.Value) || (f.NumberTo is { } t && !double.IsFinite(t))) return $"{col.Name}: bound is not a finite number";
                if (between && f.Number > f.NumberTo) return $"{col.Name}: lower bound above upper bound";
                if (!between && f.NumberTo is not null) return $"{col.Name}: one bound only";
            }
            else if (IsTime(col.Kind))
            {
                if (f.Number is not null || f.NumberTo is not null) return $"{col.Name}: a time column takes a time";
                if (f.Time is null || (between && f.TimeTo is null)) return $"{col.Name}: bound missing";
                if (between && f.Time > f.TimeTo) return $"{col.Name}: lower bound above upper bound";
                if (!between && f.TimeTo is not null) return $"{col.Name}: one bound only";
            }
            else return $"Column {col.Name} takes no filter";
        }

        if (q.ValuesForColumn != null)
        {
            var col = ReportColumns.Find(q.WidgetType, q.ValuesForColumn);
            if (col is null || !col.Filterable || col.Kind != ReportColumnKind.Text)
                return "A value list is given only for a filterable text column";
        }
        return null;
    }

    private static bool IsActive(ReportColumnFilter f) =>
        f.Values is { Count: > 0 } || !string.IsNullOrWhiteSpace(f.Text) || f.Number is not null || f.Time is not null;

    /// <summary>
    /// Does one cell pass one (already validated) filter? Text: picked values exact (ordinal), else the operator ignoring
    /// case. Number / time: greater &gt;, less &lt;, between inclusive. A null cell passes no active filter.
    /// </summary>
    internal static bool Passes(object? cell, ReportColumnKind kind, ReportColumnFilter f)
    {
        if (!IsActive(f)) return true;
        if (cell is null) return false;
        if (kind == ReportColumnKind.Text)
        {
            var value = cell.ToString()!;
            if (f.Values is { Count: > 0 }) return f.Values.Contains(value, StringComparer.Ordinal);
            var text = f.Text!.Trim();
            return (f.Op ?? "contains").ToLowerInvariant() switch
            {
                "equal" => value.Equals(text, StringComparison.OrdinalIgnoreCase),
                "startswith" => value.StartsWith(text, StringComparison.OrdinalIgnoreCase),
                "endswith" => value.EndsWith(text, StringComparison.OrdinalIgnoreCase),
                _ => value.Contains(text, StringComparison.OrdinalIgnoreCase)
            };
        }
        var op = f.Op!.ToLowerInvariant();
        if (IsNumber(kind))
        {
            var x = Convert.ToDouble(cell, System.Globalization.CultureInfo.InvariantCulture);
            return op switch
            {
                "greater" => x > f.Number!.Value,
                "less" => x < f.Number!.Value,
                _ => x >= f.Number!.Value && x <= f.NumberTo!.Value
            };
        }
        var d = (DateTime)cell;
        return op switch
        {
            "greater" => d > f.Time!.Value,
            "less" => d < f.Time!.Value,
            _ => d >= f.Time!.Value && d <= f.TimeTo!.Value
        };
    }

    /// <summary>
    /// The funnel filters on a type's final rows (all must pass), plus the checkbox list of ValuesForColumn over the same
    /// rows with every OTHER column's filter applied and its own left out (as in Excel). Before paging.
    /// </summary>
    internal static (List<T> Rows, ReportColumnValues? Values) ApplyFilters<T>(ReportWidgetType type, List<T> rows, RunReportWidgetQuery q)
    {
        var filters = q.Filters ?? Array.Empty<ReportColumnFilter>();
        if (filters.Count == 0 && q.ValuesForColumn == null) return (rows, null);

        var props = typeof(T);
        var checks = filters.Select(f =>
        {
            var col = ReportColumns.Find(type, f.Column)!;
            var prop = props.GetProperty(col.Name)!;
            return (Column: col.Name, Test: (Func<T, bool>)(row => Passes(prop.GetValue(row), col.Kind, f)));
        }).ToList();

        ReportColumnValues? values = null;
        if (q.ValuesForColumn != null)
        {
            var prop = props.GetProperty(q.ValuesForColumn)!;
            var others = checks.Where(c => c.Column != q.ValuesForColumn).ToList();
            values = ColumnValuesOf(q.ValuesForColumn,
                rows.Where(r => others.All(c => c.Test(r))).Select(r => prop.GetValue(r)?.ToString()));
        }

        return (checks.Count == 0 ? rows : rows.Where(r => checks.All(c => c.Test(r))).ToList(), values);
    }

    /// <summary>The checkbox list: distinct non-empty values, sorted, at most ColumnValuesLimit.</summary>
    public static ReportColumnValues ColumnValuesOf(string column, IEnumerable<string?> values)
    {
        var all = values.Where(v => !string.IsNullOrEmpty(v)).Select(v => v!).Distinct(StringComparer.Ordinal)
            .OrderBy(v => v, StringComparer.CurrentCultureIgnoreCase).ThenBy(v => v, StringComparer.Ordinal).ToList();
        return new ReportColumnValues(column, all.Take(ColumnValuesLimit).ToList(), all.Count, all.Count > ColumnValuesLimit);
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
        DateTime from, DateTime toExclusive, int page, bool allRows, RunReportWidgetQuery query, CancellationToken ct)
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

        // The name shown and filtered on is the one rule's (AgentNameRule, live source); the name stored in the history row
        // is the fallback. History written before the name fix carries none, so without this the column stays "-".
        var present = new HashSet<string>(intervals.Select(i => i.AgentExternalId).Where(effective.Contains));
        var liveNames = present.Count == 0
            ? (IReadOnlyDictionary<string, string>)new Dictionary<string, string>()
            : await repo.GetAgentDisplayNamesAsync(tenantId, present, ct);

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
                    liveNames.TryGetValue(g.Key.AgentExternalId, out var live) && !string.IsNullOrWhiteSpace(live)
                        ? live
                        : g.Select(x => x.AgentDisplayName).LastOrDefault(n => !string.IsNullOrEmpty(n)),
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

        // funnel filters on the final rows, before paging; the checkbox list over the whole window (FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01)
        var (filteredRows, columnValues) = ApplyFilters(type, rows, query);
        rows = filteredRows;

        var (pageRows, pageSize) = PageOf(rows, config.PageSize, page, allRows);
        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);

        return new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = effectiveColumns,
            AgentSummary = new AgentSummaryReportResult(pageRows, rows.Count, page, pageSize),
            DataThroughUtc = through,
            Incomplete = incomplete,
            CaveatCode = ReportCaveatCodes.StatusStartBucket,
            ColumnValues = columnValues
        };
    }

    private async Task<ReportWidgetResult> RunQueueSummaryAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns,
        DateTime from, DateTime toExclusive, int page, bool allRows, RunReportWidgetQuery query, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.EndOfShiftQueues;
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);

        var effective = new HashSet<string>(scopeResult.EffectiveWorkgroups);
        var intervals = await ScopedQueueIntervalsAsync(tenantId, from, toExclusive, effective, ct);

        // FEAT-REPORT-EOS-CONFIGURABLE-01: one row per (interval of the step, queue); sums of the half-hour buckets whose
        // start falls inside the interval; derived values recomputed from the sums.
        // the one rule: the viewer's own choice (on the query) -> the widget's default (editor) -> Day
        var step = query.Step ?? config.DefaultStep ?? ReportStep.Day;
        var intervalKey = new Dictionary<object, DateTime>(ReferenceEqualityComparer.Instance);   // row -> UTC interval start
        var rows = intervals
            .Where(i => effective.Contains(i.Workgroup))
            .GroupBy(i => (Interval: StepKey(i.IntervalStart, step), i.Workgroup))
            // by the UTC start (the two local 01:00 of the autumn change stay in time order), then by queue name
            .OrderBy(g => g.Key.Interval.Key)
            .ThenBy(g => g.Key.Workgroup, StringComparer.CurrentCultureIgnoreCase)
            .Select(g =>
            {
                var offered = g.Sum(i => i.Offered);
                var answered = g.Sum(i => i.Answered);
                var abandoned = g.Sum(i => i.Abandoned);
                var inSl = g.Sum(i => i.AnsweredInSl);
                var wait = g.Sum(i => i.SumWaitAnswered);
                var talk = g.Sum(i => i.SumTalk);
                var row = new QueueSummaryRow(
                    g.Key.Interval.Shown,
                    g.Key.Workgroup,
                    g.Select(i => i.QueueId).FirstOrDefault(q => q.HasValue),
                    offered, answered, abandoned, inSl, wait, talk,
                    offered == 0 ? null : abandoned * 100.0 / offered,
                    answered == 0 ? null : inSl * 100.0 / answered,
                    answered == 0 ? null : (double)wait / answered,
                    answered == 0 ? null : (double)talk / answered);
                intervalKey[row] = g.Key.Interval.Key;
                return row;
            })
            .ToList();

        var (filteredRows, columnValues) = ApplyFilters(type, rows, query);   // before paging
        rows = filteredRows;
        if (query.SortColumn is { } sortColumn)
            rows = SortQueueRows(rows, sortColumn, query.SortDescending, intervalKey);   // after the filters, before paging

        var (pageRows, pageSize) = PageOf(rows, config.PageSize, page, allRows);
        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);

        return new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = effectiveColumns,
            QueueSummary = new QueueSummaryReportResult(pageRows, rows.Count, page, pageSize),
            DataThroughUtc = through,
            Incomplete = incomplete,
            ColumnValues = columnValues,
            Step = step,
            PartialFirst = StepKey(from, step).Key != from,
            PartialLast = StepKey(toExclusive, step).Key != toExclusive
        };
    }

    /// <summary>
    /// FEAT-REPORT-QUEUE-COLUMN-SORT-01: the rows ordered by one (white-listed) column. Nulls are always last, whatever the
    /// direction; the sort is stable, so equal values keep the default order (interval, then queue). IntervalStart sorts
    /// by the UTC start of the interval, so the two local "01:00" rows of the autumn change never swap.
    /// </summary>
    internal static List<QueueSummaryRow> SortQueueRows(
        List<QueueSummaryRow> rows, string column, bool descending, IReadOnlyDictionary<object, DateTime> intervalKey)
    {
        var prop = typeof(QueueSummaryRow).GetProperty(column)
            ?? throw new ArgumentException("not a column of the queues report: " + column, nameof(column));
        object? Value(QueueSummaryRow r) =>
            column == nameof(QueueSummaryRow.IntervalStart) ? intervalKey[r] : prop.GetValue(r);
        IComparer<object?> comparer = prop.PropertyType == typeof(string)
            ? Comparer<object?>.Create((a, b) => StringComparer.CurrentCultureIgnoreCase.Compare((string?)a, (string?)b))
            : Comparer<object?>.Default;

        var withValue = rows.Where(r => Value(r) is not null);
        var ordered = descending ? withValue.OrderByDescending(Value, comparer) : withValue.OrderBy(Value, comparer);
        return ordered.Concat(rows.Where(r => Value(r) is null)).ToList();
    }

    /// <summary>
    /// The interval a half-hour bucket (UTC start) belongs to, for a step. Key = the UTC instant the interval starts (so the
    /// repeated local hour of the autumn change gives two intervals, never one mixing two real hours - coordinator
    /// 09:05:19Z, variant (a)); Shown = that start in site wall-clock time. Day: the local date, whatever its length
    /// (23 / 24 / 25 hours).
    /// </summary>
    internal (DateTime Key, DateTime Shown) StepKey(DateTime bucketUtc, ReportStep step)
    {
        var utc = DateTime.SpecifyKind(bucketUtc, DateTimeKind.Utc);
        var local = Zone.ToDisplay(utc);
        switch (step)
        {
            case ReportStep.HalfHour:
                return (utc, local);
            case ReportStep.Month:
            {
                var month = new DateTime(local.Year, local.Month, 1);
                return (Zone.WallToUtc(month), month);
            }
            case ReportStep.Year:
            {
                var year = new DateTime(local.Year, 1, 1);
                return (Zone.WallToUtc(year), year);
            }
            case ReportStep.Hour:
            {
                var localHour = new DateTime(local.Year, local.Month, local.Day, local.Hour, 0, 0, DateTimeKind.Unspecified);
                return (utc - (local - localHour), localHour);   // the UTC start of the local hour this bucket is in
            }
            default:
            {
                var day = local.Date;
                return (Zone.WallToUtc(day), day);
            }
        }
    }
}
