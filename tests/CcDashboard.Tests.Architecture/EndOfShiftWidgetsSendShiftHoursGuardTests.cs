using System.Text.RegularExpressions;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Domain.Reports;
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
///
/// Narrowed 2026-11-07 (FEAT-REPORT-EOS-CONFIGURABLE-01): the two rules hold for the types that
/// take shift hours - ReportDateFields.TakesShiftHours, today the agents report only. The queues
/// report takes the page's period and a step, and the server REFUSES hours on it; so for an
/// end-of-shift type without hours the opposite is held: no hours, and the page's From..To.
/// Selecting by the name prefix "EndOfShift", as before, would have demanded hours from a report
/// the server now refuses them on.
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

    [Fact]
    public void AnEndOfShiftWidgetWithoutHours_sendsNoHours_andThePagesPeriod()
    {
        var types = EnumTypes()
            .Select(t => Enum.Parse<ReportWidgetType>(t))
            .Where(t => ReportDateFields.IsEndOfShift(t) && !ReportDateFields.TakesShiftHours(t))
            .ToList();
        types.Should().NotBeEmpty("the end-of-shift queues report takes no hours since 2026-11-07 - it must be findable here");

        foreach (var type in types)
        {
            var text = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), $"{type}ReportWidget.razor"));
            var call = QueryStatement(text);
            SendsAnyHour(call).Should().BeFalse($"{type}: the server refuses shift hours on this type");
            ForwardsThePeriod(call).Should().BeTrue($"{type}: the window is the page's From..To");
        }

        // NEGATIVE HALVES, on the shapes that were there before 2026-11-07: hours from the config
        // and one date on both ends. Each must fail its predicate, or the loop above cannot go red.
        const string before = """
            new RunReportWidgetQuery(
                ReportWidgetType.EndOfShiftQueues,
                effectiveConfig.ToJson(),
                shiftDate,
                shiftDate,
                _page,
                TenantId,
                false,
                Config?.ShiftStartHour,
                Config?.ShiftEndHour);
            """;
        SendsAnyHour(before).Should().BeTrue("a query that still sends the hours must be seen");
        ForwardsThePeriod(before).Should().BeFalse("one date on both ends is not the page's period");
    }

    /// <summary>The query from "new RunReportWidgetQuery(" to the end of its statement.</summary>
    private static string QueryStatement(string text)
    {
        var start = text.IndexOf("new RunReportWidgetQuery(", StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, "the widget must build a query, readable here");
        var end = text.IndexOf(';', start);
        end.Should().BeGreaterThan(start);
        return text[start..end];
    }

    private static bool SendsAnyHour(string call) => Regex.IsMatch(call, @"[Ss]tartHour|[Ee]ndHour");

    private static bool ForwardsThePeriod(string call)
        => Regex.IsMatch(call, @"^\s*From\s*,\s*$", RegexOptions.Multiline)
           && Regex.IsMatch(call, @"^\s*To\s*,\s*$", RegexOptions.Multiline);

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
        foreach (var type in EnumTypes().Where(t => ReportDateFields.TakesShiftHours(Enum.Parse<ReportWidgetType>(t))))
        {
            var path = Path.Combine(ReportWidgetsDirectory(), $"{type}ReportWidget.razor");
            File.Exists(path).Should().BeTrue($"{type} is in the enum, so {type}ReportWidget.razor must exist");

            var text = File.ReadAllText(path);
            // The query may be written as a constructor call alone, or as a constructor call
            // followed by an object initializer - the filters were added that way on 2026-11-06,
            // and the older pattern stopped matching, which turned three guards red without any
            // of the things they watch having changed. Both forms are read, and BOTH parts are
            // handed on: reading only the constructor would quietly stop seeing anything set in
            // the initializer, which is weakening the guard rather than fixing it.
            var call = Regex.Match(text, @"new RunReportWidgetQuery\((?<args>[\s\S]*?)\)\s*(?<init>\{[\s\S]*?\})?\s*\);");
            call.Success.Should().BeTrue($"{type}ReportWidget.razor must build a query, readable here");
            found.Add((type, call.Groups["args"].Value + call.Groups["init"].Value));
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
