using CcDashboard.Core.Enums;

namespace CcDashboard.Core.Interfaces;

public interface IAuditService
{
    Task LogAsync(AuditEventType eventType, Guid? userId, string ipAddress, string userAgent,
        string? detail = null, CancellationToken ct = default);
}
