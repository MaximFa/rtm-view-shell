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
