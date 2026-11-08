namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-AGENT-PERF-01: one row per agent for the window (end of shift, period summary),
/// or per agent per local date (AgentPerformance byDate). Sums come from hist_agent_intervals; derived values from the sums.
/// Date is null except in AgentPerformance byDate mode.
/// </summary>
/// <summary>
/// FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: IntervalStart = the start of the interval of the step in site wall-clock time
/// (ByStep), null in Summary (one row per agent for the whole period). Replaces Date (AgentPerformance ByDate, retired).
/// </summary>
public record AgentSummaryRow(
    DateTime? IntervalStart,
    string AgentExternalId,
    string? AgentDisplayName,
    long SumLoggedInMs,
    long SumAvailableMs,
    long SumOnphoneMs,
    long SumHoldMs,
    long SumPaperworkMs,
    long SumBreakMs,
    long SumTrainingMs,
    long SumUnavailableMs,
    int Handled,
    double? OccupancyPct,
    double? AgentAht,
    double? HoldPct,
    long TalkPureMs);

public record AgentSummaryReportResult(
    IReadOnlyList<AgentSummaryRow> Rows,
    int TotalCount,
    int Page,
    int PageSize);

/// <summary>
/// FEAT-REPORT-EOS-QUEUES-01 / FEAT-REPORT-EOS-CONFIGURABLE-01: one row per (interval, queue). IntervalStart = the start of
/// the interval in site wall-clock time (Day: the local date at 00:00; Hour / HalfHour: the local start of it).
/// </summary>
public record QueueSummaryRow(
    DateTime IntervalStart,
    string Workgroup,
    Guid? QueueId,
    int Offered,
    int Answered,
    int Abandoned,
    int AnsweredInSl,
    long SumWaitAnswered,
    long SumTalk,
    double? AbandonPct,
    double? SlPct,
    double? Asa,
    double? QueueAht);

/// <summary>
/// FEAT-REPORT-QUEUE-TREND-COMPARE-01 (contract 16:1xZ). Points = the intervals of the main period by step (local start);
/// ComparePoints = the intervals of the comparison period (null without one), paired with Points by index. Each series:
/// Values[i] at Points[i], CompareValues[i] at ComparePoints[i] (null where the comparison has no i-th interval). Sums over
/// the widget's queues; percentages and averages from the sums of the interval. An interval without data: counts 0,
/// derived values null.
/// </summary>
public record QueueTrendResult(
    ReportStep Step,
    IReadOnlyList<DateTime> Points,
    IReadOnlyList<DateTime>? ComparePoints,
    IReadOnlyList<QueueTrendSeries> Series,
    DateTime PeriodFrom,
    DateTime PeriodTo,
    DateTime? CompareFrom,
    DateTime? CompareTo);

/// <summary>One metric of the queue trend chart; Kind from ReportColumns (Count / Percent / DurationSec).</summary>
public record QueueTrendSeries(string Metric, ReportColumnKind Kind, IReadOnlyList<double?> Values, IReadOnlyList<double?>? CompareValues);

public record QueueSummaryReportResult(
    IReadOnlyList<QueueSummaryRow> Rows,
    int TotalCount,
    int Page,
    int PageSize);

/// <summary>AgentPerformance mode: one row per agent for the period, or one row per agent per local date with data.</summary>
public enum AgentPerformanceMode
{
    Summary,
    ByDate
}
