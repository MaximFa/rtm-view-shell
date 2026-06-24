using System.Diagnostics;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Middleware;

public class AuditMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IAuditService _audit;

    public AuditMiddleware(RequestDelegate next, IAuditService audit) { _next = next; _audit = audit; }

    public async Task InvokeAsync(HttpContext context)
    {
        var sw = Stopwatch.StartNew();
        var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var thumbprint = context.Items["ClientCertThumbprint"]?.ToString();

        try { await _next(context); }
        finally
        {
            sw.Stop();
            _audit.LogApiCall(new AuditEntry
            {
                Timestamp = DateTime.UtcNow,
                ClientIp = remoteIp,
                ClientCertThumbprint = thumbprint,
                Endpoint = context.Request.Path,
                Method = context.Request.Method,
                Parameters = context.Request.QueryString.Value,
                Result = context.Response.StatusCode < 400 ? "Success" : "Error",
                StatusCode = context.Response.StatusCode,
                Duration = sw.Elapsed
            });
        }
    }
}
