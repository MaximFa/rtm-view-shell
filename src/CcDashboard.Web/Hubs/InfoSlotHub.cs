using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Web.Hubs;

/// <summary>
/// SignalR Hub for Info Slot message notifications.
/// Implements ARCH-09: Group naming "t:{tenantId}:is:{infoSlotId}".
/// Hub methods verify TenantId from ClaimsPrincipal.
/// </summary>
[Authorize]
public class InfoSlotHub(AppDbContext db, ITenantContext tenantContext) : Hub
{
    /// <summary>
    /// Join an Info Slot group to receive message updates.
    /// </summary>
    public async Task JoinSlot(Guid infoSlotId)
    {
        var tenantId = GetTenantIdFromClaims();
        if (tenantId is null)
            throw new HubException("Missing tenant_id claim");

        // Verify TenantId matches resolved tenant (ARCH-04 pattern)
        if (tenantId != tenantContext.TenantId)
            throw new HubException("Tenant mismatch");

        // Verify the requested InfoSlot belongs to the resolved tenant
        var slotExists = await db.InfoSlots
            .AnyAsync(s => s.Id == infoSlotId && s.IsActive);

        if (!slotExists)
            throw new HubException("Not found");

        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
    }

    /// <summary>
    /// Leave an Info Slot group.
    /// </summary>
    public async Task LeaveSlot(Guid infoSlotId)
    {
        var tenantId = GetTenantIdFromClaims();
        if (tenantId is null) return;

        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
    }

    private Guid? GetTenantIdFromClaims()
    {
        var tenantClaim = Context.User?.FindFirst("tenant_id");
        if (tenantClaim is null) return null;
        return Guid.TryParse(tenantClaim.Value, out var id) ? id : null;
    }
}
