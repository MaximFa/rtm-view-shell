using System.Collections.Concurrent;
using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// WFM Phase 1: queries λ, AHT, N for Erlang calculations.
/// DBA-LOCKED FRAME (14:22): offset from interaction's OWN TimeZone column, app-side bounds.
/// Mark: -- DBA-FRAME: INTERIM (collapses to ONE global one-pass when store-true-UTC fix lands).
/// </summary>
public sealed class WfmInputQueryService(
    IDbContextFactory<BackendEmulationDbContext> beFactory,
    ILogger<WfmInputQueryService> logger) : IWfmInputQueryService
{
    // Cached Workgroup -> TimeZone mapping per tenant (refresh every 5 min)
    private readonly ConcurrentDictionary<Guid, (DateTime CachedAt, Dictionary<string, string> Map)> _tzCache = new();
    private static readonly TimeSpan TzCacheTtl = TimeSpan.FromMinutes(5);

    // Cached BU agent pool per tenant (§36a resolution, refresh every 5 min)
    private readonly ConcurrentDictionary<Guid, (DateTime CachedAt, Dictionary<int, HashSet<string>> BuAgentPools)> _buAgentPoolCache = new();
    private static readonly TimeSpan BuAgentPoolCacheTtl = TimeSpan.FromMinutes(5);

    /// <inheritdoc/>
    public async Task<IReadOnlyDictionary<string, (double LambdaPerHour, double AhtSec)>> GetLambdaAndAhtAsync(
        Guid tenantId,
        int windowMinutes,
        CancellationToken ct = default)
    {
        // -- DBA-FRAME: INTERIM -- collapses to ONE global one-pass (winHi=UtcNow, no per-TZ partition)
        // when the backlogged store-true-UTC fix lands — tag for removal.

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // Step 1: Get/refresh Workgroup->TimeZone map
        var tzMap = await GetOrRefreshTzMapAsync(tenantId, ctx, ct);
        if (tzMap.Count == 0)
        {
            // Zero mappings means lambda and AHT are skipped for EVERY queue of this tenant.
            // Warning, not Debug: on the server Debug is not emitted, so today this path is silent.
            logger.LogWarning(
                "WfmInputQueryService: no Workgroup->TimeZone mappings for tenant {TenantId} — "
              + "lambda and AHT are skipped for ALL queues this tick", tenantId);
            return new Dictionary<string, (double, double)>();
        }

        // Step 2: Group workgroups by distinct TimeZone for partitioned queries
        var tzPartitions = tzMap
            .GroupBy(kv => kv.Value)
            .ToDictionary(g => g.Key, g => g.Select(kv => kv.Key).ToList());

        var results = new Dictionary<string, (double LambdaPerHour, double AhtSec)>();

        // Step 3: For each TZ partition, compute app-side bounds + query
        foreach (var (tz, workgroups) in tzPartitions)
        {
            // C1 PARITY: StampWallNow mirrors RTM/RTM/IDInteraction.getLocalDateTime EXACTLY
            var wallNow = StampWallNow(tz);
            var winHi = DateTime.SpecifyKind(wallNow, DateTimeKind.Utc);
            var winLo = winHi.AddMinutes(-windowMinutes);

            // λ query: SARGable on ix_rtsint_wfm_inq (bare InQueueDateTime range)
            // Scenario A: no exclusion — short-abandon + callback INCLUDED
            var lambdaSql = @"
                SELECT i.""Workgroup"" AS Queue,
                       COALESCE(COUNT(*)::double precision / @winMin * 60.0, 0) AS LambdaPerHour
                FROM public.""RTSData_Interaction"" i
                WHERE i.""TenantId"" = @tenant
                  AND i.""Workgroup"" = ANY(@wgList)
                  AND i.""Direction"" = 'Incoming'
                  AND i.""InteractionType"" IN ('Call', 'Callback')
                  AND i.""CallType"" = 'External'
                  AND i.""InQueueDateTime"" >= @winLo
                  AND i.""InQueueDateTime"" < @winHi
                GROUP BY i.""Workgroup""";

            var lambdaRows = await ctx.Database
                .SqlQueryRaw<LambdaRow>(lambdaSql,
                    new Npgsql.NpgsqlParameter("@tenant", tenantId),
                    new Npgsql.NpgsqlParameter("@wgList", workgroups.ToArray()),
                    new Npgsql.NpgsqlParameter("@winMin", windowMinutes),
                    new Npgsql.NpgsqlParameter("@winLo", winLo),
                    new Npgsql.NpgsqlParameter("@winHi", winHi))
                .ToListAsync(ct);

            // AHT query: SARGable on ix_rtsint_wfm_ans (partial on AnsweredDateTime)
            var ahtSql = @"
                SELECT i.""Workgroup"" AS Queue,
                       COALESCE(AVG(NULLIF(i.""TalkTime"", 0))::double precision, 0) AS AhtSec
                FROM public.""RTSData_Interaction"" i
                WHERE i.""TenantId"" = @tenant
                  AND i.""Workgroup"" = ANY(@wgList)
                  AND i.""Direction"" = 'Incoming'
                  AND i.""InteractionType"" IN ('Call', 'Callback')
                  AND i.""CallType"" = 'External'
                  AND i.""IsAnswered"" = true
                  AND i.""IsInQueue"" = false
                  AND i.""AnsweredDateTime"" >= @winLo
                  AND i.""AnsweredDateTime"" < @winHi
                GROUP BY i.""Workgroup""";

            var ahtRows = await ctx.Database
                .SqlQueryRaw<AhtRow>(ahtSql,
                    new Npgsql.NpgsqlParameter("@tenant", tenantId),
                    new Npgsql.NpgsqlParameter("@wgList", workgroups.ToArray()),
                    new Npgsql.NpgsqlParameter("@winLo", winLo),
                    new Npgsql.NpgsqlParameter("@winHi", winHi))
                .ToListAsync(ct);

            // Merge lambda + AHT per queue
            var lambdaDict = lambdaRows.ToDictionary(r => r.Queue, r => r.LambdaPerHour);
            var ahtDict = ahtRows.ToDictionary(r => r.Queue, r => r.AhtSec);

            foreach (var wg in workgroups)
            {
                var lambda = lambdaDict.GetValueOrDefault(wg, 0);
                var aht = ahtDict.GetValueOrDefault(wg, 0);
                results[wg] = (lambda, aht);
            }
        }

        return results;
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyDictionary<string, int>> GetServingAgentCountsAsync(
        Guid tenantId,
        IReadOnlyList<string> servingStateGroups,
        CancellationToken ct = default)
    {
        if (servingStateGroups.Count == 0)
            return new Dictionary<string, int>();

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // Step 1: Get all queues for tenant (from BU queue classifications)
        var queues = await ctx.NgcBusinessUnitQueueClassifications
            .AsNoTracking()
            .Where(bq => bq.TenantId == tenantId && bq.ClassificationId == "ALL")
            .Select(bq => bq.QueueId)
            .Distinct()
            .ToListAsync(ct);

        if (queues.Count == 0)
            return new Dictionary<string, int>();

        // Step 2: For each queue, get BU -> SG -> AG -> agents (§36a resolution)
        // Then count those currently in serving state groups
        var results = new Dictionary<string, int>();

        // Get BU -> Queue mappings
        var buQueueMappings = await ctx.NgcBusinessUnitQueueClassifications
            .AsNoTracking()
            .Where(bq => bq.TenantId == tenantId && bq.ClassificationId == "ALL")
            .Select(bq => new { bq.BusinessUnitId, bq.QueueId })
            .ToListAsync(ct);

        var busByQueue = buQueueMappings
            .GroupBy(m => m.QueueId)
            .ToDictionary(g => g.Key, g => g.Select(m => m.BusinessUnitId).Distinct().ToList());

        // Get BU -> SG mappings
        var allBuIds = busByQueue.Values.SelectMany(x => x).Distinct().ToList();
        var buSgMappings = await ctx.NgcBusinessUnitSupergroups
            .AsNoTracking()
            .Where(bs => allBuIds.Contains(bs.BusinessUnitId) && bs.TenantId == tenantId)
            .Select(bs => new { bs.BusinessUnitId, bs.SupergroupId })
            .ToListAsync(ct);

        var sgsByBu = buSgMappings
            .GroupBy(m => m.BusinessUnitId)
            .ToDictionary(g => g.Key, g => g.Select(m => m.SupergroupId).Distinct().ToList());

        // Get SG -> AG mappings
        var allSgIds = sgsByBu.Values.SelectMany(x => x).Distinct().ToList();
        var sgAgMappings = await ctx.NgcSupergroupAgentgroups
            .AsNoTracking()
            .Where(sag => sag.SupergroupId.HasValue && allSgIds.Contains(sag.SupergroupId.Value) && sag.TenantId == tenantId)
            .Select(sag => new { sag.SupergroupId, sag.AgentgroupId })
            .ToListAsync(ct);

        var agsBySg = sgAgMappings
            .GroupBy(m => m.SupergroupId!.Value)
            .ToDictionary(g => g.Key, g => g.Select(m => m.AgentgroupId).Where(id => id != null).Select(id => id!).Distinct().ToList());

        // Get AG -> User (agent) mappings
        var allAgIds = agsBySg.Values.SelectMany(x => x).Distinct().ToList();  // List<string>
        var agUserMappings = await ctx.NgcUserAgentgroups
            .AsNoTracking()
            .Where(uag => uag.AgentgroupId != null && allAgIds.Contains(uag.AgentgroupId) && uag.TenantId == tenantId && uag.UserId != null)
            .Select(uag => new { uag.AgentgroupId, uag.UserId })
            .ToListAsync(ct);

        var usersByAg = agUserMappings
            .Where(m => m.AgentgroupId != null)
            .GroupBy(m => m.AgentgroupId!)
            .ToDictionary(g => g.Key, g => new HashSet<string>(g.Select(m => m.UserId!)));

        // Step 3: For each queue, resolve agents per §36a (AGENT-RES-01: SG=AND, BU=OR)
        // Distinct StatusGroup values present in THIS TENANT's data. Computed at most once per call
        // and only if some queue actually reports N=0 - see the branch below for why it is needed
        // and why it must not be per-queue.
        List<string>? tenantStatusGroups = null;

        foreach (var queue in queues)
        {
            var busForQueue = busByQueue.GetValueOrDefault(queue, new List<int>());
            var allAgentsForQueue = new HashSet<string>();

            foreach (var buId in busForQueue)
            {
                var sgsForBu = sgsByBu.GetValueOrDefault(buId, new List<int>());

                foreach (var sgId in sgsForBu)
                {
                    var agsForSg = agsBySg.GetValueOrDefault(sgId, new List<string>());
                    if (agsForSg.Count == 0) continue;

                    // SG = AND: intersect all AG members within this SG
                    HashSet<string>? sgAgents = null;
                    foreach (var agId in agsForSg)
                    {
                        var agMembers = usersByAg.GetValueOrDefault(agId, new HashSet<string>());
                        if (sgAgents == null)
                            sgAgents = new HashSet<string>(agMembers);
                        else
                            sgAgents.IntersectWith(agMembers);
                    }

                    // BU = OR: union SG results
                    if (sgAgents != null)
                        allAgentsForQueue.UnionWith(sgAgents);
                }
            }

            if (allAgentsForQueue.Count == 0)
            {
                results[queue] = 0;
                continue;
            }

            // Step 4: Count agents in serving state groups (current snapshot)
            // SARGable on ix_rtsus_wfm
            var agentList = allAgentsForQueue.ToArray();
            var servingGroups = servingStateGroups.ToArray();

            var countSql = @"
                SELECT COUNT(DISTINCT us.""UserId"")::int AS ""Value""
                FROM public.""RTSData_UserStatus"" us
                WHERE us.""TenantId"" = @tenant
                  AND us.""StatusGroup"" = ANY(@servingGroups)
                  AND us.""UserId"" = ANY(@agentList)";

            var count = await ctx.Database
                .SqlQueryRaw<int>(countSql,
                    new Npgsql.NpgsqlParameter("@tenant", tenantId),
                    new Npgsql.NpgsqlParameter("@servingGroups", servingGroups),
                    new Npgsql.NpgsqlParameter("@agentList", agentList))
                .FirstOrDefaultAsync(ct);

            if (count == 0 && agentList.Length > 0)
            {
                // The roster is NOT empty, yet nobody counts as serving. Two different situations
                // hide behind the same zero and only one needs a human:
                //   - the configured names do not occur in this tenant's data at all -> misconfigured;
                //   - they do occur, nobody is in them right now -> an idle shift.
                // The comparison must be against the TENANT's values, not against these agents':
                // over the same agentList the count query already answers that question, so an
                // intersection taken there is empty whenever count == 0 and the test would be
                // vacuous. Measured and recorded as PR234-V4-WFM-N0-WARN-01.
                tenantStatusGroups ??= await ctx.Database
                    .SqlQueryRaw<string>(@"
                        SELECT DISTINCT us.""StatusGroup"" AS ""Value""
                        FROM public.""RTSData_UserStatus"" us
                        WHERE us.""TenantId"" = @tenant
                          AND us.""StatusGroup"" IS NOT NULL",
                        new Npgsql.NpgsqlParameter("@tenant", tenantId))
                    .ToListAsync(ct);

                // Ordinal, to match the count query's own comparison: StatusGroup = ANY(@servingGroups)
                // is exact, byte for byte. A case-insensitive test here would call the 13.10 casing
                // mismatch an overlap and silence the one Warning worth keeping.
                var configuredNamesExistInTenant = tenantStatusGroups
                    .Intersect(servingGroups, StringComparer.Ordinal)
                    .Any();

                if (!configuredNamesExistInTenant)
                {
                    logger.LogWarning(
                        "WfmInputQueryService: N=0 for queue {Queue} while roster has {AgentCount} agents, "
                      + "and NONE of the configured serving groups occurs anywhere in this tenant's data. "
                      + "Configured serving groups = [{Configured}]; StatusGroup values present for tenant = [{Actual}]",
                        queue, agentList.Length,
                        string.Join(", ", servingGroups),
                        string.Join(", ", tenantStatusGroups));
                }
                else
                {
                    // Legitimate "nobody on the line". One line, no lists: this fires on every quiet
                    // tick and must stay cheap.
                    logger.LogDebug(
                        "WfmInputQueryService: N=0 for queue {Queue}, roster {AgentCount} agents, configured groups present in tenant data",
                        queue, agentList.Length);
                }
            }

            results[queue] = count;
        }

        return results;
    }

    /// <inheritdoc/>
    public async Task<int> GetBuServingAgentCountAsync(
        Guid tenantId,
        int businessUnitId,
        IReadOnlyList<string> servingStateGroups,
        CancellationToken ct = default)
    {
        if (servingStateGroups.Count == 0)
            return 0;

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // Get or refresh the BU agent pool cache
        var buAgentPools = await GetOrRefreshBuAgentPoolsAsync(tenantId, ctx, ct);

        if (!buAgentPools.TryGetValue(businessUnitId, out var agentPool) || agentPool.Count == 0)
            return 0;

        // Count agents in serving state groups
        var agentList = agentPool.ToArray();
        var servingGroups = servingStateGroups.ToArray();

        var countSql = @"
            SELECT COUNT(DISTINCT us.""UserId"")::int AS ""Value""
            FROM public.""RTSData_UserStatus"" us
            WHERE us.""TenantId"" = @tenant
              AND us.""StatusGroup"" = ANY(@servingGroups)
              AND us.""UserId"" = ANY(@agentList)";

        var count = await ctx.Database
            .SqlQueryRaw<int>(countSql,
                new Npgsql.NpgsqlParameter("@tenant", tenantId),
                new Npgsql.NpgsqlParameter("@servingGroups", servingGroups),
                new Npgsql.NpgsqlParameter("@agentList", agentList))
            .FirstOrDefaultAsync(ct);

        return count;
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<BuInfo>> GetActiveBusAsync(Guid tenantId, CancellationToken ct = default)
    {
        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // Get all BUs for tenant
        var bus = await ctx.NgcBusinessUnits
            .AsNoTracking()
            .Where(bu => bu.TenantId == tenantId)
            .Select(bu => new { bu.BusinessUnitId, bu.BusinessUnitName })
            .ToListAsync(ct);

        if (bus.Count == 0)
            return Array.Empty<BuInfo>();

        // Get BU -> Queue mappings
        var buQueueMappings = await ctx.NgcBusinessUnitQueueClassifications
            .AsNoTracking()
            .Where(bq => bq.TenantId == tenantId && bq.ClassificationId == "ALL")
            .Select(bq => new { bq.BusinessUnitId, bq.QueueId })
            .ToListAsync(ct);

        var queuesByBu = buQueueMappings
            .GroupBy(m => m.BusinessUnitId)
            .ToDictionary(g => g.Key, g => g.Select(m => m.QueueId).Distinct().ToList());

        return bus
            .Select(bu => new BuInfo(
                bu.BusinessUnitId,
                bu.BusinessUnitName ?? $"BU-{bu.BusinessUnitId}",
                queuesByBu.GetValueOrDefault(bu.BusinessUnitId, new List<string>()) as IReadOnlyList<string>))
            .ToList();
    }

    /// <summary>
    /// Get or refresh the BU -> Agent pool mapping (§36a resolution).
    /// Cached for 5 minutes since membership changes slowly.
    /// </summary>
    private async Task<Dictionary<int, HashSet<string>>> GetOrRefreshBuAgentPoolsAsync(
        Guid tenantId,
        BackendEmulationDbContext ctx,
        CancellationToken ct)
    {
        // Check cache
        if (_buAgentPoolCache.TryGetValue(tenantId, out var cached) &&
            DateTime.UtcNow - cached.CachedAt < BuAgentPoolCacheTtl)
        {
            return cached.BuAgentPools;
        }

        // Build BU -> Agent pool using §36a resolution
        var buAgentPools = new Dictionary<int, HashSet<string>>();

        // Get all BUs for tenant
        var allBuIds = await ctx.NgcBusinessUnits
            .AsNoTracking()
            .Where(bu => bu.TenantId == tenantId)
            .Select(bu => bu.BusinessUnitId)
            .ToListAsync(ct);

        if (allBuIds.Count == 0)
        {
            _buAgentPoolCache[tenantId] = (DateTime.UtcNow, buAgentPools);
            return buAgentPools;
        }

        // Get BU -> SG mappings
        var buSgMappings = await ctx.NgcBusinessUnitSupergroups
            .AsNoTracking()
            .Where(bs => allBuIds.Contains(bs.BusinessUnitId) && bs.TenantId == tenantId)
            .Select(bs => new { bs.BusinessUnitId, bs.SupergroupId })
            .ToListAsync(ct);

        var sgsByBu = buSgMappings
            .GroupBy(m => m.BusinessUnitId)
            .ToDictionary(g => g.Key, g => g.Select(m => m.SupergroupId).Distinct().ToList());

        // Get SG -> AG mappings
        var allSgIds = sgsByBu.Values.SelectMany(x => x).Distinct().ToList();
        var sgAgMappings = await ctx.NgcSupergroupAgentgroups
            .AsNoTracking()
            .Where(sag => sag.SupergroupId.HasValue && allSgIds.Contains(sag.SupergroupId.Value) && sag.TenantId == tenantId)
            .Select(sag => new { sag.SupergroupId, sag.AgentgroupId })
            .ToListAsync(ct);

        var agsBySg = sgAgMappings
            .GroupBy(m => m.SupergroupId!.Value)
            .ToDictionary(g => g.Key, g => g.Select(m => m.AgentgroupId).Where(id => id != null).Select(id => id!).Distinct().ToList());

        // Get AG -> User (agent) mappings
        var allAgIds = agsBySg.Values.SelectMany(x => x).Distinct().ToList();
        var agUserMappings = await ctx.NgcUserAgentgroups
            .AsNoTracking()
            .Where(uag => uag.AgentgroupId != null && allAgIds.Contains(uag.AgentgroupId) && uag.TenantId == tenantId && uag.UserId != null)
            .Select(uag => new { uag.AgentgroupId, uag.UserId })
            .ToListAsync(ct);

        var usersByAg = agUserMappings
            .Where(m => m.AgentgroupId != null)
            .GroupBy(m => m.AgentgroupId!)
            .ToDictionary(g => g.Key, g => new HashSet<string>(g.Select(m => m.UserId!)));

        // Resolve agents per BU using §36a (AGENT-RES-01: SG=AND, BU=OR)
        foreach (var buId in allBuIds)
        {
            var allAgentsForBu = new HashSet<string>();
            var sgsForBu = sgsByBu.GetValueOrDefault(buId, new List<int>());

            foreach (var sgId in sgsForBu)
            {
                var agsForSg = agsBySg.GetValueOrDefault(sgId, new List<string>());
                if (agsForSg.Count == 0) continue;

                // SG = AND: intersect all AG members within this SG
                HashSet<string>? sgAgents = null;
                foreach (var agId in agsForSg)
                {
                    var agMembers = usersByAg.GetValueOrDefault(agId, new HashSet<string>());
                    if (sgAgents == null)
                        sgAgents = new HashSet<string>(agMembers);
                    else
                        sgAgents.IntersectWith(agMembers);
                }

                // BU = OR: union SG results
                if (sgAgents != null)
                    allAgentsForBu.UnionWith(sgAgents);
            }

            buAgentPools[buId] = allAgentsForBu;
        }

        _buAgentPoolCache[tenantId] = (DateTime.UtcNow, buAgentPools);
        return buAgentPools;
    }

    /// <summary>
    /// Get or refresh the Workgroup -> TimeZone mapping for a tenant.
    /// Mixed TZ within one Workgroup: pick dominant + WARN; NO per-row fallback.
    /// </summary>
    private async Task<Dictionary<string, string>> GetOrRefreshTzMapAsync(
        Guid tenantId,
        BackendEmulationDbContext ctx,
        CancellationToken ct)
    {
        // Check cache
        if (_tzCache.TryGetValue(tenantId, out var cached) &&
            DateTime.UtcNow - cached.CachedAt < TzCacheTtl)
        {
            return cached.Map;
        }

        // Query distinct Workgroup, TimeZone pairs
        var tzData = await ctx.RtsDataInteractions
            .AsNoTracking()
            .Where(i => i.TenantId == tenantId && i.TimeZone != null)
            .GroupBy(i => new { i.Workgroup, i.TimeZone })
            .Select(g => new { g.Key.Workgroup, g.Key.TimeZone, Count = g.Count() })
            .ToListAsync(ct);

        var map = new Dictionary<string, string>();

        var byWorkgroup = tzData.GroupBy(x => x.Workgroup);
        foreach (var wgGroup in byWorkgroup)
        {
            var dominant = wgGroup.OrderByDescending(x => x.Count).First();
            map[wgGroup.Key] = dominant.TimeZone ?? string.Empty;

            // Warn if mixed TZ within workgroup
            if (wgGroup.Count() > 1)
            {
                logger.LogWarning("WfmInputQueryService: workgroup {Workgroup} has mixed TimeZones, using dominant {Tz}",
                    wgGroup.Key, dominant.TimeZone);
            }
        }

        _tzCache[tenantId] = (DateTime.UtcNow, map);
        return map;
    }

    /// <summary>
    /// C1 PARITY: VERBATIM mirror of RTM/RTM/IDInteraction.getLocalDateTime (lines 253-288).
    /// Edge cases: null/empty/whitespace -> UtcNow (offset 0); offset-form parse (TrimStart+/-, TimeSpan.TryParse,
    /// Negate if negative); IANA/Windows id -> FindSystemTimeZoneById.GetUtcOffset; ANY exception -> UtcNow.
    /// wallNow = UtcNow + offset (NOT ConvertTimeFromUtc).
    /// </summary>
    private static DateTime StampWallNow(string tz)
    {
        DateTime localTime = DateTime.UtcNow;

        if (string.IsNullOrWhiteSpace(tz))
            return localTime;

        try
        {
            TimeSpan offset;

            // Try offset format first: "+03:00", "-05:00", "03:00"
            string cleaned = tz.Trim();
            bool negative = cleaned.StartsWith("-");
            string stripped = cleaned.TrimStart('+').TrimStart('-');

            if (TimeSpan.TryParse(stripped, out offset))
            {
                if (negative) offset = offset.Negate();
            }
            else
            {
                // Fallback: Windows / IANA timezone ID (e.g. "Israel", "UTC")
                var tzi = TimeZoneInfo.FindSystemTimeZoneById(tz);
                offset = tzi.GetUtcOffset(DateTime.UtcNow);
            }

            localTime = localTime.Add(offset);
        }
        catch
        {
            // Unknown timezone format — return UTC silently (offset 0)
        }

        return localTime;
    }

    // Helper record types for SqlQueryRaw
    private record LambdaRow(string Queue, double LambdaPerHour);
    private record AhtRow(string Queue, double AhtSec);
}
