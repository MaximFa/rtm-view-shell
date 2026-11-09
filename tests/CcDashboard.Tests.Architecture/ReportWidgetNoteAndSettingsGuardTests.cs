using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// One batch, three rules for the report widgets (coordinator 2026-11-09 08:17:37Z, 08:23:54Z):
/// FEAT-REPORT-INCOMPLETE-NOTE-THIN-ALL-01 - the "still running" note is ONE component, a thin line with no box, in every widget;
/// PR234-V4-REPORT-PERSONAL-SETTINGS-RACE-01 - the viewer's row is awaited by every OnParametersSetAsync call, not behind a flag;
/// PR234-V4-ASD-REPORT-LEGEND-CLIPPED-01 - the donut's legend may shrink and scroll, and the caveat is not a line of its own.
/// </summary>
public class ReportWidgetNoteAndSettingsGuardTests
{
    private static string Dir => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    [Fact]
    public void EveryReportWidget_drawsTheIncompleteNote_byTheOneComponent()
    {
        // Area: every .razor in Components/ReportWidgets.
        var files = Directory.GetFiles(Dir, "*.razor").ToList();
        files.Should().NotBeEmpty("an empty search proves nothing");
        var withNote = files.Where(f => File.ReadAllText(f).Contains("_incomplete")).Select(Path.GetFileName).ToList();
        withNote.Should().BeEquivalentTo(new[] { "AgentPerformanceReportWidget.razor", "EndOfShiftAgentsReportWidget.razor",
            "EndOfShiftQueuesReportWidget.razor", "QueueTrendReportWidget.razor", "AgentStateDistributionReportWidget.razor" },
            "the widgets that are told 'incomplete' - a new one must be looked at, not slip by");
        foreach (var f in files.Where(f => File.ReadAllText(f).Contains("_incomplete")))
            OwnNote(File.ReadAllText(f)).Should().BeFalse($"{Path.GetFileName(f)} must use <ReportIncompleteNote>, not draw its own");

        var note = File.ReadAllText(Path.Combine(Dir, "ReportIncompleteNote.razor"));
        note.Should().Contain("class=\"report-incomplete-note small text-truncate px-2\"").And.Contain("title=\"@Text\"")
            .And.NotContain("alert", "a thin line with no background");
        files.Where(f => Path.GetFileName(f) != "ReportIncompleteNote.razor" && File.ReadAllText(f).Contains("Report_Incomplete"))
            .Should().BeEmpty("one place writes the sentence");

        // NEGATIVE HALF: the yellow box the queue and agent reports drew until now is seen.
        OwnNote("@if (_incomplete)\n{\n<div class=\"alert alert-warning py-1 px-2 mb-1 small\" role=\"status\">@IncompleteText</div>\n}").Should().BeTrue();
    }

    private static bool OwnNote(string text)
        => !text.Contains("<ReportIncompleteNote Incomplete=\"_incomplete\"") || text.Contains("IncompleteText");

    [Fact]
    public void TheViewersRow_isAwaitedByEveryCall_notLoadedBehindAFlag()
    {
        var expected = new Dictionary<string, string>
        {
            ["QueueTrendReportWidget.razor"] = "_personalLoad ??= LoadPersonalAsync();\n        await _personalLoad;",
            ["AgentStateDistributionReportWidget.razor"] = "_personalLoad ??= LoadPersonalAsync();\n        await _personalLoad;",
            ["EndOfShiftQueuesReportWidget.razor"] = "_stepLoad ??= LoadAndAnnounceStepAsync();\n        await _stepLoad;",
            ["EndOfShiftAgentsReportWidget.razor"] = "_stepLoad ??= LoadAndAnnounceStepAsync();\n        await _stepLoad;",
        };
        foreach (var (file, shape) in expected)
        {
            var text = File.ReadAllText(Path.Combine(Dir, file)).Replace("\r\n", "\n");
            text.Should().Contain(shape, file);
            LoadsBehindAFlag(text).Should().BeFalse($"{file}: a second call must not pass a load that has not finished");
        }

        // NEGATIVE HALF: the shape deployed until now is seen.
        LoadsBehindAFlag("if (!_personalLoaded)\n{\n    _personalLoaded = true;\n    await LoadPersonalAsync();\n}").Should().BeTrue();
        LoadsBehindAFlag("if (!_stepLoaded)\n{\n    _stepLoaded = true;\n    await LoadStepAsync();").Should().BeTrue();
    }

    private static bool LoadsBehindAFlag(string text) => Regex.IsMatch(text, @"_(personal|step)Loaded\s*=\s*true;");

    [Fact]
    public void TheDonutLegend_mayScroll_andTheCaveatIsNoLineOfItsOwn()
    {
        var css = File.ReadAllText(Path.Combine(Dir, "AgentStateDistributionReportWidget.razor.css"));
        LegendRule(css).Should().Contain("min-height: 0").And.Contain("overflow-y: auto").And.Contain("flex: 0 1 auto");
        var widget = File.ReadAllText(Path.Combine(Dir, "AgentStateDistributionReportWidget.razor"));
        widget.Should().NotContain("report-widget-caveat", "the caveat is an icon with a tooltip in the period line");
        widget.Should().Contain("title=\"@_caveat\"");

        // NEGATIVE HALF: the rule deployed in c959380 is seen.
        LegendRule(".report-donut-legend {\n    margin-top: 6px;\n    flex: 0 0 auto;\n}").Should().NotContain("overflow-y: auto");
    }

    private static string LegendRule(string css) => Regex.Match(css, @"\.report-donut-legend \{[^}]*\}").Value;

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
