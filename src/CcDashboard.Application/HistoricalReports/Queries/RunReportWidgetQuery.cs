using CcDashboard.Domain.Domain.Reports;
using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// Single entry point for running a report widget.
/// SF-BI-001: Scope + validation happen SERVER-SIDE inside this handler — frontend CANNOT bypass.
/// </summary>
public record RunReportWidgetQuery(
    ReportWidgetType WidgetType,
    string ConfigJson,
    DateTime From,
    DateTime To,
    int Page = 1,
    Guid? TenantId = null,
    bool AllRows = false,
    // FEAT-REPORT-EOS-*-01: shift hours (site wall clock) on the single date From; required for EndOfShiftAgents, empty otherwise
    // (FEAT-REPORT-EOS-CONFIGURABLE-01: the queues report takes From..To and a Step instead).
    int? ShiftStartHour = null,
    int? ShiftEndHour = null,
    // FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01 (contract 07:23:21Z): funnel filters on any column of a table report, one per
    // column, all must match; applied to the final rows (after grouping and derived values), before sorting and paging,
    // in memory - never in SQL. Column kinds and which columns take a funnel: ReportColumns.For(type).
    IReadOnlyList<ReportColumnFilter>? Filters = null,
    // When set (a Text column), the result also carries the distinct values of that column over the WHOLE window and scope
    // (not the page), with the filters of the OTHER columns applied and its own left out - the checkbox list.
    string? ValuesForColumn = null,
    // FEAT-REPORT-EOS-CONFIGURABLE-01: the interval of the end-of-shift queues report (null = Day); other types refuse it.
    ReportStep? Step = null
) : IRequest<ReportWidgetResult>;

/// <summary>FEAT-REPORT-EOS-CONFIGURABLE-01: the interval of one row of the end-of-shift queues report.</summary>
/// Month / Year (operator 2026-11-07 12:31, contract 10:32:55Z): the local month / year of the site; IntervalStart = local
/// 1st of the month / 1 January 00:00. Only the days inside From..To are summed (see ReportWidgetResult.PartialFirst/Last).
/// New values are appended - the numbers of the existing ones do not move.
public enum ReportStep
{
    Day,
    Hour,
    HalfHour,
    Month,
    Year
}

/// <summary>
/// FEAT-REPORT-EOS-CONFIGURABLE-01: the queue reports taken out of the product (operator 2026-11-07 10:46). A saved widget of
/// such a type still opens and says so (ErrorCode retired); a new one cannot be created.
/// </summary>
public static class RetiredReports
{
    public static readonly IReadOnlySet<ReportWidgetType> Types = new HashSet<ReportWidgetType>
    {
        ReportWidgetType.QueueInterval,
        ReportWidgetType.QueueWaitTime,
        ReportWidgetType.Distribution
    };

    public static bool IsRetired(ReportWidgetType type) => Types.Contains(type);
}

/// <summary>
/// One funnel filter. Column = a field name from ReportColumns.For(type). Op by the column kind:
/// Text - "contains" (default) / "equal" / "startsWith" / "endsWith" on Text (ignoring case), OR Values (exact, any of
///        them), never both;
/// Count / DurationMs / DurationSec / Percent - "greater" (&gt; Number), "less" (&lt; Number), "between"
///        (Number &lt;= x &lt;= NumberTo, both bounds included), in the column's own unit;
/// DateTime / Date - the same three operators on Time / TimeTo (site wall clock, as the cell shows it).
/// A null cell matches no number or time filter.
/// </summary>
public record ReportColumnFilter(
    string Column,
    string? Op = null,
    string? Text = null,
    IReadOnlyList<string>? Values = null,
    double? Number = null,
    double? NumberTo = null,
    DateTime? Time = null,
    DateTime? TimeTo = null);

/// <summary>Distinct values of one column for the checkbox list; Truncated = more than the limit exist.</summary>
public record ReportColumnValues(string Column, IReadOnlyList<string> Values, int TotalCount, bool Truncated);

/// <summary>
/// Tagged union result: exactly one of the typed results is populated based on WidgetType.
/// Frontend discriminates on WidgetType to access the correct result.
/// </summary>
public record ReportWidgetResult
{
    /// <summary>The widget type that was executed.</summary>
    public required ReportWidgetType WidgetType { get; init; }

    /// <summary>True if access was denied (empty PG for non-Superadmin).</summary>
    public bool Denied { get; init; }

    /// <summary>Error message if validation or scope resolution failed. For the log only - never shown as is.</summary>
    public string? Error { get; init; }

    /// <summary>Machine code of the error (<see cref="ReportReasonCodes"/>), set whenever Error is; the screen shows this.</summary>
    public string? ErrorCode { get; init; }

    /// <summary>
    /// Effective columns to render: config.Columns if specified, else DefaultColumns for the widget type.
    /// Frontend uses this to know which columns to display when config had no explicit selection.
    /// </summary>
    public IReadOnlyList<string>? EffectiveColumns { get; init; }

