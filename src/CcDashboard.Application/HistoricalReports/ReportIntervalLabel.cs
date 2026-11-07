using System.Globalization;
using CcDashboard.Application.HistoricalReports.Queries;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// How the start of one interval of the end-of-shift queues report is written, for the step the
/// server ACTUALLY used (ReportWidgetResult.Step), not the step the screen asked for: if the two
/// ever differ, the label must describe the numbers next to it.
///
/// FEAT-REPORT-EOS-CONFIGURABLE-01, Month / Year (operator 2026-11-07 12:31, coordinator 10:38:32Z):
/// month = "MM.yyyy", year = "yyyy", the same numerals in every language. Day = the date alone:
/// a "00:00" on a day row would read as the first half-hour of that day. Hour / half-hour keep the
/// time, written like every other instant in the reports.
///
/// One rule for the screen AND the export (moved from Web on 2026-11-07, proposal backend-1015
/// 11:24:50Z): a file whose interval reads differently from the screen it was exported from is the
/// file and the screen disagreeing, which this whole line of work exists to stop.
///
/// The cut edge is NOT computed here. Whether the first or last interval is cut is the server's
/// answer (PartialFirst / PartialLast); the dates printed in the mark are the period that went into
/// that same query. This class only tells which row IS the first or last interval - the one whose
/// start is the start of the step that contains the period's first or last date.
/// </summary>
public static class ReportIntervalLabel
{
    /// <summary>The start of one interval, written for its step.</summary>
    public static string Start(DateTime start, ReportStep step) => step switch
    {
        ReportStep.Year => start.ToString("yyyy", CultureInfo.InvariantCulture),
        ReportStep.Month => start.ToString("MM.yyyy", CultureInfo.InvariantCulture),
        ReportStep.Day => start.ToString("d", CultureInfo.CurrentCulture),
        _ => start.ToString("yyyy-MM-dd HH:mm", CultureInfo.CurrentCulture)
    };

    /// <summary>
    /// The start of the interval of <paramref name="step"/> that contains the local date
    /// <paramref name="date"/> - used only to recognise the first / last row, never to decide a cut.
    /// </summary>
    public static DateTime IntervalOf(DateTime date, ReportStep step) => step switch
    {
        ReportStep.Year => new DateTime(date.Year, 1, 1),
        ReportStep.Month => new DateTime(date.Year, date.Month, 1),
        _ => date.Date
    };

    /// <summary>
    /// The mark after a cut interval, e.g. "(from 05.11)" / "(to 20.11)", or null when the row is
    /// whole. <paramref name="from"/> and <paramref name="to"/> are the period of the query that
    /// produced the answer (both inclusive local dates); the three formats are the translated
    /// sentences with {0} = from and {1} = to.
    /// </summary>
    public static string? EdgeMark(
        DateTime rowStart, ReportStep step, bool partialFirst, bool partialLast,
        DateTime from, DateTime to,
        string fromFormat, string toFormat, string fromToFormat)
    {
        // Only a month or a year can be wider than the period; for the other steps the server sends
        // false, and a stray true must not invent a mark on a day row.
        if (step is not (ReportStep.Month or ReportStep.Year)) return null;

        var isFirst = partialFirst && rowStart == IntervalOf(from, step);
        var isLast = partialLast && rowStart == IntervalOf(to, step);
        var f = from.ToString("dd.MM", CultureInfo.InvariantCulture);
        var t = to.ToString("dd.MM", CultureInfo.InvariantCulture);

        if (isFirst && isLast) return string.Format(CultureInfo.CurrentCulture, fromToFormat, f, t);
        if (isFirst) return string.Format(CultureInfo.CurrentCulture, fromFormat, f);
        if (isLast) return string.Format(CultureInfo.CurrentCulture, toFormat, t);
        return null;
    }

    /// <summary>The whole cell: the start, and the mark when the interval is cut.</summary>
    public static string Cell(
        DateTime rowStart, ReportStep step, bool partialFirst, bool partialLast,
        DateTime from, DateTime to,
        string fromFormat, string toFormat, string fromToFormat)
    {
        var start = Start(rowStart, step);
        var mark = EdgeMark(rowStart, step, partialFirst, partialLast, from, to, fromFormat, toFormat, fromToFormat);
        return mark is null ? start : start + " " + mark;
    }
}
