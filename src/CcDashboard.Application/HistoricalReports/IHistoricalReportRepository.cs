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

    /// <summary>
    /// FEAT-REPORT-AGENT-PERF-01 agent picker: the display name of each given agent by the one name rule
    /// (Infrastructure AgentNameRule: newest RTSData_UserStatus.DisplayName of the tenant that is not the login).
    /// Agents with no such name are absent from the result (the caller shows the id).
    /// Callers pass an already scoped, non-empty id set - an empty set returns empty without a query.
    /// </summary>
    Task<IReadOnlyDictionary<string, string>> GetAgentDisplayNamesAsync(
        Guid tenantId,
        IReadOnlySet<string> agentIds,
        CancellationToken ct);

    /// <summary>
    /// FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01: the newest interval start (UTC) of a data set for the tenant, within the given,
    /// already scoped keys (workgroups for <see cref="ReportDataSet.Queues"/>). Null when there is no row. An empty key set
    /// returns null without a query (PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01 shape: nothing in scope - nothing asked).
    /// </summary>
    Task<DateTime?> GetLastIntervalStartAsync(
        Guid tenantId,
        ReportDataSet dataSet,
        IReadOnlySet<string> scopedKeys,
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

/// <summary>
/// FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01: which history a report reads, for the one "last day with data" rule. Agents join
/// later as a value here (and a branch in the repository), never as a second rule.
/// </summary>
public enum ReportDataSet
{
    Queues
}
