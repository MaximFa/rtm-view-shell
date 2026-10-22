using CcDashboard.Domain.Domain.Rtm;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Server-side relay between RTM Service SignalR Hub and Blazor widget components.
/// Registered as Singleton — one HubConnection per (TenantId, UnionId/GridId).
/// See CLAUDE.md §34.
/// </summary>
public interface IRtmRelayService
{
    // ── Per-union (AgentGrid) ────────────────────────────────────────────────
    Task SubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler,
        CancellationToken ct = default);

    Task UnsubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler);

    // ── Per-grid (DataGrid) ──────────────────────────────────────────────────
    Task SubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler,
        CancellationToken ct = default);

    Task UnsubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler);

    // ── Connection state (BL-V4-STALE-VALUES-LOOK-LIVE-01) ──────────────────
    /// <summary>
    /// Raised when the relay's link to the RTM hub for one channel goes down or comes back.
    ///
    /// WHY THIS IS A SEPARATE MECHANISM, and not a case of the messages above. The union half
    /// carries a discriminated union and could take a fourth case; the grid half carries a bare
    /// list of cell updates and could not, so one shared message type would mean changing
    /// SubscribeGridAsync and all five of its consumers, two of them outside this territory
    /// (RtmRelayHub, WfmEngineAgentCountProvider). A link's state is a property of the link, not a
    /// kind of data, so it travels on its own notice. The cost is that there are now two
    /// mechanisms to remember - written down here on purpose. Decided with the coordinator
    /// 2026-10-22.
    ///
    /// Subscribers filter by TenantId/ChannelId/Kind; a widget that shows values it did not
    /// receive itself must mark them as old rather than let them pass for current, because the
    /// grids' own one-second tick keeps running durations GROWING while the hub is gone.
    /// </summary>
    event Func<RtmConnectionChanged, Task>? ConnectionChanged;

    // ── Tenant lifecycle ─────────────────────────────────────────────────────
    /// <summary>
    /// Disconnect all active connections for a tenant (called on Suspend/Delete).
    /// </summary>
    Task DisconnectTenantAsync(Guid tenantId);
    // ── Metrics hot-reload (CLAUDE.md §hot-reload-contract) ─────────────────
    /// <summary>
    /// Fires compileMetrics on the tenant's RTM hub (fire-and-forget).
    /// Sends ONLY the RT MetricIds (appliedRtMetricIds from apply response).
    /// Empty list -> no-op (log + return). History metrics (dotted) are skipped
    /// by RTM as defense-in-depth, but Shell never sends them per contract R1.
    /// </summary>
    Task InvokeCompileMetricsAsync(Guid tenantId, IReadOnlyList<string> metricIds, CancellationToken ct = default);

}
