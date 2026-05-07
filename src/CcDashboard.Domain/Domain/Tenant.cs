using CcDashboard.Domain.Enums;

namespace CcDashboard.Domain.Domain;

public class Tenant
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public TenantStatus Status { get; set; } = TenantStatus.Active;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public TenantSettings? Settings { get; set; }
    public ICollection<SsoConfiguration> SsoConfigurations { get; set; } = [];
}
