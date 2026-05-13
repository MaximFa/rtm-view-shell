using CcDashboard.Domain.Enums;

namespace CcDashboard.Domain.Domain;

public class Dashboard
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public Guid? CategoryId { get; set; }
    public DashboardStatus Status { get; set; } = DashboardStatus.Draft;
    public bool IsPublic { get; set; }
    public bool IsDarkMode { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
    public Guid? DeletedByUserId { get; set; }
    public string? LayoutJson { get; set; }
    public uint RowVersion { get; set; }

    public Tenant? Tenant { get; set; }
    public DashboardCategory? Category { get; set; }
    public ICollection<DashboardPermission> Permissions { get; set; } = [];
    public ICollection<DashboardWidget> Widgets { get; set; } = [];
}

public class DashboardWidget
{
    public Guid Id { get; set; }
    public int GridId { get; set; }  // Auto-incremented, used for SignalR communication
    public Guid DashboardId { get; set; }
    public Guid TenantId { get; set; }
    public Guid WidgetCatalogItemId { get; set; }
    public bool IsDeleted { get; set; }
    public string? PositionJson { get; set; }
    public string? ConfigJson { get; set; }
    public Dashboard? Dashboard { get; set; }
    public WidgetCatalogItem? CatalogItem { get; set; }
}
