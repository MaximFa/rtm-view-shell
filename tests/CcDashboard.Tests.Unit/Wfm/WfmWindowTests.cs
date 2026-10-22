using CcDashboard.Infrastructure.Wfm;
using FluentAssertions;
using Xunit;

namespace CcDashboard.Tests.Unit.Wfm;

/// <summary>
/// BL-234-INTERACTION-TIME-AHEAD-01: the engine now stores TRUE UTC, so the WFM window must be plain UtcNow.
/// Negative half: the removed mirror (UtcNow + site offset labelled UTC) misses an interaction stored in true UTC.
/// </summary>
public class WfmWindowTests
{
    private static readonly DateTime Now = new(2026, 10, 18, 17, 27, 0, DateTimeKind.Utc);

    [Fact]
    public void Window_IsPlainUtcNow_WithTheRequestedLength()
    {
        var (lo, hi) = WfmInputQueryService.WindowFor(Now, 15);
        hi.Should().Be(Now);
        hi.Kind.Should().Be(DateTimeKind.Utc);
        lo.Should().Be(Now.AddMinutes(-15));
    }

    [Fact]
    public void Window_AcceptsALocalNow_ByConvertingIt()
    {
        var (_, hi) = WfmInputQueryService.WindowFor(Now.ToLocalTime(), 15);
        hi.Should().Be(Now);
    }

    [Fact]
    public void InteractionStoredInTrueUtc_IsInsideTheNewWindow_AndOutsideTheOldMirroredOne()
    {
        var storedInQueue = Now.AddMinutes(-5); // engine after the fix: true UTC, five minutes ago

        var (lo, hi) = WfmInputQueryService.WindowFor(Now, 15);
        (storedInQueue >= lo && storedInQueue < hi).Should().BeTrue();

        // negative half: the old window mirrored the engine's site-local stamp (+02:00 on 234) labelled as UTC
        var oldHi = DateTime.SpecifyKind(Now.Add(TimeSpan.FromHours(2)), DateTimeKind.Utc);
        var oldLo = oldHi.AddMinutes(-15);
        (storedInQueue >= oldLo && storedInQueue < oldHi).Should().BeFalse("keeping the mirror after the engine fix would count nothing");
    }
}
