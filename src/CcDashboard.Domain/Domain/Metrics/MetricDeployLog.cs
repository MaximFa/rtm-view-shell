namespace CcDashboard.Domain.Domain.Metrics;

/// <summary>
/// Per-metric deploy ledger row (hot-reload contract §3, §38a).
/// Records which MetricIds have been applied on THIS client DB.
/// Cross-tenant (no TenantId) like RTSGrid_Metric.
/// </summary>
public class MetricDeployLog
{
    /// <summary>MetricId matching RTSGrid_Metric.MetricId (text PK).</summary>
    public string MetricId { get; set; } = "";

    /// <summary>UTC timestamp when the metric was deployed.</summary>
    public DateTime DeployedAt { get; set; }

    /// <summary>Source commit / package ref the metric came from.</summary>
    public string? SourceCommit { get; set; }
}