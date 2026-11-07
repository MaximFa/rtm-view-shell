using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Contracts.Common;

/// <summary>
/// How many date fields a report screen shows.
///
/// Operator, 2026-11-05: "one date field if the screen holds only end-of-shift reports, and take
/// the start date if there are other reports too". Measured the same morning on 234: with both
/// fields, changing only the second one changed nothing and the screen said nothing - the
/// end-of-shift reports took a single date, so the second field was a control that did not control
/// anything.
///
/// Narrowed on 2026-11-07 (FEAT-REPORT-EOS-CONFIGURABLE-01): the end-of-shift QUEUES report takes
/// a period now, like every other report, so only a screen made entirely of the end-of-shift
/// AGENTS report still has one date. The rule names that type rather than "an end-of-shift type",
/// because the two reports no longer agree about time - and a rule written for what they used to
/// have in common would quietly hide the second field from a screen that needs it.
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
            if (!TakesShiftHours(type)) return false;
        }
        return any;
    }

    /// <summary>How many days back a two-field screen opens on.</summary>
    public const int DefaultDaysBack = 7;

    /// <summary>
    /// The dates a screen opens on, given the site's today.
    ///
    /// Measured on 234 on 2026-11-06: a one-field screen opened on 30.10 while the site's today was
    /// 06.11, because the page set "today minus seven" before it knew how many fields it would
    /// draw. On a one-field screen that week-old date IS the whole window - the shift report then
    /// shows a week-old shift to anyone who does not notice the field - while on a two-field
    /// screen the same seven days are the sensible period. So the number of fields decides, and
    /// the decision lives here rather than in the page, where it cannot be tested.
    /// </summary>
    public static (DateTime From, DateTime To) DefaultRange(DateTime siteToday, bool singleDate)
    {
        var today = siteToday.Date;
        return singleDate
            ? (today, today)
            : (today.AddDays(-DefaultDaysBack), today);
    }

    /// <summary>
    /// The two end-of-shift report types. Since 2026-11-07 this says nothing about time: the queues
    /// report takes a period and a step, the agents report one date plus shift hours. Ask
    /// <see cref="TakesShiftHours"/> for that - a rule written for what the two used to share would
    /// quietly put shift hours, or one date field, back on a report that no longer has them.
    /// </summary>
    public static bool IsEndOfShift(ReportWidgetType type)
        => type is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;

    /// <summary>
    /// The types whose window is ONE date plus shift hours - today only the end-of-shift agents
    /// report (FEAT-REPORT-EOS-CONFIGURABLE-01). The one place the screen asks: the date fields,
    /// the settings dialog and the guards all read it, so they cannot disagree.
    /// The server has its own copy (RunReportWidgetQueryHandler.TakesShiftHours, the same single
    /// type); the guards pin the two together until there is one.
    /// </summary>
    public static bool TakesShiftHours(ReportWidgetType type)
        => type is ReportWidgetType.EndOfShiftAgents;
}
