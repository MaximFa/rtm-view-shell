using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Contracts.Common;

/// <summary>
/// How many date fields a report screen shows.
///
/// Operator, 2026-11-05: "one date field if the screen holds only end-of-shift reports, and take
/// the start date if there are other reports too". Measured the same morning on 234: with both
/// fields, changing only the second one changed nothing and the screen said nothing - the
/// end-of-shift reports take a single date, so the second field was a control that did not control
/// anything.
///
/// The rule lives here, outside the page, so it can be tested: a .razor page's state is not
/// reachable from tests and there is no bUnit in this solution.
/// </summary>
public static class ReportDateFields
{
    /// <summary>
    /// True when the screen shows ONE date field. An empty screen is false on purpose: a report
    /// with no widgets says nothing about what it will hold, and hiding a field on that guess
    /// would surprise whoever drops a different report onto it.
    /// </summary>
    public static bool SingleDate(IEnumerable<ReportWidgetType>? widgetTypes)
    {
        if (widgetTypes is null) return false;

        var any = false;
        foreach (var type in widgetTypes)
        {
            any = true;
            if (!IsEndOfShift(type)) return false;
        }
        return any;
    }

    /// <summary>The types whose window is one date plus shift hours.</summary>
    public static bool IsEndOfShift(ReportWidgetType type)
        => type is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;
}