    /// <summary>QueueInterval result (populated when WidgetType = QueueInterval).</summary>
    public QueueIntervalReportResult? QueueInterval { get; init; }

    /// <summary>QueueWaitTime result (populated when WidgetType = QueueWaitTime).</summary>
    public QueueWaitTimeReportResult? QueueWaitTime { get; init; }

    /// <summary>AgentMonthly result (populated when WidgetType = AgentMonthly).</summary>
    public AgentMonthlyReportResult? AgentMonthly { get; init; }

    /// <summary>AgentShiftDetail result (populated when WidgetType = AgentShiftDetail).</summary>
    public AgentShiftDetailReportResult? AgentShiftDetail { get; init; }

    /// <summary>Distribution result (populated when WidgetType = Distribution).</summary>
    public DistributionReportResult? Distribution { get; init; }

    /// <summary>EndOfShiftAgents / AgentPerformance result.</summary>
    public AgentSummaryReportResult? AgentSummary { get; init; }

    /// <summary>EndOfShiftQueues result.</summary>
    public QueueSummaryReportResult? QueueSummary { get; init; }

    /// <summary>
    /// FEAT-REPORT-EOS-*-01: the instant the historical aggregation has reached (UTC); null when nothing was aggregated yet.
    /// Set for the three summary types.
    /// </summary>
    public DateTime? DataThroughUtc { get; init; }

    /// <summary>True when the window ends after DataThroughUtc: the newest part of the window is not aggregated yet.</summary>
    public bool Incomplete { get; init; }

    /// <summary>
    /// PR234-V4-EOS-CAVEAT-NOT-LOCALIZED-01: code (<see cref="ReportCaveatCodes"/>) of a known limit of the numbers, which
    /// the screen translates into the report hint; null when none. Never free text. Set for the agent summary types.
    /// </summary>
    public string? CaveatCode { get; init; }

    /// <summary>The interval the rows are grouped by (end-of-shift queues); null for the other types.</summary>
    public ReportStep? Step { get; init; }

    /// <summary>
    /// FEAT-REPORT-EOS-CONFIGURABLE-01 (Month/Year, 10:38:32Z): the first / last interval of the step is cut by the period
    /// (e.g. Month from 05.11): its row sums only the days inside From..To. Set from the period, not from the rows.
    /// Always false for Day / Hour / HalfHour (the period is whole days).
    /// </summary>
    public bool PartialFirst { get; init; }

    /// <summary>See <see cref="PartialFirst"/>.</summary>
    public bool PartialLast { get; init; }

    /// <summary>The checkbox list asked for with ValuesForColumn; null otherwise.</summary>
    public ReportColumnValues? ColumnValues { get; init; }

    /// <summary>Create a denied result.</summary>
    public static ReportWidgetResult CreateDenied(ReportWidgetType type) => new()
    {
        WidgetType = type,
        Denied = true
    };

    /// <summary>Create an error result. The code is required: an error without a code cannot be built.</summary>
    public static ReportWidgetResult CreateError(ReportWidgetType type, string code, string error) => new()
    {
        WidgetType = type,
        ErrorCode = string.IsNullOrWhiteSpace(code) ? throw new ArgumentException("error code required", nameof(code)) : code,
        Error = error
    };
}

/// <summary>Known limits of report numbers; the screen owns the sentence and its translations.</summary>
public static class ReportCaveatCodes
{
    /// <summary>
    /// hist_agent_intervals puts a status duration into the half-hour in which the status STARTED: at the edges of the
    /// window a status that began before the start is missing, and one that began inside counts in full.
    /// </summary>
    public const string StatusStartBucket = "status-start-bucket";
}

/// <summary>
/// Why a widget produced no data sheet / no rows - the codes the screen translates. A new reason gets a new code;
/// the free-text Error/Reason stays in the log.
/// </summary>
public static class ReportReasonCodes
{
    public const string Denied = "denied";
    public const string NoData = "no-data";
    public const string ShiftHours = "shift-hours";
    public const string InvalidConfig = "invalid-config";
    /// <summary>FEAT-REPORT-EOS-CONFIGURABLE-01: the report type was taken out of the product.</summary>
    public const string Retired = "retired";

    public static readonly IReadOnlySet<string> All = new HashSet<string> { Denied, NoData, ShiftHours, InvalidConfig, Retired };

    /// <summary>
    /// Export only: the widget failed with an empty or unrecognised code, or its run threw. Not a reason of its own -
    /// a defect to find in the log; the file is still built and the widget is still listed.
    /// </summary>
    public const string Unrecognised = "unrecognised";
}

/// <summary>
/// Distribution report result: wait time distribution buckets derived from QueueInterval/QueueWaitTime data.
/// </summary>
public record DistributionReportResult(
    IReadOnlyList<DistributionBucket> Buckets,
    int TotalCount,
    double? OverallAsa);

/// <summary>A bucket in the wait time distribution.</summary>
public record DistributionBucket(
    string Label,
    int LowerBoundSec,
    int? UpperBoundSec,
    int Count,
    double Percentage);
