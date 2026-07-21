using System.Collections.Concurrent;
using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Wfm;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// In-memory store for WFM snapshots. Singleton, thread-safe.
/// Written by the WFM hosted loop (B1), read by Shell widgets.
/// </summary>
public sealed class WfmSnapshotStore : IWfmSnapshotStore
{
    private readonly ConcurrentDictionary<(Guid TenantId, string QueueId), WfmSnapshot> _snapshots = new();

    /// <inheritdoc/>
    public void Set(WfmSnapshot snapshot)
    {
        _snapshots[(snapshot.TenantId, snapshot.QueueId)] = snapshot;
    }

    /// <inheritdoc/>
    public WfmSnapshot? Get(Guid tenantId, string queueId)
    {
        return _snapshots.TryGetValue((tenantId, queueId), out var snap) ? snap : null;
    }

    /// <inheritdoc/>
    public IReadOnlyList<WfmSnapshot> GetForTenant(Guid tenantId)
    {
        return _snapshots
            .Where(kvp => kvp.Key.TenantId == tenantId)
            .Select(kvp => kvp.Value)
            .ToList();
    }
}
