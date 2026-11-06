namespace CcDashboard.Contracts.Common;

/// <summary>
/// What one report widget is currently filtered by, as it tells the page.
///
/// PR234-V4-REPORT-VIEW-NO-AGENT-QUEUE-FILTER-01: the filter belongs over the columns of its own
/// widget (the operator asked for it there), but the EXPORT is built by the page. Without this
/// message the page would build a file from unfiltered queries while the screen showed filtered
/// rows - the file and the screen disagreeing, silently, which is the defect family this whole
/// line of work keeps running into.
///
/// Per widget, not per screen: two agent reports on one board may be filtered differently, and a
/// single screen-wide filter would make the file equal to neither of them.
/// </summary>
/// <param name="WidgetId">The widget this filter belongs to.</param>
/// <param name="AgentFilter">Part of the agent login, or null for no filter.</param>
/// <param name="AgentNameFilter">Part of the agent display name, or null.</param>
/// <param name="QueueFilter">Part of the queue name, or null.</param>
public record ReportWidgetFilter(
    Guid WidgetId,
    string? AgentFilter = null,
    string? AgentNameFilter = null,
    string? QueueFilter = null)
{
    /// <summary>True when nothing is filtered: the page may forget this widget entirely.</summary>
    public bool IsEmpty =>
        string.IsNullOrWhiteSpace(AgentFilter)
        && string.IsNullOrWhiteSpace(AgentNameFilter)
        && string.IsNullOrWhiteSpace(QueueFilter);
}
