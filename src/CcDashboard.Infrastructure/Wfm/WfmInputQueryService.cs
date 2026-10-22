using System.Collections.Concurrent;
using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// WFM Phase 1: queries λ, AHT, N for Erlang calculations.
/// Bounds are true UTC (the engine stores true UTC since BL-234-INTERACTION-TIME-AHEAD-01). Queues are still grouped by
/// their TimeZone - that grouping now only decides which queues are queried; every group uses the same UTC window.
/// </summary>
public sealed class WfmInputQueryService(
    IDbContextFactory<BackendEmulationDbContext> beFactory,
    IWfmLogGate logGate,
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
        // The store-true-UTC fix has landed (BL-234-INTERACTION-TIME-AHEAD-01): winHi = UtcNow for every partition.
        // Collapsing the partitions into one pass is a separate, behaviour-neutral clean-up, not done here.

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
            // BL-234-INTERACTION-TIME-AHEAD-01: the engine now stores TRUE UTC, so the window is plain UtcNow.
            // (Before, this mirrored the engine's site-local-as-UTC stamp via StampWallNow; that mirror is removed in the
            // same release as the engine fix - with one without the other the window is off by the site offset.)
            var (winLo, winHi) = WindowFor(DateTime.UtcNow, windowMinutes);

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

            // Mixed zones inside one workgroup is a configuration fact, not an event: it stays true
            // until somebody fixes the data, so repeating it every tick buries the rest of the log
            // (measured: 42 lines/min, 1260 in 30 min, more than half the log). Once an hour per
            // queue is enough to keep it visible; a CHANGED dominant zone speaks immediately,
            // because that is new information and the one case worth interrupting for.
            if (wgGroup.Count() > 1 &&
                logGate.ShouldLog($"wfm-mixed-tz:{tenantId}:{wgGroup.Key}", dominant.TimeZone, TimeSpan.FromHours(1)))
            {
                logger.LogWarning(
                    "WfmInputQueryService: workgroup {Workgroup} has mixed TimeZones ({ZoneCount} distinct), using dominant {Tz}. "
                  + "Repeats of this line are suppressed for an hour unless the dominant zone changes.",
                    wgGroup.Key, wgGroup.Count(), dominant.TimeZone);
            }
        }

        _tzCache[tenantId] = (DateTime.UtcNow, map);
        return map;
    }

    /// <summary>
    /// The [winLo, winHi) bounds compared with RTSData_Interaction.InQueueDateTime / AnsweredDateTime, which hold
    /// true UTC (BL-234-INTERACTION-TIME-AHEAD-01). Public so the contract is testable: winHi = now in UTC, no zone shift.
    /// </summary>
    public static (DateTime WinLo, DateTime WinHi) WindowFor(DateTime utcNow, int windowMinutes)
    {
        var hi = utcNow.Kind == DateTimeKind.Utc ? utcNow : utcNow.ToUniversalTime();
        return (hi.AddMinutes(-windowMinutes), hi);
    }

    // Helper record types for SqlQueryRaw
    private record LambdaRow(string Queue, double LambdaPerHour);
    private record AhtRow(string Queue, double AhtSec);
}
