using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using System.Security.Claims;

namespace CcDashboard.Web.Middleware;

public class TenantResolutionMiddleware(RequestDelegate next, IConfiguration config)
{
    public async Task InvokeAsync(HttpContext ctx, ITenantContext tenantCtx, ITenantRepository tenants)
    {
        var host = ctx.Request.Host.Host;
        var slug = ExtractSlug(host)
                   ?? config["DefaultTenantSlug"];

        if (slug == null)
        {
            await next(ctx);
            return;
        }

        var tenant = await tenants.GetBySlugAsync(slug);
        if (tenant != null && tenant.Status == Domain.Enums.TenantStatus.Active)
        {
            tenantCtx.Set(tenant.Id, tenant.Slug);
        }

        // ARCH-02 C1: Superadmin override — if Role==Superadmin AND active_tenant_id is a valid Active tenant,
        // override the subdomain-resolved tenant. Role is read from the TRUSTED ClaimTypes.Role.
        if (ctx.User?.Identity?.IsAuthenticated == true)
        {
            var role = ctx.User.FindFirstValue(ClaimTypes.Role);
            if (role == "Superadmin")
            {
                var activeClaimValue = ctx.User.FindFirstValue("active_tenant_id");
                if (Guid.TryParse(activeClaimValue, out var activeId))
                {
                    var activeTenant = await tenants.GetByIdAsync(activeId);
                    if (activeTenant != null && activeTenant.Status == Domain.Enums.TenantStatus.Active)
                    {
                        tenantCtx.Set(activeTenant.Id, activeTenant.Slug);
                    }
                }
            }
        }

        await next(ctx);
    }

    private static string? ExtractSlug(string host)
    {
        // e.g. acme.cc-dashboard.local -> "acme"
        // e.g. acme.localhost (dev) -> "acme"
        var parts = host.Split('.');
        return parts.Length >= 2 ? parts[0] : null;
    }
}
