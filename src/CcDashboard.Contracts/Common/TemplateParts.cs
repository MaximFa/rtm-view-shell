namespace CcDashboard.Contracts.Common;

using System.Text.RegularExpressions;

/// <summary>
/// Parses format string templates and returns parts in order of appearance,
/// resolving placeholder indices ({0}, {1}, ...) to their corresponding values.
/// Unlike string.Split, this respects the numeric index inside each placeholder,
/// so "{1} of {0}" correctly maps values[1] and values[0] regardless of order.
/// </summary>
public static partial class TemplateParts
{
    /// <summary>
    /// A segment of a parsed template: either literal text or a placeholder value.
    /// </summary>
    public readonly record struct Part(bool IsPlaceholder, string Text, int Index = -1);

    /// <summary>
    /// Parses a template string and returns parts in order.
    /// Literal text segments have IsPlaceholder=false and Text contains the literal.
    /// Placeholder segments have IsPlaceholder=true, Index is the placeholder number,
    /// and Text is the resolved value (or empty if index out of range).
    /// </summary>
    /// <param name="template">Format string like "Showing {0} of {1}"</param>
    /// <param name="values">Values to substitute for {0}, {1}, etc.</param>
    /// <returns>Sequence of parts in template order</returns>
    public static IEnumerable<Part> Parse(string? template, params object?[] values)
    {
        if (string.IsNullOrEmpty(template))
            yield break;

        var matches = PlaceholderRegex().Matches(template);
        if (matches.Count == 0)
        {
            // No placeholders - return entire template as literal
            yield return new Part(false, template);
            yield break;
        }

        int pos = 0;
        foreach (Match m in matches)
        {
            // Literal text before this placeholder
            if (m.Index > pos)
            {
                yield return new Part(false, template[pos..m.Index]);
            }

            // Parse the placeholder index
            if (int.TryParse(m.Groups[1].Value, out int idx))
            {
                var value = idx >= 0 && idx < values.Length
                    ? values[idx]?.ToString() ?? ""
                    : "";
                yield return new Part(true, value, idx);
            }

            pos = m.Index + m.Length;
        }

        // Trailing literal text after last placeholder
        if (pos < template.Length)
        {
            yield return new Part(false, template[pos..]);
        }
    }

    /// <summary>
    /// Checks if the template contains any placeholders ({0}, {1}, etc.).
    /// </summary>
    public static bool HasPlaceholders(string? template)
        => !string.IsNullOrEmpty(template) && PlaceholderRegex().IsMatch(template);

    [GeneratedRegex(@"\{(\d+)\}", RegexOptions.Compiled)]
    private static partial Regex PlaceholderRegex();
}
