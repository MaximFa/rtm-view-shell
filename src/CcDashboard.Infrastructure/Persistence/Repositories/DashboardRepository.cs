using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class DashboardRepository(AppDbContext db) : IDashboardRepository
{
    public Task<Dashboard?> GetByIdAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default)
    {
        var q = bypassTenantFilter
            ? db.Dashboards.IgnoreQueryFilters().Where(d => !d.IsDeleted)
            : db.Dashboards.AsQueryable();

        return q.Include(d => d.Permissions).FirstOrDefaultAsync(d => d.Id == id, ct);
    }

    public Task<Dashboard?> GetByIdWithWidgetsAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default)
    {
        var q = bypassTenantFilter
            ? db.Dashboards.IgnoreQueryFilters().Where(d => !d.IsDeleted)
            : db.Dashboards.AsQueryable();

        return q
            .Include(d => d.Tenant)
            .Include(d => d.Category)
            .Include(d => d.Permissions)
            .Include(d => d.Widgets.Where(w => !w.IsDeleted))
            .FirstOrDefaultAsync(d => d.Id == id, ct);
    }

    public Task<Dashboard?> GetDeletedByIdAsync(Guid id, CancellationToken ct = default)
        => db.Dashboards
            .IgnoreQueryFilters()
            .Where(d => d.IsDeleted && d.Id == id)
            .FirstOrDefaultAsync(ct);

    public async Task<(IReadOnlyList<Dashboard> Items, int Total)> GetPageAsync(
        Guid? tenantId, string? search, DashboardStatus? status, Guid? categoryId, Guid? createdBy, bool? isPublic,
        Guid userId, Guid? pgId, bool isSuperadmin, bool isSuperadminOrAdmin,
        int page, int pageSize, CancellationToken ct = default)
    {
        IQueryable<Dashboard> q;

        if (isSuperadmin && tenantId == null)
        {
            // Superadmin viewing all tenants - bypass GQF
            q = db.Dashboards.IgnoreQueryFilters()
                .Where(d => !d.IsDeleted)
                .AsNoTracking();
        }
        else if (isSuperadmin && tenantId.HasValue)
        {
            // Superadmin viewing specific tenant - bypass GQF, filter by tenant
            q = db.Dashboards.IgnoreQueryFilters()
                .Where(d => !d.IsDeleted && d.TenantId == tenantId.Value)
                .AsNoTracking();
        }
        else
        {
            // Regular user - GQF active
            q = db.Dashboards.AsNoTracking();
        }

        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(d => EF.Functions.ILike(d.Name, $"%{search}%"));
        if (status.HasValue)
            q = q.Where(d => d.Status == status.Value);
        if (categoryId.HasValue)
            q = q.Where(d => d.CategoryId == categoryId.Value);
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
            .Include(d => d.Tenant)
            .Include(d => d.Category)
            .Include(d => d.Widgets.Where(w => !w.IsDeleted))
                .ThenInclude(w => w.CatalogItem)
            .OrderBy(d => d.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return (items, total);
    }

    public async Task<(IReadOnlyList<Dashboard> Items, int Total)> GetDeletedPageAsync(
        Guid tenantId, string? search, int page, int pageSize, CancellationToken ct = default)
    {
        var q = db.Dashboards
            .IgnoreQueryFilters()
            .Where(d => d.TenantId == tenantId && d.IsDeleted)
            .AsNoTracking();

        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(d => EF.Functions.ILike(d.Name, $"%{search}%"));

        var total = await q.CountAsync(ct);
        var items = await q
            .OrderByDescending(d => d.DeletedAt)
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
