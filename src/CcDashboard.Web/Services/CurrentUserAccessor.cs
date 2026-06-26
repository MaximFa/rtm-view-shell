using CcDashboard.Domain.Interfaces;
using Microsoft.AspNetCore.Components.Authorization;
using System.Security.Claims;

namespace CcDashboard.Web.Services;

public class CurrentUserAccessor(AuthenticationStateProvider authStateProvider) : ICurrentUserAccessor
{
    private ClaimsPrincipal? _principal;

    public async Task InitAsync()
    {
        var state = await authStateProvider.GetAuthenticationStateAsync();
        _principal = state.User;
    }

    // Auto-initializes synchronously if not yet initialized — works on Blazor Server
    // because AuthenticationStateProvider caches the state and the task is already complete.
    private ClaimsPrincipal Principal
    {
        get
        {
            if (_principal is not null) return _principal;
            var task = authStateProvider.GetAuthenticationStateAsync();
            if (task.IsCompletedSuccessfully)
            {
                _principal = task.Result.User;
                return _principal;
            }
            return new ClaimsPrincipal();
        }
    }

    public Guid? UserId => Guid.TryParse(Principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
    public string? UserName => Principal.FindFirstValue(ClaimTypes.Name);
    public string? Role => Principal.FindFirstValue(ClaimTypes.Role);
    public Guid? PermissionGroupId => Guid.TryParse(Principal.FindFirstValue("permission_group_id"), out var pgId) ? pgId : null;

    /// <summary>
    /// ARCH-02 C1: For Superadmin, return active_tenant_id (impersonated tenant); for all others, return home tenant_id.
    /// The Role is read from the TRUSTED ClaimTypes.Role — never infer privilege from active_tenant_id.
    /// </summary>
    public Guid? TenantId
    {
        get
        {
            var role = Principal.FindFirstValue(ClaimTypes.Role);
            if (role == "Superadmin")
            {
                var activeClaim = Principal.FindFirstValue("active_tenant_id");
                if (Guid.TryParse(activeClaim, out var activeId))
                    return activeId;
            }
            // Non-Superadmin or no active_tenant_id: use home tenant_id
            return Guid.TryParse(Principal.FindFirstValue("tenant_id"), out var tid) ? tid : null;
        }
    }

    public string PreferredLocale => Principal.FindFirstValue("locale") ?? "en-US";
    public bool IsAuthenticated => Principal.Identity?.IsAuthenticated == true;
}
