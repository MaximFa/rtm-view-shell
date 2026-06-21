namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// Resolves the security scope for historical reports based on current user's role and PG.
/// SF-BI-001: ensures non-superadmin users ONLY see data they have PG access to.
/// </summary>
public interface IReportScopeResolver
{
    /// <summary>
    /// Resolves queue scope for the current user.
    /// - Superadmin: FullScope=true (can query any queue)
    /// - Others: AllowedWorkgroups from PG -> NGC_Queues.ExternalId mapping
    /// </summary>
    Task<ReportScope> ResolveQueueScopeAsync(CancellationToken ct = default);

    /// <summary>
    /// Resolves agent scope for the current user.
    /// - Superadmin: FullScope=true (can query any agent)
    /// - Others: AllowedAgentExternalIds from PG supergroups/BUs -> NGC pool
    /// </summary>
    Task<ReportScope> ResolveAgentScopeAsync(CancellationToken ct = default);
}
