using System.Text.RegularExpressions;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-AGENT-STATE-TREND-01 - the screen half of Agent State Trend: drawn by the ONE trend body (QueueTrendReportWidget,
/// Type parameter), the server's six groups, ASD's names and colours, one Y axis in percent. The server half is backend's
/// AgentStateTrendTests.
/// </summary>
public class AgentStateTrendViewGuardTests
{
    private const ReportWidgetType T = ReportWidgetType.AgentStateTrend;

    [Fact]
    public void TheGroups_areTheServersList_withAsdNamesAndColours()
    {
        QueueTrendView.MetricsOf(T).Should().Equal(
            CcDashboard.Application.HistoricalReports.ReportWidgetConfig.AgentStateTrendMetrics.Select(c => c.Name), "one list - the server's");
        QueueTrendView.MetricsOf(T).Should().HaveCount(6);

        // ASD's own default group colours, read from the ASD code - the two screens must agree.
        var editor = Read("src", "CcDashboard.Web", "Components", "Dashboard", "ScreenEditorPage.razor");
        var asd = Regex.Match(editor, @"AsdGroupFallbackColors = new\(\)\s*\{([\s\S]*?)\};").Groups[1].Value;
        var asdColours = Regex.Matches(asd, @"\[""(\w+)""\]\s*=\s*""(#[0-9a-fA-F]{6})""").ToDictionary(m => m.Groups[1].Value, m => m.Groups[2].Value);
        asdColours.Should().HaveCount(6, "the ASD palette must be found, an empty read proves nothing");
        foreach (var m in QueueTrendView.MetricsOf(T))
            QueueTrendView.ColorOf(T, m).Should().Be(asdColours[m.ToUpperInvariant()], m);
        QueueTrendView.MetricsOf(T).Select(m => QueueTrendView.ColorOf(T, m)).Should().OnlyHaveUniqueItems("the legend is colour only");

        // ASD's group names, in every locale.
        foreach (var locale in new[] { "en-US", "he-IL", "ru-RU" })
        {
            var resx = Read("src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx");
            foreach (var m in QueueTrendView.MetricsOf(T))
                resx.Should().Contain($"name=\"{QueueTrendView.LabelKeyOf(T, m)}\"", $"{m} in {locale}");
        }

        // NEGATIVE HALF: an unknown group is grey, and Queue Trend keeps its own colours and labels.
        QueueTrendView.ColorOf(T, "SomethingNew").Should().Be("#6c757d");
        QueueTrendView.ColorOf(ReportWidgetType.QueueTrend, "Offered").Should().Be(QueueTrendView.Color("Offered"));
        QueueTrendView.LabelKeyOf(ReportWidgetType.QueueTrend, "Offered").Should().NotStartWith("Widget_ASD_Segment_");
    }

    [Fact]
    public void WithNothingChosen_allSixGroupsAreShown_theWholeLoginTime()
    {
        QueueTrendView.EffectiveOf(T, null, null).Should().Equal(QueueTrendView.MetricsOf(T));
        QueueTrendView.EffectiveOf(T, new[] { "Break" }, new[] { "Available" }).Should().Equal("Break");
        QueueTrendView.EffectiveOf(T, null, new[] { "Training", "Available" }).Should().Equal("Available", "Training");

        // NEGATIVE HALF: Queue Trend's fallback is not all of its metrics.
        QueueTrendView.EffectiveOf(ReportWidgetType.QueueTrend, null, null).Should().Equal(QueueTrendView.FallbackMetrics);
    }

    [Fact]
    public void ItIsDrawnByTheOneTrendBody_inPercent_andDayTrendIsUnchanged()
    {
        var render = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "RenderReportWidget.razor");
        render.Should().Contain("<QueueTrendReportWidget Type=\"ReportWidgetType.AgentStateTrend\"");
        SecondTrendBodies(Directory.GetFiles(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets"), "*.razor"))
            .Should().BeEmpty("no second copy of the trend widget");

        var widget = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "QueueTrendReportWidget.razor");
        widget.Should().Contain("Type == ReportWidgetType.AgentStateTrend ? res.AgentStateTrend : res.QueueTrend");
        widget.Should().Contain("percent = Type == ReportWidgetType.AgentStateTrend");

        var js = Read("src", "CcDashboard.Web", "wwwroot", "js", "daytrendChart.js");
        js.Should().Contain("if (options?.percent) {").And.Contain("defaultOptions.scales.y.max = 100;");
        Read("src", "CcDashboard.Web", "Components", "Widgets", "DayTrendWidget.razor").Should().NotContain("percent",
            "DayTrend passes no percent option and draws as before");

        // NEGATIVE HALF: a copied widget would be caught.
        SecondTrendBodies(new[] { "x/AgentStateTrendReportWidget.razor" }).Should().HaveCount(1);
    }

    private static List<string> SecondTrendBodies(IEnumerable<string> files)
        => files.Select(Path.GetFileName).Where(n => n!.Contains("Trend", StringComparison.Ordinal) && n != "QueueTrendReportWidget.razor").ToList()!;

    [Fact]
    public void ThePalette_offersIt_amongAgents_withAnIconOfItsOwn()
    {
        ReportWidgetPalette.Ready.Should().Contain(T);
        ReportWidgetPalette.Category(T).Should().Be("Agents");
        var icons = Enum.GetValues<ReportWidgetType>().Where(t => t != T).Select(ReportWidgetPalette.Icon).ToList();
        icons.Should().NotContain(ReportWidgetPalette.Icon(T), "an icon of its own");

        // NEGATIVE HALF: the check sees a taken icon.
        icons.Should().Contain(ReportWidgetPalette.Icon(ReportWidgetType.QueueTrend));
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
