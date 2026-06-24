using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;
using System.Net;

namespace RTMMaintenance.ReadPlane.Middleware;

public class IpAllowListMiddleware
{
    private readonly RequestDelegate _next;
    private readonly HashSet<IPAddress> _allowedIps;
    private readonly IAuditService _audit;
    private readonly ILogger<IpAllowListMiddleware> _logger;

    public IpAllowListMiddleware(RequestDelegate next, IOptions<SecurityOptions> options, IAuditService audit, ILogger<IpAllowListMiddleware> logger)
    {
        _next = next;
        _audit = audit;
        _logger = logger;
        _allowedIps = options.Value.AllowedIpAddresses.Select(IPAddress.Parse).ToHashSet();
        if (_allowedIps.Count == 0) { _allowedIps.Add(IPAddress.Loopback); _allowedIps.Add(IPAddress.IPv6Loopback); }
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var remoteIp = context.Connection.RemoteIpAddress;
        if (remoteIp == null || !_allowedIps.Contains(remoteIp))
        {
            _logger.LogWarning("Rejected IP {RemoteIp}", remoteIp);
            _audit.LogApiCall(new AuditEntry { Timestamp = DateTime.UtcNow, ClientIp = remoteIp?.ToString() ?? "unknown", Endpoint = context.Request.Path, Method = context.Request.Method, Result = "Rejected:IP", StatusCode = 403 });
            context.Response.StatusCode = 403;
            await context.Response.WriteAsync("Forbidden: IP not allowed");
            return;
        }
        await _next(context);
    }
}
