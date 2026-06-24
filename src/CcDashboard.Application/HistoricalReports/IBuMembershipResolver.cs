namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// Axis indicating whether a report aggregates or lists agents.
/// DETAIL = union of all agents in BU; CUMULATIVE = intersection-per-SG then union.
/// </summary>
public enum AgentReportAxis
{
    /// <summary>Agent list reports: UNION of all agents of all AgentGroups in all Supergroups of the BU.</summary>
    Detail,
    /// <summary>Aggregate reports: ∪_SG(∩_AG members(AG)) — per SG intersect, then union across SGs.</summary>
    Cumulative
}

/// <summary>
/// Resolves Business Unit(s) to concrete filter sets for historical reports.
/// BU -> queues (workgroups) for queue reports.
/// BU -> agent external IDs for agent reports (detail or cumulative axis).
/// All results are INTERSECTED with PG scope (SF-BI-001 enforcement).
/// </summary>
public interface IBuMembershipResolver
{
    /// <summary>
    /// Resolves BU(s) to a workgroup set for queue/workgroup reports.
    /// Path: NGC_BusinessUnitQueueClassification (ClassificationId='ALL') -> QueueId.
    /// Result is intersected with PG-allowed workgroups.
    /// </summary>
    Task<IReadOnlySet<string>> ResolveQueuesAsync(
        Guid tenantId,
        IReadOnlyList<int> businessUnitIds,
        ReportScope pgScope,
        CancellationToken ct = default);

    /// <summary>
    /// Resolves BU(s) to an agent external ID set for agent reports.
    /// Path: NGC_BusinessUnitSupergroup -> NGC_SupergroupAgentgroup -> NGC_UserAgentgroup.
    /// Axis: Detail = union all; Cumulative = ∪_SG(∩_AG).
    /// Result is intersected with PG-allowed agent IDs.
    /// </summary>
    Task<IReadOnlySet<string>> ResolveAgentsAsync(
        Guid tenantId,
        IReadOnlyList<int> businessUnitIds,
        AgentReportAxis axis,
        ReportScope pgScope,
        CancellationToken ct = default);
}
