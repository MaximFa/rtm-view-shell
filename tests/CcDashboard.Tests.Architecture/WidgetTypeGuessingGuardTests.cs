using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// Guards against the return of "guess the value type from the data".
///
/// A widget must take the type of a value from the metric catalogue (RtsGridMetric.ValueType),
/// never from the data it happens to have received: deducing it from the first row made a column's
/// type depend on which agent was first, and a widget writing that guess into the shared config
/// object rewrote the user's saved settings.
///
/// These two guards read SOURCE FILES, so they watch the form, not the behaviour. The proof that
/// the type no longer follows the data is the behavioural test (MetricValueTypeTests); these keep
/// the pattern from creeping back in.
/// </summary>
public class WidgetTypeGuessingGuardTests
{
    // A type DEDUCED and then returned or remembered: `return "time"` or `_isTimeFormat = true`.
    // Field DECLARATIONS are excluded on purpose (`private bool _isTimeFormat = false;` states
    // nothing about the data) — that is the exact edge this guard was first written wrong on.
    private static readonly Regex DerivesType = new(
        "return \"(text|time|number)\"|_is(Time|Numeric)[A-Za-z]*\\s*=\\s*(true|false)\\s*;",
        RegexOptions.Compiled);

    private static readonly Regex Declaration = new(
        @"\b(private|public|protected|internal|bool|var)\b.*=",
        RegexOptions.Compiled);

    // The type must not be carried on the column definition either: that copy is what got saved.
    private static readonly Regex ReadsColumnDataType = new(
        @"\.DataType\b|\bdataType\b",
        RegexOptions.Compiled);

    // A comparison kind deduced from the VALUE the user typed into a threshold box.
    // This is the third shape the same defect took: `var isNumericThreshold = ... t.From ...`
    // made a text column's threshold numeric just because "5" was typed into From. The first two
    // needles were blind to it, which is why this one exists.
    private static readonly Regex DerivesThresholdKind = new(
        @"var\s+is[A-Za-z]*(Numeric|Text|Time|Ordered)[A-Za-z]*\s*=.*\b(t|rule|threshold)\.(From|To|TextMatch)\b",
        RegexOptions.Compiled);

    [Fact]
    public void No_widget_derives_a_value_type_from_the_data()
    {
        var hits = ScanWidgets(line => DerivesType.IsMatch(line) && !Declaration.IsMatch(line));

        hits.Should().BeEmpty(
            "a widget must read the metric's catalogue type, not deduce one from a value; found:\n"
            + string.Join("\n", hits));
    }

    [Fact]
    public void No_widget_reads_a_data_type_off_the_column_definition()
    {
        var hits = ScanWidgets(line => ReadsColumnDataType.IsMatch(line));

        hits.Should().BeEmpty(
            "the column's type is the metric's type; a copy on the column is what used to be saved; found:\n"
            + string.Join("\n", hits));
    }

    [Fact]
    public void Guard_can_go_red_parsing_for_arithmetic_is_not_a_type_guess()
    {
        // NEGATIVE HALF. Without this, both guards above stay green even if their needle matches
        // nothing at all — and a guard that cannot tell the two apart would also forbid legitimate
        // parsing, which is "stricter than the question" and would block honest code.
        DerivesType.IsMatch("                return \"time\";").Should().BeTrue("the needle must find a derived type");
        DerivesType.IsMatch("    private bool _isTimeFormat = false;").Should().BeTrue();
        Declaration.IsMatch("    private bool _isTimeFormat = false;").Should().BeTrue("a declaration is excluded");

        // Parsing whose result is a NUMBER used in arithmetic or comparison is not a type guess.
        foreach (var legitimate in new[]
                 {
                     "        var numValue = ParseNumericValue(value);",
                     "        if (TryParseTimeFormat(text, out var seconds)) return seconds;",
                     "            var fontSize = int.TryParse(Config?.FontSize, out var fs) ? fs : 14;",
                     "            var isTimeMetric = metric.ValueType == \"Time\";",
                 })
        {
            (DerivesType.IsMatch(legitimate) && !Declaration.IsMatch(legitimate))
                .Should().BeFalse($"must not flag legitimate code: {legitimate}");
            ReadsColumnDataType.IsMatch(legitimate).Should().BeFalse($"must not flag: {legitimate}");
        }
    }

    [Fact]
    public void No_widget_derives_a_comparison_kind_from_the_threshold_value()
    {
        var hits = ScanWidgets(line => DerivesThresholdKind.IsMatch(line));

        hits.Should().BeEmpty(
            "the comparison follows the metric's type, not the look of the value typed into the "
            + "threshold box; found:\n" + string.Join("\n", hits));
    }

    [Fact]
    public void Threshold_guard_can_go_red_and_leaves_legitimate_lines_alone()
    {
        // POSITIVE CONTROL — the line this guard exists for, as it stood in AgentGridWidget before
        // the fix. Without this the guard is green merely because its needle matches nothing.
        DerivesThresholdKind.IsMatch(
            "            var isNumericThreshold = t.MatchType == \"numeric\" || IsNumericThresholdValue(t.From) || IsNumericThresholdValue(t.To);")
            .Should().BeTrue("the needle must find the threshold-kind guess it was written for");

        // NEGATIVE HALF. The fixed lines, and a legitimate numeric-by-nature threshold: the WFM
        // widget's metrics are Erlang results, not catalogue metrics, so "numeric" there is the
        // type of the source and not a guess from a value.
        foreach (var legitimate in new[]
                 {
                     "            var isNumericThreshold = MetricValueType.IsOrdered(GetMetricValueType(metricId));",
                     "        var isOrdered = MetricValueType.IsOrdered(GetMetricValueType(metricId));",
                     "                if (rule.MatchType == \"numeric\")",
                     "            var from = ParseThresholdValue(rule.From, double.MinValue);",
                 })
        {
            DerivesThresholdKind.IsMatch(legitimate).Should().BeFalse($"must not flag: {legitimate}");
        }
    }

    private static List<string> ScanWidgets(Func<string, bool> isHit)
    {
        var dir = WidgetsDirectory();
        var hits = new List<string>();

        foreach (var file in Directory.GetFiles(dir, "*.razor"))
        {
            var lines = File.ReadAllLines(file);
            for (var i = 0; i < lines.Length; i++)
                if (isHit(lines[i]))
                    hits.Add($"{Path.GetFileName(file)}:{i + 1}: {lines[i].Trim()}");
        }

        // A guard that scanned nothing would be green for the wrong reason.
        Directory.GetFiles(dir, "*.razor").Should().NotBeEmpty("the widgets directory must be found");
        return hits;
    }

    private static string WidgetsDirectory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return Path.Combine(dir!.FullName, "src", "CcDashboard.Web", "Components", "Widgets");
    }
}
