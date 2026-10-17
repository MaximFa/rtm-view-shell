namespace CcDashboard.Contracts.Common;

/// <summary>
/// Single source of truth for "what type is this metric's value".
///
/// The type comes from the metric catalogue (RtsGridMetric.ValueType / HistoryMetric.ValueType)
/// and NEVER from the data itself: deducing the type from the first row made a column's type
/// depend on which agent happened to be first, so the same column showed as "number" for one
/// business unit and "time" for another, and a widget writing that guess back into the shared
/// config object silently rewrote the user's saved settings.
///
/// The catalogue stores the seeded rows in LOWER case ("number"/"time"/"text") while older rows
/// use "Number"/"Time"/"String", so every comparison here is case-insensitive. Keeping the
/// literals in this one class is the point: a per-widget comparison is how the case trap
/// returns.
/// </summary>
public static class MetricValueType
{
    public const string Text = "text";
    public const string Number = "number";
    public const string Time = "time";

    /// <summary>Normalises a catalogue ValueType to Text / Number / Time. Unknown or missing -&gt; Text.</summary>
    public static string Normalize(string? valueType)
    {
        if (ThresholdTextMatch.IsEmpty(valueType)) return Text;
        if (string.Equals(valueType, "number", StringComparison.OrdinalIgnoreCase)) return Number;
        if (string.Equals(valueType, "time", StringComparison.OrdinalIgnoreCase)) return Time;
        if (string.Equals(valueType, "timems", StringComparison.OrdinalIgnoreCase)) return Time;
        // "String", "text" and anything unrecognised are shown as text: text only disables
        // ordered comparisons, while a wrong "number" breaks sorting and thresholds.
        return Text;
    }

    /// <summary>True when the value is ordered (Number or Time) and ordered comparisons apply.</summary>
    public static bool IsOrdered(string? valueType)
    {
        var t = Normalize(valueType);
        return t == Number || t == Time;
    }

    // ── Saved filter rules: operator substitution ────────────────────────────
    // Operators understood by MatchesTableFilterRule (widget side), lower case.
    // Four of them are valid for ANY type and are never touched: equal, notequal, empty, notempty.

    private static readonly string[] OrderedOnly = { "greater", "greaterequal", "less", "lessequal" };
    private static readonly string[] TextOnly = { "contains", "notcontains", "startswith", "endswith" };

    /// <summary>True when the operator already fits the metric type and must be left byte-for-byte alone.</summary>
    public static bool OperatorFitsType(string? op, string? valueType)
    {
        if (ThresholdTextMatch.IsEmpty(op)) return true;   // nothing to decide
        var o = op!.ToLowerInvariant();
        if (o is "equal" or "notequal" or "empty" or "notempty") return true;
        return IsOrdered(valueType) ? OrderedOnly.Contains(o) : TextOnly.Contains(o);
    }

    /// <summary>
    /// The operator to use for this metric type. Returns the ORIGINAL operator unchanged when it
    /// already fits, so a rule that was already valid is carried over byte for byte.
    ///
    /// Every substitution NARROWS the set of rows and never widens it. That is the whole principle:
    /// if a replaced rule lets too few rows through, the operator sees it at once and fixes the
    /// rule; a widened rule looks like "the filter is not working" and nobody suspects it was
    /// replaced. So "contains" becomes "equal", "notcontains" becomes "notequal", and the six
    /// cases with no meaningful counterpart — greater/greaterequal/less/lessequal on text,
    /// startswith/endswith on a number or time — all become "equal" against the same value:
    /// of a value written into a rule, the only honest statement on a foreign type is "equals it".
    ///
    /// Decided by the operator on 2026-10-17, with the cost stated: after substitution the filter
    /// passes FEWER rows, and for startswith/endswith noticeably fewer ("calls starting with 1"
    /// becomes "calls = 1", so 10, 15 and 100 no longer pass).
    /// </summary>
    public static string NearestOperator(string? op, string? valueType)
    {
        if (OperatorFitsType(op, valueType)) return op!;
        var o = op!.ToLowerInvariant();
        // Only operators that do NOT fit reach this point, so "notcontains" here always means a
        // text operator on an ordered metric: its negation is kept, which also narrows.
        if (o == "notcontains") return "notequal";
        // contains, greater, greaterequal, less, lessequal, startswith, endswith
        return "equal";
    }
}

