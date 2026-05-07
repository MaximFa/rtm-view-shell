using System.Security.Claims;
using CcDashboard.Application.Interfaces;

namespace CcDashboard.Api.Middleware;

/// <summary>
/// Rejects requests whose JWT JTI is in the Redis revocation list [AUTH-API-05].
/// Must run AFTER UseAuthentication().
/// </summary>
public class JtiRevocationMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx, ICacheService cache)
    {
        if (ctx.User.Identity?.IsAuthenticated == true)
        {
            var jti = ctx.User.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Jti);
            var tenantIdStr = ctx.User.FindFirstValue("tenant_id");

            if (!string.IsNullOrEmpty(jti) && Guid.TryParse(tenantIdStr, out var tenantId))
            {
                var key = $"{tenantId}:revoked_jti:{jti}";
                if (await cache.ExistsAsync(key))
                {
                    ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    await ctx.Response.WriteAsync("Token has been revoked.");
                    return;
                }
            }
        }

        await next(ctx);
    }
}
