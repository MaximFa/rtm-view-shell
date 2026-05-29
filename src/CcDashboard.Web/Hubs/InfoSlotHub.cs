using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Web.Hubs;

/// <summary>
/// SignalR Hub for Info Slot message notifications.
/// Implements ARCH-09: Group naming "t:{tenantId}:is:{infoSlotId}".
///
/// Auth note: Blazor Server widgets create HubConnection from server-side code and
/// cannot forward the browser cookie to [Authorize]. Instead, tenantId is passed
/// explicitly and verified against the DB (slot must exist for that tenant).
/// The hub only BROADCASTS — it accepts no writes — so the attack surface is limited.
/// </summary>
[AllowAnonymous]
public class InfoSlotHub(AppDbContext db) : Hub
{
    /// <summary>
    /// Join an Info Slot group to receive message updates.
    /// tenantId is supplied by the caller (Blazor component or browser JS client)
    /// and validated against the database.
    /// </summary>
    public async Task JoinSlot(Guid infoSlotId, Guid tenantId)
    {
        // Verify the slot exists AND belongs to the claimed tenant
        var slotExists = await db.InfoSlots
            .IgnoreQueryFilters()
            .AnyAsync(s => s.Id == infoSlotId && s.TenantId == tenantId && s.IsActive);

        if (!slotExists)
            throw new HubException("Not found");

        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
    }

    /// <summary>
    /// Leave an Info Slot group.
    /// </summary>
    public async Task LeaveSlot(Guid infoSlotId, Guid tenantId)
    {
        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
    }
}
