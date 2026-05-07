namespace CcDashboard.Core.Domain;

public class ScreenPermission
{
    public Guid ScreenId { get; set; }
    public Screen Screen { get; set; } = null!;

    public Guid GroupId { get; set; }
    public PermissionGroup Group { get; set; } = null!;

    public bool CanView { get; set; }
    public bool CanEdit { get; set; }
    public bool CanDelete { get; set; }
}
