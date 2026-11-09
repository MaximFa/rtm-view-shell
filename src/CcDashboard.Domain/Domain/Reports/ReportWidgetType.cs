namespace CcDashboard.Domain.Domain.Reports;

public enum ReportWidgetType
{
    QueueInterval,
    QueueWaitTime,
    AgentMonthly,
    AgentShiftDetail,
    Distribution,
    // FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-EOS-QUEUES-01 / FEAT-REPORT-AGENT-PERF-01. Stored as string: appended, never reorder.
    EndOfShiftAgents,
    EndOfShiftQueues,
    AgentPerformance,
    // FEAT-REPORT-QUEUE-TREND-COMPARE-01: a chart of the queue metrics by step, with an optional comparison period
    QueueTrend,
    // FEAT-REPORT-AGENT-STATE-TREND-01: a chart of the agents' share of logged-in time per status group, same rule as QueueTrend
    AgentStateTrend,
    // FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01: the same six groups as one donut for the period
    AgentStateDistribution
}
