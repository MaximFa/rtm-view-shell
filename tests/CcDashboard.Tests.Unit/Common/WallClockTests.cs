using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// BL-V4-INFOSLOT-TIME-NO-LOCAL-01. The shell stores true UTC and shows the server's wall clock.
/// Two halves, and the second is the one that makes the first mean anything: a value marked UTC
/// must MOVE, and a value not marked UTC must NOT - otherwise this class would double-convert the
/// times that reach the screen already local (DayTrend's _lastUpdate, DayTrendQueryHandler's
/// interval starts), which is the opposite defect.
/// </summary>
public class WallClockTests
{
    // The host zone is whatever the test machine has; the assertions are written so they hold in
    // any zone, including UTC, instead of hard-coding +02:00/+03:00.
    private static readonly TimeSpan HostOffset = TimeZoneInfo.Local.GetUtcOffset(new DateTime(2026, 10, 21, 9, 0, 0, DateTimeKind.Utc));

    [Fact]
    public void AUtcValue_isConvertedToTheServersWallClock()
    {
        var utc = new DateTime(2026, 10, 21, 9, 0, 0, DateTimeKind.Utc);

        var shown = WallClock.ToServerLocal(utc);

        shown.Should().Be(utc.ToLocalTime());
        (shown - utc).Should().Be(HostOffset, "the shift must be exactly the host's offset, no more and no less");
    }

    [Fact]
    public void AUtcValue_actuallyMoves_whenTheHostIsNotOnUtc()
    {
        // NEGATIVE HALF #1 of the pair: without this, a no-op implementation would pass the test
        // above on a UTC build agent and the defect would survive the suite.
        if (HostOffset == TimeSpan.Zero)
            return; // on a UTC host there is nothing to move; the equality above is the whole claim.

        var utc = new DateTime(2026, 10, 21, 9, 0, 0, DateTimeKind.Utc);
        WallClock.HourMinute(utc).Should().NotBe("09:00",
            "a UTC instant printed unconverted is exactly the defect: the panel and the widget then disagree");
    }

    [Theory]
    [InlineData(DateTimeKind.Unspecified)]
    [InlineData(DateTimeKind.Local)]
    public void AValueNotMarkedUtc_isLeftAlone(DateTimeKind kind)
    {
        // NEGATIVE HALF #2: values that are already local must not be shifted again.
        // DayTrendQueryHandler hands out interval starts as Unspecified, DateTime.Now is Local.
        var already = DateTime.SpecifyKind(new DateTime(2026, 10, 21, 9, 0, 0), kind);

        WallClock.ToServerLocal(already).Should().Be(already);
        WallClock.HourMinute(already).Should().Be("09:00");
    }

    [Fact]
    public void HourMinute_printsTwoDigitsAndNoDate()
        => WallClock.HourMinute(new DateTime(2026, 10, 21, 7, 5, 0, DateTimeKind.Utc).AddHours(-HostOffset.TotalHours))
            .Should().Be("07:05");
}
