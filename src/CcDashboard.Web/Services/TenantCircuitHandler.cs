using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using Microsoft.AspNetCore.Components.Server.Circuits;

namespace CcDashboard.Web.Services;

/// <summary>
/// Initialises ITenantContext for each Blazor Server SignalR circuit from the
/// authenticated user's tenant_id claim. [ARCH-03, ARCH-07]
/// </summary>
public class TenantCircuitHandler(
    IHttpContextAccessor httpContextAccessor,
    ITenantContext tenantContext,
    ITenantRepository tenantRepository,
    ILogger<TenantCircuitHandler> logger)
    : CircuitHandler
{
    public override async Task OnCircuitOpenedAsync(Circuit circuit, CancellationToken ct)
    {
        if (tenantContext.IsResolved) return;

        // Try to read tenant_id from the current HttpContext (available during initial negotiation)
        var httpContext = httpContextAccessor.HttpContext;
        var tenantIdClaim = httpContext?.User?.FindFirst("tenant_id")?.Value;

        if (Guid.TryParse(tenantIdClaim, out var tenantId))
        {
            var tenant = await tenantRepository.GetByIdAsync(tenantId, ct);
            if (tenant != null)
            {
                tenantContext.Set(tenant.Id, tenant.Slug);
                logger.LogDebug("Circuit {CircuitId}: tenant resolved from claims ({Slug})", circuit.Id, tenant.Slug);
                return;
            }
        }

        logger.LogWarning("Circuit {CircuitId}: could not resolve tenant from claims.", circuit.Id);
        await base.OnCircuitOpenedAsync(circuit, ct);
    }
}
