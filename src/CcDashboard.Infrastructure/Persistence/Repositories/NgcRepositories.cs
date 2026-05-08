using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class SiteRepository(AppDbContext db) : ISiteRepository
{
    public async Task<IReadOnlyList<Site>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.Sites.AsNoTracking().IgnoreQueryFilters()
            .Where(s => tenantId == null || s.TenantId == tenantId)
            .OrderBy(s => s.SiteName)
            .ToListAsync(ct);

    public async Task<Site?> GetByIdAsync(string siteId, Guid tenantId, CancellationToken ct = default)
        => await db.Sites.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.SiteId == siteId && s.TenantId == tenantId, ct);

    public async Task AddAsync(Site site, CancellationToken ct = default)
        => await db.Sites.AddAsync(site, ct);

    public void Update(Site site) => db.Sites.Update(site);
    public void Delete(Site site) => db.Sites.Remove(site);
}

public class BusinessUnitRepository(AppDbContext db) : IBusinessUnitRepository
{
    public async Task<IReadOnlyList<BusinessUnit>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.BusinessUnits.AsNoTracking().IgnoreQueryFilters()
            .Include(b => b.Site)
            .Include(b => b.QueueAssignments)
            .Include(b => b.SupergroupAssignments)
            .Where(b => tenantId == null || b.TenantId == tenantId)
            .OrderBy(b => b.BusinessUnitName)
            .ToListAsync(ct);

    public async Task<BusinessUnit?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default)
        => await db.BusinessUnits.IgnoreQueryFilters()
            .Include(b => b.QueueAssignments)
            .Include(b => b.SupergroupAssignments)
            .FirstOrDefaultAsync(b => b.BusinessUnitId == id && b.TenantId == tenantId, ct);

    public async Task AddAsync(BusinessUnit bu, CancellationToken ct = default)
        => await db.BusinessUnits.AddAsync(bu, ct);

    public void Update(BusinessUnit bu) => db.BusinessUnits.Update(bu);
    public void Delete(BusinessUnit bu) => db.BusinessUnits.Remove(bu);
}

public class QueueRepository(AppDbContext db) : IQueueRepository
{
    public async Task<IReadOnlyList<Queue>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.Queues.AsNoTracking().IgnoreQueryFilters()
            .Where(q => tenantId == null || q.TenantId == tenantId)
            .OrderBy(q => q.Name ?? q.QueueId)
            .ToListAsync(ct);
}

public class SupergroupRepository(AppDbContext db) : ISupergroupRepository
{
    public async Task<IReadOnlyList<Supergroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.Supergroups.AsNoTracking().IgnoreQueryFilters()
            .Include(s => s.AgentGroupAssignments)
            .Where(s => tenantId == null || s.TenantId == tenantId)
            .OrderBy(s => s.SupergroupName)
            .ToListAsync(ct);

    public async Task<Supergroup?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default)
        => await db.Supergroups.IgnoreQueryFilters()
            .Include(s => s.AgentGroupAssignments)
            .FirstOrDefaultAsync(s => s.SupergroupId == id && s.TenantId == tenantId, ct);

    public async Task AddAsync(Supergroup sg, CancellationToken ct = default)
        => await db.Supergroups.AddAsync(sg, ct);

    public void Update(Supergroup sg) => db.Supergroups.Update(sg);
    public void Delete(Supergroup sg) => db.Supergroups.Remove(sg);
}

public class AgentGroupRepository(AppDbContext db) : IAgentGroupRepository
{
    public async Task<IReadOnlyList<AgentGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.AgentGroups.AsNoTracking().IgnoreQueryFilters()
            .Where(a => tenantId == null || a.TenantId == tenantId)
            .OrderBy(a => a.Name ?? a.AgentGroupId)
            .ToListAsync(ct);
}

public class RtsGridMetricRepository(AppDbContext db) : IRtsGridMetricRepository
{
    public async Task<IReadOnlyList<RtsGridMetric>> GetAllAsync(CancellationToken ct = default)
        => await db.RtsGridMetrics.AsNoTracking()
            .OrderBy(m => m.MetricId)
            .ToListAsync(ct);

    public async Task<RtsGridMetric?> GetByIdAsync(string metricId, CancellationToken ct = default)
        => await db.RtsGridMetrics.FirstOrDefaultAsync(m => m.MetricId == metricId, ct);

    public async Task AddAsync(RtsGridMetric metric, CancellationToken ct = default)
        => await db.RtsGridMetrics.AddAsync(metric, ct);

    public void Update(RtsGridMetric metric) => db.RtsGridMetrics.Update(metric);
    public void Delete(RtsGridMetric metric) => db.RtsGridMetrics.Remove(metric);
}
