using CcDashboard.Domain.Domain.Historical;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// Repository interface for historical reports data access.
/// All reads are AsNoTracking. SF-BI-001: PG scope is MANDATORY on all query methods.
/// </summary>
public interface IHistoricalReportRepository
{
    /// <summary>
    /// Get queue intervals for a date range with mandatory PG scope.
    /// SF-BI-001: workgroups filter is ALWAYS applied for non-FullScope.
    /// </summary>
    Task<IReadOnlyList<HistQueueInterval>> GetQueueIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        ReportScope scope,
        IReadOnlySet<string> effectiveWorkgroups,
        CancellationToken ct);

    /// <summary>
    /// Get agent intervals for a date range with mandatory PG scope.
    /// SF-BI-001: agent filter is ALWAYS applied for non-FullScope.
    /// </summary>
    Task<IReadOnlyList<HistAgentInterval>> GetAgentIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        ReportScope scope,
        IReadOnlySet<string> effectiveAgentIds,
        CancellationToken ct);

    /// <summary>Get watermark for a tenant (aggregation progress).</summary>
    Task<HistAggregationWatermark?> GetWatermarkAsync(Guid tenantId, CancellationToken ct);

    /// <summary>Update or insert watermark.</summary>
    Task UpsertWatermarkAsync(Guid tenantId, DateTime aggregatedThrough, CancellationToken ct);

    /// <summary>Delete queue intervals for re-aggregation (idempotent upsert pattern).</summary>
    Task DeleteQueueIntervalsAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct);

    /// <summary>Delete agent intervals for re-aggregation (idempotent upsert pattern).</summary>
    Task DeleteAgentIntervalsAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct);

    /// <summary>Insert queue intervals batch.</summary>
    Task InsertQueueIntervalsAsync(IEnumerable<HistQueueInterval> intervals, CancellationToken ct);

    /// <summary>Insert agent intervals batch.</summary>
    Task InsertAgentIntervalsAsync(IEnumerable<HistAgentInterval> intervals, CancellationToken ct);

    /// <summary>Ensure partitions exist for aggregation window.</summary>
    Task EnsurePartitionsAsync(int monthsBack, int monthsAhead, CancellationToken ct);
}
