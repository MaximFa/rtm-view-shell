using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class DashboardRepository(AppDbContext db) : IDashboardRepository
{
    public Task<Dashboard?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.Dashboards.Include(d => d.Permissions).FirstOrDefaultAsync(d => d.Id == id, ct);

    public async Task<(IReadOnlyList<Dashboard> Items, int Total)> GetPageAsync(
        Guid tenantId, string? search, DashboardStatus? status, Guid? createdBy, bool? isPublic,
        Guid userId, Guid? pgId, bool isSuperadminOrAdmin,
        int page, int pageSize, CancellationToken ct = default)
    {
        var q = db.Dashboards.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(d => EF.Functions.ILike(d.Name, $"%{search}%"));
        if (status.HasValue)
            q = q.Where(d => d.Status == status.Value);
        if (createdBy.HasValue)
            q = q.Where(d => d.CreatedByUserId == createdBy.Value);
        if (isPublic.HasValue)
            q = q.Where(d => d.IsPublic == isPublic.Value);

        if (!isSuperadminOrAdmin)
        {
            q = q.Where(d => d.IsPublic ||
                db.DashboardPermissions.Any(p =>
                    p.DashboardId == d.Id && p.PermissionGroupId == pgId && (p.AccessLevel & 1) == 1));
        }

        var total = await q.CountAsync(ct);
        var items = await q
            .OrderBy(d => d.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return (items, total);
    }

    public Task AddAsync(Dashboard dashboard, CancellationToken ct = default)
    {
        db.Dashboards.Add(dashboard);
        return Task.CompletedTask;
    }

    public void Update(Dashboard dashboard) => db.Dashboards.Update(dashboard);

    public void Remove(Dashboard dashboard) => db.Dashboards.Remove(dashboard);
}
