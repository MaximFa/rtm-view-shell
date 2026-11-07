using System.Globalization;
using System.Reflection;
using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Web.Components.ReportWidgets;
using ReportIntervalLabel = CcDashboard.Application.HistoricalReports.ReportIntervalLabel;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-EOS-CONFIGURABLE-01, the step of the end-of-shift queues report (operator
/// 2026-11-07 12:31: "half hour / hour / day / month / year", ascending).
///
/// Three things a person can see must agree: the button they pressed, the rows on screen, and the
/// file they export. The step is chosen in the widget, but the export is built by the PAGE - the
/// same split that once let a filtered screen export an unfiltered file. And the interval label is
/// written from the ANSWER: whether the first or last month is cut by the period is the server's
/// flag, never this screen's guess.
/// </summary>
public class ReportStepReachesTheQueryAndTheExportGuardTests
{
    private static readonly ReportStep[] Ascending =
        { ReportStep.HalfHour, ReportStep.Hour, ReportStep.Day, ReportStep.Month, ReportStep.Year };

    // ---- the buttons ------------------------------------------------------------------------------

    [Fact]
    public void TheStepWindow_offersEveryStep_inAscendingOrder()
    {
        ReportWidgetSteps.Ascending.Should().Equal(Ascending,
            "the operator named the order: half hour, hour, day, month, year");
        // Derived, not typed: a step added to the contract without a button goes red here.
        ReportWidgetSteps.Ascending.Should().BeEquivalentTo(Enum.GetValues<ReportStep>(),
            "every step the server can compute must be offered - and nothing it cannot");

        // Both windows read THAT list - the viewer's step window and the editor's default field.
        foreach (var file in new[] { "EndOfShiftQueuesReportWidget.razor", "ReportWidgetConfigModal.razor" })
            File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), file))
                .Should().Contain("foreach (var step in ReportWidgetSteps.Ascending)",
                    $"{file} must draw its step buttons from the one list");
    }

    // ---- which step is in force: personal -> widget default -> Day ---------------------------------

    [Fact]
    public void ThePersonalChoice_winsOverTheWidgetsDefault()
        => ReportWidgetSteps.Effective(ReportStep.Hour, "month").Should().Be(ReportStep.Hour);

    [Fact]
    public void WithoutAPersonalChoice_theWidgetsDefaultIsUsed()
        => ReportWidgetSteps.Effective(null, "month").Should().Be(ReportStep.Month);

    [Fact]
    public void WithNeither_theStepIsDay()
    {
        ReportWidgetSteps.Effective(null, null).Should().Be(ReportStep.Day);
        // NEGATIVE: an unknown stored default is not a step - it falls through to Day, not to an
        // exception and not to some neighbouring value.
        ReportWidgetSteps.Effective(null, "fortnight").Should().Be(ReportStep.Day);
    }

    [Fact]
    public void TheDefaultTheEditorWrites_isTheDefaultTheServerReads_forEveryStep()
    {
        foreach (var step in Enum.GetValues<ReportStep>())
        {
            var json = new CcDashboard.Web.Components.ReportWidgets.ReportWidgetConfig
            {
                Scope = new ReportScope { BusinessUnitIds = new List<int> { 1 } },
                // Set as the product sets it (the dialog and the widget's query both do): the
                // server's PageSize is a plain int and refuses null.
                PageSize = 25,
                DefaultStep = ReportWidgetSteps.ToConfig(step)
            }.ToJson();

            CcDashboard.Application.HistoricalReports.ReportWidgetConfig.Parse(json).DefaultStep
                .Should().Be(step, $"the server must read back {step} from \"{json}\"");
            ReportWidgetSteps.FromConfig(ReportWidgetSteps.ToConfig(step)).Should().Be(step);
        }

        // NEGATIVE: a name the server does not know is refused by it - the comparison above can fail.
        var act = () => CcDashboard.Application.HistoricalReports.ReportWidgetConfig.Parse(
            "{\"scope\":{\"businessUnitIds\":[1]},\"defaultStep\":\"monthly\"}");
        act.Should().Throw<System.Text.Json.JsonException>();
    }

    [Fact]
    public void ResetInTheStepWindow_returnsToTheWidgetsDefault_notToDay()
    {
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "EndOfShiftQueuesReportWidget.razor"));
        var reset = Regex.Match(widget, @"private async Task ResetStepAsync\(\)[\s\S]*?\n    \}");
        reset.Success.Should().BeTrue("the reset must be readable here");
        reset.Value.Should().Contain("ReportWidgetSteps.Effective(null, Config?.DefaultStep)",
            "reset undoes the viewer's choice; the widget's default stays");
        reset.Value.Should().NotContain("ChangeStepAsync(ReportStep.Day)",
            "a reset straight to Day would throw the editor's default away");
    }

    // ---- query, page, export ------------------------------------------------------------------------

    [Fact]
    public void TheWidget_sendsItsStepWithTheQuery_andTellsThePageWhichWidget()
    {
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "EndOfShiftQueuesReportWidget.razor"));

        // Read inside the query statement itself: "_viewStep = _step" elsewhere in the file contains
        // the same characters, and a needle over the whole file stayed green with the step taken
        // out of the query (caught by this guard's own negative half on 2026-11-07).
        var start = widget.IndexOf("new RunReportWidgetQuery(", StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, "the widget must build a query, readable here");
        var query = widget[start..widget.IndexOf(';', start)];
        Regex.IsMatch(query, @"(?<![\w.])Step\s*=\s*_step\b")
            .Should().BeTrue("the chosen step must go into the query, not only onto the button");
        Regex.IsMatch(widget, @"StepChanged\.InvokeAsync\(\s*new ReportWidgetStep\(\s*WidgetId")
            .Should().BeTrue("the widget must tell the page its step, and say which widget it is");
    }

    [Fact]
    public void TheDispatcher_passesTheStepCallback_toTheQueuesReport()
    {
        var dispatcher = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "RenderReportWidget.razor"));
        var branch = Regex.Match(dispatcher, @"<EndOfShiftQueuesReportWidget[^>]*>");
        branch.Success.Should().BeTrue("the dispatcher must draw the queues report");
        branch.Value.Should().Contain("StepChanged=\"StepChanged\"",
            "without the callback the widget reports its step to nobody, and the file is grouped by days");
    }

    [Fact]
    public void TheExport_carriesTheStepsTheWidgetsReported()
    {
        var page = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));

        page.Should().Contain("StepChanged=\"OnWidgetStepChanged\"", "the page must subscribe to the widgets' steps");

        var start = page.IndexOf("new ExportReportCommand(", StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, "the export command must be readable here");
        var end = page.IndexOf("_cts.Token", start, StringComparison.Ordinal);
        end.Should().BeGreaterThan(start, "the export call must end where it is sent");
        var call = page[start..end];

        call.Should().Contain("Steps:", "the export must carry each widget's step, or the file disagrees with the screen");
        call.Should().Contain("_widgetSteps", "and they must be the steps the widgets reported, not a fresh guess");
    }

    // ---- the interval label -------------------------------------------------------------------------


    [Fact]
    public void TheStart_isWrittenByTheStep()
    {
        var start = new DateTime(2026, 11, 1);
        ReportIntervalLabel.Start(start, ReportStep.Month).Should().Be("11.2026");
        ReportIntervalLabel.Start(new DateTime(2026, 1, 1), ReportStep.Year).Should().Be("2026");

        // Day: the date alone. Hour and half hour: the time is part of the interval.
        ReportIntervalLabel.Start(start, ReportStep.Day).Should().NotContain(":");
        ReportIntervalLabel.Start(new DateTime(2026, 11, 5, 9, 30, 0), ReportStep.HalfHour).Should().Contain("09:30");
        ReportIntervalLabel.Start(new DateTime(2026, 11, 5, 9, 0, 0), ReportStep.Hour).Should().Contain("09:00");
    }

    [Fact]
    public void TheMonthAndYear_lookTheSame_inEveryLanguage()
    {
        foreach (var culture in new[] { "en-US", "ru-RU", "he-IL" })
        {
            var saved = CultureInfo.CurrentCulture;
            try
            {
                CultureInfo.CurrentCulture = new CultureInfo(culture);
                ReportIntervalLabel.Start(new DateTime(2026, 11, 1), ReportStep.Month).Should().Be("11.2026", culture);
                ReportIntervalLabel.Start(new DateTime(2026, 1, 1), ReportStep.Year).Should().Be("2026", culture);
            }
            finally
            {
                CultureInfo.CurrentCulture = saved;
            }
        }
    }

    // FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01 (operator 2026-11-07 18:51: "in the date remove what is in brackets").
    // The five cases below asked "is a cut month / year marked from the period?"; the question is now "is the cell the
    // start for its step and nothing else, however the period cuts it?" - same five cases, same dates.

    [Fact]
    public void ACutFirstAndLastMonth_readAsTheMonthAlone_andTheMiddleToo()
    {
        Cell(new DateTime(2026, 9, 1), ReportStep.Month).Should().Be("09.2026");
        Cell(new DateTime(2026, 10, 1), ReportStep.Month).Should().Be("10.2026");
        Cell(new DateTime(2026, 11, 1), ReportStep.Month).Should().Be("11.2026");
    }

    [Fact]
    public void APeriodInsideOneMonth_readsAsTheMonthAlone()
    {
        Cell(new DateTime(2026, 11, 1), ReportStep.Month).Should().Be("11.2026");
    }

    [Fact]
    public void AYearCutAtTheEnd_readsAsTheYearAlone()
    {
        // The server's own measured case: year 01.01-07.11 -> PartialLast true; the label does not care.
        Cell(new DateTime(2026, 1, 1), ReportStep.Year).Should().Be("2026");
    }

    [Fact]
    public void TheCell_isTheStart_forEveryStep()
    {
        var at = new DateTime(2026, 11, 5, 9, 30, 0);
        foreach (var step in Enum.GetValues<ReportStep>())
            Cell(at, step).Should().Be(ReportIntervalLabel.Start(at, step), $"step {step}");
    }

    [Fact]
    public void NEGATIVE_noCodeBuildsAMark_neitherTheRuleNorTheScreen()
    {
        var rule = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Application", "HistoricalReports", "ReportIntervalLabel.cs"));
        var screen = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "EndOfShiftQueuesReportWidget.razor"));
        BuildsAMark(rule).Should().BeFalse("the rule must write the start and nothing after it");
        BuildsAMark(screen).Should().BeFalse("the screen must not add its own mark to the rule's cell");

        // NEGATIVE HALF: the 3756cce shapes are caught - the method, the bracket glued on, the translated sentence.
        BuildsAMark("public static string? EdgeMark(DateTime rowStart)").Should().BeTrue();
        BuildsAMark("return mark is null ? start : start + \" \" + mark;").Should().BeTrue();
        BuildsAMark("L[\"Report_IntervalFrom\"].Value").Should().BeTrue();
        BuildsAMark("return Start(rowStart, step);").Should().BeFalse();
    }

    private static bool BuildsAMark(string code)
        => code.Contains("EdgeMark(") || code.Contains("Report_IntervalFrom") || code.Contains("Report_IntervalTo")
           || System.Text.RegularExpressions.Regex.IsMatch(code, @"start\s*\+\s*""\s");

    private static string Cell(DateTime row, ReportStep step) => ReportIntervalLabel.Cell(row, step);

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
