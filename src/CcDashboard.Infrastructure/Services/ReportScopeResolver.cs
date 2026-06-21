using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// SF-BI-001: Resolves PG-based security scope for historical reports.
/// Superadmin gets full scope; others get PG-filtered scope only.
/// </summary>
public class ReportScopeResolver(
    AppDbContext appDb,
    BackendEmulationDbContext beDb,
    ICurrentUserAccessor currentUser,
    ILogger<ReportScopeResolver> logger) : IReportScopeResolver
{
    public async Task<ReportScope> ResolveQueueScopeAsync(CancellationToken ct = default)
    {
        if (currentUser.Role == "Superadmin")
            return ReportScope.Full();

        var pgId = currentUser.PermissionGroupId;
        var tenantId = currentUser.TenantId;

        if (pgId is null || tenantId is null)
        {
            logger.LogWarning("ReportScopeResolver: user {UserId} has no PG or TenantId, returning empty scope", currentUser.UserId);
            return ReportScope.Empty();
        }

        var allowedQueueIds = await appDb.PgQueues
            .AsNoTracking()
            .Where(pq => pq.PermissionGroupId == pgId.Value && pq.TenantId == tenantId.Value)
            .Select(pq => pq.ObjectId)
            .ToListAsync(ct);

        if (allowedQueueIds.Count == 0)
        {
            logger.LogDebug("ReportScopeResolver: PG {PgId} has no queue assignments, returning empty scope", pgId);
            return ReportScope.Empty();
        }

        var allowedWorkgroups = await beDb.NgcQueues
            .AsNoTracking()
            .Where(q => allowedQueueIds.Contains(q.Id) && q.TenantId == tenantId.Value)
            .Select(q => q.ExternalId)
            .ToListAsync(ct);

        logger.LogDebug("ReportScopeResolver: resolved {Count} workgroups for PG {PgId}", allowedWorkgroups.Count, pgId);

        return new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = new HashSet<string>(allowedWorkgroups)
        };
    }

    public async Task<ReportScope> ResolveAgentScopeAsync(CancellationToken ct = default)
    {
        if (currentUser.Role == "Superadmin")
            return ReportScope.Full();

        var pgId = currentUser.PermissionGroupId;
        var tenantId = currentUser.TenantId;

        if (pgId is null || tenantId is null)
        {
            logger.LogWarning("ReportScopeResolver: user {UserId} has no PG or TenantId, returning empty scope", currentUser.UserId);
            return ReportScope.Empty();
        }

        var allowedSupergroupIds = await appDb.PgSupergroups
            .AsNoTracking()
            .Where(ps => ps.PermissionGroupId == pgId.Value && ps.TenantId == tenantId.Value)
            .Select(ps => ps.SupergroupId)
            .ToListAsync(ct);

        var allowedBuIds = await appDb.PgBusinessUnits
            .AsNoTracking()
            .Where(pb => pb.PermissionGroupId == pgId.Value && pb.TenantId == tenantId.Value)
            .Select(pb => pb.BusinessUnitId)
            .ToListAsync(ct);

        if (allowedSupergroupIds.Count == 0 && allowedBuIds.Count == 0)
        {
            logger.LogDebug("ReportScopeResolver: PG {PgId} has no supergroup/BU assignments, returning empty scope", pgId);
            return ReportScope.Empty();
        }

        var supergroupsFromBus = await beDb.NgcBusinessUnitSupergroups
            .AsNoTracking()
            .Where(bus => allowedBuIds.Contains(bus.BusinessUnitId) && bus.TenantId == tenantId.Value)
            .Select(bus => bus.SupergroupId)
            .ToListAsync(ct);

        var allSupergroupIds = allowedSupergroupIds.Concat(supergroupsFromBus).Distinct().ToList();

        var agentGroupIds = await beDb.NgcSupergroupAgentgroups
            .AsNoTracking()
            .Where(sag => sag.SupergroupId.HasValue && allSupergroupIds.Contains(sag.SupergroupId.Value) && sag.TenantId == tenantId.Value)
            .Select(sag => sag.AgentgroupId)
            .Where(id => id != null)
            .Distinct()
            .ToListAsync(ct);

        var agentExternalIds = await beDb.NgcUserAgentgroups
            .AsNoTracking()
            .Where(uag => agentGroupIds.Contains(uag.AgentgroupId) && uag.TenantId == tenantId.Value)
            .Select(uag => uag.UserId)
            .Where(id => id != null)
            .Distinct()
            .ToListAsync(ct);

        logger.LogDebug("ReportScopeResolver: resolved {Count} agent external IDs for PG {PgId}", agentExternalIds.Count, pgId);

        return new ReportScope
        {
            FullScope = false,
            AllowedAgentExternalIds = new HashSet<string>(agentExternalIds!)
        };
    }
}
