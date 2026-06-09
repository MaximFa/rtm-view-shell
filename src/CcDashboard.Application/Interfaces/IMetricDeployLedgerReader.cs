namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Reads the per-metric deploy ledger (contract §9 / §38a).
/// Returns MetricIds already recorded as applied on THIS client DB.
/// Read-only, no DML in web tier (contract §2 security model).
/// NOTE: TenantId N/A — RTSGrid_Metric is platform-wide cross-tenant (CLAUDE.md §6.1/WGT-01).
/// </summary>
public interface IMetricDeployLedgerReader
{
    /// <summary>
    /// Returns the set of MetricIds that have been applied (recorded in the ledger).
    /// Shell computes delta as: package manifest MetricIds MINUS this set.
    /// </summary>
    Task<IReadOnlySet<string>> GetAppliedMetricIdsAsync(CancellationToken ct = default);
}
