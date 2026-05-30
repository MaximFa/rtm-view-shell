using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// Calls GET {SignalRConnectionUrl}/LoadData on the RTM SignalR Server after any
/// RTM-related config change, so RTM re-reads all RTSGrid_* tables without restarting.
/// Fails gracefully — save always succeeds even if RTM is unreachable.
/// </summary>
public class RtmConfigurationApiHook(
    AppDbContext db,
    ITenantContext tenantContext,
    IHttpClientFactory httpClientFactory,
    ILogger<RtmConfigurationApiHook> logger) : IConfigurationApiHook
{
    private static readonly HashSet<string> RtmEventTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "QueueGridRts.Saved",  "QueueGridRts.Deleted",
        "AgentGridRts.Saved",  "AgentGridRts.Deleted",
        "DataSlotRts.Saved",   "DataSlotRts.Deleted",
        "BusinessUnit", "Supergroup", "Site", "RtsGridMetric"
    };

    public async Task NotifyAsync(string entityType, object payload, CancellationToken ct = default)
    {
        if (!RtmEventTypes.Contains(entityType))
            return;

        if (!tenantContext.IsResolved)
        {
            logger.LogDebug("[RTM-HOOK] Tenant not resolved, skipping /LoadData for {EntityType}", entityType);
            return;
        }

        string? rtmUrl;
        try
        {
            var settings = await db.TenantSettings
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.TenantId == tenantContext.TenantId, ct);
            rtmUrl = settings?.SignalRConnectionUrl;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "[RTM-HOOK] Failed to read TenantSettings for {EntityType}", entityType);
            return;
        }

        if (string.IsNullOrWhiteSpace(rtmUrl))
        {
            logger.LogDebug("[RTM-HOOK] SignalRConnectionUrl not set for tenant {TenantId}", tenantContext.TenantId);
            return;
        }

        var loadDataUrl = $"{rtmUrl.TrimEnd('/')}/LoadData";
        try
        {
            var client = httpClientFactory.CreateClient("RtmServer");
            var response = await client.GetAsync(loadDataUrl, ct);
            if (response.IsSuccessStatusCode)
                logger.LogInformation("[RTM-HOOK] /LoadData OK ({Status}) for {EntityType}, tenant {TenantId}",
                    (int)response.StatusCode, entityType, tenantContext.TenantId);
            else
                logger.LogWarning("[RTM-HOOK] /LoadData returned {Status} for {EntityType}",
                    (int)response.StatusCode, entityType);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or OperationCanceledException)
        {
            logger.LogWarning(ex,
                "[RTM-HOOK] /LoadData unreachable for {EntityType} — save succeeded, RTM will sync later",
                entityType);
        }
    }
}
