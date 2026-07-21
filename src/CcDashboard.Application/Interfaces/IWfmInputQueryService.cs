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
}
