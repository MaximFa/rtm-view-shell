using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// PR234-V4-REPORT-FILTER-EMPTY-RESULT-STUCK-01 (operator 2026-11-07 17:00): a filter that leaves no rows used to take
/// the whole table away - header and funnels with it - and replace it with "no data for the period / your access may be
/// limited". The person could not take the filter off, and the message named the wrong cause.
/// Held here: "no data" only when nothing is filtered; empty WITH filters keeps the table, which says why and offers
/// "Clear filters" through the same path as clearing one funnel (so the export drops the filters too).
/// The reports are taken from the column rule, not listed: every table report is covered the day it is added.
/// </summary>
public class ReportEmptyFilteredResultGuardTests
{
    private static IReadOnlyList<ReportWidgetType> TableTypes()
        => Enum.GetValues<ReportWidgetType>().Where(t => ReportColumns.RowTypeOf(t) is not null).ToList();

    /// <summary>The "no data" branch of a widget: the else-if that leads to Report_NoData.</summary>
    private static string NoDataBranch(string widget)
    {
        var m = Regex.Match(widget, @"else if \((?<cond>[^\n]*)\)\s*\{\s*<div class=""alert alert-info"">\s*<i[^>]*></i>@L\[""Report_NoData""\]");
        return m.Success ? m.Groups["cond"].Value : string.Empty;
    }

    private static bool NoDataOnlyWithoutFilters(string cond) => cond.Contains("!_filters.Any");

    [Fact]
    public void EveryTableReport_saysNoDataOnlyWhenNothingIsFiltered()
    {
        var types = TableTypes();
        types.Should().NotBeEmpty("the table reports must be findable, or this guard watches nothing");

        foreach (var type in types)
        {
            var widget = Widget(type);
            var cond = NoDataBranch(widget);
            cond.Should().NotBeEmpty($"{type}: the no-data branch must be readable here");
            NoDataOnlyWithoutFilters(cond).Should().BeTrue($"{type}: \"no data\" must not replace a table that a filter emptied");
        }

        // NEGATIVE HALF: the shape before the fix must fail the same predicate.
        NoDataOnlyWithoutFilters("_result is null || _result.Rows.Count == 0").Should().BeFalse();
    }

    [Fact]
    public void ClearingAllFilters_goesThroughTheSamePathAsOneFunnel()
    {
        foreach (var type in TableTypes())
        {
            var widget = Widget(type);
            var clear = Regex.Match(widget, @"private async Task ClearAllFiltersAsync\(\)\s*\{(?<body>[\s\S]*?)\n    \}");
            clear.Success.Should().BeTrue($"{type}: ClearAllFiltersAsync must exist");
            clear.Groups["body"].Value.Should().Contain("_filters.ClearAll()");
            clear.Groups["body"].Value.Should().Contain("AfterFilterChangedAsync()",
                $"{type}: a clear that skips FilterChanged leaves the export filtered while the screen is not");
            widget.Should().Contain("OnClearFilters=\"ClearAllFiltersAsync\"", $"{type}: the table's button must reach it");
            widget.Should().Contain("FiltersActive=\"_filters.Any\"");
        }

        // NEGATIVE HALF: a clear that only empties the screen state is caught.
        Regex.IsMatch("{ _filters.ClearAll(); StateHasChanged(); }", @"AfterFilterChangedAsync\(\)").Should().BeFalse();
    }

    [Fact]
    public void TheTable_saysWhyItIsEmpty_andOffersTheWayOut_onlyWhenFiltered()
    {
        var table = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportRowTable.razor"));
        var block = Regex.Match(table, @"@if \(FiltersActive && !Rows\.Any\(\)\)\s*\{(?<body>[\s\S]*?)</tr>");
        block.Success.Should().BeTrue("the empty-filtered row must be guarded by FiltersActive - without filters the widget says \"no data\" itself");
        block.Groups["body"].Value.Should().Contain("Report_FilterNoMatch");
        block.Groups["body"].Value.Should().Contain("Widget_ClearFilters");
        block.Groups["body"].Value.Should().Contain("OnClearFilters");

        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
            File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"))
                .Should().Contain("name=\"Report_FilterNoMatch\"", $"missing from {locale}");
    }

    private static string Widget(ReportWidgetType type)
        => File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), $"{type}ReportWidget.razor"));

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
