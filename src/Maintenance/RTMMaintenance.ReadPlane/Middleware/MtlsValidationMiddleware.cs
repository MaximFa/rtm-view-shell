using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Middleware;

public class MtlsValidationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly HashSet<string> _allowedThumbprints;
    private readonly IAuditService _audit;
    private readonly ILogger<MtlsValidationMiddleware> _logger;

    public MtlsValidationMiddleware(RequestDelegate next, IOptions<SecurityOptions> options, IAuditService audit, ILogger<MtlsValidationMiddleware> logger)
    {
        _next = next;
        _audit = audit;
        _logger = logger;
        _allowedThumbprints = options.Value.AllowedClientThumbprints.Select(t => t.Replace(" ", "").ToUpperInvariant()).ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var clientCert = await context.Connection.GetClientCertificateAsync();

        if (clientCert == null)
        {
            _logger.LogWarning("No client certificate from {RemoteIp}", remoteIp);
            _audit.LogApiCall(new AuditEntry { Timestamp = DateTime.UtcNow, ClientIp = remoteIp, Endpoint = context.Request.Path, Method = context.Request.Method, Result = "Rejected:NoCert", StatusCode = 401 });
            context.Response.StatusCode = 401;
            await context.Response.WriteAsync("Unauthorized: client certificate required");
            return;
        }

        var thumbprint = clientCert.Thumbprint.ToUpperInvariant();
        if (!_allowedThumbprints.Contains(thumbprint))
        {
            _logger.LogWarning("Cert {Thumbprint} not in allow-list from {RemoteIp}", thumbprint, remoteIp);
            _audit.LogApiCall(new AuditEntry { Timestamp = DateTime.UtcNow, ClientIp = remoteIp, ClientCertThumbprint = thumbprint, Endpoint = context.Request.Path, Method = context.Request.Method, Result = "Rejected:CertNotAllowed", StatusCode = 403 });
            context.Response.StatusCode = 403;
            await context.Response.WriteAsync("Forbidden: certificate not in allow-list");
            return;
        }

        context.Items["ClientCertThumbprint"] = thumbprint;
        await _next(context);
    }
}
