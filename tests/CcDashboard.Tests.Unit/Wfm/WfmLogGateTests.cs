using CcDashboard.Infrastructure.Wfm;
using FluentAssertions;
using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Tests.Unit.Wfm;

/// <summary>
/// The gate exists because WfmInputQueryService is Scoped and the loop makes a new scope per tick,
/// so "once an hour per queue" cannot be kept in that service's fields. These tests pin the two
/// behaviours the coordinator asked for - the hourly interval and the immediate line on a changed
/// dominant zone - plus the key isolation that keeps one tenant from silencing another.
/// </summary>
public class WfmLogGateTests
{
    private static readonly TimeSpan Hour = TimeSpan.FromHours(1);

    [Fact]
    public void FirstCall_Logs_AndImmediateRepeat_DoesNot()
    {
        var clock = new MovableClock(new DateTime(2026, 10, 14, 9, 0, 0, DateTimeKind.Utc));
        var gate = new WfmLogGate(clock);

        gate.ShouldLog("q1", "+02:00", Hour).Should().BeTrue();
        gate.ShouldLog("q1", "+02:00", Hour).Should().BeFalse();
    }

    [Fact]
    public void AfterTheInterval_LogsAgain()
    {
        // NEGATIVE half of the test above: a gate that always answered false would pass that one
        // and fail here, which is exactly the failure mode that would hide the condition for good.
        var clock = new MovableClock(new DateTime(2026, 10, 14, 9, 0, 0, DateTimeKind.Utc));
        var gate = new WfmLogGate(clock);

        gate.ShouldLog("q1", "+02:00", Hour).Should().BeTrue();

        clock.Advance(TimeSpan.FromMinutes(59));
        gate.ShouldLog("q1", "+02:00", Hour).Should().BeFalse("59 minutes is inside the interval");

        clock.Advance(TimeSpan.FromMinutes(1));
        gate.ShouldLog("q1", "+02:00", Hour).Should().BeTrue("the hour has elapsed");
    }

    [Fact]
    public void ChangedContext_LogsImmediately_EvenInsideTheInterval()
    {
        // A different dominant zone is new information; suppressing it would turn the throttle into
        // a way of losing the one line worth interrupting for.
        var clock = new MovableClock(new DateTime(2026, 10, 14, 9, 0, 0, DateTimeKind.Utc));
        var gate = new WfmLogGate(clock);

        gate.ShouldLog("q1", "+02:00", Hour).Should().BeTrue();

        clock.Advance(TimeSpan.FromSeconds(30));
        gate.ShouldLog("q1", "+03:00", Hour).Should().BeTrue("the dominant zone changed");

        // ...and the new context then throttles on its own terms
        gate.ShouldLog("q1", "+03:00", Hour).Should().BeFalse();
    }

    [Fact]
    public void DifferentKeys_DoNotSilenceEachOther()
    {
        // The real key carries the tenant id, so this covers the cross-tenant case: the gate is
        // process-wide while the service is per-tenant per tick.
        var clock = new MovableClock(new DateTime(2026, 10, 14, 9, 0, 0, DateTimeKind.Utc));
        var gate = new WfmLogGate(clock);

        gate.ShouldLog("wfm-mixed-tz:tenantA:q1", "+02:00", Hour).Should().BeTrue();
        gate.ShouldLog("wfm-mixed-tz:tenantB:q1", "+02:00", Hour).Should().BeTrue();
        gate.ShouldLog("wfm-mixed-tz:tenantA:q1", "+02:00", Hour).Should().BeFalse();
    }

    [Fact]
    public void NullContext_IsHandled_AndTreatedAsItsOwnValue()
    {
        // dominant.TimeZone is nullable in the caller (`dominant.TimeZone ?? string.Empty` is used
        // for the map, but the raw value goes to the gate), so null must not throw and must not be
        // confused with a real zone.
        var clock = new MovableClock(new DateTime(2026, 10, 14, 9, 0, 0, DateTimeKind.Utc));
        var gate = new WfmLogGate(clock);

        gate.ShouldLog("q1", null, Hour).Should().BeTrue();
        gate.ShouldLog("q1", null, Hour).Should().BeFalse();
        gate.ShouldLog("q1", "+02:00", Hour).Should().BeTrue("null and a real zone are different contexts");
    }

    /// <summary>
    /// A clock the test moves by hand. IDateTimeProvider is the project's own time abstraction
    /// (registered singleton, InfrastructureServiceExtensions.cs:32); FakeTimeProvider was not used
    /// because Microsoft.Extensions.TimeProvider.Testing is not referenced by this solution.
    /// </summary>
    private sealed class MovableClock(DateTime start) : IDateTimeProvider
    {
        public DateTime UtcNow { get; private set; } = start;

        public void Advance(TimeSpan by) => UtcNow = UtcNow.Add(by);
    }
}
