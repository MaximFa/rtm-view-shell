using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Interfaces;
using CcDashboard.Infrastructure.Persistence;

namespace CcDashboard.Infrastructure.Audit;

public class AuditService : IAuditService
{
    private readonly AppDbContext _context;

    public AuditService(AppDbContext context)
    {
        _context = context;
    }

    public async Task LogAsync(
        AuditEventType eventType,
        Guid? userId,
        string ipAddress,
        string userAgent,
        string? detail = null,
        CancellationToken ct = default)
    {
        _context.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            EventType = eventType,
            IpAddress = ipAddress,
            UserAgent = userAgent,
            Detail = detail,
            OccurredAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync(ct);
    }
}
