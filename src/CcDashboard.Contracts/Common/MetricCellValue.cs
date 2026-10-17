namespace CcDashboard.Contracts.Common;

/// <summary>
/// A metric value as the person sees it in a cell.
///
/// One place, called from both the display path and the comparison path, because a filter, a sort
/// or a threshold must judge the value the person is looking at. Everything this does was already
/// being done on the way to the screen and nowhere else, which is exactly how the gap appeared:
/// the engine marks an empty field with the HTML entity "&amp;nbsp;" (legacy HTML client), the cell
/// showed a blank, and a saved filter rule compared the raw "&amp;nbsp;" — so a rule could not match
/// the rows that look empty. The same held for NaN/Infinity, shown blank and compared as "NaN".
///
/// Keeping it as two copies (one for the screen, one for comparing) is how they drift apart again,
/// so both paths call this.
/// </summary>
public static class MetricCellValue
{
    /// <summary>The engine's placeholder for an empty field, from the legacy HTML client.</summary>
    public const string EmptyPlaceholder = "&nbsp;";

    /// <summary>
    /// Normalises a raw metric value to its displayed form: anomalies and the empty placeholder
    /// become an empty string, and "h:mm:ss" / "mm:ss" are zero-padded, dropping a zero hour.
    /// </summary>
    public static string Display(string? rawValue)
    {
        var value = rawValue ?? string.Empty;
        if (value.Length == 0) return value;

        // Anomalies are shown as blank, so they must compare as blank too.
        if (value is "NaN" or "Infinity" or "-Infinity") return string.Empty;
        if (value == EmptyPlaceholder) return string.Empty;

        var parts = value.Split(':');
        if (parts.Length == 3
            && int.TryParse(parts[0], out var h)
            && int.TryParse(parts[1], out var m)
            && int.TryParse(parts[2], out var s))
        {
            return h > 0 ? $"{h:D2}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
        }

        if (parts.Length == 2
            && int.TryParse(parts[0], out var m2)
            && int.TryParse(parts[1], out var s2))
        {
            return $"{m2:D2}:{s2:D2}";
        }

        return value;
    }
}
