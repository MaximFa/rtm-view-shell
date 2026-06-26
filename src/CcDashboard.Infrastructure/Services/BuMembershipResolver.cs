using CcDashboard.Application.HistoricalReports;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// Resolves BU membership to concrete filter sets per spec §4.
/// All results are PG-intersected (SF-BI-001).
/// External CC IDs only (IDENT-01/02).
/// Uses IDbContextFactory for parallel-widget isolation.
/// </summary>
public class BuMembershipResolver(
    IDbContextFactory<BackendEmulationDbContext> beFactory,
    ILogger<BuMembershipResolver> logger) : IBuMembershipResolver
{
    public async Task<IReadOnlySet<string>> ResolveQueuesAsync(
        Guid tenantId,
        IReadOnlyList<int> businessUnitIds,
        ReportScope pgScope,
        CancellationToken ct = default)
    {
        if (businessUnitIds.Count == 0)
        {
            logger.LogDebug("BuMembershipResolver.ResolveQueues: no BUs provided, returning empty");
            return new HashSet<string>();
        }

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // BU -> queues via NGC_BusinessUnitQueueClassification (ClassificationId='ALL' per §36)
        var queueIds = await ctx.NgcBusinessUnitQueueClassifications
            .AsNoTracking()
            .Where(bq => businessUnitIds.Contains(bq.BusinessUnitId)
                      && bq.TenantId == tenantId
                      && bq.ClassificationId == "ALL")
            .Select(bq => bq.QueueId)
            .Distinct()
            .ToListAsync(ct);

        logger.LogDebug("BuMembershipResolver.ResolveQueues: BUs [{BuIds}] -> {Count} queues (pre-PG)",
            string.Join(",", businessUnitIds), queueIds.Count);

        // PG-intersection (SF-BI-001)
        var result = IntersectWithPgScope(queueIds, pgScope.AllowedWorkgroups, pgScope.FullScope);

        logger.LogDebug("BuMembershipResolver.ResolveQueues: {Count} queues after PG-intersection", result.Count);
        return result;
    }

    public async Task<IReadOnlySet<string>> ResolveAgentsAsync(
        Guid tenantId,
        IReadOnlyList<int> businessUnitIds,
        AgentReportAxis axis,
        ReportScope pgScope,
        CancellationToken ct = default)
    {
        if (businessUnitIds.Count == 0)
        {
            logger.LogDebug("BuMembershipResolver.ResolveAgents: no BUs provided, returning empty");
            return new HashSet<string>();
        }

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // Step 1: BU -> Supergroups via NGC_BusinessUnitSupergroup
        var supergroupIds = await ctx.NgcBusinessUnitSupergroups
            .AsNoTracking()
            .Where(bs => businessUnitIds.Contains(bs.BusinessUnitId) && bs.TenantId == tenantId)
            .Select(bs => bs.SupergroupId)
            .Distinct()
            .ToListAsync(ct);

        if (supergroupIds.Count == 0)
        {
            logger.LogDebug("BuMembershipResolver.ResolveAgents: no supergroups found for BUs");
            return new HashSet<string>();
        }

        // Step 2: Get SG -> AG mapping
        var sgAgMappings = await ctx.NgcSupergroupAgentgroups
            .AsNoTracking()
            .Where(sag => sag.SupergroupId.HasValue
                       && supergroupIds.Contains(sag.SupergroupId.Value)
                       && sag.TenantId == tenantId
                       && sag.AgentgroupId != null)
            .Select(sag => new { sag.SupergroupId, sag.AgentgroupId })
            .ToListAsync(ct);

        var agentGroupIds = sgAgMappings.Select(m => m.AgentgroupId!).Distinct().ToList();

        if (agentGroupIds.Count == 0)
        {
            logger.LogDebug("BuMembershipResolver.ResolveAgents: no agent groups found");
            return new HashSet<string>();
        }

        // Step 3: AG -> agents via NGC_UserAgentgroup
        var agMembershipList = await ctx.NgcUserAgentgroups
            .AsNoTracking()
            .Where(uag => agentGroupIds.Contains(uag.AgentgroupId)
                       && uag.TenantId == tenantId
                       && uag.UserId != null)
            .Select(uag => new { uag.AgentgroupId, uag.UserId })
            .ToListAsync(ct);

        // Build AG -> members dictionary
        var agMembers = agMembershipList
            .GroupBy(m => m.AgentgroupId!)
            .ToDictionary(
                g => g.Key,
                g => new HashSet<string>(g.Select(m => m.UserId!)));

        HashSet<string> agentSet;

        if (axis == AgentReportAxis.Detail)
        {
            // DETAIL: UNION of all agents across all AGs
            agentSet = new HashSet<string>(agMembershipList.Select(m => m.UserId!));
            logger.LogDebug("BuMembershipResolver.ResolveAgents DETAIL: {Count} agents (pre-PG)", agentSet.Count);
        }
        else
        {
            // CUMULATIVE: ∪_SG ( ∩_AG members(AG) )
            // Per SG: intersect member sets of all AGs in that SG; then union across SGs.
            agentSet = new HashSet<string>();

            var sgToAgs = sgAgMappings
                .GroupBy(m => m.SupergroupId!.Value)
                .ToDictionary(
                    g => g.Key,
                    g => g.Select(m => m.AgentgroupId!).Distinct().ToList());

            foreach (var (sgId, agsInSg) in sgToAgs)
            {
                if (agsInSg.Count == 0) continue;

                // Start with first AG's members, then intersect with the rest
                HashSet<string>? sgAgentSet = null;
                foreach (var agId in agsInSg)
                {
                    if (!agMembers.TryGetValue(agId, out var agSet)) continue;

                    if (sgAgentSet == null)
                        sgAgentSet = new HashSet<string>(agSet);
                    else
                        sgAgentSet.IntersectWith(agSet);
                }

                if (sgAgentSet != null)
                    agentSet.UnionWith(sgAgentSet);
            }

            logger.LogDebug("BuMembershipResolver.ResolveAgents CUMULATIVE: {Count} agents (pre-PG)", agentSet.Count);
        }

        // PG-intersection (SF-BI-001)
        var result = IntersectWithPgScope(agentSet, pgScope.AllowedAgentExternalIds, pgScope.FullScope);

        logger.LogDebug("BuMembershipResolver.ResolveAgents: {Count} agents after PG-intersection", result.Count);
        return result;
    }

    private static HashSet<string> IntersectWithPgScope(
        IEnumerable<string> buSet,
        IReadOnlySet<string> pgAllowed,
        bool fullScope)
    {
        if (fullScope)
            return new HashSet<string>(buSet);

        // Empty PG = DENY (PG-03)
        if (pgAllowed.Count == 0)
            return new HashSet<string>();

        return new HashSet<string>(buSet.Where(pgAllowed.Contains));
    }
}
