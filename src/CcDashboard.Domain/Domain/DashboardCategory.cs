namespace CcDashboard.Domain.Domain;

public class DashboardCategory
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public Tenant? Tenant { get; set; }
    public ICollection<Dashboard> Dashboards { get; set; } = [];
}
