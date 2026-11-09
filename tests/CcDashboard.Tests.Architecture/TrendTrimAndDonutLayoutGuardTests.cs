using System.Text.RegularExpressions;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-TREND-TRIM-ZERO-EDGES-01 (operator 2026-11-09 14:07): both trends start and end with non-zero values - leading
/// and trailing zeros are cut, zeros inside stay, the comparison is cut by the same indices, all zeros = "no data".
/// PR234-V4-ASD-REPORT-LEGEND-CLIPPED-01 follow-up: the donut's ring takes what the legend leaves, not its full square first.
/// </summary>
public class TrendTrimAndDonutLayoutGuardTests
{
    [Fact]
    public void LeadingAndTrailingZerosAreCut_zerosInsideStay()
    {
        var series = new double?[] { 0, null, 3, 0, 5, 0, 0 };
        var range = QueueTrendView.NonZeroRange(new[] { series });
        range.Should().Be((2, 4));
        QueueTrendView.Cut(series, range!.Value).Should().Equal(3, 0, 5);
        QueueTrendView.Cut(new[] { "a", "b", "c", "d", "e", "f", "g" }, range.Value).Should().Equal("c", "d", "e");

        // NEGATIVE HALF: the whole axis (what was drawn until now) is not the range.
        range.Should().NotBe((0, series.Length - 1));
    }

    [Fact]
    public void WithAComparison_theEdgesAreTheUnion_andBothAreCutByTheSameIndices()
    {
        var main = new double?[] { 0, 0, 0, 1, 0 };
        var compare = new double?[] { 0, 2, 0, 0, 0 };
        var range = QueueTrendView.NonZeroRange(new[] { main, compare });
        range.Should().Be((1, 3), "from the comparison's first value to the main period's last");
        QueueTrendView.Cut(main, range!.Value).Should().Equal(0, 0, 1);
        QueueTrendView.Cut(compare, range.Value).Should().Equal(2, 0, 0);

        // NEGATIVE HALF: cutting each by its own edges would break the alignment by index.
        QueueTrendView.NonZeroRange(new[] { main }).Should().NotBe(QueueTrendView.NonZeroRange(new[] { compare }));
    }

    [Fact]
    public void AllZeros_isNoData_notAnEmptyAxis()
    {
        QueueTrendView.NonZeroRange(new[] { new double?[] { 0, null, 0 }, new double?[] { null } }).Should().BeNull();
        QueueTrendView.NonZeroRange(Array.Empty<IReadOnlyList<double?>>()).Should().BeNull();
        // NEGATIVE HALF: one value is enough.
        QueueTrendView.NonZeroRange(new[] { new double?[] { 0, 0.5, 0 } }).Should().Be((1, 1));
    }

    [Fact]
    public void TheTrendBody_cutsEveryListOfTheChart_andSaysNoData()
    {
        var w = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        w.Should().Contain("QueueTrendView.NonZeroRange(ShownSeries(_result))");
        w.Should().Contain("foreach (var metric in _metrics)", "only the shown series decide the edges");
        w.Should().Contain("else if (Range is null)").And.Contain("@L[\"Report_NoData\"]");
        CutCalls(w).Should().Be(4, "labels, comparison labels, main values, comparison values - by one range");

        // NEGATIVE HALF: the uncut shape deployed until now is seen.
        CutCalls("var labels = r.Points.Select(p => ReportIntervalLabel.Cell(p, r.Step)).ToArray(); data = series.Values").Should().Be(0);
    }

    private static int CutCalls(string text) => Regex.Matches(text, @"QueueTrendView\.Cut\(").Count;

    [Fact]
    public void TheDonutRing_takesWhatTheLegendLeaves()
    {
        var css = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "AgentStateDistributionReportWidget.razor.css");
        // Harness of the live chain (2026-11-09): 400x300 - ring 75 px, all 6 rows; 449x479 - ring 254 px, all 6 rows.
        Rule(css, "report-donut-box").Should().Contain("flex: 1 1 0;").And.Contain("min-height: 60px;");
        Rule(css, "report-donut-legend").Should().Contain("overflow-y: auto");
        // NEGATIVE HALF: the basis deployed in 67f3678 is seen.
        Rule(".report-donut-box {\n    flex: 1 1 auto;\n}", "report-donut-box").Should().NotContain("flex: 1 1 0;");
    }

    private static string Rule(string css, string cls) => Regex.Match(css, @"\." + cls + @" \{[^}]*\}").Value;

    private static string Read(params string[] parts) => File.ReadAllText(Path.Combine(new[] { RepoRoot() }.Concat(parts).ToArray()));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
