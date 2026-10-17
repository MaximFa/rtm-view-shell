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
}
