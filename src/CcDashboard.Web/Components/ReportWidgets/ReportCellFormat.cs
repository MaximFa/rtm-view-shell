using System.Globalization;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// How one cell of a report is written, from the ONE rule that says what a column holds
/// (<see cref="ReportColumns"/>). The screen does not decide units.
///
/// This file briefly carried its own copy of that rule - an enum and two hand-written lists - and
/// the copy was wrong within the hour: eight column names that no row has, a string month printed
/// as a date, an id formatted as a number, and anything unknown silently becoming a count. That is
/// the same shape as the defect it was meant to cure, where a total in seconds was printed through
/// the milliseconds formatter and nine hours showed as thirty-two seconds. One rule, one place.
///
/// A column the rule does not know is a defect, not a default: ReportColumns throws, and the test
/// suite is where that must be discovered - not the operator's board.
/// </summary>
public static class ReportCellFormat
{
    /// <summary>True when the cell is right-aligned, i.e. when it is a measured number.</summary>
    public static bool IsNumeric(ReportColumnKind kind)
        => kind is ReportColumnKind.Count or ReportColumnKind.DurationMs
                or ReportColumnKind.DurationSec or ReportColumnKind.Percent;

    /// <summary>
    /// One cell, written for a person. Null is a dash, never a blank: a blank among real rows
    /// reads as data that failed to load, while a dash says "nothing here".
    /// </summary>
    public static string Cell(object? value, ReportColumnKind kind)
    {
        if (value is null) return "-";

        return kind switch
        {
            ReportColumnKind.Percent => ReportFormat.Pct(AsDouble(value)),
            ReportColumnKind.DurationSec => ReportFormat.Duration(AsDouble(value)),
            ReportColumnKind.DurationMs => ReportFormat.Duration(AsDouble(value) / 1000.0),
            // An instant keeps its time. The 00:00-00:30 bucket of an interval report is a real
            // interval, and dropping the time there takes away the one thing that tells the row
            // apart from the next. Whether a column carries a date or an instant is the column's
            // property - which is why these are two kinds and not one guess about a value.
            ReportColumnKind.DateTime => AsDateTime(value)?.ToString("yyyy-MM-dd HH:mm", CultureInfo.CurrentCulture)
                                         ?? value.ToString() ?? "-",
            ReportColumnKind.Date => AsDateTime(value)?.ToString("d", CultureInfo.CurrentCulture)
                                     ?? value.ToString() ?? "-",
            ReportColumnKind.Count => AsLong(value)?.ToString("N0", CultureInfo.CurrentCulture)
                                      ?? value.ToString() ?? "-",
            _ => value.ToString() ?? "-"
        };
    }

    private static DateTime? AsDateTime(object value) => value as DateTime?;

    private static double? AsDouble(object value) => value switch
    {
        double d => d,
        float f => f,
        decimal m => (double)m,
        long l => l,
        int i => i,
        _ => double.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed) ? parsed : null
    };

    private static long? AsLong(object value) => value switch
    {
        long l => l,
        int i => i,
        short s => s,
        _ => null
    };
}
