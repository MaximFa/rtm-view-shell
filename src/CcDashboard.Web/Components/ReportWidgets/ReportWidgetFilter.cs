using CcDashboard.Application.HistoricalReports.Queries;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// What one report widget is currently filtered by, as it tells the page.
///
/// PR234-V4-REPORT-VIEW-NO-AGENT-QUEUE-FILTER-01: the filter belongs over the columns of its own
/// widget (the operator asked for it there), but the EXPORT is built by the page. Without this
/// message the page would build a file from unfiltered queries while the screen showed filtered
/// rows - the file and the screen disagreeing, silently, which is the defect family this whole
/// line of work keeps running into.
///
/// It lives in Web, not in Contracts: it carries ReportColumnFilter, which belongs to Application,
/// and Contracts is referenced BY Application - putting it there would have made the reference
/// circular. The message never leaves the browser session anyway; it is one component telling
/// another what the person did.
///
/// Per widget, not per screen: two agent reports on one board may be filtered differently, and a
/// single screen-wide filter would make the file equal to neither of them.
/// </summary>
/// <param name="WidgetId">The widget this filter belongs to.</param>
/// <param name="Filters">The funnel filters in force on that widget, or null when none are.</param>
public record ReportWidgetFilter(Guid WidgetId, IReadOnlyList<ReportColumnFilter>? Filters = null)
{
    /// <summary>True when nothing is filtered: the page may forget this widget entirely.</summary>
    public bool IsEmpty => Filters is null || Filters.Count == 0;
}
