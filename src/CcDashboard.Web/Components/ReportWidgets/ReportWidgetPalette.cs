using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// Which report widget types are FINISHED, and how each one is presented in the palette.
///
/// Before this, the palette listed Enum.GetValues&lt;ReportWidgetType&gt;() while the names,
/// descriptions and icons were a switch covering the five old types only. So the three new types
/// appeared in the palette the moment the enum grew - with a bare technical name, an empty
/// description and a placeholder icon - and dropping one on a board produced "unknown widget",
/// because RenderReportWidget had no branch for it. The palette promised what nothing could draw.
///
/// One list decides it now (operator's rule, via the coordinator 2026-11-03): a type appears in
/// the palette in the SAME commit as its renderer. The guard checks the other half - that every
/// type listed here has a branch in RenderReportWidget - so the two cannot drift apart again.
/// </summary>
public static class ReportWidgetPalette
{
    /// <summary>
    /// The finished types, in palette order. Adding a type here without a branch in
    /// RenderReportWidget turns the guard red; that is the point of the list.
    /// </summary>
    public static readonly IReadOnlyList<ReportWidgetType> Ready = new[]
    {
        ReportWidgetType.QueueInterval,
        ReportWidgetType.QueueWaitTime,
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail,
        ReportWidgetType.Distribution,
        ReportWidgetType.EndOfShiftQueues,
        // EndOfShiftAgents and AgentPerformance: the server side exists, the renderers do not yet.
        // They stay out until their own commit brings both halves.
    };

    public static string Category(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval or ReportWidgetType.QueueWaitTime => "Queues",
        ReportWidgetType.AgentMonthly or ReportWidgetType.AgentShiftDetail => "Agents",
        ReportWidgetType.Distribution => "Analytics",
        ReportWidgetType.EndOfShiftQueues => "Queues",
        _ => "Other"
    };

    public static string Name(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "Queue Interval",
        ReportWidgetType.QueueWaitTime => "Queue Wait Time",
        ReportWidgetType.AgentMonthly => "Agent Monthly",
        ReportWidgetType.AgentShiftDetail => "Agent Shift Detail",
        ReportWidgetType.Distribution => "Distribution",
        ReportWidgetType.EndOfShiftQueues => "End of Shift — Queues",
        _ => type.ToString()
    };

    public static string Description(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "Calls and service levels by time interval",
        ReportWidgetType.QueueWaitTime => "Wait time distribution analysis",
        ReportWidgetType.AgentMonthly => "Monthly agent performance summary",
        ReportWidgetType.AgentShiftDetail => "Detailed shift-by-shift agent metrics",
        ReportWidgetType.Distribution => "Call distribution charts",
        ReportWidgetType.EndOfShiftQueues => "One row per queue for the shift window",
        _ => ""
    };

    public static string Icon(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "bi-clock-history",
        ReportWidgetType.QueueWaitTime => "bi-hourglass-split",
        ReportWidgetType.AgentMonthly => "bi-calendar-month",
        ReportWidgetType.AgentShiftDetail => "bi-person-lines-fill",
        ReportWidgetType.Distribution => "bi-pie-chart",
        ReportWidgetType.EndOfShiftQueues => "bi-door-closed",
        _ => "bi-grid"
    };
}
