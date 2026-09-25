namespace CcDashboard.Contracts.Common;

/// <summary>
/// Shared text threshold matching logic for widgets.
/// All comparisons are case-insensitive.
/// </summary>
public static class ThresholdTextMatch
{
    /// <summary>
    /// Determines if a cell value matches a threshold pattern based on the specified match type.
    /// </summary>
    /// <param name="matchType">The type of comparison: equal, notequal, contains, startswith, endswith, empty, notempty.
    /// Unknown or null defaults to equal for backward compatibility.</param>
    /// <param name="cellValue">The value to test (may be null or empty).</param>
    /// <param name="pattern">The pattern to match against (ignored for empty/notempty).</param>
    /// <returns>True if the value matches the pattern according to the match type.</returns>
    public static bool IsMatch(string? matchType, string? cellValue, string? pattern)
    {
        var value = cellValue ?? string.Empty;
        var pat = pattern ?? string.Empty;
        
        return matchType switch
        {
            "notequal" => !value.Equals(pat, StringComparison.OrdinalIgnoreCase),
            "contains" => value.Contains(pat, StringComparison.OrdinalIgnoreCase),
            "startswith" => value.StartsWith(pat, StringComparison.OrdinalIgnoreCase),
            "endswith" => value.EndsWith(pat, StringComparison.OrdinalIgnoreCase),
            "empty" => IsEmpty(value),
            "notempty" => !IsEmpty(value),
            // "equal" and unknown/null default to equality (backward compatibility)
            _ => value.Equals(pat, StringComparison.OrdinalIgnoreCase)
        };
    }
    
    /// <summary>
    /// Determines if a value is considered empty (null, empty string, or whitespace only).
    /// </summary>
    public static bool IsEmpty(string? value)
    {
        return string.IsNullOrEmpty(value) || string.IsNullOrWhiteSpace(value);
    }
}