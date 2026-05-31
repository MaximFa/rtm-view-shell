using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Rtm;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CcDashboard.Web.Hubs;

/// <summary>
/// Browser-facing SignalR Hub. Relays RTM Service pushes to JS/external widget clients.
/// Blazor Server components should inject IRtmRelayService directly instead.
/// See CLAUDE.md §34.7.
/// </summary>
[Authorize]
public sealed class RtmRelayHub : Hub
{
    private readonly IRtmRelayService _relay;
    private readonly ILogger<RtmRelayHub> _logger;

    public RtmRelayHub(IRtmRelayService relay, ILogger<RtmRelayHub> logger)
    {
        _relay = relay;
        _logger = logger;
    }

    private Guid TenantId =>
        Guid.TryParse(Context.User?.FindFirst("tenant_id")?.Value, out var tid)
            ? tid
            : throw new HubException("tenant_id claim missing");

    /// <summary>Subscribe to agent grid updates for a union.</summary>
    public async Task SubscribeUnion(int unionId)
    {
        var tenantId = TenantId;
        Func<UnionStateChange, Task> handler = async change =>
        {
            try { await Clients.Caller.SendAsync("unionUpdate", change); }
            catch (Exception ex)
            {
                _logger.LogDebug(ex,
                    "RtmRelayHub: failed to send unionUpdate to caller (connection may be closed)");
            }
        };

        StoreHandler($"union:{unionId}", tenantId, unionId, 0, handler, null);
        await _relay.SubscribeUnionAsync(tenantId, unionId, handler);
    }

    /// <summary>Subscribe to data grid cell updates.</summary>
    public async Task SubscribeGrid(int gridId)
    {
        var tenantId = TenantId;
        Func<IReadOnlyList<GridCellUpdate>, Task> handler = async updates =>
        {
            try { await Clients.Caller.SendAsync("gridUpdate", updates); }
            catch (Exception ex)
            {
                _logger.LogDebug(ex,
                    "RtmRelayHub: failed to send gridUpdate to caller (connection may be closed)");
            }
        };

        StoreHandler($"grid:{gridId}", tenantId, 0, gridId, null, handler);
        await _relay.SubscribeGridAsync(tenantId, gridId, handler);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        foreach (var key in Context.Items.Keys.ToList())
        {
            if (Context.Items[key] is not HubSubscription sub) continue;
            try
            {
                if (sub.UnionHandler != null)
                    await _relay.UnsubscribeUnionAsync(sub.TenantId, sub.UnionId, sub.UnionHandler);
                if (sub.GridHandler != null)
                    await _relay.UnsubscribeGridAsync(sub.TenantId, sub.GridId, sub.GridHandler);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "RtmRelayHub: error unsubscribing on disconnect");
            }
        }
        await base.OnDisconnectedAsync(exception);
    }

    private void StoreHandler(string key, Guid tenantId, int unionId, int gridId,
        Func<UnionStateChange, Task>? unionHandler,
        Func<IReadOnlyList<GridCellUpdate>, Task>? gridHandler)
    {
        Context.Items[key] = new HubSubscription(tenantId, unionId, gridId, unionHandler, gridHandler);
    }

    private sealed record HubSubscription(
        Guid TenantId, int UnionId, int GridId,
        Func<UnionStateChange, Task>? UnionHandler,
        Func<IReadOnlyList<GridCellUpdate>, Task>? GridHandler);
}
