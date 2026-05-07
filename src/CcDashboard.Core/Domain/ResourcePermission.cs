using CcDashboard.Core.Enums;

namespace CcDashboard.Core.Domain;

public class ResourcePermission
{
    public Guid Id { get; set; }
    public Guid GroupId { get; set; }
    public PermissionGroup Group { get; set; } = null!;
    public ResourceType ResourceType { get; set; }
    public string ResourceId { get; set; } = string.Empty;
    public bool CanView { get; set; }
}
