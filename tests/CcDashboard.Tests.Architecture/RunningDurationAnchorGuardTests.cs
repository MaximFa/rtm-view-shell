using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// PR234-V4-RUNNING-DURATION-RESET-ON-RELOAD-01.
///
/// The engine does not send a running duration's length: it sends the MOMENT it started, as
/// "+dd/MM/yyyy HH:mm:ss". There are fifteen such places in the engine (RTM/UserManager.cs:1329,
/// 1351, 1361, 1400, 1404, 1420, 1430, 1443, 1460, 1634, 1650 and RTM/Union.cs:1095, 1124), every
/// one of them built from DateTime.Now. Shell used to split that text on ':', which made
/// "18/10/2026 17" the hours part, parsed as nothing, and returned 0 - so every timer on the screen
/// restarted from zero on each page reload. The operator saw it and confirmed it reproduces.
///
/// CONDITION, stated here because the code depends on it: engine and Shell share one host, so the
/// moment is read as this machine's local wall clock. Measured 2026-10-20 (acceptance report
/// 234_20261020_073118): RTMService (pid 10380) and RTMViewShell (pid 8432) on machine "RTM". If
/// Shell is ever moved to another host or zone, this guard's subject needs an explicit zone source.
///
/// The guard reads SOURCE: a widget's private members are not reachable from tests and there is no
/// bUnit in this solution. What it watches is that every widget which strips a leading "+" asks
/// RunningDuration for the moment first, and that a value which is neither a moment nor a duration
/// is not timed from zero in silence.
/// </summary>
public class RunningDurationAnchorGuardTests
{
    [Fact]
    public void EveryWidgetThatStripsThePlus_readsTheMomentThroughRunningDuration()
    {
        var offenders = new List<string>();

        foreach (var path in WidgetSources())
        {
            var source = File.ReadAllText(path);
            if (!StripsTheLeadingPlus(source)) continue;

            if (!source.Contains("RunningDuration.TryParseEngineInstant"))
                offenders.Add(Path.GetFileName(path));
        }

        offenders.Should().BeEmpty(
            "a widget that strips the engine's \"+\" must read the moment, not split a timestamp on ':'");
    }

    [Fact]
    public void TheSearchArea_isNotEmpty_andTheThreeKnownWidgetsAreInIt()
    {
        // "Found nothing" is worth nothing without the area it was searched in.
        var strippers = WidgetSources()
            .Where(p => StripsTheLeadingPlus(File.ReadAllText(p)))
            .Select(Path.GetFileName)
            .ToList();

        strippers.Should().Contain(new[] { "AgentGridWidget.razor", "QueueGridWidget.razor", "DataSlotWidget.razor" },
            "these three are the widgets the defect was found in; losing one from the area would hide a regression");
    }

    // DataSlot is deliberately absent from this theory: it has no timer and no
    // "time it from zero" branch at all, so LooksLikeDuration has nothing to tell apart there.
    // What it DOES share - a moment ahead of the clock must be reported - is checked separately
    // below, so the third stripper is covered rather than quietly skipped.
    [Theory]
    [InlineData("AgentGridWidget.razor")]
    [InlineData("QueueGridWidget.razor")]
    public void AValueThatIsNeitherAMomentNorADuration_isNotTimedFromZeroInSilence(string widget)
    {
        var source = File.ReadAllText(Path.Combine(WidgetsDirectory(), widget));

        source.Should().Contain("RunningDuration.IsFutureInstant",
            "a start in the future is a clock or payload fault and must be reported, not displayed as 00:00");
        source.Should().Contain("LooksLikeDuration",
            "zero seconds from an unrecognised payload must be told apart from a genuine 00:00");
        source.Should().Contain("is in the future; shown as text, not timed",
            $"{widget} must log a start moment that lies ahead of the clock");
        // (The two grids share one wording, so here the whole sentence is a fair needle; DataSlot's
        // differs and is checked by substrings above.)
        source.Should().Contain("neither a start moment nor a duration",
            $"{widget} must log a payload it could not read, instead of timing it from zero quietly");
    }

