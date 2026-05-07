using CcDashboard.Core.Enums;

namespace CcDashboard.Core.Domain;

public class Screen
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid OwnerId { get; set; }
    public Guid? OwnerGroupId { get; set; }
    public ScreenStatus Status { get; set; } = ScreenStatus.Draft;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<WidgetSlot> WidgetSlots { get; set; } = new List<WidgetSlot>();
    public ICollection<ScreenPermission> Permissions { get; set; } = new List<ScreenPermission>();
}
