using CcDashboard.Domain.Enums;

namespace CcDashboard.Domain.Domain;

public class SsoConfiguration
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public SsoProvider Provider { get; set; }
    public string? MetadataUrl { get; set; }
    public string? ClientId { get; set; }
    public string? ClientSecret { get; set; }
    public string ClaimMappings { get; set; } = "{}";
    public bool IsActive { get; set; }

    public Tenant? Tenant { get; set; }
}