    [Fact]
    public void DataSlot_reportsAMomentAheadOfTheClock_eventhoughItHasNoTimer()
    {
        var source = File.ReadAllText(Path.Combine(WidgetsDirectory(), "DataSlotWidget.razor"));

        source.Should().Contain("RunningDuration.IsFutureInstant",
            "the tile must not present a future moment as an elapsed duration");
        // The needle is two independent substrings, not the whole sentence: DataSlot's message names
        // the metric in the middle ("... is in the future for {MetricId}; shown as text ..."), and
        // the grids' does not. A whole-sentence needle made this test red for a wording difference
        // while the behaviour it guards was correct - the test was stricter than its own question.
        source.Should().Contain("is in the future",
            "and it must say in the log that the moment lies ahead of the clock");
        source.Should().Contain("shown as text, not timed",
            "and that the value is shown as text rather than timed");
        source.Should().NotContain("LooksLikeDuration",
            "the tile has no zero-timing branch, so that distinction would be dead code here");
    }

    [Fact]
    public void TheFutureMomentNeedles_canGoRed_onCodeWithoutThatBranch()
    {
        // NEGATIVE HALF for the needles just loosened. A loosened needle is only worth keeping if it
        // still fails on code that lacks the branch - otherwise it would pass on anything.
        const string withoutTheBranch = """
                    if (RunningDuration.TryParseEngineInstant(rawValue, out var startedUtc))
                    {
                        value = RunningDuration.Comparable(0, startedUtc, DateTime.UtcNow);
                    }
            """;
        withoutTheBranch.Contains("RunningDuration.IsFutureInstant").Should().BeFalse();
        withoutTheBranch.Contains("is in the future").Should().BeFalse();
        withoutTheBranch.Contains("shown as text, not timed").Should().BeFalse();

        // And both wordings actually in the code must satisfy the loosened needles.
        const string dataSlotWording = "DataSlot: start moment {Moment} is in the future for {MetricId}; shown as text, not timed";
        const string gridWording = "AgentGrid {GridId}: metric {MetricId} start moment {Moment} is in the future; shown as text, not timed";
        foreach (var wording in new[] { dataSlotWording, gridWording })
        {
            wording.Contains("is in the future").Should().BeTrue();
            wording.Contains("shown as text, not timed").Should().BeTrue();
        }
    }

    [Fact]
    public void Guard_canGoRed()
    {
        // NEGATIVE HALF. Without this, everything above is green on an empty area or a needle that
        // matches any text at all.
        WidgetSources().Should().NotBeEmpty("the widgets directory must actually be found and read");

        // The pre-fix shape of the reader, as it stood in AgentGridWidget before this unit:
        const string beforeTheFix = """
                    if (rawValue?.StartsWith('+') == true)
                    {
                        var secs = ParseTimeToSeconds(rawValue[1..]);
                        row.TimerAnchors[metricId] = (secs, receivedAt);
                    }
            """;
        StripsTheLeadingPlus(beforeTheFix).Should().BeTrue("the detector must recognise this shape at all");
        beforeTheFix.Contains("RunningDuration.TryParseEngineInstant").Should().BeFalse(
            "so the first guard would have reported this file - that is the red it is able to produce");
        beforeTheFix.Contains("RunningDuration.IsFutureInstant").Should().BeFalse();
        beforeTheFix.Contains("LooksLikeDuration").Should().BeFalse();
    }

    private static bool StripsTheLeadingPlus(string source)
        => Regex.IsMatch(source, @"StartsWith\('\+'\)");

    private static IReadOnlyList<string> WidgetSources()
        => Directory.GetFiles(WidgetsDirectory(), "*.razor");

    private static string WidgetsDirectory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return Path.Combine(dir!.FullName, "src", "CcDashboard.Web", "Components", "Widgets");
    }
}
