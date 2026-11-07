using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A filter the person can see must reach everything the screen produces.
///
/// The filter lives over the columns of its own widget - that is where the operator asked for it -
/// but the export file is built by the PAGE. So a widget that filters without telling the page
/// would hand somebody a file with rows their screen was not showing, and nothing would say so.
/// That is the same family as the silently skipped export widget and the ignored second date:
/// the screen acting on something it never told anyone about.
///
/// Held here, and deliberately as two separate facts: a widget can fall silent, and a page can
/// stop listening, and each failure looks exactly like the other from the file.
/// </summary>
public class ReportFilterReachesTheExportGuardTests
{
    [Theory]
    [InlineData("EndOfShiftAgentsReportWidget.razor")]
    [InlineData("AgentPerformanceReportWidget.razor")]
    [InlineData("EndOfShiftQueuesReportWidget.razor")]
    public void AWidgetThatFilters_tellsThePage(string widgetFile)
    {
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), widgetFile));

        // It filters at all - otherwise this guard is watching a widget that cannot go wrong. The
        // filter must reach the QUERY: cutting rows out of the page already in hand would leave
        // "showing 7 of 342" standing over a filtered table.
        Regex.IsMatch(widget, @"(Agent|AgentName|Queue)Filter\s*=\s*AppliedFilter\(")
            .Should().BeTrue($"{widgetFile} must send its applied filter into the query");

        widget.Should().Contain("FilterChanged.InvokeAsync",
            $"{widgetFile} filters but never tells the page - the export would disagree with the screen");

        // And it must say WHICH widget: one board can hold two agent reports filtered differently.
        Regex.IsMatch(widget, @"ReportWidgetFilter\s*BuildWidgetFilter\(\)[\s\S]{0,200}?WidgetId")
            .Should().BeTrue($"{widgetFile} must identify itself, or the page cannot tell two widgets apart");
    }

    [Fact]
    public void ThePage_keepsOneFilterPerWidget_andForgetsTheEmptyOnes()
    {
        var page = ViewPage();

        page.Should().Contain("Dictionary<Guid, ReportWidgetFilter>",
            "the page must keep the filters per widget, not one filter for the whole screen");
        page.Should().Contain("FilterChanged=\"OnWidgetFilterChanged\"",
            "and it must actually subscribe, or the widgets talk to nobody");
        page.Should().Contain("_widgetFilters.Remove",
            "a widget that stopped filtering must be forgotten, not stored as an empty filter");

        // NEGATIVE HALF: a single screen-wide filter field would make the file match neither of
        // two differently filtered widgets. Named as a shape so it cannot return as a shortcut.
        Regex.IsMatch(page, @"private\s+string\??\s+_agentFilter\b")
            .Should().BeFalse("the page must not hold a filter of its own - the filter belongs to the widget");
    }

    [Fact]
    public void TheExport_carriesTheFilters()
    {
        // The last link: the page holds the filters AND builds the file. Before this, the file was
        // built from unfiltered queries while the screen showed filtered rows - and said nothing.
        var page = ViewPage();

        var export = Regex.Match(page, @"new ExportReportCommand\([\s\S]*?\)\s*,");
        export.Success.Should().BeTrue("the export command must be readable here");
        export.Value.Should().Contain("Filters:",
            "the export must carry the screen's filters, or the file disagrees with the screen");
        export.Value.Should().Contain("_widgetFilters",
            "and they must be the filters the widgets reported, not a fresh guess");
    }

    [Fact]
    public void TheWidgetIdReachesTheWidget()
    {
        // The dispatcher is the only path from the page to the widget: if it stops passing the id
        // or the callback, every widget reports filters for Guid.Empty and the page overwrites one
        // with another - two widgets, one entry, and the file matches whichever spoke last.
        var dispatcher = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "RenderReportWidget.razor"));

        Regex.Matches(dispatcher, @"WidgetId=""WidgetId""").Count
            .Should().Be(3, "all three filtering widgets must receive their id");
        Regex.Matches(dispatcher, @"FilterChanged=""FilterChanged""").Count
            .Should().Be(3, "all three filtering widgets must receive the callback");
    }

    private static string ViewPage()
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));

    private static string ReportWidgetsDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
