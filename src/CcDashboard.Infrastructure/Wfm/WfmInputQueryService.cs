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
            logger.LogDebug("WfmInputQueryService: no TimeZone mappings for tenant {TenantId}", tenantId);
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

            results[queue] = count;
        }

        return results;
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
