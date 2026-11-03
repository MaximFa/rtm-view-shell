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
    AgentPerformance
}
