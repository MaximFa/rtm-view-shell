using System.Globalization;
using Microsoft.Extensions.Localization;
using ReportIntervalLabel = CcDashboard.Application.HistoricalReports.ReportIntervalLabel;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The "data for ..." line of the report widgets (PR234-V4-REPORT-SHOWN-FOR-DATE-FORMAT-01): ONE rule for Queue Report,
/// Agent Report and Queue Trend - dates dd/MM/yyyy everywhere (operator 2026-11-07 22:32), one date when the period is
/// one day. Before this each widget wrote its own line, and two of them wrote the page culture's short date ("1.11.2026").
/// </summary>
public static class ReportPeriodText
{
    public static string Day(DateTime d) => d.ToString(ReportIntervalLabel.DayFormat, CultureInfo.InvariantCulture);

    public static string ShownFor(IStringLocalizer localizer, DateTime from, DateTime to)
    {
        var f = Day(from.Date);
        var t = Day(to.Date);
        return f == t
            ? string.Format(localizer["Report_ShownForDate"].Value, f)
            : string.Format(localizer["Report_ShownForRange"].Value, f, t);
    }
}
