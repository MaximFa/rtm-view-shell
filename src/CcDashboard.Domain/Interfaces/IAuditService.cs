using CcDashboard.Domain.Enums;

namespace CcDashboard.Domain.Interfaces;

public interface IAuditService
{
    Task LogAsync(
        string eventType,
        AuditEventResult result,
        Guid? tenantId = null,
        Guid? userId = null,
        string? userName = null,
        string? ipAddress = null,
        string? userAgent = null,
        object? details = null,
        CancellationToken ct = default);
}
