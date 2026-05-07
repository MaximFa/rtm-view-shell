using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using System.Text.Json;
using UUIDNext;

namespace CcDashboard.Infrastructure.Audit;

public class AuditService(AuditDbContext db, IDateTimeProvider clock) : IAuditService
{
    public async Task LogAsync(
        string eventType, AuditEventResult result, Guid? tenantId = null, Guid? userId = null,
        string? userName = null, string? ipAddress = null, string? userAgent = null,
        object? details = null, CancellationToken ct = default)
    {
        var log = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            UserId = userId,
            UserName = userName ?? string.Empty,
            EventType = eventType,
            EventResult = result,
            IpAddress = ipAddress,
            UserAgent = userAgent,
            Details = details is null ? null : JsonSerializer.Serialize(details),
            CreatedAt = clock.UtcNow,
        };
        db.AuditLogs.Add(log);
        await db.SaveChangesAsync(ct);
    }
}
