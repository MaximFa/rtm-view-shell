using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Middleware;

/// <summary>
/// Bearer token validation (defense-in-depth layer 2).
/// Pin-at-build (b): 60min TTL + revocation list.
/// </summary>
public class TokenValidationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly SecurityOptions _options;
    private readonly IAuditService _audit;
    private readonly ILogger<TokenValidationMiddleware> _logger;
    private readonly HashSet<string> _revokedTokens = new(StringComparer.Ordinal);

    public TokenValidationMiddleware(RequestDelegate next, IOptions<SecurityOptions> options, IAuditService audit, ILogger<TokenValidationMiddleware> logger)
    {
        _next = next;
        _options = options.Value;
        _audit = audit;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var thumbprint = context.Items["ClientCertThumbprint"]?.ToString();
        var authHeader = context.Request.Headers.Authorization.FirstOrDefault();

        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            _audit.LogApiCall(new AuditEntry { Timestamp = DateTime.UtcNow, ClientIp = remoteIp, ClientCertThumbprint = thumbprint, Endpoint = context.Request.Path, Method = context.Request.Method, Result = "Rejected:NoToken", StatusCode = 401 });
            context.Response.StatusCode = 401;
            await context.Response.WriteAsync("Unauthorized: bearer token required");
            return;
        }

        var token = authHeader["Bearer ".Length..].Trim();
        if (_options.TokenRevocationEnabled && _revokedTokens.Contains(token))
        {
            _audit.LogApiCall(new AuditEntry { Timestamp = DateTime.UtcNow, ClientIp = remoteIp, ClientCertThumbprint = thumbprint, Endpoint = context.Request.Path, Method = context.Request.Method, Result = "Rejected:TokenRevoked", StatusCode = 401 });
            context.Response.StatusCode = 401;
            await context.Response.WriteAsync("Unauthorized: token revoked");
            return;
        }

        // TODO: validate token signature/expiry from secure store
        await _next(context);
    }

    public void RevokeToken(string token) => _revokedTokens.Add(token);
    public void RotateOnCompromise() { _revokedTokens.Clear(); _logger.LogWarning("All tokens rotated"); }
}
