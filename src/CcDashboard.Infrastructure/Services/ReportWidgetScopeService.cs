using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// SF-BI-001: Server-side scope resolution for report widgets.
/// SF-BI-002: Out-of-scope entries are dropped and logged (detective control).
/// </summary>
public class ReportWidgetScopeService(
    IReportScopeResolver scopeResolver,
    IBuMembershipResolver buResolver,
    BackendEmulationDbContext beDb,
    ICurrentUserAccessor currentUser,
    ILogger<ReportWidgetScopeService> logger) : IReportWidgetScopeService
{
    public async Task<ReportWidgetScopeResult> ResolveQueueScopeAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        CancellationToken ct = default)
    {
        var pgScope = await scopeResolver.ResolveQueueScopeAsync(ct);

        if (pgScope.FullScope)
        {
            var requestedWorkgroups = await ResolveRequestedWorkgroupsAsync(tenantId, config, ct);
            return new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveWorkgroups = requestedWorkgroups
            };
        }

        if (pgScope.AllowedWorkgroups.Count == 0)
        {
            logger.LogWarning(
                "SF-BI-001 DENY: User {UserId} PG {PgId} has no queue access, widget scope denied",
                currentUser.UserId, currentUser.PermissionGroupId);
            return new ReportWidgetScopeResult { DroppedCount = 0 };
        }

        var requested = await ResolveRequestedWorkgroupsAsync(tenantId, config, ct);
        var effective = new HashSet<string>(requested.Where(pgScope.AllowedWorkgroups.Contains));
        var droppedCount = requested.Count - effective.Count;

        if (droppedCount > 0)
        {
            var droppedSample = requested.Except(effective).Take(5).ToList();
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} queues, " +
                "{DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId,
                requested.Count, droppedCount, string.Join(", ", droppedSample));
        }

        return new ReportWidgetScopeResult
        {
            FullScope = false,
            EffectiveWorkgroups = effective,
            DroppedCount = droppedCount
        };
    }

    public async Task<ReportWidgetScopeResult> ResolveAgentScopeAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        AgentReportAxis axis,
        CancellationToken ct = default)
    {
        var pgScope = await scopeResolver.ResolveAgentScopeAsync(ct);

        if (pgScope.FullScope)
        {
            var requestedAgents = await ResolveRequestedAgentsAsync(tenantId, config, axis, ct);
            return new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveAgentIds = requestedAgents
            };
        }

        if (pgScope.AllowedAgentExternalIds.Count == 0)
        {
            logger.LogWarning(
                "SF-BI-001 DENY: User {UserId} PG {PgId} has no agent access, widget scope denied",
                currentUser.UserId, currentUser.PermissionGroupId);
            return new ReportWidgetScopeResult { DroppedCount = 0 };
        }

        var requested = await ResolveRequestedAgentsAsync(tenantId, config, axis, ct);
        var effective = new HashSet<string>(requested.Where(pgScope.AllowedAgentExternalIds.Contains));
        var droppedCount = requested.Count - effective.Count;

        if (droppedCount > 0)
        {
            var droppedSample = requested.Except(effective).Take(5).ToList();
            logger.LogWarning(
                "SF-BI-002: User {UserId} PG {PgId} requested {RequestedCount} agents, " +
                "{DroppedCount} out-of-scope dropped (sample: {DroppedSample})",
                currentUser.UserId, currentUser.PermissionGroupId,
                requested.Count, droppedCount, string.Join(", ", droppedSample));
        }

        return new ReportWidgetScopeResult
        {
            FullScope = false,
            EffectiveAgentIds = effective,
            DroppedCount = droppedCount
        };
    }

    private async Task<IReadOnlySet<string>> ResolveRequestedWorkgroupsAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        CancellationToken ct)
    {
        if (config.Scope.Mode.Equals("bu", StringComparison.OrdinalIgnoreCase))
        {
            var buIds = config.Scope.BusinessUnitIds ?? Array.Empty<int>();
            return await buResolver.ResolveQueuesAsync(
                tenantId, buIds.ToList(), ReportScope.Full(), ct);
        }

        var queueIds = (config.Scope.QueueIds ?? Array.Empty<Guid>()).ToList();
        var workgroups = await beDb.NgcQueues
            .AsNoTracking()
            .Where(q => queueIds.Contains(q.Id) && q.TenantId == tenantId)
            .Select(q => q.ExternalId)
            .ToListAsync(ct);

        return new HashSet<string>(workgroups);
    }

    private async Task<IReadOnlySet<string>> ResolveRequestedAgentsAsync(
        Guid tenantId,
        ReportWidgetConfig config,
        AgentReportAxis axis,
        CancellationToken ct)
    {
        var buIds = config.Scope.BusinessUnitIds ?? Array.Empty<int>();
        return await buResolver.ResolveAgentsAsync(
            tenantId, buIds.ToList(), axis, ReportScope.Full(), ct);
    }
}
