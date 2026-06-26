using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;

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
