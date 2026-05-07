namespace CcDashboard.Core.Domain;

public class UserGroup
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public Guid GroupId { get; set; }
    public PermissionGroup Group { get; set; } = null!;
}
