namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>Which of the relay's two kinds of channel a connection notice is about.</summary>
public enum RtmChannelKind
{
    /// <summary>A union channel (AgentGrid).</summary>
    Union,

    /// <summary>A grid channel (QueueGrid, DataSlot, AgentStateDistribution).</summary>
    Grid
}

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01: the relay's link to the RTM hub went down or came back.
///
/// This is deliberately NOT a fourth case of UnionStateChange, even though it would fit there.
/// The grid half of the relay delivers a bare IReadOnlyList&lt;GridCellUpdate&gt; and has no
/// discriminated union to extend, so making one message type for both halves would change
/// SubscribeGridAsync's signature and with it five consumers - two of them outside this
/// territory (RtmRelayHub, WfmEngineAgentCountProvider). The connection's state is a property of
/// the link rather than a kind of data, so it travels on its own notice instead. Decided with the
/// coordinator on 2026-10-22; see IRtmRelayService.ConnectionChanged.
/// </summary>
public sealed record RtmConnectionChanged(
    Guid TenantId,
    int ChannelId,
    RtmChannelKind Kind,
    bool Connected);
