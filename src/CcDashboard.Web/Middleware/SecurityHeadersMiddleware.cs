namespace CcDashboard.Web.Middleware;

public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;

    public SecurityHeadersMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx)
    {
        var h = ctx.Response.Headers;

        // Blazor Server requires unsafe-eval (SignalR) and wss for WebSocket
        h.Append("Content-Security-Policy",
            "default-src 'self'; " +
            "script-src 'self' 'unsafe-eval'; " +
            "style-src 'self' 'unsafe-inline'; " +
            "connect-src 'self' wss: ws:; " +
            "img-src 'self' data:; " +
            "font-src 'self'; " +
            "frame-ancestors 'none';");

        h.Append("X-Content-Type-Options", "nosniff");
        h.Append("Referrer-Policy", "strict-origin-when-cross-origin");
        h.Append("Permissions-Policy", "camera=(), microphone=(), geolocation=()");

        await _next(ctx);
    }
}
