using System.Text.RegularExpressions;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 - the screen half of the period donut: the period in force (own, else the report's),
/// drawn by ASD's own module, Agent State Trend's groups, names and colours; plus, in the same batch,
/// PR234-V4-REPORT-UNCONFIGURED-TEXT-SAYS-QUEUE-01 and PR234-V4-REPORT-AGENT-PICKER-TAB-01. The server half is backend's.
/// </summary>
public class AgentStateDistributionViewGuardTests
{
    private const ReportWidgetType T = ReportWidgetType.AgentStateDistribution;
    private static readonly DateTime PageFrom = new(2026, 11, 1), PageTo = new(2026, 11, 8);

    [Fact]
    public void ThePeriod_isTheWidgetsOwn_whenSet_elseTheReports()
    {
        AgentStateDistributionView.Period(new DateTime(2026, 9, 14), new DateTime(2026, 9, 20), PageFrom, PageTo)
            .Should().Be((new DateTime(2026, 9, 14), new DateTime(2026, 9, 20), true));
        AgentStateDistributionView.Period(null, null, PageFrom, PageTo).Should().Be((PageFrom, PageTo, false));

        // NEGATIVE HALF: half a period, or a reversed one, is not a period - the report's applies, and the window refuses it.
        AgentStateDistributionView.Period(new DateTime(2026, 9, 14), null, PageFrom, PageTo).Should().Be((PageFrom, PageTo, false));
        AgentStateDistributionView.Period(new DateTime(2026, 9, 20), new DateTime(2026, 9, 14), PageFrom, PageTo).Should().Be((PageFrom, PageTo, false));
        AgentStateDistributionView.CanApply(new DateTime(2026, 9, 14), null).Should().BeFalse();
        AgentStateDistributionView.CanApply(null, null).Should().BeTrue("both empty = back to the report's period");

        var widget = Widget();
        widget.Should().Contain("private void ApplyEffective() => (_from, _to, _own) = AgentStateDistributionView.Period(_ownFrom, _ownTo, From, To);");
        Regex.Matches(widget, @"type=""date""").Count.Should().Be(2, "both ends with the date picker");
    }

    [Fact]
    public void ItIsDrawnByAsdsOwnModule_withTheTrendsGroups_andAsdIsUnchanged()
    {
        var widget = Widget();
        widget.Should().Contain("agentStateDistributionChart.render").And.Contain("valueFormat = \"duration\"");
        Regex.IsMatch(widget, @"new\s+Chart\s*\(").Should().BeFalse("no second copy of the chart code");
        widget.Should().Contain("private const ReportWidgetType Trend = ReportWidgetType.AgentStateTrend;", "one list of groups, one palette");
        widget.Should().Contain("QueueTrendView.ColorOf(Trend, g.Metric)").And.Contain("QueueTrendView.LabelKeyOf(Trend, g.Metric)");

        var js = Read("src", "CcDashboard.Web", "wwwroot", "js", "agentStateDistributionChart.js");
        js.Should().Contain("cd.valueFormat === 'duration' ? self._formatDuration(rawValue) : rawValue");
        Read("src", "CcDashboard.Web", "Components", "Widgets", "AgentStateDistributionWidget.razor")
            .Should().NotContain("valueFormat", "the real-time ASD passes no new option and keeps its counts");

        AgentStateDistributionView.Segment(-5000).Should().Be(0, "a negative Other is no arc");
        AgentStateDistributionView.Segment(5000).Should().Be(5000);
        AgentStateDistributionView.Share(37.25).Should().Be("37.3%");
        AgentStateDistributionView.Share(null).Should().Be("—");
        AgentStateDistributionView.Duration(3_725_000).Should().Be("1:02:05");
        AgentStateDistributionView.Duration(125_000).Should().Be("2:05");
        // Operator 2026-11-09 07:54: the centre is the number of distinct agents who logged in, under ASD's own word.
        Centre(widget).Should().Contain("@_result.AgentCount").And.Contain("L[\"Widget_Agents\"]").And.NotContain("LoggedInMs");
        // NEGATIVE HALF: the login-time centre written first is seen.
        Centre("<div class=\"report-donut-centre\"><b>@AgentStateDistributionView.LoginTime(_result.LoggedInMs)</b></div>")
            .Should().NotContain("AgentCount");

        // NEGATIVE HALF: a widget with its own Chart would be caught.
        Regex.IsMatch("x = new Chart(ctx, cfg);", @"new\s+Chart\s*\(").Should().BeTrue();
    }

    private static string Centre(string text) => Regex.Match(text, @"<div class=""report-donut-centre"">[\s\S]*?</div>").Value;

    [Fact]
    public void ThePalette_offersIt_amongAgents_withAnIconOfItsOwn()
    {
        ReportWidgetPalette.Ready.Should().Contain(T);
        ReportWidgetPalette.Category(T).Should().Be("Agents");
        var icons = Enum.GetValues<ReportWidgetType>().Where(t => t != T).Select(ReportWidgetPalette.Icon).ToList();
        icons.Should().NotContain(ReportWidgetPalette.Icon(T));
        // NEGATIVE HALF: the retired Distribution's icon is taken.
        icons.Should().Contain("bi-pie-chart");
    }

    [Fact]
    public void AnUnconfiguredAgentReport_asksForUnitsAndAgents_notAQueue()
    {
        var render = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "RenderReportWidget.razor");
        render.Should().Contain("<span>@L[UnconfiguredKey]</span>");
        render.Should().Contain("ReportWidgetPalette.Category(WidgetType) == \"Agents\"");
        foreach (var locale in new[] { "en-US", "he-IL", "ru-RU" })
        {
            var resx = Read("src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx");
            var text = Regex.Match(resx, @"name=""ReportWidget_UnconfiguredAgents""><value>([^<]*)<").Groups[1].Value;
            text.Should().NotBeEmpty(locale);
            QueueWords.Any(w => text.Contains(w, StringComparison.OrdinalIgnoreCase)).Should().BeFalse($"{locale}: an agent report has no queue");
        }
        var agents = ReportWidgetPalette.Ready.Where(t => ReportWidgetPalette.Category(t) == "Agents").ToList();
        agents.Should().Contain(new[] { ReportWidgetType.EndOfShiftAgents, ReportWidgetType.AgentStateTrend, T });

        // NEGATIVE HALF: the shared text deployed until now does name the queue.
        var old = Regex.Match(Read("src", "CcDashboard.Web", "Resources", "SharedResources.he-IL.resx"),
            @"name=""ReportWidget_Unconfigured""><value>([^<]*)<").Groups[1].Value;
        QueueWords.Any(w => old.Contains(w)).Should().BeTrue();
    }

    private static readonly string[] QueueWords = { "queue", "תור", "очеред" };

    [Fact]
    public void TheAgentPick_isOnTheScopeTab_forEveryAgentReport()
    {
        var modal = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "ReportWidgetConfigModal.razor");
        TabOf(modal, "@if (TakesAgentPick)").Should().Be("scope", "the scope - whom to show - is one tab for every report");
        foreach (var t in new[] { "ReportWidgetType.EndOfShiftAgents", "ReportWidgetType.AgentStateTrend", "ReportWidgetType.AgentStateDistribution" })
            Regex.Match(modal, @"private bool TakesAgentPick =>[^;]*;").Value.Should().Contain(t);

        // NEGATIVE HALF: the place it had until now (the general tab) is seen.
        TabOf("@if (_tab == \"scope\")\n x \n else if (_tab == \"general\")\n @if (TakesAgentPick)", "@if (TakesAgentPick)").Should().Be("general");
    }

    private static string TabOf(string modal, string needle)
    {
        var at = modal.IndexOf(needle, StringComparison.Ordinal);
        at.Should().BeGreaterThan(0, "the needle must be found, or the check proves nothing");
        var scope = modal.IndexOf("@if (_tab == \"scope\")", StringComparison.Ordinal);
        var general = modal.IndexOf("else if (_tab == \"general\")", StringComparison.Ordinal);
        return at > scope && at < general ? "scope" : at > general ? "general" : "?";
    }

    private static string Widget() => Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "AgentStateDistributionReportWidget.razor");

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
