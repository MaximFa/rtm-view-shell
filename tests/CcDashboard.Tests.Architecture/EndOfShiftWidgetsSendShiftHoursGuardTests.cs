using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// An end-of-shift widget must send the shift hours, and must send ONE date.
///
/// What went wrong: the shift hours existed on the query (RunReportWidgetQuery.ShiftStartHour /
/// ShiftEndHour) and were enforced server-side (RunReportWidgetQueryHandler.ValidateShift), but
/// nothing in Web ever filled them - measured 2026-11-04: zero occurrences of either name under
/// src/CcDashboard.Web, against seven RunReportWidgetQuery call sites. So both end-of-shift
/// widgets could only ever draw the server's refusal, in English, on a production dashboard. The
/// unit tests could not see it: they do not reach the handler, and the palette guard only asks
/// whether a renderer exists.
///
/// The two rules this holds:
///   1. a widget for an end-of-shift type passes both hours;
///   2. it asks for a single date - the handler refuses a window that spans two dates, and the
///      date is the one picked on the page (operator, 2026-11-04: "from the screen, like the
///      other reports"), so the page's second date field does not take part.
///
/// The widget files are found through the enum, not by a list of names written here: a third
/// end-of-shift type would be covered the day it is added, without touching this file.
/// </summary>
public class EndOfShiftWidgetsSendShiftHoursGuardTests
{
    [Fact]
    public void EveryEndOfShiftWidget_sendsBothShiftHours_andTheCheckCanStillGoRed()
    {
        var widgets = EndOfShiftWidgetSources();
        widgets.Should().NotBeEmpty("the end-of-shift widgets must be findable, or this guard checks nothing");

        foreach (var (name, call) in widgets)
        {
            SendsBothHours(call).Should().BeTrue(
                $"{name} must pass the shift hours; without them the server refuses before reading any data");
        }

        // NEGATIVE HALF, built here rather than taken from today's code: a call that omits the
        // hours must be caught by the SAME predicate. If this came back true, the loop above would
        // be incapable of failing and its green would mean nothing.
        const string callWithoutHours = """
            new RunReportWidgetQuery(
                ReportWidgetType.EndOfShiftSomething,
                configJson,
                shiftDate,
                shiftDate,
                _page,
                TenantId)
            """;
        SendsBothHours(callWithoutHours).Should().BeFalse(
            "the predicate must spot a query built without the hours - that is the red this guard produces");
    }

    [Fact]
    public void EveryEndOfShiftWidget_asksForOneDate_andTheCheckCanStillGoRed()
    {
        foreach (var (name, call) in EndOfShiftWidgetSources())
        {
            AsksForOneDate(call).Should().BeTrue(
                $"{name} must send one date on both ends; a two-date window is refused as \"covers one date\"");
        }

        // NEGATIVE HALF: the shape that was there before this unit - the page's range passed
        // straight through - must fail the same predicate.
        const string callWithARange = """
            new RunReportWidgetQuery(
                ReportWidgetType.EndOfShiftSomething,
                configJson,
                From,
                To,
                _page,
                TenantId,
                false,
                startHour,
                endHour)
            """;
        AsksForOneDate(callWithARange).Should().BeFalse(
            "a call that still forwards the page's To must be seen as a range, not as one date");
    }

    [Fact]
    public void TheSettingsDialog_offersTheHours_andRefusesAnUnusablePair()
    {
        // The hours have no sensible invented default: a shift nobody chose must not be saved as
        // though it had been. So the dialog blocks Save instead, and says which half is missing -
        // an unset pair is reported as unset, not as a wrong order.
        var modal = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetConfigModal.razor"));

        modal.Should().Contain("ShiftStartHour", "the dialog is where the hours are chosen");
        modal.Should().Contain("ShiftEndHour");
        modal.Should().Contain("ShiftProblem is null",
            "Save must be blocked while the pair is unusable, not merely warned about");

        // And the message must come from the resources, in all three locales: an English refusal
        // on a Hebrew board is the defect this unit started from.
        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
        {
            var resx = File.ReadAllText(Path.Combine(
                RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));
            foreach (var key in new[]
                     {
                         "ReportWidget_ShiftHours",
                         "ReportWidget_ShiftHoursRequired",
                         "ReportWidget_ShiftEndBeforeStart",
                         "ReportWidget_ShiftHoursMissing"
                     })
                resx.Should().Contain($"name=\"{key}\"", $"{key} is missing from {locale}");
        }
    }

    /// <summary>Both hour arguments reach the query, under any name a widget gives the locals.</summary>
    private static bool SendsBothHours(string queryCall)
        => Regex.IsMatch(queryCall, @"[Ss]tartHour") && Regex.IsMatch(queryCall, @"[Ee]ndHour");

    /// <summary>
    /// The window is one date: the call carries no bare From/To pair from the page. Written as
    /// "no range" rather than "mentions .Date", because a widget could name its single date
    /// anything, while forwarding the page's To is the one shape that is always wrong here.
    /// </summary>
    private static bool AsksForOneDate(string queryCall)
        => !Regex.IsMatch(queryCall, @"^\s*From\s*,\s*$", RegexOptions.Multiline)
           || !Regex.IsMatch(queryCall, @"^\s*To\s*,\s*$", RegexOptions.Multiline);

    private static IReadOnlyList<(string Name, string Call)> EndOfShiftWidgetSources()
    {
        var found = new List<(string, string)>();
        foreach (var type in EnumTypes().Where(t => t.StartsWith("EndOfShift", StringComparison.Ordinal)))
        {
            var path = Path.Combine(ReportWidgetsDirectory(), $"{type}ReportWidget.razor");
            File.Exists(path).Should().BeTrue($"{type} is in the enum, so {type}ReportWidget.razor must exist");

            var text = File.ReadAllText(path);
            var call = Regex.Match(text, @"new RunReportWidgetQuery\((?<body>[\s\S]*?)\)\s*\);");
            call.Success.Should().BeTrue($"{type}ReportWidget.razor must build a query, readable here");
            found.Add((type, call.Groups["body"].Value));
        }
        return found;
    }

    private static IReadOnlyList<string> EnumTypes()
    {
        var path = Path.Combine(RepoRoot(), "src", "CcDashboard.Domain", "Domain", "Reports", "ReportWidgetType.cs");
        File.Exists(path).Should().BeTrue("ReportWidgetType.cs must exist");

        var body = Regex.Match(File.ReadAllText(path), @"enum ReportWidgetType\s*\{(?<body>[^}]*)\}");
        body.Success.Should().BeTrue("the enum must be a plain declaration, readable here");

        return Regex.Matches(body.Groups["body"].Value, @"^\s*(?<t>[A-Z]\w*)\s*,?\s*$", RegexOptions.Multiline)
            .Select(m => m.Groups["t"].Value)
            .ToList();
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
