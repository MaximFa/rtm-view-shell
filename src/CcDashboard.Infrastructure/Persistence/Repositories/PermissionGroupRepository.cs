using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class PermissionGroupRepository(AppDbContext db) : IPermissionGroupRepository
{
    public Task<PermissionGroup?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.PermissionGroups
             .IgnoreQueryFilters()
             .Include(g => g.MenuPermissions)
             .FirstOrDefaultAsync(g => g.Id == id, ct);

    public Task<IReadOnlyList<PermissionGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => db.PermissionGroups
             .IgnoreQueryFilters()
             .AsNoTracking()
             .Include(g => g.MenuPermissions)
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
}
