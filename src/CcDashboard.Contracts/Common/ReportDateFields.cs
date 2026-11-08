namespace CcDashboard.Contracts.Common;

/// <summary>
/// The dates a report screen opens on.
///
/// History: from 2026-11-05 a screen made only of end-of-shift reports showed ONE date field (they took one date plus
/// shift hours). On 2026-11-07 the queues report took a period and a step (FEAT-REPORT-EOS-CONFIGURABLE-01), and on
/// 2026-11-08 the agents report did too (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01, operator 07:54). No report takes one
/// date or shift hours any more, so the rules that answered "which types do" - SingleDate, TakesShiftHours,
/// IsEndOfShift - are gone rather than kept answering "none": an empty rule invites a type back into it unnoticed.
/// Every screen shows two date fields.
/// </summary>
public static class ReportDateFields
{
    /// <summary>How many days back a screen opens on.</summary>
    public const int DefaultDaysBack = 7;

    /// <summary>The dates a screen opens on, given the day it is anchored on (the site's today or the last day with data).</summary>
    public static (DateTime From, DateTime To) DefaultRange(DateTime siteToday)
    {
        var today = siteToday.Date;
        return (today.AddDays(-DefaultDaysBack), today);
    }
}
