using System.Text.RegularExpressions;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// What the report screen says about time, and what it refuses.
///
/// Three defects measured on 234 on 2026-11-05 are held here, all of the same family - the screen
/// acting on something it never showed the person:
///   - changing only the second date changed nothing, silently (the end-of-shift reports take one
///     date), so the screen now shows ONE field when every widget is end-of-shift;
///   - a start date later than the end date was accepted, and the empty result read as "no
///     traffic" rather than "an impossible window";
///   - an untitled widget showed the enum name, in English, on a Hebrew board.
/// </summary>
public class ReportScreenDatesGuardTests
{
    // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 (operator 2026-11-08 07:54): Agent Report takes a period now, so no report
    // takes one date, and the one-field screen of 2026-11-05 is gone with the rule that drew it. The question of this
    // case changed with it - from "is the second field drawn only where the rule says" to "is it drawn always, and is
    // no single-date path left to hide it again" - and so did its name. Same number of cases in the file.
    [Fact]
    public void BothDateFields_areDrawnAlways_andNoSingleDatePathIsLeft()
    {
        foreach (var page in new[] { ViewPage(), EditorPage() })
        {
            SingleDatePath(page).Should().BeEmpty("no report takes one date; a path that hides the \"to\" field hides a control people need");
            page.Should().Contain("@bind=\"_to\"", "the \"to\" field must be drawn");
        }

        // NEGATIVE HALF: the 2026-11-05 shapes are caught.
        SingleDatePath("@if (!_singleDate)\n{ <input @bind=\"_to\" /> }").Should().NotBeEmpty();
        SingleDatePath("To=\"@(SingleDateNow ? _rangeFrom : _rangeTo)\"").Should().NotBeEmpty();
        SingleDatePath("ReportDateFields.SingleDate(types)").Should().NotBeEmpty();
    }

    private static List<string> SingleDatePath(string text)
        => Regex.Matches(text, @"_singleDate|SingleDateNow|ReportDateFields\.SingleDate|TakesShiftHours").Select(m => m.Value).ToList();

    [Fact]
    public void AnInvertedRange_isRefusedBeforeAnythingIsSent_andOnlyWhereThereIsAPair()
    {
        var page = ViewPage();

        page.Should().Contain("Report_DateRangeInverted",
            "the refusal must be a localised sentence, not an empty report");
        Regex.IsMatch(page, @"if \(_from\.Date > _to\.Date\)")
            .Should().BeTrue("the order check must run - every screen has the pair now");

        // The refusal must happen BEFORE the range is applied: a check after the assignment would
        // show the message and still send the impossible window.
        var apply = Regex.Match(page, @"private void ApplyDateRange\(\)[\s\S]*?\n    \}");
        apply.Success.Should().BeTrue("ApplyDateRange must be readable here");
        apply.Value.IndexOf("Report_DateRangeInverted", StringComparison.Ordinal)
            .Should().BeLessThan(apply.Value.IndexOf("_rangeFrom = _from;", StringComparison.Ordinal),
                "the refusal must come before the range is applied");
    }

    [Fact]
    public void TheDefaultDates_comeFromTheSiteZone_notFromUtc()
    {
        // After local midnight a UTC "today" is still yesterday: the report would open on the
        // wrong day with nobody touching it, and on a one-field screen that is the whole window.
        var page = ViewPage();

        page.Should().Contain("DisplayZone.Zone", "today must be today where the site is");
        Regex.IsMatch(page, @"_from\s*=\s*DateTime\.UtcNow").Should().BeFalse("UtcNow is not the site's today");
        Regex.IsMatch(page, @"_to\s*=\s*DateTime\.UtcNow\.Date\s*;").Should().BeFalse("UtcNow is not the site's today");
    }

