using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Infrastructure.RtmRelay;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NSubstitute;
using StackExchange.Redis;

namespace CcDashboard.Tests.Unit.RtmRelay;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01: the relay must TELL its subscribers that the link went down.
///
/// Scope, stated plainly. A test cannot make a real hub connection drop here: the HubConnection is
/// built inside the service (HubConnectionBuilder) and has no interface, and substituting it would
/// mean changing how the service is wired - structure, not design. So what is tested is the part
/// that is ours and that actually broke the screen: the fan-out. That every subscriber is told,
/// and that one failing subscriber does not silence the others, is what decides whether a widget
/// ever learns to stop counting. Whether Closed and the reconnect path CALL this fan-out, and in
/// which order relative to the data, is held by StaleValuesMarkedGuardTests on the source; the real
/// drop is checked live on 234 by stopping the hub.
/// </summary>
public class RtmRelayConnectionNoticeTests
{
    private static RtmRelayService NewService() => new(
        Substitute.For<Microsoft.Extensions.DependencyInjection.IServiceScopeFactory>(),
        Substitute.For<IConnectionMultiplexer>(),
        NullLogger<RtmRelayService>.Instance,
        Substitute.For<IOptionsMonitor<RtmRelayOptions>>());

    [Fact]
    public async Task EverySubscriberIsTold_withTheChannelThatWentDown()
    {
        var service = NewService();
        var seenByFirst = new List<RtmConnectionChanged>();
        var seenBySecond = new List<RtmConnectionChanged>();
        var tenant = Guid.NewGuid();

        service.ConnectionChanged += c => { seenByFirst.Add(c); return Task.CompletedTask; };
        service.ConnectionChanged += c => { seenBySecond.Add(c); return Task.CompletedTask; };

        await service.RaiseConnectionChangedAsync(tenant, 42, RtmChannelKind.Union, connected: false);

        foreach (var seen in new[] { seenByFirst, seenBySecond })
        {
            seen.Should().HaveCount(1, "a widget that is not told keeps showing old values as current");
            seen[0].TenantId.Should().Be(tenant);
            seen[0].ChannelId.Should().Be(42);
            seen[0].Kind.Should().Be(RtmChannelKind.Union);
            seen[0].Connected.Should().BeFalse();
        }
    }

    [Fact]
    public async Task RecoveryIsAlsoAnnounced()
    {
        var service = NewService();
        var seen = new List<bool>();
        service.ConnectionChanged += c => { seen.Add(c.Connected); return Task.CompletedTask; };

        await service.RaiseConnectionChangedAsync(Guid.NewGuid(), 7, RtmChannelKind.Grid, connected: false);
        await service.RaiseConnectionChangedAsync(Guid.NewGuid(), 7, RtmChannelKind.Grid, connected: true);

        // NEGATIVE HALF of the notice: a signal that only ever says "down" would leave the stale
        // mark on screen forever, and people would learn to ignore it.
        seen.Should().Equal(new[] { false, true });
    }

    [Fact]
    public async Task AThrowingSubscriberDoesNotSilenceTheOthers_andDoesNotThrowOut()
    {
        var service = NewService();
        var afterTheBadOne = 0;

        service.ConnectionChanged += _ => throw new InvalidOperationException("a widget blew up");
        service.ConnectionChanged += _ => { afterTheBadOne++; return Task.CompletedTask; };

        var act = () => service.RaiseConnectionChangedAsync(Guid.NewGuid(), 1, RtmChannelKind.Union, connected: false);

        await act.Should().NotThrowAsync(
            "losing the hub is already the bad day; a failing notice handler must not break reconnection too");
        afterTheBadOne.Should().Be(1,
            "one broken widget must not stop the others from learning the link is down");
    }

    [Fact]
    public async Task AFaultedTaskFromASubscriberIsAlsoContained()
    {
        // The same claim for the async shape of the same mistake: a handler that returns a faulted
        // task rather than throwing synchronously.
        var service = NewService();
        var afterTheBadOne = 0;

        service.ConnectionChanged += _ => Task.FromException(new InvalidOperationException("faulted"));
        service.ConnectionChanged += _ => { afterTheBadOne++; return Task.CompletedTask; };

        var act = () => service.RaiseConnectionChangedAsync(Guid.NewGuid(), 1, RtmChannelKind.Grid, connected: true);

        await act.Should().NotThrowAsync();
        afterTheBadOne.Should().Be(1);
    }

    [Fact]
    public async Task WithNoSubscribers_nothingHappensAndNothingThrows()
    {
        // NEGATIVE HALF: the fan-out must be safe before any widget has subscribed - the relay can
        // lose the hub while no screen is open.
        var service = NewService();
        var act = () => service.RaiseConnectionChangedAsync(Guid.NewGuid(), 1, RtmChannelKind.Union, connected: false);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task AnUnsubscribedWidgetIsNoLongerTold()
    {
        // A disposed component that keeps being called would redraw a dead circuit.
        var service = NewService();
        var seen = 0;
        Func<RtmConnectionChanged, Task> handler = _ => { seen++; return Task.CompletedTask; };

        service.ConnectionChanged += handler;
        await service.RaiseConnectionChangedAsync(Guid.NewGuid(), 1, RtmChannelKind.Union, connected: false);
        service.ConnectionChanged -= handler;
        await service.RaiseConnectionChangedAsync(Guid.NewGuid(), 1, RtmChannelKind.Union, connected: false);

        seen.Should().Be(1);
    }
}
