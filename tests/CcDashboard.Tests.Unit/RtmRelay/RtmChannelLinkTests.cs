using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Infrastructure.RtmRelay;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NSubstitute;
using StackExchange.Redis;

namespace CcDashboard.Tests.Unit.RtmRelay;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01, the gap found on 2026-10-27: a widget learned the link state
/// only from the broadcast notice, so a screen opened AFTER the link dropped heard nothing and
/// showed the last values with no mark - the defect, entered from the other side.
///
/// The verdict is a function of the connection state alone, which is what makes it testable: a
/// HubConnection is built inside the service and cannot be substituted, but every state it can be
/// in can be passed here, including the ones that look like success.
/// </summary>
public class RtmChannelLinkTests
{
    [Fact]
    public void OnlyConnectedCountsAsUp()
        => RtmChannelLink.IsUp(HubConnectionState.Connected).Should().BeTrue();

    [Theory]
    [InlineData(HubConnectionState.Disconnected)]
    [InlineData(HubConnectionState.Connecting)]
    [InlineData(HubConnectionState.Reconnecting)]
    public void EveryOtherStateIsDown(HubConnectionState state)
    {
        // NEGATIVE HALF, and the one that matters: Connecting and Reconnecting LOOK like progress,
        // but nothing arrives during them. A widget treating them as up would clear its stale mark
        // and present old values as current - the defect, narrowed to a few seconds.
        RtmChannelLink.IsUp(state).Should().BeFalse();
    }

    [Fact]
    public void NoConnectionObjectAtAllIsDown()
    {
        // After a failed reconnect the service abandons the connection and leaves null behind.
        RtmChannelLink.IsUp(null).Should().BeFalse();
    }

    [Fact]
    public void AnUnknownChannelIsReportedDown_notUp()
    {
        // The service's own answer for a channel it has never seen. Reporting an unknown channel as
        // up would put a clean screen in front of someone with nothing behind it.
        var service = new RtmRelayService(
            Substitute.For<Microsoft.Extensions.DependencyInjection.IServiceScopeFactory>(),
            Substitute.For<IConnectionMultiplexer>(),
            NullLogger<RtmRelayService>.Instance,
            Substitute.For<IOptionsMonitor<RtmRelayOptions>>());

        service.IsChannelUp(Guid.NewGuid(), 42, RtmChannelKind.Union).Should().BeFalse();
        service.IsChannelUp(Guid.NewGuid(), 42, RtmChannelKind.Grid).Should().BeFalse();
    }
}
