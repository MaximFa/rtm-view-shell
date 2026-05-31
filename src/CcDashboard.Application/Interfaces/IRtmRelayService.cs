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
}
