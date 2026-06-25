using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class ReportScreenRepository(AppDbContext db) : IReportScreenRepository
{
    public async Task<ReportScreen?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        return await db.ReportScreens
            .Include(s => s.Category)
            .Include(s => s.Permissions)
            .FirstOrDefaultAsync(s => s.Id == id, ct);
    }

    public async Task<ReportScreen?> GetByIdWithWidgetsAsync(Guid id, CancellationToken ct = default)
    {
        return await db.ReportScreens
            .Include(s => s.Category)
            .Include(s => s.Widgets)
            .Include(s => s.Permissions)
            .FirstOrDefaultAsync(s => s.Id == id, ct);
    }

    public async Task<ReportScreen?> GetByIdWithWidgetsAndSchedulesAsync(Guid id, CancellationToken ct = default)
    {
        return await db.ReportScreens
            .Include(s => s.Category)
            .Include(s => s.Widgets)
            .Include(s => s.Permissions)
            .Include(s => s.Schedules)
            .FirstOrDefaultAsync(s => s.Id == id, ct);
    }

    public async Task<(IReadOnlyList<ReportScreen> Items, int Total)> GetPageAsync(
        Guid tenantId,
        string? search,
        Guid? categoryId,
        ReportScreenStatus? status,
        bool? isPublic,
        Guid userId,
        Guid? pgId,
        bool isSuperadmin,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        var query = db.ReportScreens
            .Include(s => s.Category)
            .Include(s => s.Permissions)
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId);

        // PG-scoped: return screens where user's PG has View OR IsPublic (unless Superadmin)
        if (!isSuperadmin && pgId.HasValue)
        {
            query = query.Where(s =>
                s.IsPublic ||
                s.Permissions.Any(p => p.PermissionGroupId == pgId.Value && (p.AccessLevel & 1) != 0));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(s => s.Name.ToLower().Contains(term));
        }

        if (categoryId.HasValue)
            query = query.Where(s => s.CategoryId == categoryId.Value);

        if (status.HasValue)
            query = query.Where(s => s.Status == status.Value);

        if (isPublic.HasValue)
            query = query.Where(s => s.IsPublic == isPublic.Value);

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(s => s.UpdatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return (items, total);
    }

    public async Task<IReadOnlyList<ReportCategory>> GetCategoriesAsync(Guid tenantId, CancellationToken ct = default)
    {
        return await db.ReportCategories
            .AsNoTracking()
            .Where(c => c.TenantId == tenantId && c.IsActive)
            .OrderBy(c => c.Name)
            .ToListAsync(ct);
    }

    public async Task<(IReadOnlyList<ReportScreen> Items, int Total)> GetDeletedPageAsync(
        Guid tenantId,
        string? search,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        var query = db.ReportScreens
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId && s.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(s => s.Name.ToLower().Contains(term));
        }

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(s => s.DeletedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return (items, total);
    }

    public async Task<int> GetUserAccessLevelAsync(
        Guid reportScreenId,
        Guid? pgId,
        bool isPublic,
        bool isSuperadmin,
        CancellationToken ct = default)
    {
        if (isSuperadmin)
            return 7; // Full

        if (!pgId.HasValue)
            return isPublic ? 1 : 0; // View only if public; otherwise denied

        var permission = await db.ReportPermissions
            .AsNoTracking()
            .FirstOrDefaultAsync(p =>
                p.ReportScreenId == reportScreenId &&
                p.PermissionGroupId == pgId.Value, ct);

        // If explicit permission exists, use it; otherwise View-only if public
        return permission?.AccessLevel ?? (isPublic ? 1 : 0);
    }

    public async Task AddAsync(ReportScreen screen, CancellationToken ct = default)
    {
        await db.ReportScreens.AddAsync(screen, ct);
    }

    public void Update(ReportScreen screen)
    {
        db.ReportScreens.Update(screen);
    }

    public void UpdateWidget(ReportWidget widget)
    {
        db.ReportWidgets.Update(widget);
    }

    public async Task AddWidgetAsync(ReportWidget widget, CancellationToken ct = default)
    {
        await db.ReportWidgets.AddAsync(widget, ct);
    }

    public async Task<ReportScreen?> GetByIdForPurgeAsync(Guid id, Guid tenantId, CancellationToken ct = default)
    {
        return await db.ReportScreens
            .IgnoreQueryFilters()
            .Include(s => s.Widgets)
            .Include(s => s.Permissions)
            .Include(s => s.Schedules)
            .FirstOrDefaultAsync(s => s.Id == id && s.TenantId == tenantId, ct);
    }

    public async Task PurgeAsync(ReportScreen screen, CancellationToken ct = default)
    {
        // Explicit cascade-agnostic removal: children first, then parent
        // IgnoreQueryFilters needed because widgets have !IsDeleted GQF too
        var widgets = await db.ReportWidgets
            .IgnoreQueryFilters()
            .Where(w => w.ReportScreenId == screen.Id)
            .ToListAsync(ct);
        db.ReportWidgets.RemoveRange(widgets);

        var permissions = await db.ReportPermissions
            .Where(p => p.ReportScreenId == screen.Id)
            .ToListAsync(ct);
        db.ReportPermissions.RemoveRange(permissions);

        var schedules = await db.ReportSchedules
            .Where(s => s.ReportScreenId == screen.Id)
            .ToListAsync(ct);
        db.ReportSchedules.RemoveRange(schedules);

        db.ReportScreens.Remove(screen);
    }
}
