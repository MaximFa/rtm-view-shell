using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// The English human name of a report type, for places that have no localizer (the xlsx export: a widget saved without a
/// title used to give its sheet the enum name, "EndOfShiftQueues"). The values are the en-US resources Report_{type}
/// (Web SharedResources.en-US.resx) - the names the screen shows in English; ReportTypeNamesGuardTests measures them
/// against that file for every type, so the two cannot drift apart.
/// </summary>
public static class ReportTypeNames
{
    public static string English(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "Queue Interval",
        ReportWidgetType.QueueWaitTime => "Queue Wait Time",
        ReportWidgetType.AgentMonthly => "Agent Monthly",
        ReportWidgetType.AgentShiftDetail => "Agent Shift Detail",
        ReportWidgetType.Distribution => "Distribution",
        ReportWidgetType.EndOfShiftQueues => "Queue Report",
        ReportWidgetType.EndOfShiftAgents => "End of shift — agents",
        ReportWidgetType.AgentPerformance => "Agent Performance",
        _ => type.ToString()   // a value without a name (never for a defined type - see the guard)
    };
}
