using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Web.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Web.Services;

/// <summary>
/// Background service that expires Info Slot messages.
/// Runs every 60 seconds and deactivates messages past ExpiresAt.
/// Per ARCH-07: creates fresh DI scope per run.
/// </summary>
public class InfoSlotExpiryService(
    IServiceScopeFactory scopeFactory,
    IHubContext<InfoSlotHub> hubContext,
    ILogger<InfoSlotExpiryService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ExpireMessagesAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "InfoSlotExpiryService: error during expiry run");
            }

            await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
        }
    }

    private async Task ExpireMessagesAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var now = DateTime.UtcNow;

        // Cross-tenant: IgnoreQueryFilters + explicit where
        var expired = await db.InfoSlotMessages
            .IgnoreQueryFilters()
            .Where(m => m.IsActive &&
                        m.ExpiresAt.HasValue &&
                        m.ExpiresAt.Value <= now)
            .Select(m => new { m.Id, m.TenantId, m.InfoSlotId })
            .ToListAsync(ct);

        if (expired.Count == 0) return;

        var expiredIds = expired.Select(e => e.Id).ToList();
        await db.InfoSlotMessages
            .IgnoreQueryFilters()
            .Where(m => expiredIds.Contains(m.Id))
            .ExecuteUpdateAsync(s => s
                .SetProperty(m => m.IsActive, false)
                .SetProperty(m => m.DeactivatedAt, now), ct);

        foreach (var msg in expired)
        {
            var group = $"t:{msg.TenantId}:is:{msg.InfoSlotId}";
            await hubContext.Clients.Group(group)
                .SendAsync("MessageExpired", new { MessageId = msg.Id }, ct);
        }

        logger.LogInformation("InfoSlotExpiryService: expired {Count} messages", expired.Count);
    }
}
