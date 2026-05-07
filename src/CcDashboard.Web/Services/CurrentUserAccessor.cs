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

    private ClaimsPrincipal Principal => _principal ?? new ClaimsPrincipal();

    public Guid? UserId => Guid.TryParse(Principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
    public string? UserName => Principal.FindFirstValue(ClaimTypes.Name);
    public string? Role => Principal.FindFirstValue(ClaimTypes.Role);
    public Guid? PermissionGroupId => Guid.TryParse(Principal.FindFirstValue("permission_group_id"), out var pgId) ? pgId : null;
    public Guid? TenantId => Guid.TryParse(Principal.FindFirstValue("tenant_id"), out var tid) ? tid : null;
    public string PreferredLocale => Principal.FindFirstValue("locale") ?? "en-US";
    public bool IsAuthenticated => Principal.Identity?.IsAuthenticated == true;
}
