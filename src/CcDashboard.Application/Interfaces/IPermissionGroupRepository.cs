using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IPermissionGroupRepository
{
    Task<PermissionGroup?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<PermissionGroup>> GetAllByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task<int> CountUsersAsync(Guid permissionGroupId, CancellationToken ct = default);
    Task AddAsync(PermissionGroup group, CancellationToken ct = default);
    void Update(PermissionGroup group);
    void Remove(PermissionGroup group);
}
