namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-AGENT-PERF-01: one row per agent for the window (end of shift, period summary),
/// or per agent per local date (AgentPerformance byDate). Sums come from hist_agent_intervals; derived values from the sums.
/// Date is null except in AgentPerformance byDate mode.
/// </summary>
public record AgentSummaryRow(
    DateTime? Date,
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

/// <summary>FEAT-REPORT-EOS-QUEUES-01: one row per queue (workgroup) for the shift window.</summary>
public record QueueSummaryRow(
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
