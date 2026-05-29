namespace CcDashboard.Domain.Domain;

/// <summary>
/// Named container for scrolling messages displayed on contact-centre dashboards.
/// Shell-managed entity with own SignalR hub (InfoSlotHub).
/// </summary>
public class InfoSlot
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string DisplayMode { get; set; } = "Ticker"; // "Ticker" | "Sequential"
    public int SecondsPerMessage { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public ICollection<InfoSlotPermission> Permissions { get; set; } = [];
    public ICollection<InfoSlotMessage> Messages { get; set; } = [];
}

/// <summary>
/// Junction table: which Permission Groups can write to which Info Slots.
/// </summary>
public class InfoSlotPermission
{
    public Guid InfoSlotId { get; set; }
    public Guid PermissionGroupId { get; set; }
    public Guid TenantId { get; set; }

    public InfoSlot InfoSlot { get; set; } = default!;
    public PermissionGroup PermissionGroup { get; set; } = default!;
}

/// <summary>
/// Message written by management staff for display in Info Slot widgets.
/// </summary>
public class InfoSlotMessage
{
    public Guid Id { get; set; }
    public Guid InfoSlotId { get; set; }
    public Guid TenantId { get; set; }
    public string Content { get; set; } = default!;
    public string Priority { get; set; } = "Normal"; // "Normal" | "High"
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime? DeactivatedAt { get; set; }
    public Guid? DeactivatedByUserId { get; set; }

    public InfoSlot InfoSlot { get; set; } = default!;
}
