using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class DashboardCategoryRepository(AppDbContext db) : IDashboardCategoryRepository
{
    public Task<DashboardCategory?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.DashboardCategories.FirstOrDefaultAsync(c => c.Id == id, ct);

    public async Task<IReadOnlyList<DashboardCategory>> GetAllAsync(Guid? tenantId, bool isSuperadmin, CancellationToken ct = default)
    {
        IQueryable<DashboardCategory> q;

        if (isSuperadmin && tenantId == null)
        {
            q = db.DashboardCategories.IgnoreQueryFilters().AsNoTracking();
        }
        else if (isSuperadmin && tenantId.HasValue)
        {
            q = db.DashboardCategories.IgnoreQueryFilters()
                .Where(c => c.TenantId == tenantId.Value)
                .AsNoTracking();
        }
        else
        {
            q = db.DashboardCategories.AsNoTracking();
        }

        return await q.OrderBy(c => c.Name).ToListAsync(ct);
    }

    public async Task<(IReadOnlyList<DashboardCategory> Items, int Total)> GetPageAsync(
        Guid? tenantId, string? search, bool isSuperadmin,
        int page, int pageSize, CancellationToken ct = default)
    {
        IQueryable<DashboardCategory> q;

        if (isSuperadmin && tenantId == null)
        {
            q = db.DashboardCategories.IgnoreQueryFilters().AsNoTracking();
        }
        else if (isSuperadmin && tenantId.HasValue)
        {
            q = db.DashboardCategories.IgnoreQueryFilters()
                .Where(c => c.TenantId == tenantId.Value)
                .AsNoTracking();
        }
        else
        {
            q = db.DashboardCategories.AsNoTracking();
        }

        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(c => EF.Functions.ILike(c.Name, $"%{search}%"));

        var total = await q.CountAsync(ct);
        var items = await q
            .Include(c => c.Tenant)
            .OrderBy(c => c.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return (items, total);
    }

    public Task<bool> ExistsWithNameAsync(Guid tenantId, string name, Guid? excludeId, CancellationToken ct = default)
    {
        var normalizedName = name.Trim().ToLowerInvariant();
        return db.DashboardCategories
            .IgnoreQueryFilters()
            .AnyAsync(c => c.TenantId == tenantId &&
                           c.Name.ToLower() == normalizedName &&
                           (excludeId == null || c.Id != excludeId), ct);
    }

    public Task<int> GetDashboardCountAsync(Guid categoryId, CancellationToken ct = default)
        => db.Dashboards.CountAsync(d => d.CategoryId == categoryId && !d.IsDeleted, ct);

    public Task AddAsync(DashboardCategory category, CancellationToken ct = default)
    {
        db.DashboardCategories.Add(category);
        return Task.CompletedTask;
    }

    public void Update(DashboardCategory category) => db.DashboardCategories.Update(category);

    public void Remove(DashboardCategory category) => db.DashboardCategories.Remove(category);
}
