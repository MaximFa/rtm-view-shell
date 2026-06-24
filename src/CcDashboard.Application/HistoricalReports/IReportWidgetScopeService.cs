using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// SF-BI-001: Server-side scope resolution for report widgets.
/// NON-BYPASSABLE — the frontend CANNOT skip this; all queries go through RunReportWidgetQuery.
/// </summary>
public interface IReportWidgetScopeService
{
    /// <summary>
    /// Resolve effective workgroups for a queue widget.
    /// - Superadmin: all requested queues pass
    /// - Others: requested ∩ PG-allowed (out-of-scope dropped + logged)
    /// Empty PG -> DENY (returns empty set).
    /// </summary>
    Task<ReportWidgetScopeResult> ResolveQueueScopeAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        CancellationToken ct = default);

    /// <summary>
    /// Resolve effective agents for an agent widget.
    /// - Superadmin: all requested agents pass
    /// - Others: requested ∩ PG-allowed (out-of-scope dropped + logged)
    /// Empty PG -> DENY (returns empty set).
    /// </summary>
    Task<ReportWidgetScopeResult> ResolveAgentScopeAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        AgentReportAxis axis,
        CancellationToken ct = default);
}

/// <summary>Result of scope resolution with audit info.</summary>
public record ReportWidgetScopeResult
{
    /// <summary>True if user is Superadmin (no filtering).</summary>
    public bool FullScope { get; init; }

    /// <summary>Effective workgroups (queue ext-ids) after PG intersection.</summary>
    public IReadOnlySet<string> EffectiveWorkgroups { get; init; } = new HashSet<string>();

    /// <summary>Effective agent external IDs after PG intersection.</summary>
    public IReadOnlySet<string> EffectiveAgentIds { get; init; } = new HashSet<string>();

    /// <summary>Count of out-of-scope entries dropped (SF-BI-002 detective log).</summary>
    public int DroppedCount { get; init; }

    /// <summary>True if access is denied (non-Superadmin with empty PG).</summary>
    public bool Denied => !FullScope && EffectiveWorkgroups.Count == 0 && EffectiveAgentIds.Count == 0 && DroppedCount == 0;
}
