using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// The funnel filters: who offers them, and in whose units the typed value is sent.
///
/// Operator, 2026-11-07: "why didn't we make the filter like the real-time grids - a funnel at the
/// column? I want filters on all the fields, and this way we just build another filter bar that
/// duplicates the columns." A bar above the table names the columns a second time, and two
/// namings drift; a funnel sits on the column it filters.
///
/// The unit is the dangerous half. A duration column stores milliseconds or seconds, and the
/// window takes "h:mm:ss" because that is what the cell shows. Sending the typed number straight
/// through would filter by a thousandth of what the person meant - the same defect, in the
/// opposite direction, as the total that was once printed through the milliseconds formatter and
/// showed nine hours as thirty-two seconds.
/// </summary>
public class ReportFunnelFiltersGuardTests
{
    private static readonly string[] TableWidgets =
    {
        "QueueIntervalReportWidget.razor",
        "QueueWaitTimeReportWidget.razor",
        "AgentMonthlyReportWidget.razor",
        "AgentShiftDetailReportWidget.razor",
        "EndOfShiftQueuesReportWidget.razor",
        "EndOfShiftAgentsReportWidget.razor",
        "AgentPerformanceReportWidget.razor"
    };

    [Fact]
    public void EveryTableReport_hasFunnelsAndNoFilterBar()
    {
        foreach (var file in TableWidgets)
        {
            var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), file));

            widget.Should().Contain("<ColumnFilterHeader", $"{file} must offer the funnel on its columns");
            widget.Should().Contain("<ReportRowTable", $"{file} must draw through the one table");
            widget.Should().NotContain("report-widget-filters",
                $"{file} still carries the row of filter buttons - it names the columns a second time");
            widget.Should().NotContain("<table",
                $"{file} must not draw a table of its own: its columns and units would drift from the shared one");
        }
    }

    [Fact]
    public void TheFunnelIsOfferedByTheRule_notByTheMarkup()
    {
        // The table asks ReportColumns which columns take a filter, and only those get a funnel.
        var table = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportRowTable.razor"));
        table.Should().Contain("Filterable",
            "the funnel must follow the rule, so a column that cannot be filtered never shows one");

        // NEGATIVE HALF on the rule itself: an id column must not be filterable, and a plain
        // column must be. If both came back the same, "by the rule" would mean nothing.
        ReportColumns.Find(ReportWidgetType.QueueInterval, "QueueId")!.Filterable
            .Should().BeFalse("an id is not something a person filters by");
        ReportColumns.Find(ReportWidgetType.QueueInterval, "Answered")!.Filterable
            .Should().BeTrue();
    }

    [Theory]
    [InlineData(ReportColumnKind.DurationMs, "0:01:00", 60000)]
    [InlineData(ReportColumnKind.DurationSec, "0:01:00", 60)]
    [InlineData(ReportColumnKind.DurationSec, "1:00:00", 3600)]
    [InlineData(ReportColumnKind.Count, "42", 42)]
    public void ATypedValue_leavesInTheColumnsOwnUnit(ReportColumnKind kind, string typed, double expected)
    {
        var draft = new ColumnFilterDraft("greater", string.Empty, Array.Empty<string>(),
            Number: kind is ReportColumnKind.DurationMs or ReportColumnKind.DurationSec
                ? ReportFilterState.ParseDuration(typed)
                : ReportFilterState.ParseNumber(typed));

        var filter = ReportFilterState.Build("AnyColumn", kind, draft);

        filter.Should().NotBeNull();
        filter!.Number.Should().Be(expected,
            "a minute typed as 0:01:00 is 60000 in a milliseconds column and 60 in a seconds one");
    }

    [Fact]
    public void AValueThatCannotBeRead_isNotSent()
    {
        // The window says so instead: a value the column cannot hold comes back from the server as
        // "the settings cannot be used", which reads as a broken report rather than as a typo.
        ReportFilterState.ParseDuration("yesterday").Should().BeNull();
        ReportFilterState.ParseNumber("yesterday").Should().BeNull();

        var empty = new ColumnFilterDraft("greater", string.Empty, Array.Empty<string>());
        ReportFilterState.Build("AnyColumn", ReportColumnKind.Count, empty)
            .Should().BeNull("an empty window is not a filter that matches everything");
    }

    [Fact]
    public void TickedValuesWinOverTypedText_andAreSentAsThemselves()
    {
        // The server refuses text and values at once; the ticks are the more exact statement, so
        // they win - and they are sent as they are, never run through a unit conversion.
        var draft = new ColumnFilterDraft("contains", "adi", new[] { "adi@example.com" });
        var filter = ReportFilterState.Build("AgentExternalId", ReportColumnKind.Text, draft);

        filter!.Values.Should().Equal("adi@example.com");
        filter.Text.Should().BeNull("text and values must never travel together");
    }

    [Fact]
    public void TheFilterIsScreenStateOnly()
    {
        // Operator's rule: a filter kept in the configuration would open tomorrow's shift already
        // narrowed, and whoever opened it would read an empty table as "there was no work".
        var webConfig = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetConfig.cs"));
        webConfig.Should().NotContain("Filter",
            "the widget configuration must carry no filter of any kind");

        foreach (var file in TableWidgets)
            File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), file))
                .Should().NotContain("localStorage", $"{file} must not remember filters in the browser either");
    }

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
