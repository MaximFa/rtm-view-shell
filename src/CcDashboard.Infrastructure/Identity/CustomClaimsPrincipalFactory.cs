using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using System.Security.Claims;

namespace CcDashboard.Infrastructure.Identity;

/// <summary>
/// Adds tenant_id, permission_group_id, and locale custom claims to the Identity cookie principal.
/// Called automatically by SignInManager during every sign-in.
/// </summary>
public class CustomClaimsPrincipalFactory(
    UserManager<ApplicationUser> userManager,
    RoleManager<ApplicationRole> roleManager,
    IOptions<IdentityOptions> optionsAccessor)
    : UserClaimsPrincipalFactory<ApplicationUser, ApplicationRole>(userManager, roleManager, optionsAccessor)
{
    protected override async Task<ClaimsIdentity> GenerateClaimsAsync(ApplicationUser user)
    {
        var identity = await base.GenerateClaimsAsync(user);

        identity.AddClaim(new Claim("tenant_id", user.TenantId.ToString()));
        identity.AddClaim(new Claim("active_tenant_id", user.TenantId.ToString())); // ARCH-02: default = home; shell re-issues with target on switch
        identity.AddClaim(new Claim("locale", user.PreferredLocale));

        if (user.PermissionGroupId.HasValue)
            identity.AddClaim(new Claim("permission_group_id", user.PermissionGroupId.Value.ToString()));

        return identity;
    }
}
