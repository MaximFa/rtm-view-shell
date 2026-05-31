namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>
/// Discriminated union for changes delivered to IRtmRelayService subscribers.
/// </summary>
public abstract record UnionStateChange
{
    /// <summary>Full snapshot delivered immediately on Subscribe.</summary>
    public sealed record InitialSnapshot(
        IReadOnlyDictionary<string, AgentSnapshot> Agents,
        TimeSpan ServerTimeOffset) : UnionStateChange;

    /// <summary>One or more agents were added or updated.</summary>
    public sealed record AgentsUpserted(
        IReadOnlyList<AgentSnapshot> Agents) : UnionStateChange;

    /// <summary>One or more agents were removed (logged out / disconnected).</summary>
    public sealed record AgentsRemoved(
        IReadOnlyList<string> AgentLoginNames) : UnionStateChange;
}
