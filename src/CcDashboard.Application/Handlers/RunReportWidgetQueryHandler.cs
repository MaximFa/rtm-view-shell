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

        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: no report takes shift hours any more - both end-of-shift reports cover the
        // whole local days From..To with a step; hours saved in an old widget's config are ignored, hours on a query refused.

        var stepError = ValidateStep(query);
        if (stepError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, stepError);

        var sortError = ValidateSort(query);
        if (sortError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, sortError);

        var filterError = ValidateFilters(query);
        if (filterError != null)
            return ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, filterError);

        // The picked days are days in the display zone: local midnight -> UTC instant.
        var from = Zone.WallToUtc(query.From.Date);
        var toExclusive = Zone.WallToUtc(query.To.Date.AddDays(1));

        // the one rule of the row mode (agents): the viewer's own choice -> the widget's default (editor) -> Summary
        var rowMode = query.RowMode ?? config.DefaultRowMode ?? ReportRowMode.Summary;

        // Compute effective columns: config.Columns if non-empty, else DefaultColumns per WidgetType (and the row mode)
        var effectiveColumns = config.GetEffectiveColumns(query.WidgetType, rowMode);

        return query.WidgetType switch
        {
            ReportWidgetType.EndOfShiftAgents => await RunAgentSummaryAsync(rowMode, tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.EndOfShiftQueues => await RunQueueSummaryAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, query.AllRows, query, ct),
            ReportWidgetType.QueueTrend => await RunQueueTrendAsync(tenantId, config, from, toExclusive, query, ct),
            ReportWidgetType.AgentStateTrend => await RunAgentStateTrendAsync(tenantId, config, from, toExclusive, query, ct),
            ReportWidgetType.AgentStateDistribution => await RunAgentStateDistributionAsync(tenantId, config, from, toExclusive, query, ct),
            _ => ReportWidgetResult.CreateError(query.WidgetType, ReportReasonCodes.InvalidConfig, $"Unknown widget type: {query.WidgetType}")
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

    /// <summary>The report types that take a step (and From..To). FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: both end-of-shift
    /// reports; no report takes shift hours any more.</summary>
    internal static bool TakesStep(ReportWidgetType t) =>
        t is ReportWidgetType.EndOfShiftQueues or ReportWidgetType.EndOfShiftAgents || IsTrend(t);

    /// <summary>The trend charts (FEAT-REPORT-QUEUE-TREND-COMPARE-01, FEAT-REPORT-AGENT-STATE-TREND-01): a grid by step, an
    /// optional comparison period; no columns, filters or sort; not exported.</summary>
    internal static bool IsTrend(ReportWidgetType t) => t is ReportWidgetType.QueueTrend or ReportWidgetType.AgentStateTrend;

    /// <summary>The charts: the two trends and the donut (FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01) - no columns, no sort, not
    /// exported.</summary>
    internal static bool IsChart(ReportWidgetType t) => IsTrend(t) || t is ReportWidgetType.AgentStateDistribution;

    /// <summary>The table reports that sort on the server (FEAT-REPORT-QUEUE-COLUMN-SORT-01); a chart has no columns.</summary>
    internal static bool TakesSort(ReportWidgetType t) => t is ReportWidgetType.EndOfShiftQueues or ReportWidgetType.EndOfShiftAgents;

    internal static string? ValidateStep(RunReportWidgetQuery q)
    {
        if (q.Step is not null && !TakesStep(q.WidgetType))
            return "The interval step applies only to the queues, agents and queue trend reports";
        if (q.Step is not null && !Enum.IsDefined(q.Step.Value))
            return "Unknown interval step";
        if (q.RowMode is not null && q.WidgetType != ReportWidgetType.EndOfShiftAgents)
            return "The row mode applies only to the end-of-shift agents report";
        if (q.RowMode is not null && !Enum.IsDefined(q.RowMode.Value))
            return "Unknown row mode";
        if (q.ShiftStartHour.HasValue || q.ShiftEndHour.HasValue)
            return "Reports take dates from-to, not shift hours";
        if (q.CompareFrom is not null && !IsTrend(q.WidgetType))
            return "A comparison period applies only to the trend charts";
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
        if (q.SortColumn is not null && IsChart(q.WidgetType))
            return "A chart has no columns to sort";
        if (q.SortColumn is null || !TakesSort(q.WidgetType))
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

    /// <summary>
    /// The agents a widget shows: its scope, narrowed (never widened) by the agents picked in its config. One rule for the
    /// report run and for the last-day-with-data query (FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01, agents).
    /// </summary>
    internal static (HashSet<string> Effective, IReadOnlyList<string> Dropped) NarrowToPickedAgents(
        IReadOnlySet<string> scoped, IReadOnlyList<string>? picked) => NarrowToPicked(scoped, picked);

    /// <summary>A widget's set: its scope, narrowed (never widened) by what its config picked (agents, or the trend's
    /// queues). One rule for the runs and the last-day-with-data query.</summary>
    internal static (HashSet<string> Effective, IReadOnlyList<string> Dropped) NarrowToPicked(
        IReadOnlySet<string> scoped, IReadOnlyList<string>? picked)
    {
        var effective = new HashSet<string>(scoped);
        if (picked is not { Count: > 0 })
            return (effective, Array.Empty<string>());
        var requested = new HashSet<string>(picked);
        var dropped = requested.Where(id => !effective.Contains(id)).ToList();
        effective.IntersectWith(requested);
        return (effective, dropped);
    }

    private async Task<ReportWidgetResult> RunAgentSummaryAsync(
        ReportRowMode rowMode, Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns,
        DateTime from, DateTime toExclusive, int page, bool allRows, RunReportWidgetQuery query, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.EndOfShiftAgents;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);

        // The agent filter only narrows the scope (SF-BI-001); requested ids outside it are dropped and logged (SF-BI-002).
        var (effective, dropped) = NarrowToPickedAgents(scopeResult.EffectiveAgentIds, config.AgentIds);
        if (dropped.Count > 0)
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} agents in {Type}, {DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId, config.AgentIds!.Count, type, dropped.Count, string.Join(", ", dropped.Take(5)));

        var intervals = await ScopedAgentIntervalsAsync(tenantId, from, toExclusive, effective, ct);

        // The name shown and filtered on is the one rule's (AgentNameRule, live source); the name stored in the history row
        // is the fallback. History written before the name fix carries none, so without this the column stays "-".
        var present = new HashSet<string>(intervals.Select(i => i.AgentExternalId).Where(effective.Contains));
        var liveNames = present.Count == 0
            ? (IReadOnlyDictionary<string, string>)new Dictionary<string, string>()
            : await repo.GetAgentDisplayNamesAsync(tenantId, present, ct);

        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: Summary = one row per agent for the whole period (no step); ByStep = one row
        // per (interval of the step, agent), the interval by the same StepKey as the queues report.
        var byStep = rowMode == ReportRowMode.ByStep;
        ReportStep? step = byStep ? query.Step ?? config.DefaultStep ?? ReportStep.Day : null;
        var intervalKey = new Dictionary<object, DateTime>(ReferenceEqualityComparer.Instance);   // row -> UTC interval start
        var rows = intervals
            .Where(i => effective.Contains(i.AgentExternalId))
            .GroupBy(i => (Interval: step is { } st ? StepKey(i.IntervalStart, st) : ((DateTime Key, DateTime Shown)?)null, i.AgentExternalId))
            .Select(g =>
            {
                long Sum(Func<CcDashboard.Domain.Domain.Historical.HistAgentInterval, long> f) => g.Sum(f);
                var available = Sum(x => x.SumAvailableMs);
                var onphone = Sum(x => x.SumOnphoneMs);
                var hold = Sum(x => x.SumHoldMs);
                var paperwork = Sum(x => x.SumPaperworkMs);
                var handled = g.Sum(x => x.Handled);
                var occDenom = available + onphone + paperwork;
                var row = new AgentSummaryRow(
                    g.Key.Interval?.Shown,
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
                if (g.Key.Interval is { } iv)
                    intervalKey[row] = iv.Key;
                return row;
            })
            // by the UTC start of the interval (the two local 01:00 of the autumn change stay in time order), then by name
            .OrderBy(r => intervalKey.TryGetValue(r, out var k) ? k : DateTime.MinValue)
            .ThenBy(r => r.AgentDisplayName ?? r.AgentExternalId, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(r => r.AgentExternalId, StringComparer.Ordinal)
            .ToList();

        // funnel filters on the final rows, before paging; the checkbox list over the whole window (FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01)
        var (filteredRows, columnValues) = ApplyFilters(type, rows, query);
        rows = filteredRows;
        if (query.SortColumn is { } sortColumn)
            rows = SortRows(rows, sortColumn, query.SortDescending, intervalKey);   // after the filters, before paging

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
            ColumnValues = columnValues,
            Step = step,
            RowMode = rowMode,
            PartialFirst = step is { } s1 && StepKey(from, s1).Key != from,
            PartialLast = step is { } s2 && StepKey(toExclusive, s2).Key != toExclusive
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
                var row = QueueRow(g.Key.Interval.Shown, g.Key.Workgroup, g);
                intervalKey[row] = g.Key.Interval.Key;
                return row;
            })
            .ToList();

        var (filteredRows, columnValues) = ApplyFilters(type, rows, query);   // before paging
        rows = filteredRows;
        if (query.SortColumn is { } sortColumn)
            rows = SortRows(rows, sortColumn, query.SortDescending, intervalKey);   // after the filters, before paging

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
    /// The one formula of a queue row: sums of the half-hour buckets, derived values from the sums (never the mean of
    /// per-interval percentages). Used by the queues report (per queue) and the queue trend chart (over its queues).
    /// </summary>
    internal static QueueSummaryRow QueueRow(DateTime shown, string workgroup,
        IEnumerable<CcDashboard.Domain.Domain.Historical.HistQueueInterval> buckets)
    {
        var g = buckets as IReadOnlyCollection<CcDashboard.Domain.Domain.Historical.HistQueueInterval> ?? buckets.ToList();
        var offered = g.Sum(i => i.Offered);
        var answered = g.Sum(i => i.Answered);
        var abandoned = g.Sum(i => i.Abandoned);
        var inSl = g.Sum(i => i.AnsweredInSl);
        var wait = g.Sum(i => i.SumWaitAnswered);
        var talk = g.Sum(i => i.SumTalk);
        return new QueueSummaryRow(
            shown,
            workgroup,
            g.Select(i => i.QueueId).FirstOrDefault(q => q.HasValue),
            offered, answered, abandoned, inSl, wait, talk,
            offered == 0 ? null : abandoned * 100.0 / offered,
            answered == 0 ? null : inSl * 100.0 / answered,
            answered == 0 ? null : (double)wait / answered,
            answered == 0 ? null : (double)talk / answered);
    }

    // ── FEAT-REPORT-QUEUE-TREND-COMPARE-01 ──────────────────────────────────────────────────────────────────────────

    /// <summary>Most intervals in one period of the trend chart (half-hours: ~41 days); beyond it: choose a larger step.</summary>
    public const int TrendMaxPoints = 2000;

    /// <summary>The intervals of a period by step, in time order - built from the period, not from the data, so an interval
    /// without data is still a point. Key = UTC start (the two autumn 01:00 hours stay two), Shown = local start.</summary>
    internal List<(DateTime Key, DateTime Shown)> TrendGrid(DateTime fromUtc, DateTime toExclusiveUtc, ReportStep step)
    {
        var grid = new List<(DateTime Key, DateTime Shown)>();
        var seen = new HashSet<DateTime>();
        for (var t = DateTime.SpecifyKind(fromUtc, DateTimeKind.Utc); t < toExclusiveUtc; t = t.AddMinutes(30))
        {
            var k = StepKey(t, step);
            if (seen.Add(k.Key)) grid.Add(k);
            if (grid.Count > TrendMaxPoints) break;
        }
        return grid;
    }

    private async Task<ReportWidgetResult> RunQueueTrendAsync(
        Guid tenantId, ReportWidgetConfig config, DateTime from, DateTime toExclusive, RunReportWidgetQuery query, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.QueueTrend;
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);
        var (effective, dropped) = NarrowToPicked(scopeResult.EffectiveWorkgroups, config.Workgroups);
        if (dropped.Count > 0)
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} queues in {Type}, {DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId, config.Workgroups!.Count, type, dropped.Count, string.Join(", ", dropped.Take(5)));

        // one value per interval over all the widget's queues, by the queues report's own formula
        var empty = QueueRow(default, "", Array.Empty<CcDashboard.Domain.Domain.Historical.HistQueueInterval>());
        return await RunTrendAsync(type, tenantId, config, from, toExclusive, query, ReportWidgetConfig.QueueTrendMetrics,
            (f, t) => ScopedQueueIntervalsAsync(tenantId, f, t, effective, ct),
            i => i.IntervalStart,
            bucket =>
            {
                var row = bucket.Count == 0 ? empty : QueueRow(default, "", bucket);
                return metric => typeof(QueueSummaryRow).GetProperty(metric)!.GetValue(row) switch
                {
                    null => null,
                    var v => Convert.ToDouble(v, System.Globalization.CultureInfo.InvariantCulture)
                };
            },
            (r, trend) => r with { QueueTrend = trend }, ct);
    }

    /// <summary>
    /// FEAT-REPORT-AGENT-STATE-TREND-01 (contract 20:02:22Z, accepted 20:05:25Z): the share of logged-in time per status group
    /// of one interval, summed over the agents first (never the mean of shares). Onphone = SumOnphoneMs (Hold is inside it,
    /// HistoricalAggregationService); Paperwork = SumPaperworkMs + SumUnavailableMs (operator 21:59); Other = LoggedIn minus
    /// the five (unmapped statuses, operator 22:04). No login in the interval: null for all six.
    /// </summary>
    public static IReadOnlyDictionary<string, double?> AgentStateShares(IReadOnlyCollection<CcDashboard.Domain.Domain.Historical.HistAgentInterval> bucket)
    {
        var (loggedIn, ms) = AgentStateMs(bucket);
        return ms.ToDictionary(kv => kv.Key, kv => loggedIn == 0 ? (double?)null : kv.Value * 100.0 / loggedIn);
    }

    /// <summary>
    /// The time of the six groups (ms), summed over the agents and buckets given; the one rule behind the agent state trend
    /// (per interval) and the donut (per period). FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 split it out of AgentStateShares.
    /// </summary>
    public static (long LoggedIn, IReadOnlyDictionary<string, long> Ms) AgentStateMs(IEnumerable<CcDashboard.Domain.Domain.Historical.HistAgentInterval> bucket)
    {
        var b = bucket as IReadOnlyCollection<CcDashboard.Domain.Domain.Historical.HistAgentInterval> ?? bucket.ToList();
        long loggedIn = b.Sum(i => i.SumLoggedInMs);
        long available = b.Sum(i => i.SumAvailableMs);
        long onphone = b.Sum(i => i.SumOnphoneMs);
        long paperwork = b.Sum(i => i.SumPaperworkMs + i.SumUnavailableMs);
        long brk = b.Sum(i => i.SumBreakMs);
        long training = b.Sum(i => i.SumTrainingMs);
        long other = loggedIn - (available + onphone + paperwork + brk + training);
        return (loggedIn, new Dictionary<string, long>
        {
            ["Available"] = available,
            ["Onphone"] = onphone,
            ["Paperwork"] = paperwork,
            ["Break"] = brk,
            ["Training"] = training,
            ["Other"] = other,
        });
    }

    private async Task<ReportWidgetResult> RunAgentStateDistributionAsync(
        Guid tenantId, ReportWidgetConfig config, DateTime from, DateTime toExclusive, RunReportWidgetQuery query, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.AgentStateDistribution;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);
        var (effective, dropped) = NarrowToPicked(scopeResult.EffectiveAgentIds, config.AgentIds);
        if (dropped.Count > 0)
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} agents in {Type}, {DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId, config.AgentIds!.Count, type, dropped.Count, string.Join(", ", dropped.Take(5)));

        // the period the screen sent (the widget's own, or the page's - the screen's one rule, coordinator 04:43:29Z)
        var intervals = await ScopedAgentIntervalsAsync(tenantId, from, toExclusive, effective, ct);
        var (loggedIn, ms) = AgentStateMs(intervals);
        if (ms["Other"] < 0)
            logger.LogWarning("AgentStateDistribution: a negative Other ({OtherMs} ms) - status durations larger than the login time", ms["Other"]);

        var groups = ReportWidgetConfig.AgentStateTrendMetrics
            .Select(m => new AgentStateGroup(m.Name, ms[m.Name], loggedIn == 0 ? null : ms[m.Name] * 100.0 / loggedIn))
            .ToList();
        var agents = intervals.Where(i => i.SumLoggedInMs > 0).Select(i => i.AgentExternalId).Distinct().Count();

        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);
        return new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = Array.Empty<string>(),
            AgentStateDistribution = new AgentStateDistributionResult(query.From.Date, query.To.Date, loggedIn, agents, groups),
            DataThroughUtc = through,
            Incomplete = incomplete,
            CaveatCode = ReportCaveatCodes.StatusStartBucket
        };
    }

    private async Task<ReportWidgetResult> RunAgentStateTrendAsync(
        Guid tenantId, ReportWidgetConfig config, DateTime from, DateTime toExclusive, RunReportWidgetQuery query, CancellationToken ct)
    {
        const ReportWidgetType type = ReportWidgetType.AgentStateTrend;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(type);
        var (effective, dropped) = NarrowToPicked(scopeResult.EffectiveAgentIds, config.AgentIds);
        if (dropped.Count > 0)
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} agents in {Type}, {DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId, config.AgentIds!.Count, type, dropped.Count, string.Join(", ", dropped.Take(5)));

        var negativeOther = 0;
        var result = await RunTrendAsync(type, tenantId, config, from, toExclusive, query, ReportWidgetConfig.AgentStateTrendMetrics,
            (f, t) => ScopedAgentIntervalsAsync(tenantId, f, t, effective, ct),
            i => i.IntervalStart,
            bucket =>
            {
                var shares = AgentStateShares(bucket);
                if (shares["Other"] < 0) negativeOther++;
                return metric => shares[metric];
            },
            (r, trend) => r with { AgentStateTrend = trend, CaveatCode = ReportCaveatCodes.StatusStartBucket }, ct);

        // coordinator 20:05:25Z: a negative Other (a negative duration in the source) is shown as it is, never hidden - and
        // counted in the log (a count only, no agent ids), so the PROBE in .coord/measure/agent-state-trend-1108 is run if needed
        if (negativeOther > 0)
            logger.LogWarning("AgentStateTrend: {Count} interval(s) with a negative Other share (status durations larger than the login time)", negativeOther);
        return result;
    }

    /// <summary>
    /// FEAT-REPORT-QUEUE-TREND-COMPARE-01 / FEAT-REPORT-AGENT-STATE-TREND-01: the one rule of a trend chart - the grid of the
    /// main period by step (from the period, not the data), the comparison from CompareFrom with the main period's length in
    /// local days, paired by index (missing = null, extra dropped), the point limit, the freshness. Each chart gives only how
    /// its buckets are read and what one interval's values are.
    /// </summary>
    private async Task<ReportWidgetResult> RunTrendAsync<TBucket>(
        ReportWidgetType type, Guid tenantId, ReportWidgetConfig config, DateTime from, DateTime toExclusive, RunReportWidgetQuery query,
        IReadOnlyList<ReportColumn> metrics,
        Func<DateTime, DateTime, Task<IReadOnlyList<TBucket>>> read,
        Func<TBucket, DateTime> bucketStart,
        Func<IReadOnlyCollection<TBucket>, Func<string, double?>> valuesOf,
        Func<ReportWidgetResult, QueueTrendResult, ReportWidgetResult> place,
        CancellationToken ct)
    {
        var step = query.Step ?? config.DefaultStep ?? ReportStep.Day;

        // the comparison period: from its first local day, as many local days as the main period (operator 18:08)
        DateTime? cFrom = null, cToExclusive = null;
        if (query.CompareFrom is { } compareDay)
        {
            var days = (query.To.Date - query.From.Date).Days + 1;
            cFrom = Zone.WallToUtc(compareDay.Date);
            cToExclusive = Zone.WallToUtc(compareDay.Date.AddDays(days));
        }

        var grid = TrendGrid(from, toExclusive, step);
        var compareGrid = cFrom is null ? null : TrendGrid(cFrom.Value, cToExclusive!.Value, step);
        if (grid.Count > TrendMaxPoints || compareGrid?.Count > TrendMaxPoints)
            return ReportWidgetResult.CreateError(type, ReportReasonCodes.InvalidConfig,
                $"More than {TrendMaxPoints} intervals in the period - choose a larger step");

        async Task<List<Func<string, double?>>> Values(DateTime f, DateTime t, List<(DateTime Key, DateTime Shown)> g)
        {
            var byKey = (await read(f, t))
                .GroupBy(b => StepKey(bucketStart(b), step).Key)
                .ToDictionary(x => x.Key, x => (IReadOnlyCollection<TBucket>)x.ToList());
            return g.Select(p => valuesOf(byKey.TryGetValue(p.Key, out var b) ? b : Array.Empty<TBucket>())).ToList();
        }

        var main = await Values(from, toExclusive, grid);
        var compare = cFrom is null ? null : await Values(cFrom.Value, cToExclusive!.Value, compareGrid!);

        var series = metrics.Select(m => new QueueTrendSeries(
                m.Name,
                m.Kind,
                main.Select(v => v(m.Name)).ToList(),
                compare is null ? null
                    // paired by index (the 1st with the 1st); comparison intervals past the main grid are dropped, missing are null
                    : grid.Select((_, i) => i < compare.Count ? compare[i](m.Name) : null).ToList()))
            .ToList();

        var (through, incomplete) = await FreshnessAsync(tenantId, toExclusive, ct);
        var compareDays = (query.To.Date - query.From.Date).Days;
        var trend = new QueueTrendResult(
            step,
            grid.Select(p => p.Shown).ToList(),
            compareGrid?.Take(grid.Count).Select(p => p.Shown).ToList(),
            series,
            query.From.Date,
            query.To.Date,
            query.CompareFrom?.Date,
            query.CompareFrom?.Date.AddDays(compareDays));
        return place(new ReportWidgetResult
        {
            WidgetType = type,
            EffectiveColumns = Array.Empty<string>(),
            DataThroughUtc = through,
            Incomplete = incomplete,
            Step = step
        }, trend);
    }

    /// <summary>
    /// FEAT-REPORT-QUEUE-COLUMN-SORT-01 (agents: FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01): the rows ordered by one
    /// (white-listed) column. Nulls are always last, whatever the
    /// direction; the sort is stable, so equal values keep the default order (interval, then queue). IntervalStart sorts
    /// by the UTC start of the interval, so the two local "01:00" rows of the autumn change never swap.
    /// </summary>
    internal static List<T> SortRows<T>(
        List<T> rows, string column, bool descending, IReadOnlyDictionary<object, DateTime> intervalKey) where T : class
    {
        var prop = typeof(T).GetProperty(column)
            ?? throw new ArgumentException("not a column of the report: " + column, nameof(column));
        // IntervalStart by the UTC start of its interval (a Summary row of the agents report has none: null, last)
        object? Value(T r) =>
            column == nameof(QueueSummaryRow.IntervalStart) ? (intervalKey.TryGetValue(r, out var k) ? (object?)k : null) : prop.GetValue(r);
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
