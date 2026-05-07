namespace CcDashboard.Core.Domain;

public class PermissionGroup
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public List<string> MenuPermissions { get; set; } = new();
    public DateTime CreatedAt { get; set; }

    public ICollection<UserGroup> Users { get; set; } = new List<UserGroup>();
    public ICollection<ScreenPermission> ScreenPermissions { get; set; } = new List<ScreenPermission>();
    public ICollection<ResourcePermission> ResourcePermissions { get; set; } = new List<ResourcePermission>();
}
