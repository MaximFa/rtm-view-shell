using System.Globalization;

namespace CcDashboard.Web.Components.Shared;

/// <summary>
/// How the filter window reads and shows a date. FEAT-REPORT-QUEUE-DATE-FORMAT-01 (operator 2026-11-07 22:32): Queue
/// Report asks for dates as dd/MM/yyyy; every other report keeps the browser's date field, whose value is yyyy-MM-dd.
/// With a format the text must match it exactly - "03/11/2026" is the 3rd of November, never March the 11th, whatever
/// the culture of the server or the browser.
/// </summary>
public static class ColumnFilterDates
{
    /// <summary>The browser's date field always speaks ISO, whatever it shows.</summary>
    public const string BrowserFieldFormat = "yyyy-MM-dd";

    public static DateTime? Parse(string? text, string? format)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        if (format is null)
            return DateTime.TryParse(text, out var any) ? any : null;
        return DateTime.TryParseExact(text.Trim(), format, CultureInfo.InvariantCulture, DateTimeStyles.None, out var exact)
            ? exact
            : null;
    }

    public static string Show(DateTime? value, string? format)
        => value?.ToString(format ?? BrowserFieldFormat, CultureInfo.InvariantCulture) ?? string.Empty;
}
