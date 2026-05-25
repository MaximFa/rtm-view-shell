using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class NgcSiteRepository(BackendEmulationDbContext db) : INgcSiteRepository
{
    public async Task<IReadOnlyList<NgcSite>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.NgcSites.AsNoTracking().IgnoreQueryFilters()
            .Where(s => tenantId == null || s.TenantId == tenantId)
            .OrderBy(s => s.SiteName)
            .ToListAsync(ct);

    public async Task<NgcSite?> GetByIdAsync(string siteId, Guid tenantId, CancellationToken ct = default)
        => await db.NgcSites.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.SiteId == siteId && s.TenantId == tenantId, ct);

    public async Task AddAsync(NgcSite site, CancellationToken ct = default)
        => await db.NgcSites.AddAsync(site, ct);

    public void Update(NgcSite site) => db.NgcSites.Update(site);
    public void Delete(NgcSite site) => db.NgcSites.Remove(site);
}

public class NgcBusinessUnitRepository(BackendEmulationDbContext db) : INgcBusinessUnitRepository
{
    public async Task<IReadOnlyList<NgcBusinessUnit>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.NgcBusinessUnits.AsNoTracking().IgnoreQueryFilters()
            .Include(b => b.Site)
            .Include(b => b.QueueAssignments)
            .Include(b => b.SupergroupAssignments)
            .Where(b => tenantId == null || b.TenantId == tenantId)
            .OrderBy(b => b.BusinessUnitName)
            .ToListAsync(ct);

    public async Task<NgcBusinessUnit?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default)
        => await db.NgcBusinessUnits.IgnoreQueryFilters()
            .Include(b => b.QueueAssignments)
            .Include(b => b.SupergroupAssignments)
            .FirstOrDefaultAsync(b => b.BusinessUnitId == id && b.TenantId == tenantId, ct);

    public async Task AddAsync(NgcBusinessUnit bu, CancellationToken ct = default)
        => await db.NgcBusinessUnits.AddAsync(bu, ct);

    public void Update(NgcBusinessUnit bu) => db.NgcBusinessUnits.Update(bu);
    public void Delete(NgcBusinessUnit bu) => db.NgcBusinessUnits.Remove(bu);
}

public class NgcSupergroupRepository(BackendEmulationDbContext db) : INgcSupergroupRepository
{
    public async Task<IReadOnlyList<NgcSupergroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.NgcSupergroups.AsNoTracking().IgnoreQueryFilters()
            .Include(s => s.AgentGroupAssignments)
            .Where(s => tenantId == null || s.TenantId == tenantId)
            .OrderBy(s => s.SupergroupName)
            .ToListAsync(ct);

    public async Task<NgcSupergroup?> GetByIdAsync(int id, Guid tenantId, CancellationToken ct = default)
        => await db.NgcSupergroups.IgnoreQueryFilters()
            .Include(s => s.AgentGroupAssignments)
            .FirstOrDefaultAsync(s => s.SupergroupId == id && s.TenantId == tenantId, ct);

    public async Task AddAsync(NgcSupergroup sg, CancellationToken ct = default)
        => await db.NgcSupergroups.AddAsync(sg, ct);

    public void Update(NgcSupergroup sg) => db.NgcSupergroups.Update(sg);
    public void Delete(NgcSupergroup sg) => db.NgcSupergroups.Remove(sg);
}

public class RtsGridMetricRepository(BackendEmulationDbContext db) : IRtsGridMetricRepository
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

public class NgcQueueRepository(BackendEmulationDbContext db) : INgcQueueRepository
{
    public async Task<IReadOnlyList<NgcQueue>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.NgcQueues.AsNoTracking().IgnoreQueryFilters()
            .Where(q => tenantId == null || q.TenantId == tenantId)
            .Where(q => q.IsActive)
            .OrderBy(q => q.Name)
            .ToListAsync(ct);
}

public class NgcAgentGroupRepository(BackendEmulationDbContext db) : INgcAgentGroupRepository
{
    public async Task<IReadOnlyList<NgcAgentGroup>> GetAllByTenantAsync(Guid? tenantId, CancellationToken ct = default)
        => await db.NgcAgentGroups.AsNoTracking().IgnoreQueryFilters()
            .Where(a => tenantId == null || a.TenantId == tenantId)
            .Where(a => a.IsActive)
            .OrderBy(a => a.Name)
            .ToListAsync(ct);
}
