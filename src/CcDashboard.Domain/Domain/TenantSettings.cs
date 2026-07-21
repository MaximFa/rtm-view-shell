namespace CcDashboard.Domain.Domain;

public class TenantSettings
{
    public Guid TenantId { get; set; }
    public int PasswordMinLength { get; set; } = 12;
    public int PasswordExpireDays { get; set; } = 90;
    public bool Require2faForAll { get; set; }
    public int AuditRetentionDays { get; set; } = 365;
    public string DefaultLocale { get; set; } = "en-US";
    public bool SoftDeleteDashboards { get; set; }
    public int SoftDeleteRetentionDays { get; set; } = 90;
    public string? EmailProviderConfig { get; set; }
    public Guid? SsoConfigurationId { get; set; }

    // Licensing
    public int PurchasedLicences { get; set; } = 0;        // 0 = unlimited
    public int MaxConcurrentConnections { get; set; } = 0; // 0 = unlimited

    // SignalR widgets connection
    public string? SignalRConnectionUrl { get; set; }

    // Appearance settings (JSON arrays)
    public string? BackgroundColorPalette { get; set; }  // JSON array of hex colors
    public string? FontColorPalette { get; set; }        // JSON array of hex colors
    public string? FontSizes { get; set; }               // JSON array of font size options

    // Historical Reports SL threshold (seconds) - per tenant, used by aggregation
    // NULL = use default (20 sec). Caveat: changing after data accrues needs re-aggregation.
    public int? SlThresholdSeconds { get; set; }

    // ─── WFM Phase 1 config (spec §5) ───────────────────────────────────────
    /// <summary>Agent state groups counted as "serving" for N calculation. Default: Available, On Phone, Paperwork.</summary>
    public string[] WfmServingStateGroups { get; set; } = new[] { "Available", "On Phone", "Paperwork" };
    /// <summary>Rolling window length for λ/AHT calculation (minutes). Default 30.</summary>
    public int WfmWindowMinutes { get; set; } = 30;
    /// <summary>SL target percentage (e.g. 80 for 80%). Default 80.</summary>
    public double WfmSlTargetPct { get; set; } = 80;
    /// <summary>SL threshold in seconds (answer within t seconds). Default 20.</summary>
    public int WfmSlThresholdSec { get; set; } = 20;
    /// <summary>Trunk capacity for ErlangB calculation. Default 100.</summary>
    public int WfmTrunkCapacity { get; set; } = 100;
    /// <summary>Default shrinkage for FTE calculation (0.28 = 28%). Default 0.28.</summary>
    public double WfmDefaultShrinkage { get; set; } = 0.28;
    /// <summary>Enable real-time WFM metrics. Default true.</summary>
    public bool WfmEnableRealtime { get; set; } = true;
    /// <summary>Per-metric RAG threshold overrides (JSON). NULL = use spec defaults.</summary>
    public string? WfmThresholds { get; set; }

    public Tenant? Tenant { get; set; }
}
