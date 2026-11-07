using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A filter the person can see must reach everything the screen produces.
///
/// The filter lives on the column it filters - a funnel in the header - but the export file is
/// built by the PAGE. So a widget that filters without telling the page would hand somebody a file
/// with rows their screen was not showing, and nothing would say so. That is the same family as
/// the silently skipped export widget and the ignored second date: the screen acting on something
/// it never told anyone about.
///
/// Rewritten on 2026-11-07, when the funnels replaced the row of filter buttons. The questions it
/// asks are unchanged - that is the point of rewriting rather than deleting - but two of them had
/// been written against the shape of the day: "the three filtering widgets" and "AgentFilter =
/// AppliedFilter(...)". Both are now derived: every TABLE report filters, and the filters travel
/// as a list built by the shared state. A guard that counts today's widgets goes red the day an
/// eighth report is added, and a guard that names today's spelling goes red the day the spelling
/// changes - neither failure would be about the rule it is meant to hold.
/// </summary>
public class ReportFilterReachesTheExportGuardTests
{
    /// <summary>
    /// The report types that draw a table, from the one rule - not a list typed here. Distribution
    /// has no row record and therefore no columns to filter.
    /// </summary>
    private static IReadOnlyList<ReportWidgetType> TableTypes()
        => Enum.GetValues<ReportWidgetType>()
            .Where(t => ReportColumns.RowTypeOf(t) is not null)
            .ToList();

    private static string WidgetFile(ReportWidgetType type) => $"{type}ReportWidget.razor";

    [Fact]
    public void EveryTableReport_sendsItsFilterIntoTheQuery_andTellsThePage()
    {
        var types = TableTypes();
        types.Should().NotBeEmpty("the table reports must be findable, or this guard watches nothing");

        foreach (var type in types)
        {
            var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), WidgetFile(type)));

            // Into the QUERY, not over the page already in hand: cutting rows here would leave
            // "showing 7 of 342" standing over a filtered table - a lie about the data.
            widget.Should().Contain("Filters = _filters.ForQuery()",
                $"{WidgetFile(type)} must send its funnel filters with the query");

            widget.Should().Contain("FilterChanged.InvokeAsync",
                $"{WidgetFile(type)} filters but never tells the page - the export would disagree with the screen");

            // And it must say WHICH widget: one board can hold two agent reports filtered differently.
            Regex.IsMatch(widget, @"new ReportWidgetFilter\(\s*WidgetId")
                .Should().BeTrue($"{WidgetFile(type)} must identify itself, or the page cannot tell two widgets apart");
        }
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

        // NEGATIVE HALF: a single screen-wide filter would make the file match neither of two
        // differently filtered widgets. Named as a shape so it cannot return as a shortcut.
        Regex.IsMatch(page, @"private\s+(?:readonly\s+)?(?:string|ReportColumnFilter)\??\s+_filter\b")
            .Should().BeFalse("the page must not hold a filter of its own - a filter belongs to its widget");
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
    public void TheDispatcherPassesTheIdAndTheCallback_toEveryTableReport()
    {
        // The dispatcher is the only path from the page to a widget: if it stops passing the id or
        // the callback, widgets report filters for Guid.Empty and the page overwrites one with
        // another - two widgets, one entry, and the file matches whichever spoke last.
        //
        // The expected number comes from the rule, not from a number typed here: when an eighth
        // table report is added, this guard must ask about eight, not go red about seven.
        var dispatcher = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "RenderReportWidget.razor"));
        var expected = TableTypes().Count;

        foreach (var type in TableTypes())
        {
            var branch = Regex.Match(dispatcher, $@"<{type}ReportWidget[^>]*>");
            branch.Success.Should().BeTrue($"the dispatcher must draw {type}");
            branch.Value.Should().Contain("WidgetId=\"WidgetId\"", $"{type} must receive its id");
            branch.Value.Should().Contain("FilterChanged=\"FilterChanged\"", $"{type} must receive the callback");
        }

        Regex.Matches(dispatcher, @"WidgetId=""WidgetId""").Count
            .Should().BeGreaterThanOrEqualTo(expected,
                "every table report must receive its id - counted from the rule, not from today's markup");
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
