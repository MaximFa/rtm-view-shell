using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-EOS-CONFIGURABLE-01 (operator 2026-11-07 10:46): QueueInterval, QueueWaitTime and
/// Distribution are taken out of the product. Two things must hold at once, and they pull in
/// opposite directions: a retired type is NOT offered for a new widget, and a widget of that type
/// already standing on a board STILL DRAWS - it says "retired" instead of going blank. Blank is the
/// worse ending: a person reads an empty report as "there was no work".
///
/// Both sets come from the rules - RetiredReports (server) and ReportWidgetPalette.Ready (screen) -
/// so a fourth retired type is covered the day it is retired, without touching this file.
/// </summary>
public class ReportRetiredTypesGuardTests
{
    [Fact]
    public void ARetiredType_isNotOffered_butStillDraws()
    {
        RetiredReports.Types.Should().NotBeEmpty("the retired types must be findable, or this guard watches nothing");

        ReportWidgetPalette.Ready.Intersect(RetiredReports.Types)
            .Should().BeEmpty("a retired report must not be offered for a new widget");

        var dispatched = DispatchedTypes();
        foreach (var type in RetiredReports.Types)
            dispatched.Should().Contain(type.ToString(),
                $"{type} is retired, but widgets of it stand on boards and must still draw (\"retired\", not \"unknown widget\")");
    }

    [Fact]
    public void NEGATIVE_aPaletteThatStillOffersARetiredType_isCaught()
    {
        // The palette as it was before 2026-11-07, rebuilt here: the same intersection must find it.
        var before = ReportWidgetPalette.Ready.Concat(RetiredReports.Types).ToList();
        before.Intersect(RetiredReports.Types).Should().NotBeEmpty(
            "the comparison must spot a retired type in the palette - that is the red this guard produces");

        // And the dispatcher reading must be able to miss a type, or "still draws" cannot go red.
        DispatchedTypes().Should().NotContain("__TypeWithNoRendererForTheGuard__");
    }

    private static IReadOnlyList<string> DispatchedTypes()
    {
        var dispatcher = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets", "RenderReportWidget.razor"));
        var types = Regex.Matches(dispatcher, @"case\s+ReportWidgetType\.(?<t>\w+)\s*:")
            .Select(m => m.Groups["t"].Value)
            .ToList();
        types.Should().NotBeEmpty("the dispatcher's branches must be readable here");
        return types;
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
