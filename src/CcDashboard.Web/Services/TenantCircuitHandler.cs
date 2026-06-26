using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using Microsoft.AspNetCore.Components.Server.Circuits;
using System.Security.Claims;

namespace CcDashboard.Web.Services;

/// <summary>
/// Initialises ITenantContext for each Blazor Server SignalR circuit from the
/// authenticated user's tenant claims. [ARCH-03, ARCH-07]
/// ARCH-02 C1: For Superadmin, reads active_tenant_id; for others, reads tenant_id.
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

        var httpContext = httpContextAccessor.HttpContext;
        if (httpContext?.User?.Identity?.IsAuthenticated != true)
        {
            logger.LogWarning("Circuit {CircuitId}: user not authenticated.", circuit.Id);
            await base.OnCircuitOpenedAsync(circuit, ct);
            return;
        }

        // ARCH-02 C1: Superadmin uses active_tenant_id; others use tenant_id.
        // Role is read from TRUSTED ClaimTypes.Role — never infer from active_tenant_id.
        var role = httpContext.User.FindFirstValue(ClaimTypes.Role);
        var claimName = role == "Superadmin" ? "active_tenant_id" : "tenant_id";
        var tenantIdClaim = httpContext.User.FindFirstValue(claimName);

        if (Guid.TryParse(tenantIdClaim, out var tenantId))
        {
            var tenant = await tenantRepository.GetByIdAsync(tenantId, ct);
            if (tenant != null)
            {
                tenantContext.Set(tenant.Id, tenant.Slug);
                logger.LogDebug("Circuit {CircuitId}: tenant resolved from {Claim} ({Slug})",
                    circuit.Id, claimName, tenant.Slug);
                return;
            }
        }

        logger.LogWarning("Circuit {CircuitId}: could not resolve tenant from claims.", circuit.Id);
        await base.OnCircuitOpenedAsync(circuit, ct);
    }
}
