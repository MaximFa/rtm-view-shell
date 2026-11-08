using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 (operator 2026-11-08 07:54): Agent Report - the Queue Report configuration by
/// steps, plus a row mode chosen on the view screen ("summary": one row per agent for the period; "by step": one row
/// per agent per interval). These cases hold the screen half; the server half (the order of the rule, the columns per
/// mode, the sort) is backend's QueueReportSortTests / Agent Report tests.
/// </summary>
public class AgentReportViewGuardTests
{
    [Fact]
    public void TheRowMode_isTheViewersOwn_elseTheWidgetsDefault_elseSummary()
    {
        ReportRowModes.Effective(ReportRowMode.ByStep, "summary").Should().Be(ReportRowMode.ByStep, "the viewer's own choice wins");
        ReportRowModes.Effective(null, "byStep").Should().Be(ReportRowMode.ByStep, "else the editor's default");
        ReportRowModes.Effective(null, null).Should().Be(ReportRowMode.Summary, "else summary - what this report always was");
        ReportRowModes.ToConfig(ReportRowMode.ByStep).Should().Be("byStep", "the camelCase name the server reads");

        // NEGATIVE HALF: a value a later version wrote is not a mode here, and does not take the report down.
        ReportRowModes.FromConfig("byShift").Should().BeNull();
        ReportRowModes.Effective(null, "byShift").Should().Be(ReportRowMode.Summary);
    }

    [Fact]
    public void TheWidget_sendsItsStepAndRowMode_andKeepsBothInOneSettingsRow()
    {
        var widget = Widget();
        var build = Regex.Match(widget, @"private RunReportWidgetQuery BuildQuery\([\s\S]*?\n    \}").Value;
        build.Should().Contain("Step = _step").And.Contain("RowMode = _rowMode").And.Contain("SortColumn = _sortColumn");
        SendsHours(build).Should().BeFalse("Agent Report takes the page's period, no shift hours");

        var apply = Regex.Match(widget, @"private async Task ApplyStepAsync\([\s\S]*?\n    \}").Value;
        SavesBoth(apply).Should().BeTrue("the settings row is written whole; saving the step alone would erase the mode");

        // NEGATIVE HALF: the Queue Report save - the step alone - is caught.
        SavesBoth("new Dictionary<string, string> { [StepSettingKey] = _viewStep.ToString() }").Should().BeFalse();
        SendsHours("Config?.ShiftStartHour, Config?.ShiftEndHour").Should().BeTrue();
    }

    private static bool SavesBoth(string text) => text.Contains("[StepSettingKey]") && text.Contains("[RowModeSettingKey]");

    private static bool SendsHours(string text) => Regex.IsMatch(text, @"[Ss]tartHour|[Ee]ndHour");

    [Fact]
    public void InSummary_theStepIsOfferedDisabled_andSaidNotToApply()
    {
        var widget = Widget();
        widget.Should().Contain("disabled=\"@(_viewRowMode == ReportRowMode.Summary)\"", "a step that does nothing must not look like a choice");
        widget.Should().Contain("Report_StepNotInSummary");
        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
        {
            var resx = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));
            foreach (var key in new[] { "Report_StepNotInSummary", "Report_RowModeByStep", "ReportWidget_ModeSummary", "ReportWidget_Mode" })
                resx.Should().Contain($"name=\"{key}\"", $"{key} in {locale}");
        }
    }

    [Fact]
    public void TheEditor_setsTheDefaults_andThePageExportsTheRowModes()
    {
        var modal = File.ReadAllText(Path.Combine(Widgets(), "ReportWidgetConfigModal.razor"));
        modal.Should().Contain("DefaultRowMode = TakesDefaultRowMode ? ReportRowModes.ToConfig(_defaultRowMode) : null");
        Regex.IsMatch(modal, @"TakesDefaultStep => WidgetType is ReportWidgetType\.EndOfShiftQueues or ReportWidgetType\.EndOfShiftAgents")
            .Should().BeTrue("Agent Report opens with a default step too");

        var view = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));
        var export = Regex.Match(view, @"new ExportReportCommand\([\s\S]*?_cts\.Token\)").Value;
        export.Should().Contain("Modes:", "the file must be grouped like the screen").And.Contain("_widgetRowModes");

        // NEGATIVE HALF: the export call as it was for Queue Report alone is caught.
        "new ExportReportCommand(_report.Id, a, b, t, Filters: f, Steps: s), _cts.Token)".Should().NotContain("Modes:");
    }

    /// <summary>
    /// Coordinator 2026-11-08T06:49:47Z: no report takes shift hours, so the code "shift-hours" can no longer arrive -
    /// dead code is a defect. The screen half: no mapping in ReportErrorText or ExportSkipReason, no shift-hour text in
    /// the resources. (The server half, ReportReasonCodes.All and SheetText, is backend's ExportEndOfShiftTests.)
    /// </summary>
    [Fact]
    public void TheShiftHoursCode_isGoneFromTheScreen()
    {
        var contracts = Path.Combine(RepoRoot(), "src", "CcDashboard.Contracts", "Common");
        var texts = new[] { "ReportErrorText.cs", "ExportSkipReason.cs" }.Select(f => File.ReadAllText(Path.Combine(contracts, f)));
        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
            texts = texts.Append(File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx")));
        texts.SelectMany(ShiftHourTraces).Should().BeEmpty();
        CcDashboard.Contracts.Common.ReportErrorText.IsUnknown("shift-hours").Should().BeTrue("the code is not one the screen knows any more");

        // NEGATIVE HALF: the 2026-11-07 lines are caught.
        ShiftHourTraces("        \"shift-hours\" => \"Report_ErrorShiftHours\",").Should().HaveCount(2);
        ShiftHourTraces("<data name=\"ReportWidget_ShiftHoursMissing\">").Should().ContainSingle();
    }

    private static IEnumerable<string> ShiftHourTraces(string text)
        => Regex.Matches(text, @"shift-hours|\w*ShiftHours\w*").Select(m => m.Value);

    private static string Widgets() => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    private static string Widget() => File.ReadAllText(Path.Combine(Widgets(), "EndOfShiftAgentsReportWidget.razor"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
