namespace CcDashboard.Domain.Domain;

public class WidgetTemplate
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid WidgetCatalogItemId { get; set; }
    public string? ConfigJson { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }

    public Tenant? Tenant { get; set; }
    public WidgetCatalogItem? CatalogItem { get; set; }
}
