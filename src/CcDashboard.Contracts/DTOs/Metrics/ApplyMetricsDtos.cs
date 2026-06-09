namespace CcDashboard.Contracts.DTOs.Metrics;

/// <summary>
/// Request to the devops apply-endpoint (contract §5).
/// Shell -> apply-service (localhost HTTP).
/// </summary>
public sealed record ApplyMetricsRequest
{
    /// <summary>Source commit / package id the migration came from (-> sourceCommit in ledger).</summary>
    public string PackageRef { get; init; } = "";
    
    /// <summary>The metric-migration file in the package to apply.</summary>
    public string MigrationRef { get; init; } = "";
    
    /// <summary>The undeployed MetricIds Shell computed from manifest MINUS ledger.</summary>
    public IReadOnlyList<string> MetricIds { get; init; } = Array.Empty<string>();
    
    /// <summary>Superadmin UserId who triggered the deploy (audit only).</summary>
    public string TriggeredBy { get; init; } = "";
}

/// <summary>
/// Response from the devops apply-endpoint (contract §6).
/// apply-service -> Shell.
/// </summary>
public sealed record ApplyMetricsResponse
{
    /// <summary>True if apply succeeded (catalogue + ledger written in one tx).</summary>
    public bool Success { get; init; }
    
    /// <summary>RT-half MetricIds ONLY (history excluded at apply). Shell passes EXACTLY this to compileMetrics.</summary>
    public IReadOnlyList<string> AppliedRtMetricIds { get; init; } = Array.Empty<string>();
    
    /// <summary>Per-metric ledger rows created (§38a).</summary>
    public IReadOnlyList<LedgerRow> LedgerRows { get; init; } = Array.Empty<LedgerRow>();
    
    /// <summary>Warnings (e.g. metricIds mismatch, already deployed).</summary>
    public IReadOnlyList<string> Warnings { get; init; } = Array.Empty<string>();
    
    /// <summary>Audit row id for System.MetricsDeployed event.</summary>
    public string? AuditId { get; init; }
    
    /// <summary>Error message on failure (Success=false).</summary>
    public string? Error { get; init; }
}

/// <summary>
/// Per-metric ledger row (contract §9 / §38a).
/// Records which MetricIds have been applied on THIS client DB.
/// </summary>
public sealed record LedgerRow
{
    public string MetricId { get; init; } = "";
    public DateTimeOffset DeployedAt { get; init; }
    public string SourceCommit { get; init; } = "";
}
