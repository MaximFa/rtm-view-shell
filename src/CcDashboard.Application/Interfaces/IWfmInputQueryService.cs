namespace CcDashboard.Application.Interfaces;

/// <summary>
/// WFM Phase 1: queries λ (arrivals), AHT, and N (serving agents) for Erlang calculations.
/// Per dba-locked frame (14:22): offset from interaction's OWN TimeZone column, app-side bounds.
/// </summary>
public interface IWfmInputQueryService
{
    /// <summary>
    /// Get λ (arrivals/hour) and AHT (sec) for all queues in a tenant within a rolling window.
    /// Returns dictionary keyed by Workgroup (queue external ID).
    /// </summary>
    Task<IReadOnlyDictionary<string, (double LambdaPerHour, double AhtSec)>> GetLambdaAndAhtAsync(
        Guid tenantId,
        int windowMinutes,
        CancellationToken ct = default);

    /// <summary>
    /// Get N (serving agent count) for each queue in a tenant.
    /// Returns dictionary keyed by Workgroup (queue external ID).
    /// </summary>
    Task<IReadOnlyDictionary<string, int>> GetServingAgentCountsAsync(
        Guid tenantId,
        IReadOnlyList<string> servingStateGroups,
        CancellationToken ct = default);

    /// <summary>
    /// Get distinct serving agent count for a Business Unit.
    /// Uses §36a resolution: SG=AND (intersect AG members), BU=OR (union SG results).
    /// Returns count of agents in serving state groups.
    /// </summary>
    Task<int> GetBuServingAgentCountAsync(
        Guid tenantId,
        int businessUnitId,
        IReadOnlyList<string> servingStateGroups,
        CancellationToken ct = default);

    /// <summary>
    /// Get all active Business Units for a tenant with their names and queue mappings.
    /// Used by WFM loop for per-BU aggregate computation.
    /// </summary>
    Task<IReadOnlyList<BuInfo>> GetActiveBusAsync(Guid tenantId, CancellationToken ct = default);
}

/// <summary>Business Unit info for WFM aggregation.</summary>
public record BuInfo(int BusinessUnitId, string BusinessUnitName, IReadOnlyList<string> QueueIds);
