using CcDashboard.Domain.Domain;

namespace CcDashboard.Domain.Interfaces;

public interface ISiteRepository
{
    Task<IReadOnlyList<Site>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<Site?> GetByIdAsync(string siteId, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(Site site, CancellationToken ct = default);
    void Update(Site site);
    void Delete(Site site);
}

public interface IBusinessUnitRepository
{
    Task<IReadOnlyList<BusinessUnit>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<BusinessUnit?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(BusinessUnit bu, CancellationToken ct = default);
    void Update(BusinessUnit bu);
    void Delete(BusinessUnit bu);
}

public interface IQueueRepository
{
    Task<IReadOnlyList<Queue>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
}

public interface ISupergroupRepository
{
    Task<IReadOnlyList<Supergroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
    Task<Supergroup?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default);
    Task AddAsync(Supergroup sg, CancellationToken ct = default);
    void Update(Supergroup sg);
    void Delete(Supergroup sg);
}

public interface IAgentGroupRepository
{
    Task<IReadOnlyList<AgentGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default);
}

public interface IRtsGridMetricRepository
{
    Task<IReadOnlyList<RtsGridMetric>> GetAllAsync(CancellationToken ct = default);
    Task<RtsGridMetric?> GetByIdAsync(string metricId, CancellationToken ct = default);
    Task AddAsync(RtsGridMetric metric, CancellationToken ct = default);
    void Update(RtsGridMetric metric);
    void Delete(RtsGridMetric metric);
}
