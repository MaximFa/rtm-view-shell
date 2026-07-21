using CcDashboard.Application.Wfm;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// In-memory store for WFM snapshots. Singleton.
/// Written by the WFM hosted loop (B1), read by Shell widgets.
/// </summary>
public interface IWfmSnapshotStore
{
    /// <summary>Store or update a snapshot for (tenant, queue).</summary>
    void Set(WfmSnapshot snapshot);

    /// <summary>Get the latest snapshot for (tenant, queue). Returns null if none.</summary>
    WfmSnapshot? Get(Guid tenantId, string queueId);

    /// <summary>Get all snapshots for a tenant.</summary>
    IReadOnlyList<WfmSnapshot> GetForTenant(Guid tenantId);
}
