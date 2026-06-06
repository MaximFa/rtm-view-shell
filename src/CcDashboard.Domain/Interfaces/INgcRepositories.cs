using CcDashboard.Domain.Domain;

namespace CcDashboard.Domain.Interfaces;

public interface INgcSiteRepository
{
    Task<IReadOnlyList<NgcSite>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<NgcSite?> GetByIdAsync(string siteId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(NgcSite site, CancellationToken ct = default);
    void Update(NgcSite site);
    void Delete(NgcSite site);
}

public interface INgcBusinessUnitRepository
{
    Task<IReadOnlyList<NgcBusinessUnit>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<NgcBusinessUnit?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(NgcBusinessUnit bu, CancellationToken ct = default);
    void Update(NgcBusinessUnit bu);
    void Delete(NgcBusinessUnit bu);
}

public interface INgcSupergroupRepository
{
    Task<IReadOnlyList<NgcSupergroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<NgcSupergroup?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(NgcSupergroup sg, CancellationToken ct = default);
    void Update(NgcSupergroup sg);
    void Delete(NgcSupergroup sg);
}

public interface IRtsGridMetricRepository
{
    Task<IReadOnlyList<RtsGridMetric>> GetAllAsync(CancellationToken ct = default);
    Task<IReadOnlyList<(RtsGridMetric Metric, RtsGridMetricTranslation? Translation)>> GetAllWithTranslationAsync(string locale, CancellationToken ct = default);
    Task<RtsGridMetric?> GetByIdAsync(string metricId, CancellationToken ct = default);
    Task AddAsync(RtsGridMetric metric, CancellationToken ct = default);
    void Update(RtsGridMetric metric);
    void Delete(RtsGridMetric metric);
}

public interface INgcQueueRepository
{
    Task<IReadOnlyList<NgcQueue>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
}

public interface INgcAgentGroupRepository
{
    Task<IReadOnlyList<NgcAgentGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
}
