using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IDashboardCategoryRepository
{
    Task<DashboardCategory?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<DashboardCategory>> GetAllAsync(Guid? tenantId, bool isSuperadmin, CancellationToken ct = default);
    Task<IReadOnlyList<DashboardCategory>> GetUsedAsync(Guid? tenantId, bool isSuperadmin, CancellationToken ct = default);
    Task<(IReadOnlyList<DashboardCategory> Items, int Total)> GetPageAsync(
        Guid? tenantId, string? search, bool isSuperadmin,
        int page, int pageSize, CancellationToken ct = default);
    Task<bool> ExistsWithNameAsync(Guid tenantId, string name, Guid? excludeId, CancellationToken ct = default);
    Task<int> GetDashboardCountAsync(Guid categoryId, CancellationToken ct = default);
    Task AddAsync(DashboardCategory category, CancellationToken ct = default);
    void Update(DashboardCategory category);
    void Remove(DashboardCategory category);
}
