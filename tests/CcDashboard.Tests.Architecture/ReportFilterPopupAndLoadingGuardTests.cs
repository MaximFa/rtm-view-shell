using System.Text.RegularExpressions;
using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// Two things the operator saw on 234 on 2026-11-07, both mine.
///
/// The filter window was written with class names and no stylesheet rules at all, so it stood in
/// the document flow: it pushed the table out of a widget body that clips its overflow, and the
/// screen showed a cut-off window over an empty widget. Measured: a 968px window inside a 430px
/// widget, 623px of it past the bottom edge, 32 values and no scrolling anywhere.
///
/// And applying a filter replaced the whole table with a spinner, so the data blinked away and
/// back on every change - rows that are one answer old are not wrong, and taking them away is how
/// people learn that a report "loses" data.
///
/// Both are held as rules rather than as the wording of the fixes: the stylesheet must position
/// the window out of the flow and cap the list, and the widgets must ask the shared rule what to
/// show while loading instead of each deciding again.
/// </summary>
public class ReportFilterPopupAndLoadingGuardTests
{
    [Fact]
    public void TheFilterWindowHasRules_andTheyTakeItOutOfTheFlow()
    {
        var css = AppCss();

        var popup = RuleBody(css, ".column-filter-popup");
        popup.Should().NotBeNull("the window had no rules at all, which is how it ended up in the flow");
        Regex.IsMatch(popup!, @"position\s*:\s*(absolute|fixed)")
            .Should().BeTrue("a window in the flow pushes the table out of the widget");
        Regex.IsMatch(popup!, @"z-index\s*:\s*\d+").Should().BeTrue("it must sit above the table, not inside it");
        Regex.IsMatch(popup!, @"max-height\s*:").Should().BeTrue("the window itself must not grow past the screen");

        var values = RuleBody(css, ".column-filter-values");
        values.Should().NotBeNull("the list of values is the part that grows without limit");
        Regex.IsMatch(values!, @"max-height\s*:").Should().BeTrue("32 agents made the window three times the widget's height");
        Regex.IsMatch(values!, @"overflow-y\s*:\s*(auto|scroll)")
            .Should().BeTrue("what does not fit must scroll inside the window, not spill out of it");

        // Right-to-left is the production board: a physical side would put the window on the wrong
        // side of its own button there.
        Regex.IsMatch(popup!, @"\bleft\s*:|\bright\s*:")
            .Should().BeFalse("the window must be placed with logical properties, not left/right");

        // NEGATIVE HALF, built here: the state this guard was written against - a rule block with
        // no positioning at all - must fail the same predicate.
        const string ruleWithoutPositioning = "min-width: 220px; background: #fff;";
        Regex.IsMatch(ruleWithoutPositioning, @"position\s*:\s*(absolute|fixed)").Should().BeFalse();
    }

    [Fact]
    public void TheStylesheetVersionWasBumped()
    {
        // A stylesheet change nobody receives is not a change: the page asks for app.css with a
        // version, and browsers on the board keep the old file until that number moves.
        var app = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "App.razor"));
        var version = Regex.Match(app, @"app\.css\?v=(?<v>\d+)");
        version.Success.Should().BeTrue("app.css must be requested with a version");
        int.Parse(version.Groups["v"].Value).Should().BeGreaterThan(39,
            "the version in force when the window had no rules was 39");
    }

    [Theory]
    [InlineData("EndOfShiftAgentsReportWidget.razor")]
    [InlineData("AgentPerformanceReportWidget.razor")]
    [InlineData("EndOfShiftQueuesReportWidget.razor")]
    public void AWidget_asksTheSharedRuleWhatToShowWhileLoading(string widgetFile)
    {
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), widgetFile));

        widget.Should().Contain("ReportLoadingView.ShowSpinner",
            $"{widgetFile} must not decide on its own when to replace the table with a spinner");
        widget.Should().Contain("ReportLoadingView.ShowUpdatingMark",
            $"{widgetFile} must say that the rows are being refreshed - a silent wait looks like a healthy screen");

        // The shape that was there before: the spinner branch keyed on the loading flag alone,
        // which blanked the table on every filter change.
        Regex.IsMatch(widget, @"else if \(_loading\)")
            .Should().BeFalse($"{widgetFile} must not show the spinner whenever it is loading");
    }

    [Fact]
    public void TheLoadingRuleItself_keepsTheRows()
    {
        // Exercised here too, so this file fails if the behaviour changes while the calls stay.
        ReportLoadingView.ShowSpinner(loading: true, hasRows: true).Should().BeFalse();
        ReportLoadingView.ShowUpdatingMark(loading: true, hasRows: true).Should().BeTrue();
        ReportLoadingView.ShowSpinner(loading: true, hasRows: false).Should().BeTrue();
    }

    /// <summary>The declarations of the first rule for a selector, or null when there is none.</summary>
    private static string? RuleBody(string css, string selector)
    {
        var match = Regex.Match(css, Regex.Escape(selector) + @"\s*\{(?<body>[^}]*)\}");
        return match.Success ? match.Groups["body"].Value : null;
    }

    private static string AppCss()
        => File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css"));

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
