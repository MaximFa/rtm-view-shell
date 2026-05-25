using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CcDashboard.Web.Hubs;

/// <summary>
/// SignalR Hub for grid update notifications.
/// Implements ARCH-09: Hub methods verify TenantId from ClaimsPrincipal before adding to groups.
/// Group naming: "t:{tenantId}:{groupName}" per ARCH-09.
/// </summary>
[Authorize]
public class GridNotificationHub : Hub
{
    /// <summary>
    /// Joins a tenant-scoped group. Rejects if token TenantId doesn't match requested group.
    /// </summary>
    public async Task JoinGridGroup(Guid tenantId, string groupName)
    {
        var tokenTenantId = GetTenantIdFromClaims();
        if (tokenTenantId is null)
        {
            throw new HubException("Unauthenticated request.");
        }

        if (tokenTenantId != tenantId)
        {
            throw new HubException("Tenant mismatch: cannot join group for a different tenant.");
        }

        var fullGroupName = $"t:{tenantId}:{groupName}";
        await Groups.AddToGroupAsync(Context.ConnectionId, fullGroupName);
    }

    /// <summary>
    /// Leaves a tenant-scoped group.
    /// </summary>
    public async Task LeaveGridGroup(Guid tenantId, string groupName)
    {
        var fullGroupName = $"t:{tenantId}:{groupName}";
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, fullGroupName);
    }

    private Guid? GetTenantIdFromClaims()
    {
        var tenantClaim = Context.User?.FindFirst("tenant_id");
        if (tenantClaim is null) return null;
        return Guid.TryParse(tenantClaim.Value, out var id) ? id : null;
    }
}
