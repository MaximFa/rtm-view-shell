using System.Text.RegularExpressions;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-QUEUE-TREND-COMPARE-01 - the screen half of Queue Trend: the metric list and colours, the rule of what is
/// shown, the comparison's end, and that the chart is drawn by the ONE chart module (daytrendChart.js) through opt-in
/// options, so DayTrend draws as before. The server half (grid, sums, comparison by index) is backend's QueueTrendTests.
/// </summary>
public class QueueTrendViewGuardTests
{
    [Fact]
    public void TheMetrics_areTheServersList_andEachHasAColourOfItsOwn()
    {
        QueueTrendView.Metrics.Should().Equal(
            CcDashboard.Application.HistoricalReports.ReportWidgetConfig.QueueTrendMetrics.Select(c => c.Name),
            "one list of metrics - the server's");
        var colours = QueueTrendView.Metrics.Select(QueueTrendView.Color).ToList();
        colours.Should().OnlyHaveUniqueItems("two metrics in one colour cannot be told apart - the legend is colour only (18:17)");
        colours.Should().NotContain("#6c757d", "every metric has its own colour, none falls to the grey of an unknown one");

        // NEGATIVE HALF: an unknown metric is grey - the check above would catch a metric added without a colour.
        QueueTrendView.Color("SomethingNew").Should().Be("#6c757d");
    }

    [Fact]
    public void TheMetricsShown_areTheViewersOwn_elseTheEditorsDefault_elseTheFallback()
    {
        QueueTrendView.Effective(new[] { "SlPct" }, new[] { "Offered" }).Should().Equal("SlPct");
        QueueTrendView.Effective(null, new[] { "Asa", "Offered" }).Should().Equal(new[] { "Offered", "Asa" }, "in the server's order");
        QueueTrendView.Effective(null, null).Should().Equal(QueueTrendView.FallbackMetrics);

        // NEGATIVE HALF: names a later version wrote are not metrics here, and an all-unknown pick does not empty the chart.
        QueueTrendView.Effective(new[] { "Nope" }, null).Should().Equal(QueueTrendView.FallbackMetrics);
    }

    [Fact]
    public void TheComparison_endsAsManyDaysLaterAsTheReportIsLong()
    {
        // The mockup the operator saw: 02/11-08/11/2026 compared from 26/10/2026 -> to 01/11/2026 (operator 18:08).
        var from = new DateTime(2026, 11, 2); var to = new DateTime(2026, 11, 8);
        QueueTrendView.CompareTo(new DateTime(2026, 10, 26), from, to).Should().Be(new DateTime(2026, 11, 1));
        QueueTrendView.Days(from, to).Should().Be(7);

        // NEGATIVE HALF: one day out either way is caught.
        QueueTrendView.CompareTo(new DateTime(2026, 10, 26), from, to).Should().NotBe(new DateTime(2026, 11, 2));
        QueueTrendView.CompareTo(new DateTime(2026, 10, 26), from, to).Should().NotBe(new DateTime(2026, 10, 31));
    }

    [Fact]
    public void TheWidget_asksForItsStepAndComparison_drawsWithTheSharedChart_andKeepsOneSettingsRow()
    {
        var widget = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        widget.Should().Contain("Step = _step").And.Contain("CompareFrom = _compareFrom");
        widget.Should().Contain("dayTrendChart.render", "the one chart module draws it");
        NewChartCode(widget).Should().BeEmpty("no second copy of the chart code");
        var apply = Regex.Match(widget, @"private async Task ApplyAsync\(\)[\s\S]*?\n    \}").Value;
        apply.Should().Contain("[StepKey]").And.Contain("[MetricsKey]").And.Contain("[CompareKey]");
        var legend = Regex.Match(widget, @"report-trend-legend[\s\S]*?</div>").Value;
        legend.Should().Contain("foreach (var m in _metrics)").And.NotContain("compare", "one legend entry per metric (18:17)");

        // NEGATIVE HALF: a widget that built its own Chart is caught.
        NewChartCode("<script>new Chart(ctx, cfg)</script>").Should().NotBeEmpty();
    }

    [Fact]
    public void TheComparisonStart_isChosenWithTheDatePicker()
    {
        var widget = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        CompareInputType(widget).Should().Be("date", "operator 20:26 - every date in the product is chosen with the picker");
        QueueTrendView.FromStored("2026-10-26").Should().Be(new DateTime(2026, 10, 26), "the picker hands over yyyy-MM-dd");
        QueueTrendView.FromStored(string.Empty).Should().BeNull("an empty picker means no comparison");

        // NEGATIVE HALF: the plain text box that was deployed in 12faa24 is caught.
        CompareInputType("<input id=\"@(_chartId + \"-cmp\")\" type=\"text\" class=\"x\" />").Should().Be("text");
    }

