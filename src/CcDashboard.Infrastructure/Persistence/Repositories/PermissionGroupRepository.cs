using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.PermissionGroups;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class PermissionGroupRepository(AppDbContext db) : IPermissionGroupRepository
{
    public Task<PermissionGroup?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.PermissionGroups
             .IgnoreQueryFilters()
             .Include(g => g.MenuPermissions)
             .Include(g => g.DashboardPermissions)
             .Include(g => g.AllowedQueues)
             .Include(g => g.AllowedSkills)
             .Include(g => g.AllowedBusinessUnits)
             .Include(g => g.AllowedSupergroups)
             .FirstOrDefaultAsync(g => g.Id == id, ct);

    public Task<IReadOnlyList<PermissionGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => db.PermissionGroups
             .IgnoreQueryFilters()
             .AsNoTracking()
             .Include(g => g.MenuPermissions)
             .Include(g => g.DashboardPermissions)
             .Include(g => g.AllowedQueues)
             .Include(g => g.AllowedSkills)
             .Include(g => g.AllowedBusinessUnits)
             .Include(g => g.AllowedSupergroups)
             .Where(g => tenantId == null || g.TenantId == tenantId)
             .OrderBy(g => g.Name)
             .ToListAsync(ct)
             .ContinueWith<IReadOnlyList<PermissionGroup>>(t => t.Result);

    public Task<int> CountUsersAsync(Guid permissionGroupId, CancellationToken ct = default)
        => db.Users.CountAsync(u => u.PermissionGroupId == permissionGroupId, ct);

    public Task AddAsync(PermissionGroup group, CancellationToken ct = default)
    {
        db.PermissionGroups.Add(group);
        return Task.CompletedTask;
    }

    public void Update(PermissionGroup group) => db.PermissionGroups.Update(group);
    public void Remove(PermissionGroup group) => db.PermissionGroups.Remove(group);

    public async Task<AvailableEntitiesResult> GetAllEntitiesForTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        var dashboards = await db.Dashboards.IgnoreQueryFilters()
            .Where(d => d.TenantId == tenantId && !d.IsDeleted)
            .OrderBy(d => d.Name)
            .Select(d => new AvailableEntityDto(d.Id, d.Name))
            .ToListAsync(ct);

        var queues = await db.NgcQueues.IgnoreQueryFilters()
            .Where(q => q.TenantId == tenantId && q.IsActive)
            .OrderBy(q => q.Name)
            .Select(q => new AvailableEntityDto(q.Id, q.Name))
            .ToListAsync(ct);

        var agentGroups = await db.NgcAgentGroups.IgnoreQueryFilters()
            .Where(s => s.TenantId == tenantId && s.IsActive)
            .OrderBy(s => s.Name)
            .Select(s => new AvailableEntityDto(s.Id, s.Name))
            .ToListAsync(ct);

        var businessUnits = await db.NgcBusinessUnits.IgnoreQueryFilters()
            .Where(b => b.TenantId == tenantId)
            .OrderBy(b => b.BusinessUnitName)
            .Select(b => new AvailableEntityIntDto(b.BusinessUnitId, b.BusinessUnitName ?? $"BU {b.BusinessUnitId}"))
            .ToListAsync(ct);

        var supergroups = await db.NgcSupergroups.IgnoreQueryFilters()
            .Where(s => s.TenantId == tenantId)
            .OrderBy(s => s.SupergroupName)
            .Select(s => new AvailableEntityIntDto(s.SupergroupId, s.SupergroupName ?? $"SG {s.SupergroupId}"))
            .ToListAsync(ct);

        return new AvailableEntitiesResult(dashboards, queues, agentGroups, businessUnits, supergroups);
    }

    public async Task<AvailableEntitiesResult> GetEntitiesForPermissionGroupAsync(Guid pgId, Guid tenantId, CancellationToken ct = default)
    {
        var dashboardIds = await db.DashboardPermissions.IgnoreQueryFilters()
            .Where(dp => dp.PermissionGroupId == pgId)
            .Select(dp => dp.DashboardId)
            .ToListAsync(ct);

        var dashboards = await db.Dashboards.IgnoreQueryFilters()
            .Where(d => dashboardIds.Contains(d.Id) && !d.IsDeleted)
            .OrderBy(d => d.Name)
            .Select(d => new AvailableEntityDto(d.Id, d.Name))
            .ToListAsync(ct);

        var queueIds = await db.PgQueues.IgnoreQueryFilters()
            .Where(pq => pq.PermissionGroupId == pgId)
            .Select(pq => pq.ObjectId)
            .ToListAsync(ct);

        var queues = await db.NgcQueues.IgnoreQueryFilters()
            .Where(q => q.TenantId == tenantId && queueIds.Contains(q.Id))
            .OrderBy(q => q.Name)
            .Select(q => new AvailableEntityDto(q.Id, q.Name))
            .ToListAsync(ct);

        var skillIds = await db.PgSkills.IgnoreQueryFilters()
            .Where(ps => ps.PermissionGroupId == pgId)
            .Select(ps => ps.ObjectId)
            .ToListAsync(ct);

        var agentGroups = await db.NgcAgentGroups.IgnoreQueryFilters()
            .Where(s => skillIds.Contains(s.Id))
            .OrderBy(s => s.Name)
            .Select(s => new AvailableEntityDto(s.Id, s.Name))
            .ToListAsync(ct);

        var buIds = await db.PgBusinessUnits.IgnoreQueryFilters()
            .Where(pb => pb.PermissionGroupId == pgId)
            .Select(pb => pb.BusinessUnitId)
            .ToListAsync(ct);

        var businessUnits = await db.NgcBusinessUnits.IgnoreQueryFilters()
            .Where(b => b.TenantId == tenantId && buIds.Contains(b.BusinessUnitId))
            .OrderBy(b => b.BusinessUnitName)
            .Select(b => new AvailableEntityIntDto(b.BusinessUnitId, b.BusinessUnitName ?? $"BU {b.BusinessUnitId}"))
            .ToListAsync(ct);

        var sgIds = await db.PgSupergroups.IgnoreQueryFilters()
            .Where(ps => ps.PermissionGroupId == pgId)
            .Select(ps => ps.SupergroupId)
            .ToListAsync(ct);

        var supergroups = await db.NgcSupergroups.IgnoreQueryFilters()
            .Where(s => s.TenantId == tenantId && sgIds.Contains(s.SupergroupId))
            .OrderBy(s => s.SupergroupName)
            .Select(s => new AvailableEntityIntDto(s.SupergroupId, s.SupergroupName ?? $"SG {s.SupergroupId}"))
            .ToListAsync(ct);

        return new AvailableEntitiesResult(dashboards, queues, agentGroups, businessUnits, supergroups);
    }
}
