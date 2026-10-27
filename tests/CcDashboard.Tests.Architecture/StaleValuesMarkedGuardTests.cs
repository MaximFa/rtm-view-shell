using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01: a widget must not let values it is no longer receiving pass
/// for current.
///
/// Measured twice on 234, both times by a checker who nearly accepted the stale numbers (18.10
/// 20:03/20:05, 22.10 07:00:37/07:00:54: identical values, no increment, nothing on screen saying
/// so). Worse than freezing: the two grids redraw running durations from their own one-second tick
/// whether or not data arrives, so when the relay loses the hub while the browser stays connected,
/// the durations go on GROWING - which the "values are moving" liveness check cannot catch at all.
///
/// The fix has two sources for one verdict, because the two kinds of widget learn it differently:
/// the grids from the relay's connection notice, the pollers from the age of their last answer.
/// This guard watches that shape in source; the behaviour itself is checked by DataFreshnessTests
/// (the verdict), RtmRelayConnectionNoticeTests (the notice) and live on screen after the deploy.
/// </summary>
public class StaleValuesMarkedGuardTests
{
    private static readonly string[] RelayDriven = { "AgentGridWidget.razor", "QueueGridWidget.razor" };
    private static readonly string[] PollDriven = { "DayTrendWidget.razor", "WfmWidget.razor" };

    [Theory]
    [InlineData("AgentGridWidget.razor")]
    [InlineData("QueueGridWidget.razor")]
    public void ARelayDrivenWidget_learnsTheLinkIsDown_freezesItsClock_andSaysSo(string widget)
    {
        var source = Source(widget);

        source.Should().Contain("RtmRelay.ConnectionChanged +=",
            "the widget must learn the link state from the relay, not guess it from the screen");
        source.Should().Contain("RtmRelay.ConnectionChanged -=",
            "and must unsubscribe, or a disposed component keeps being called");
        source.Should().Contain("Widget_DataStale",
            "the viewer must be told the values are the last ones received");

        // The frozen clock: elapsed time is computed against EffectiveNowUtc, never the wall clock.
        source.Should().Contain("EffectiveNowUtc",
            "a running duration must stop at its last truthful value");
        Regex.IsMatch(source, @"DateTime\.UtcNow - anchor\.StartedAt").Should().BeFalse(
            "computing elapsed time from the wall clock is what made dead screens keep counting");
        Regex.IsMatch(source, @"now \?\? DateTime\.UtcNow").Should().BeFalse(
            "the comparison path must use the same frozen clock as the cell, or sorting disagrees with the display");

        // And the tick must stand still while the link is down.
        Regex.IsMatch(source, @"if \(!_linkDown && _rows\.Any").Should().BeTrue(
            "the one-second tick must not advance values with no data behind them");
    }

    [Theory]
    [InlineData("DayTrendWidget.razor")]
    [InlineData("WfmWidget.razor")]
    public void APollDrivenWidget_judgesTheAgeOfItsLastAnswer_andSaysSo(string widget)
    {
        var source = Source(widget);

        source.Should().Contain("DataFreshness.IsStale",
            "a poller has no link to listen to: its signal is how old the shown answer is");
        source.Should().Contain("Widget_DataStale",
            "and it must say so on screen rather than look like a quiet hour");
        source.Should().NotContain("RtmRelay.ConnectionChanged +=",
            "these two do not go through the relay at all; pretending they do would be a decoration, not a fix");
    }

    [Fact]
    public void TheThresholdLivesInOnePlace_notInTheWidgets()
    {
        // A number repeated in four widgets drifts. It also cannot be tested where it sits.
        foreach (var widget in RelayDriven.Concat(PollDriven))
        {
            var source = Source(widget);
            Regex.IsMatch(source, @"TimeSpan\.FromSeconds\(15\)").Should().BeFalse(
                $"{widget} must not carry its own copy of the staleness threshold");
        }

        var freshness = File.ReadAllText(Path.Combine(ContractsCommonDirectory(), "DataFreshness.cs"));
        freshness.Should().Contain("StaleAfter", "the threshold belongs here, where a test can reach it");
    }

