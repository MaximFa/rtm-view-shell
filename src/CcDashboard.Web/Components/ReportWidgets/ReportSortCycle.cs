namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// FEAT-REPORT-QUEUE-COLUMN-SORT-01 (operator 2026-11-07 22:29): what a click on a column name does to the order.
/// Another column: ascending by it. The same column: ascending -> descending -> the report's own order (null).
/// </summary>
public static class ReportSortCycle
{
    public static (string? Column, bool Descending) Next(string? current, bool descending, string clicked)
    {
        if (!string.Equals(current, clicked, StringComparison.Ordinal)) return (clicked, false);
        return descending ? (null, false) : (clicked, true);
    }
}
