using Microsoft.AspNetCore.Identity;

namespace CcDashboard.Infrastructure.Identity;

public class ApplicationUser : IdentityUser<Guid>
{
    public Guid TenantId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public Guid? PermissionGroupId { get; set; }
    public bool IsActive { get; set; } = true;
    public bool Is2faEnabled { get; set; }
    public DateTime? LastLoginAt { get; set; }
    public string PreferredLocale { get; set; } = "en-US";
    public DateTime? MustChangePasswordAt { get; set; }
}

public class ApplicationRole : IdentityRole<Guid>
{
    public ApplicationRole() { }
    public ApplicationRole(string name) : base(name) { }
}
