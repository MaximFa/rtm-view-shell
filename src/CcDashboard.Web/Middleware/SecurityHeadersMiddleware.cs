namespace CcDashboard.Web.Middleware;

/// <summary>
/// Adds security headers to all responses [SEC-05].
/// CSP nonce available via HttpContext.Items["csp-nonce"] for inline scripts/styles.
/// </summary>
public class SecurityHeadersMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        var nonce = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16));
        ctx.Items["csp-nonce"] = nonce;

        ctx.Response.Headers["X-Frame-Options"] = "DENY";
        ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
        ctx.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        ctx.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";

        // [SEC-05] CSP configuration
        // Note: Blazor Server requires 'unsafe-inline' and 'unsafe-eval' for dynamic content.
        // This is a known Blazor limitation — cannot use strict CSP with Blazor Server.
        ctx.Response.Headers["Content-Security-Policy"] =
            $"default-src 'self'; " +
            $"script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +  // Blazor Server requires these
            $"style-src 'self' 'unsafe-inline'; " +
            $"img-src 'self' data: blob:; " +  // blob: for color picker
            $"font-src 'self'; " +
            $"connect-src 'self' ws: wss:; " +
            $"frame-ancestors 'none'; " +
            $"base-uri 'self'; " +
            $"form-action 'self';";

        // [SEC-05] HSTS with preload for production
        if (ctx.Request.IsHttps)
            ctx.Response.Headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload";

        // Remove server fingerprinting headers
        ctx.Response.Headers.Remove("Server");
        ctx.Response.Headers.Remove("X-Powered-By");

        await next(ctx);
    }
}
