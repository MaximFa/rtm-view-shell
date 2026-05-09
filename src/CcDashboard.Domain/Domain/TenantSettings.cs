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

    public Tenant? Tenant { get; set; }
}