    [Fact]
    public void TheDefaultDates_areChosenByTheRule_notByTheFieldCountBeingUnknown()
    {
        // The defect this replaces: the page set "today minus seven" before it knew whether it
        // would draw one field or two, so a one-date screen opened on a week-old shift.
        //
        // The first version of this guard could not go red, and a control proved it: it asked for
        // the words "ReportDateFields.DefaultRange" anywhere in the file - satisfied by a SECOND
        // call further down - and forbade the old defect spelled with the variable name "today",
        // which the page no longer uses. It held the wording of one old mistake instead of the
        // rule. Now it holds the rule: wherever the opening dates are set, they come from the
        // field-count-aware call, and no date arithmetic sits next to _from or _to under any name.
        var page = ViewPage();

        FieldCountAwareCall(page).Should().BeTrue(
            "the opening dates must come from ReportDateFields.DefaultRange, not from arithmetic in the page");
        DateArithmeticOnTheFields(page).Should().BeEmpty(
            "the page must not compute its own period - the rule knows about the one-field screen");

        // NEGATIVE HALF #1: exactly the control that exposed the hole - the call replaced by the
        // old arithmetic, written with the page's current variable name.
        const string brokenAsTheControlDidIt = """
            _from = _siteToday.Date.AddDays(-7);
            _to = _siteToday.Date;
            """;
        DateArithmeticOnTheFields(brokenAsTheControlDidIt).Should().NotBeEmpty(
            "this is the break a control actually made; a guard that misses it watches nothing");
        FieldCountAwareCall(brokenAsTheControlDidIt).Should().BeFalse();

        // NEGATIVE HALF #2: the same break under a different name, because the rule is about what
        // the code DOES, not about which variable somebody used that week.
        const string brokenWithAnotherName = """
            _from = whateverToday.Date.AddDays( -7 );
            _to = whateverToday.Date;
            """;
        DateArithmeticOnTheFields(brokenWithAnotherName).Should().NotBeEmpty(
            "a renamed variable must not make the defect invisible");
    }

    /// <summary>The opening dates are set by the shared rule (since 2026-11-08 it has no field count to know).</summary>
    private static bool FieldCountAwareCall(string text)
        => Regex.IsMatch(text, @"\(\s*_from\s*,\s*_to\s*\)\s*=\s*ReportDateFields\.DefaultRange\s*\(");

    /// <summary>Any date arithmetic assigned to the date fields, whatever it is written against.</summary>
    private static IReadOnlyList<string> DateArithmeticOnTheFields(string text)
        => Regex.Matches(text, @"_(?:from|to)\s*=\s*[^;\r\n]*Add(?:Days|Months|Years)\s*\(")
            .Select(m => m.Value)
            .ToList();

    [Fact]
    public void NoWidgetTitleFallsBackToTheEnumName_andEveryTypeHasAName()
    {
        var page = ViewPage();
        page.Should().NotContain("return widget.WidgetType.ToString();",
            "an untitled widget showed \"EndOfShiftAgents\" on the board - the name must be localised");
        page.Should().Contain("ReportWidgetPalette.NameKey", "and it must be the same name the palette offers");

        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
        {
            var resx = Resx(locale);
            foreach (var type in Enum.GetValues<ReportWidgetType>())
                resx.Should().Contain($"name=\"Report_{type}\"",
                    $"{type} has no name in {locale} and would show as a blank header");

            // NEGATIVE CONTROL for the presence check itself.
            resx.Should().NotContain("name=\"Report___NoSuchTypeForTheGuard__\"");
        }
    }

    [Fact]
    public void TheEndOfShiftWidgets_sayWhichDateAndHoursTheyShow()
    {
        // The caption is what makes an ignored date visible at all; it must be drawn before the
        // refusing branches, or it disappears exactly when the person most needs it.
        foreach (var name in new[] { "EndOfShiftAgentsReportWidget.razor", "EndOfShiftQueuesReportWidget.razor" })
        {
            var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), name));
            widget.Should().Contain("ShownForText", $"{name} must carry the caption");
            widget.IndexOf("ShownForText", StringComparison.Ordinal)
                .Should().BeLessThan(widget.IndexOf("@if (_denied)", StringComparison.Ordinal),
                    $"{name} must draw the caption before the branches that refuse");
            widget.Should().Contain("Report_ShownForDate",
                "with no hours set the caption names the date alone - inventing a window would hide the defect");
        }
    }

    private static string ViewPage()
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));

    private static string EditorPage()
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportEditorPage.razor"));

    private static string Resx(string locale)
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));

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
