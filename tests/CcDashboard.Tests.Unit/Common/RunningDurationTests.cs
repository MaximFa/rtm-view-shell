using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// A running duration must be COMPARED by the same elapsed time it DISPLAYS.
/// The engine sends the moment it started, which used to be compared as a timestamp string — so
/// such a column sorted by day of month. "now" is a parameter here, so these tests do not flicker.
/// </summary>
public class RunningDurationTests
{
    private static readonly DateTime Now = new(2026, 10, 17, 12, 00, 00, DateTimeKind.Utc);

    [Fact]
    public void ElapsedSeconds_countsFromTheAnchor()
        => RunningDuration.ElapsedSeconds(60, Now.AddSeconds(-30), Now).Should().Be(90);

    [Fact]
    public void ElapsedSeconds_neverNegative_whenTheAnchorIsInTheFuture()
        => RunningDuration.ElapsedSeconds(0, Now.AddSeconds(30), Now).Should().Be(0);

    [Theory]
    [InlineData(0, "00:00")]
    [InlineData(59, "00:59")]
    [InlineData(463, "07:43")]
    [InlineData(3600, "1:00:00")]
    [InlineData(3723, "1:02:03")]
    public void Format_isTheSameSpellingTheCellShows(int seconds, string expected)
        => RunningDuration.Format(seconds).Should().Be(expected);

    [Fact]
    public void LongerWaitSortsAbove_theDefectThisFixes()
    {
        // Two rows: one waiting since 17/10 07:43, one since 05/11 00:01 (a later start = shorter
        // wait). Compared as stored timestamps, "05/11..." < "17/10..." as text, so the SHORTER
        // wait ranked first. By elapsed time the longer wait is the larger number.
        var longWait = RunningDuration.ElapsedSeconds(0, Now.AddMinutes(-30), Now);
        var shortWait = RunningDuration.ElapsedSeconds(0, Now.AddMinutes(-2), Now);

        longWait.Should().BeGreaterThan(shortWait);

        // And the compared text parses back into seconds, which the stored timestamp never did.
        RunningDuration.Comparable(0, Now.AddMinutes(-30), Now).Should().Be("30:00");
        "17/10/2026 07:43:12".Split(':').Length.Should().Be(3,
            "the stored form looks like a time but its first part is a date, so it parses to nothing");
    }

    [Fact]
    public void NEGATIVE_HALF_valueWithoutAnAnchorIsNotTouchedHere()
    {
        // The widget only calls this when a timer anchor exists; a column without one must keep
        // comparing its raw stored value byte for byte. This pins the contract that the helper
        // itself introduces no formatting for plain values: it is never asked about them.
        // (The widget-side branch is GetComparableValue's early return.)
        RunningDuration.Format(0).Should().Be("00:00");
        RunningDuration.Comparable(0, Now, Now).Should().Be("00:00",
            "a freshly started duration reads as zero, not as the start timestamp");
    }

    // ---- PR234-V4-RUNNING-DURATION-RESET-ON-RELOAD-01 -------------------------------------------
    // The engine sends the MOMENT a duration started ("+dd/MM/yyyy HH:mm:ss"), not its length.
    // CONDITION of these tests, and of the code: engine and Shell share one host, so the moment is
    // read as THIS machine's local wall clock (measured 2026-10-20, acceptance 234_20261020_073118:
    // RTMService pid 10380 and RTMViewShell pid 8432 on machine "RTM"). Hence the expected values
    // below are built with DateTimeKind.Local, not a hard-coded offset.

    // NEGATIVE HALF #1: this is exactly what the old reader did with a moment - and it must fail.
    private static int OldReader(string time)
    {
        var parts = time.Split(':');
        return parts.Length switch
        {
            2 when int.TryParse(parts[0], out var m) && int.TryParse(parts[1], out var s) => m * 60 + s,
            3 when int.TryParse(parts[0], out var h) && int.TryParse(parts[1], out var m) && int.TryParse(parts[2], out var s)
                => h * 3600 + m * 60 + s,
            _ => 0
        };
    }

    [Fact]
    public void OldReader_turnedAStartMomentIntoZero_whichIsTheDefect()
        => OldReader("18/10/2026 17:05:12").Should().Be(0, "a timestamp is not hh:mm:ss, so every timer restarted at zero");

    [Fact]
    public void TryParseEngineInstant_readsTheMoment_andElapsedIsTheDifference()
    {
        var started = new DateTime(2026, 10, 18, 17, 05, 12, DateTimeKind.Local);
        RunningDuration.TryParseEngineInstant("+18/10/2026 17:05:12", out var utc).Should().BeTrue();
        utc.Kind.Should().Be(DateTimeKind.Utc);
        utc.Should().Be(started.ToUniversalTime());

        // Same anchor, 90 seconds later: a real duration, not zero.
        RunningDuration.ElapsedSeconds(0, utc, utc.AddSeconds(90)).Should().Be(90);
        RunningDuration.Comparable(0, utc, utc.AddSeconds(90)).Should().Be("01:30");
    }

    [Fact]
    public void TryParseEngineInstant_acceptsTheValueWithoutThePlus()
        => RunningDuration.TryParseEngineInstant("18/10/2026 17:05:12", out _).Should().BeTrue();

    // NEGATIVE HALF #2: things that are NOT a moment must be refused, or a real duration would be
    // mistaken for a timestamp and the fix would break the values it is supposed to leave alone.
    [Theory]
    [InlineData("+05:17")]
    [InlineData("+1:05:17")]
    [InlineData("05:17")]
    [InlineData("+2026-10-18 17:05:12")]
    [InlineData("+18/10/2026")]
    [InlineData("+18/13/2026 17:05:12")]
    [InlineData("&nbsp;")]
    [InlineData("")]
    [InlineData(null)]
    public void TryParseEngineInstant_refusesWhatIsNotAMoment(string? text)
        => RunningDuration.TryParseEngineInstant(text, out _).Should().BeFalse();

    // NEGATIVE HALF #3: a moment in the future is not a start - it must be flagged, not timed.
    [Fact]
    public void IsFutureInstant_flagsAMomentAheadOfTheClock()
    {
        var now = new DateTime(2026, 10, 18, 17, 00, 00, DateTimeKind.Utc);
        RunningDuration.IsFutureInstant(now.AddMinutes(5), now).Should().BeTrue();
        RunningDuration.IsFutureInstant(now.AddSeconds(-1), now).Should().BeFalse();
        // Small clock jitter stays tolerated, otherwise every tick would warn.
        RunningDuration.IsFutureInstant(now.AddSeconds(RunningDuration.FutureToleranceSeconds - 1), now)
            .Should().BeFalse();
    }
}