    [Fact]
    public void TheRelayAnnouncesBothDirections_andSendsDataBeforeSayingConnected()
    {
        // The notice itself is tested in RtmRelayConnectionNoticeTests; what cannot be tested there
        // is whether the reconnect path CALLS it, and in which order relative to the data - the
        // HubConnection has no interface, so no test can make a real link drop. Hence source here.
        var relay = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Infrastructure",
                                                  "RtmRelay", "RtmRelayService.cs"));

        // Both halves must announce a drop: union and grid each have their own Closed handler.
        Regex.Matches(relay, @"RaiseConnectionChangedAsync\([^)]*connected: false\)").Count
            .Should().Be(2, "both the union and the grid Closed handler must say the link went down");
        Regex.Matches(relay, @"RaiseConnectionChangedAsync\([^)]*connected: true\)").Count
            .Should().Be(2, "and both reconnect paths must say it came back, or the mark stays forever");

        // Order: fresh data first, then "connected". The other way round, a widget would clear its
        // stale mark and spend one tick presenting old values as current.
        var snapshotSent = relay.IndexOf("new UnionStateChange.InitialSnapshot(snap, state.ServerTimeOffset)", StringComparison.Ordinal);
        var unionConnected = relay.IndexOf("RtmChannelKind.Union, connected: true", StringComparison.Ordinal);
        snapshotSent.Should().BeGreaterThan(0, "the union reconnect must still deliver a fresh snapshot");
        unionConnected.Should().BeGreaterThan(snapshotSent,
            "\"connected\" must come after the data, not before it");

        var gridInit = relay.IndexOf("await GridInitAsync(state, key.GridId, default);", StringComparison.Ordinal);
        var gridConnected = relay.IndexOf("RtmChannelKind.Grid, connected: true", StringComparison.Ordinal);
        gridInit.Should().BeGreaterThan(0);
        gridConnected.Should().BeGreaterThan(gridInit);
    }

    [Fact]
    public void Wfm_saysWhyTheFiguresAreDashes_andKeepsTheTechnicalReasonOutOfTheDisplay()
    {
        // BL-V4-WFM-NO-REASON-SHOWN-01: nine identical dashes answered none of the operator's
        // question on 2026-10-22. The classification must come from WfmBlankReason (where it is
        // tested), the text from the resources, and the engine's technical UnknownReason must stay
        // in the tooltip - it is English log prose, not wall-display copy.
        var source = Source("WfmWidget.razor");

        source.Should().Contain("WfmBlankReason.Classify",
            "the cause must be classified in one tested place, not re-derived in the markup");
        source.Should().Contain("Wfm_Reason_", "and shown through the localised resources");
        source.Should().Contain("title=\"@_snapshot.UnknownReason\"",
            "the technical reason belongs in the tooltip, for whoever fixes it");

        // The line must not be printed when there is nothing to explain.
        source.Should().Contain("BlankReasonText is { Length: > 0 }",
            "a permanent note beside working figures is noise, and noise is how a real warning gets ignored");

        // All five causes must be reachable from the widget, or a situation would silently show
        // no line at all - the defect again, narrower.
        foreach (var key in new[] { "Overloaded", "AgentCountUnknown", "NobodyServing", "NoAnsweredCalls", "NoArrivals" })
            source.Should().Contain($"Wfm_Reason_{key}", $"{key} must have a line of its own");

        // And every code the classifier can return must be covered above: if someone adds a sixth,
        // this fails rather than letting it fall through to "no explanation".
        var reason = File.ReadAllText(Path.Combine(ContractsCommonDirectory(), "WfmBlankReason.cs"));
        var codes = Regex.Matches(reason, @"public const string (\w+) =")
            .Select(m => m.Groups[1].Value)
            .Where(n => n != "None")
            .ToList();
        codes.Should().HaveCount(5, "a new cause needs a line in the widget and in three resx files");
    }

    [Fact]
    public void Guard_canGoRed()
    {
        // NEGATIVE HALF. Without this everything above passes on an empty area or a needle that
        // matches any text.
        Directory.GetFiles(WidgetsDirectory(), "*.razor").Should().NotBeEmpty();

        // The pre-fix shape of the grid cell, as it stood before this unit:
        const string beforeTheFix = """
                    if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
                    {
                        var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
                        return FormatSeconds(anchor.BaseSecs + elapsed);
                    }
            """;
        Regex.IsMatch(beforeTheFix, @"DateTime\.UtcNow - anchor\.StartedAt").Should().BeTrue(
            "the detector must recognise the wall-clock shape at all - this is the red it can produce");
        beforeTheFix.Contains("EffectiveNowUtc").Should().BeFalse();
        beforeTheFix.Contains("Widget_DataStale").Should().BeFalse();

        // And a poller that merely subscribed to the relay must NOT satisfy the poller theory.
        const string decorationOnly = """RtmRelay.ConnectionChanged += _connectionHandler;""";
        decorationOnly.Contains("DataFreshness.IsStale").Should().BeFalse();
    }

    [Fact]
    public void EveryWidgetWithItsOwnTick_isCoveredHere()
    {
        // Guards that name files by hand rot when a fifth ticking widget appears.
        var ticking = Directory.GetFiles(WidgetsDirectory(), "*.razor")
            .Where(f =>
            {
                var text = File.ReadAllText(f);
                return text.Contains("PeriodicTimer");
            })
            .Select(Path.GetFileName)
            .ToList();

        ticking.Should().BeEquivalentTo(RelayDriven.Concat(PollDriven),
            "a widget that advances its own values without new data would show a dead screen as live");
    }

    private static string Source(string widgetFileName)
    {
        var path = Path.Combine(WidgetsDirectory(), widgetFileName);
        File.Exists(path).Should().BeTrue($"{widgetFileName} must exist");
        return File.ReadAllText(path);
    }

    private static string WidgetsDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Widgets");

    private static string ContractsCommonDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Contracts", "Common");

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
