using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Audit;
using CcDashboard.Infrastructure.Audit;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class AuditLogRepository(AuditDbContext db) : IAuditLogRepository
{
    public async Task<(IReadOnlyList<AuditLogDto> Items, int Total)> GetPageAsync(
        Guid? tenantId,
        string? eventType,
        string? result,
        DateTime? from,
        DateTime? to,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        var q = db.AuditLogs.AsNoTracking();

        if (tenantId.HasValue)
            q = q.Where(l => l.TenantId == tenantId);
        if (!string.IsNullOrEmpty(eventType))
            q = q.Where(l => l.EventType == eventType);
        if (!string.IsNullOrEmpty(result))
            q = q.Where(l => l.EventResult.ToString() == result);
        if (from.HasValue)
            q = q.Where(l => l.CreatedAt >= from.Value);
        if (to.HasValue)
            q = q.Where(l => l.CreatedAt <= to.Value);

        var total = await q.CountAsync(ct);
        var items = await q
            .OrderByDescending(l => l.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(l => new AuditLogDto(
                l.Id, l.TenantId, l.UserId, l.UserName,
                l.EventType, l.EventResult.ToString(),
                l.IpAddress, l.Details, l.CreatedAt))
            .ToListAsync(ct);

        return (items, total);
    }

    public async Task<IReadOnlyList<string>> GetDistinctEventTypesAsync(Guid? tenantId, CancellationToken ct = default)
    {
        var q = db.AuditLogs.AsNoTracking();
        if (tenantId.HasValue)
            q = q.Where(l => l.TenantId == tenantId);

        return await q
            .Select(l => l.EventType)
            .Distinct()
            .OrderBy(t => t)
            .ToListAsync(ct);
    }
}
