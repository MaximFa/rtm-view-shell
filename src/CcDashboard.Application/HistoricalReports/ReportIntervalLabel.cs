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
/// No mark of a cut edge (FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01, operator 2026-11-07 18:51: "in the date
/// remove what is in brackets"): the cell is the start written for its step and nothing else, on the screen and in
/// the file. The server still sends PartialFirst / PartialLast; nothing here reads them.
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

    /// <summary>The whole cell of the interval column: the start for its step, without any mark.</summary>
    public static string Cell(DateTime rowStart, ReportStep step) => Start(rowStart, step);
}
