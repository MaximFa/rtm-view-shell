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
        // QueueInterval, QueueWaitTime and Distribution are RETIRED (operator, 2026-11-07): the
        // configurable end-of-shift queues report covers what they did, with a step of a day, an
        // hour or half an hour. They stay in the enum and keep their renderers - widgets already
        // standing on boards must still draw, and they say "retired" instead of going blank.
        // Blank would be the worse ending: a person reads an empty report as "there was no work".
        // AgentMonthly, AgentShiftDetail and AgentPerformance are RETIRED the same way (operator, 2026-11-08 07:54,
        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01): Agent Report covers them - for the period, or by a step.
        ReportWidgetType.EndOfShiftQueues,
        ReportWidgetType.EndOfShiftAgents,
        // FEAT-REPORT-QUEUE-TREND-COMPARE-01 (operator 2026-11-08): queue metrics as lines, with a comparison period.
        ReportWidgetType.QueueTrend,
        // FEAT-REPORT-AGENT-STATE-TREND-01 (operator 2026-11-08 21:54): shares of the agents' login time by ASD group as lines.
        ReportWidgetType.AgentStateTrend,
    };

    public static string Category(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval or ReportWidgetType.QueueWaitTime => "Queues",
        ReportWidgetType.AgentMonthly or ReportWidgetType.AgentShiftDetail => "Agents",
        ReportWidgetType.Distribution => "Analytics",
        ReportWidgetType.EndOfShiftQueues => "Queues",
        ReportWidgetType.EndOfShiftAgents => "Agents",
        ReportWidgetType.AgentPerformance => "Agents",
        ReportWidgetType.QueueTrend => "Queues",
        ReportWidgetType.AgentStateTrend => "Agents",
        _ => "Other"
    };

    /// <summary>
    /// Resource key of a type's human name. PR234-V4-REPORT-WIDGET-TITLE-TECHNICAL-NAME-01: a
    /// widget saved without a title showed the enum name ("EndOfShiftAgents") as its header - a
    /// technical identifier on an operator's wall, in English, on a Hebrew board. The names below
    /// stay as the English fallback for places that have no localizer.
    /// </summary>
    public static string NameKey(ReportWidgetType type) => $"Report_{type}";

    /// <summary>
    /// The English name, for places without a localizer. ONE rule: ReportTypeNames.English (Application), which the export
    /// uses too and which its guard measures against en-US Report_{type}. This file used to carry a second copy that had
    /// already drifted («End of Shift — Agents» against the resource's «End of shift — agents») - coordinator 15:34:29Z.
    /// </summary>
    public static string Name(ReportWidgetType type)
        => CcDashboard.Application.HistoricalReports.ReportTypeNames.English(type);

    /// <summary>
    /// Resource key of a type's description. The English constants below stay as the fallback for
    /// places with no localizer; the palette itself shows the localised text, so a Hebrew board no
    /// longer explains its reports in English.
    /// </summary>
    public static string DescriptionKey(ReportWidgetType type) => $"Report_Desc{type}";

    public static string Description(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "Calls and service levels by time interval",
        ReportWidgetType.QueueWaitTime => "Wait time distribution analysis",
        ReportWidgetType.AgentMonthly => "Monthly agent performance summary",
        ReportWidgetType.AgentShiftDetail => "Detailed shift-by-shift agent metrics",
        ReportWidgetType.Distribution => "Call distribution charts",
        ReportWidgetType.EndOfShiftQueues => "One row per queue for the shift window",
        ReportWidgetType.EndOfShiftAgents => "One row per agent for the shift window",
        ReportWidgetType.AgentPerformance => "Agent figures for the period: one row per agent, or one per agent per date",
        ReportWidgetType.QueueTrend => "Queue metrics over the period by step, with an optional comparison period",
        ReportWidgetType.AgentStateTrend => "Share of the agents' login time in each state group over the period by step, with an optional comparison period",
        _ => ""
    };

    public static string Icon(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => "bi-clock-history",
        ReportWidgetType.QueueWaitTime => "bi-hourglass-split",
        ReportWidgetType.AgentMonthly => "bi-calendar-month",
        ReportWidgetType.AgentShiftDetail => "bi-person-lines-fill",
        ReportWidgetType.Distribution => "bi-pie-chart",
        // FEAT-REPORT-QUEUE-REPORT-ICON-01 (operator 2026-11-08 07:56, 08:04): the door meant "end of shift"; it is a queue report
        // now - a queue ticket, not a door and not a telephone.
        ReportWidgetType.EndOfShiftQueues => "bi-ticket-perforated",
        ReportWidgetType.EndOfShiftAgents => "bi-people",
        ReportWidgetType.AgentPerformance => "bi-graph-up",
        // Working icon until the operator's word (coordinator 17:02:51Z); bi-graph-up belongs to the retired AgentPerformance.
        ReportWidgetType.QueueTrend => "bi-graph-up-arrow",
        // Working icon until the operator's word (coordinator 20:05:25Z): free in src, db and deploy; "a person at work".
        ReportWidgetType.AgentStateTrend => "bi-person-workspace",
        _ => "bi-grid"
    };
}
