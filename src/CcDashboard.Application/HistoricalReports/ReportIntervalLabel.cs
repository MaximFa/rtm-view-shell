using System.Globalization;
using CcDashboard.Application.HistoricalReports.Queries;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// How the start of one interval of the end-of-shift queues report is written, for the step the
/// server ACTUALLY used (ReportWidgetResult.Step), not the step the screen asked for: if the two
/// ever differ, the label must describe the numbers next to it.
///
/// FEAT-REPORT-EOS-CONFIGURABLE-01 (operator 2026-11-07 12:31) and FEAT-REPORT-QUEUE-DATE-FORMAT-01 (22:32):
/// year "yyyy", month "MM/yyyy", day "dd/MM/yyyy" (a "00:00" on a day row would read as the first half-hour of
/// that day), hour / half-hour "dd/MM/yyyy HH:mm". The same numerals in every language.
///
/// One rule for the screen AND the export (moved from Web on 2026-11-07, proposal backend-1015
/// 11:24:50Z): a file whose interval reads differently from the screen it was exported from is the
/// file and the screen disagreeing, which this whole line of work exists to stop.
///
/// No mark of a cut edge (FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01, operator 2026-11-07 18:51: "in the date
/// remove what is in brackets"): the cell is the start written for its step and nothing else, on the screen and in
/// the file. The server still sends PartialFirst / PartialLast; nothing here reads them.
/// </summary>
public static class ReportIntervalLabel
{
    /// <summary>
    /// The start of one interval, written for its step. FEAT-REPORT-QUEUE-DATE-FORMAT-01 (operator 2026-11-07 22:32):
    /// "where only the month - MM/YYYY, where the day - DD/MM/YYYY, where half an hour / an hour - DD/MM/YYYY HH:MI";
    /// the year stays yyyy. The same numerals and the same "/" in every language: the separator is a literal, not the
    /// culture's date separator.
    /// </summary>
    public static string Start(DateTime start, ReportStep step) => step switch
    {
        ReportStep.Year => start.ToString("yyyy", CultureInfo.InvariantCulture),
        ReportStep.Month => start.ToString(MonthFormat, CultureInfo.InvariantCulture),
        ReportStep.Day => start.ToString(DayFormat, CultureInfo.InvariantCulture),
        _ => start.ToString(InstantFormat, CultureInfo.InvariantCulture)
    };

    /// <summary>Queue Report formats (FEAT-REPORT-QUEUE-DATE-FORMAT-01). The agents' reports do not use them.</summary>
    public const string MonthFormat = "MM'/'yyyy";
    public const string DayFormat = "dd'/'MM'/'yyyy";
    public const string InstantFormat = "dd'/'MM'/'yyyy HH':'mm";

    /// <summary>A value that is a date and a time by itself (a DateTime column, the "data through" stamp) in Queue Report.</summary>
    public static string Instant(DateTime value) => value.ToString(InstantFormat, CultureInfo.InvariantCulture);

    /// <summary>The whole cell of the interval column: the start for its step, without any mark.</summary>
    public static string Cell(DateTime rowStart, ReportStep step) => Start(rowStart, step);
}
