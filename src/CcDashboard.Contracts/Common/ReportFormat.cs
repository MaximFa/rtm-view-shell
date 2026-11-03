namespace CcDashboard.Contracts.Common;

/// <summary>
/// How a report cell shows a percentage or a duration.
///
/// These two functions existed in nine copies (FormatDuration) and eight (FormatPct) across
/// Components/Reports and Components/ReportWidgets - byte-identical apart from a `static` modifier
/// and one trailing space. Three new report widgets would have made it twelve and eleven.
///
/// Copies in components are also untestable: a widget's private members are not reachable from
/// tests and there is no bUnit in this solution. Here they have tests, and the rules below are
/// stated once rather than nine times:
/// - no value prints as "-", not "0" and not an empty cell: a queue with no answered calls has no
///   average wait, and showing 0 would read as "instant".
/// - a duration under an hour prints as m:ss, an hour or more as h:mm:ss - the same two spellings
///   the existing reports have always produced, kept deliberately so a migrated report looks
///   unchanged next to an old one.
/// </summary>
public static class ReportFormat
{
    /// <summary>A percentage with one decimal, or "-" when there is no value.</summary>
    public static string Pct(double? value) => value.HasValue ? $"{value.Value:F1}%" : "-";

    /// <summary>A duration in seconds as m:ss, or h:mm:ss past an hour; "-" when there is no value.</summary>
    public static string Duration(double? seconds)
    {
        if (!seconds.HasValue) return "-";

        var ts = TimeSpan.FromSeconds(seconds.Value);
        return ts.TotalHours >= 1
            ? $"{(int)ts.TotalHours}:{ts.Minutes:D2}:{ts.Seconds:D2}"
            : $"{ts.Minutes}:{ts.Seconds:D2}";
    }
}