    private static string CompareInputType(string text)
        => Regex.Match(text, @"<input id=""@\(_chartId \+ ""-cmp""\)"" type=""(\w+)""").Groups[1].Value;

    [Fact]
    public void WithAComparison_theChartIsLinesOnly_whateverTypeWasChosen()
    {
        // Operator 2026-11-08 20:47: a comparison draws lines; the choices are kept, not erased.
        foreach (var saved in QueueTrendView.ChartTypes)
        {
            QueueTrendView.ChartType(saved, null, comparing: true).Should().Be("line");
            QueueTrendView.ChartType(null, saved, comparing: true).Should().Be("line");
        }

        // NEGATIVE HALF: without a comparison a saved "bar" draws bars - the rule above is not "always line".
        QueueTrendView.ChartType("bar", null, comparing: false).Should().Be("bar");
        QueueTrendView.ChartType(null, "area", comparing: false).Should().Be("area", "the editor's default");
        QueueTrendView.ChartType("step", "area", comparing: false).Should().Be("step", "the viewer's own first");
        QueueTrendView.ChartType("pie", "nonsense", comparing: false).Should().Be("line", "unknown names count as not chosen");

        var widget = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        widget.Should().Contain("chartType = _chartType", "the widget draws the type in force, not a fixed line");
        widget.Should().Contain("comparing: _compareFrom is not null");
        var apply = Regex.Match(widget, @"private async Task ApplyAsync\(\)[\s\S]*?\n    \}").Value;
        apply.Should().Contain("[ChartTypeKey]", "the type lives in the same one settings row");
    }

    [Fact]
    public void TheIncompleteNote_isOneThinLine_notABox()
    {
        var widget = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        IncompleteNote(widget).Should().Contain("report-trend-incomplete").And.Contain("text-truncate")
            .And.Contain("title=\"@IncompleteText\"", "the full text stays in the tooltip");

        // NEGATIVE HALF: the alert box deployed in 12faa24 is caught.
        IncompleteNote("@if (_incomplete)\n{\n<div class=\"alert alert-warning py-1 px-2 mb-1 small\" role=\"status\">")
            .Should().NotContain("report-trend-incomplete");
    }

    private static string IncompleteNote(string text) => Regex.Match(text, @"@if \(_incomplete\)[\s\S]*?</div>|@if \(_incomplete\)[\s\S]*$").Value;

    private static List<string> NewChartCode(string text) => Regex.Matches(text, @"new\s+Chart\s*\(").Select(m => m.Value).ToList();

    [Fact]
    public void TheSharedChart_drawsTheComparisonOnlyWhenAsked_soDayTrendIsUnchanged()
    {
        var js = Read("src", "CcDashboard.Web", "wwwroot", "js", "daytrendChart.js");
        js.Should().Contain("if (options?.compareLabels)", "the top axis only when a comparison is passed");
        js.Should().Contain("if (options?.periodLabels)", "the per-point date tooltip only when asked");
        js.Should().Contain("(options?.keepNulls ? null : 0)", "DayTrend keeps its zeros; only Queue Trend keeps gaps");
        js.Split("new Chart(").Length.Should().Be(2, "still one place that creates a chart");
        Read("src", "CcDashboard.Web", "Components", "Widgets", "DayTrendWidget.razor")
            .Should().NotContain("compareLabels").And.NotContain("keepNulls", "DayTrend passes none of the new options");
    }

    [Fact]
    public void TheEditor_offersTheQueuesAndDefaultMetrics_andNoColumnsForTheChart()
    {
        var modal = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "ReportWidgetConfigModal.razor");
        modal.Should().Contain("new GetScopedQueuesQuery(_selectedBuIds.ToList())", "the server's queues of the chosen units");
        modal.Should().Contain("Columns = (IsQueueTrendWidget ||", "a chart saves no columns; the server refuses them");
        modal.Should().Contain("DefaultMetrics = IsQueueTrendWidget");
        modal.Should().Contain("Workgroups = IsQueueTrendWidget");
        ReportWidgetPalette.Ready.Should().Contain(CcDashboard.Domain.Domain.Reports.ReportWidgetType.QueueTrend);
    }

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
