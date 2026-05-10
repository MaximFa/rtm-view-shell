using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;

namespace CcDashboard.Application.Interfaces;

public interface IDashboardRepository
{
    Task<Dashboard?> GetByIdAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default);
    Task<Dashboard?> GetByIdWithWidgetsAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default);
    Task<Dashboard?> GetDeletedByIdAsync(Guid id, CancellationToken ct = default);
    Task<(IReadOnlyList<Dashboard> Items, int Total)> GetPageAsync(
        Guid? tenantId, string? search, DashboardStatus? status, Guid? categoryId, Guid? createdBy, bool? isPublic,
        Guid userId, Guid? pgId, bool isSuperadmin, bool isSuperadminOrAdmin,
        int page, int pageSize, CancellationToken ct = default);
    Task<(IReadOnlyList<Dashboard> Items, int Total)> GetDeletedPageAsync(
        Guid tenantId, string? search, int page, int pageSize, CancellationToken ct = default);
    Task AddAsync(Dashboard dashboard, CancellationToken ct = default);
    void Update(Dashboard dashboard);
    void Remove(Dashboard dashboard);
}
