using System.Collections.Concurrent;

namespace CcDashboard.Web.Middleware;

/// <summary>
/// Rate limits login attempts per IP address [BFP-02].
/// Max 10 requests per minute per IP to /login POST.
/// </summary>
public class LoginRateLimitMiddleware(RequestDelegate next, ILogger<LoginRateLimitMiddleware> logger)
{
    private static readonly ConcurrentDictionary<string, RateLimitEntry> _entries = new();
    private const int MaxAttempts = 10;
    private static readonly TimeSpan Window = TimeSpan.FromMinutes(1);

    public async Task InvokeAsync(HttpContext ctx)
    {
        // Only rate-limit POST to login endpoints
        if (ctx.Request.Method == "POST" && IsLoginPath(ctx.Request.Path))
        {
            var ip = GetClientIp(ctx);
            var now = DateTime.UtcNow;

            var entry = _entries.AddOrUpdate(
                ip,
                _ => new RateLimitEntry { Count = 1, WindowStart = now },
                (_, existing) =>
                {
                    if (now - existing.WindowStart > Window)
                    {
                        return new RateLimitEntry { Count = 1, WindowStart = now };
                    }
                    existing.Count++;
                    return existing;
                });

            if (entry.Count > MaxAttempts)
            {
                logger.LogWarning("[BFP-02] Rate limit exceeded for IP {Ip} on login endpoint", ip);
                ctx.Response.StatusCode = StatusCodes.Status429TooManyRequests;
                ctx.Response.Headers.RetryAfter = "60";
                await ctx.Response.WriteAsync("Too many login attempts. Please try again later.");
                return;
            }
        }

        await next(ctx);
    }

    private static bool IsLoginPath(PathString path)
    {
        var p = path.Value?.ToLowerInvariant();
        return p is "/login" or "/login/2fa" or "/api/auth/login";
    }

    private static string GetClientIp(HttpContext ctx)
    {
        // Check X-Forwarded-For first (behind reverse proxy)
        var forwarded = ctx.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        if (!string.IsNullOrEmpty(forwarded))
        {
            var ip = forwarded.Split(',').FirstOrDefault()?.Trim();
            if (!string.IsNullOrEmpty(ip))
                return ip;
        }

        return ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    }

    private class RateLimitEntry
    {
        public int Count;
        public DateTime WindowStart;
    }
}
