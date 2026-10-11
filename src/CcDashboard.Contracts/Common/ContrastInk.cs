namespace CcDashboard.Contracts.Common;

/// <summary>
/// WCAG contrast helper: picks dark or light ink for readable text on any fill.
/// Dark ink: #1f2937, Light ink: #f9fafb.
/// Selection is made by measuring WCAG contrast ratio and choosing whichever ink
/// has higher contrast against the fill.
/// </summary>
public static class ContrastInk
{
    /// <summary>Dark ink color for light backgrounds.</summary>
    public const string DarkInk = "#1f2937";

    /// <summary>Light ink color for dark backgrounds.</summary>
    public const string LightInk = "#f9fafb";

    /// <summary>
    /// Returns a readable text color for the given fill, picking whichever ink has higher contrast.
    /// Returns null if the fill is not a measurable hex color (transparent, default, rgb(), etc.).
    /// </summary>
    /// <param name="fill">CSS color value; only #RGB, #RRGGBB, RGB, RRGGBB are measurable.</param>
    /// <returns>DarkInk, LightInk, or null if fill is not measurable.</returns>
    public static string? ReadableColorOnFill(string? fill)
    {
        var parsed = TryParseHex(fill);
        if (parsed is null) return null;

        var fillLum = RelativeLuminance(parsed.Value);
        var darkLum = RelativeLuminance(TryParseHex(DarkInk)!.Value);
        var lightLum = RelativeLuminance(TryParseHex(LightInk)!.Value);

        var darkContrast = ContrastRatio(fillLum, darkLum);
        var lightContrast = ContrastRatio(fillLum, lightLum);

        return darkContrast >= lightContrast ? DarkInk : LightInk;
    }

    /// <summary>
    /// Computes the WCAG 2.1 contrast ratio between two colors.
    /// </summary>
    /// <param name="hex1">First color as hex (#RGB, #RRGGBB, RGB, or RRGGBB).</param>
    /// <param name="hex2">Second color as hex.</param>
    /// <returns>Contrast ratio (1.0 to 21.0), or null if either color is not parseable.</returns>
    public static double? GetContrastRatio(string? hex1, string? hex2)
    {
        var c1 = TryParseHex(hex1);
        var c2 = TryParseHex(hex2);
        if (c1 is null || c2 is null) return null;

        return ContrastRatio(RelativeLuminance(c1.Value), RelativeLuminance(c2.Value));
    }

    /// <summary>
    /// Parses #RGB, #RRGGBB, RGB, RRGGBB (case-insensitive). Returns null for anything else.
    /// </summary>
    private static (int r, int g, int b)? TryParseHex(string? hex)
    {
        if (string.IsNullOrEmpty(hex)) return null;

        hex = hex.TrimStart('#');
        // Only accept 3 or 6 hex digits
        if (hex.Length != 3 && hex.Length != 6) return null;
        // Must be all hex chars
        foreach (var c in hex)
            if (!Uri.IsHexDigit(c)) return null;

        if (hex.Length == 3)
            hex = $"{hex[0]}{hex[0]}{hex[1]}{hex[1]}{hex[2]}{hex[2]}";

        return (
            Convert.ToInt32(hex.Substring(0, 2), 16),
            Convert.ToInt32(hex.Substring(2, 2), 16),
            Convert.ToInt32(hex.Substring(4, 2), 16)
        );
    }

    /// <summary>
    /// Computes WCAG 2.1 relative luminance (sRGB).
    /// </summary>
    private static double RelativeLuminance((int r, int g, int b) c)
    {
        double Linearize(int v)
        {
            var s = v / 255.0;
            return s <= 0.04045 ? s / 12.92 : Math.Pow((s + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * Linearize(c.r) + 0.7152 * Linearize(c.g) + 0.0722 * Linearize(c.b);
    }

    /// <summary>
    /// Computes WCAG contrast ratio from two luminance values.
    /// </summary>
    private static double ContrastRatio(double l1, double l2)
    {
        var lighter = Math.Max(l1, l2);
        var darker = Math.Min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
    }
}
