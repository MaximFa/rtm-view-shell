using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Historical;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

/// <summary>
/// SF-BI-001: Repository with MANDATORY scope filtering.
/// Non-FullScope queries ALWAYS filter by the provided scope - no bypass possible.
/// Read methods use IDbContextFactory for parallel-widget isolation; write/transaction methods keep shared db.
/// </summary>
public class HistoricalReportRepository(
    AppDbContext db,
    IDbContextFactory<AppDbContext> dbFactory,
    IDbContextFactory<BackendEmulationDbContext> backendFactory) : IHistoricalReportRepository
{
    public async Task<IReadOnlyList<HistQueueInterval>> GetQueueIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        ReportScope scope,
        IReadOnlySet<string> effectiveWorkgroups,
        CancellationToken ct)
    {
        await using var ctx = await dbFactory.CreateDbContextAsync(ct);
        var query = ctx.HistQueueIntervals
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to);

        if (!scope.FullScope)
        {
            if (effectiveWorkgroups.Count == 0)
                return Array.Empty<HistQueueInterval>();

            query = query.Where(x => effectiveWorkgroups.Contains(x.Workgroup));
        }
        else if (effectiveWorkgroups.Count > 0)
        {
            query = query.Where(x => effectiveWorkgroups.Contains(x.Workgroup));
        }

        return await query
            .OrderBy(x => x.IntervalStart)
            .ThenBy(x => x.Workgroup)
            .ToListAsync(ct);
    }

    public async Task<DateTime?> GetLastIntervalStartAsync(
        Guid tenantId,
        ReportDataSet dataSet,
        IReadOnlySet<string> scopedKeys,
        CancellationToken ct)
    {
        // nothing in scope - nothing asked, never "the whole tenant"
        if (scopedKeys.Count == 0)
            return null;

        await using var ctx = await dbFactory.CreateDbContextAsync(ct);
        return dataSet switch
        {
            // (TenantId, IntervalStart[, Workgroup]) index: a backward scan that stops at the first row in scope
            // (measured on 234, .coord/measure/lastday-1107: 7-13 ms)
            ReportDataSet.Queues => await ctx.HistQueueIntervals
                .IgnoreQueryFilters()
                .AsNoTracking()
                .Where(x => x.TenantId == tenantId && scopedKeys.Contains(x.Workgroup))
                .MaxAsync(x => (DateTime?)x.IntervalStart, ct),
            _ => throw new ArgumentOutOfRangeException(nameof(dataSet), dataSet, "Unknown report data set")
        };
    }

    public async Task<IReadOnlyList<HistAgentInterval>> GetAgentIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        ReportScope scope,
        IReadOnlySet<string> effectiveAgentIds,
        CancellationToken ct)
    {
        await using var ctx = await dbFactory.CreateDbContextAsync(ct);
        var query = ctx.HistAgentIntervals
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to);

        if (!scope.FullScope)
        {
            if (effectiveAgentIds.Count == 0)
                return Array.Empty<HistAgentInterval>();

            query = query.Where(x => effectiveAgentIds.Contains(x.AgentExternalId));
        }
        else if (effectiveAgentIds.Count > 0)
        {
            query = query.Where(x => effectiveAgentIds.Contains(x.AgentExternalId));
        }

        return await query
            .OrderBy(x => x.IntervalStart)
            .ThenBy(x => x.AgentExternalId)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyDictionary<string, string>> GetAgentDisplayNamesAsync(
        Guid tenantId,
        IReadOnlySet<string> agentIds,
        CancellationToken ct)
    {
        if (agentIds.Count == 0)
            return new Dictionary<string, string>();

        // Live source, same rule as the aggregator: hist_agent_intervals carried no name at all (0 of 29032 on 234),
        // so the picker reads the name where it lives and is right before any history backfill.
        await using var be = await backendFactory.CreateDbContextAsync(ct);
        return await AgentNameRule.NewestRealNamesAsync(be, tenantId, agentIds, ct);
    }

    public async Task<HistAggregationWatermark?> GetWatermarkAsync(Guid tenantId, CancellationToken ct)
    {
        return await db.HistAggregationWatermarks
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.TenantId == tenantId, ct);
    }

    public async Task UpsertWatermarkAsync(Guid tenantId, DateTime aggregatedThrough, CancellationToken ct)
    {
        var existing = await db.HistAggregationWatermarks
            .FirstOrDefaultAsync(x => x.TenantId == tenantId, ct);

        if (existing is null)
        {
            db.HistAggregationWatermarks.Add(new HistAggregationWatermark
            {
                TenantId = tenantId,
                AggregatedThrough = aggregatedThrough,
                LastRunAt = DateTime.UtcNow
            });
        }
        else
        {
            existing.AggregatedThrough = aggregatedThrough;
            existing.LastRunAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task DeleteQueueIntervalsAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct)
    {
        await db.HistQueueIntervals
            .IgnoreQueryFilters()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to)
            .ExecuteDeleteAsync(ct);
    }

    public async Task DeleteAgentIntervalsAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct)
    {
        await db.HistAgentIntervals
            .IgnoreQueryFilters()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to)
            .ExecuteDeleteAsync(ct);
    }

    public async Task InsertQueueIntervalsAsync(IEnumerable<HistQueueInterval> intervals, CancellationToken ct)
    {
        db.HistQueueIntervals.AddRange(intervals);
        await db.SaveChangesAsync(ct);
    }

    public async Task InsertAgentIntervalsAsync(IEnumerable<HistAgentInterval> intervals, CancellationToken ct)
    {
        db.HistAgentIntervals.AddRange(intervals);
        await db.SaveChangesAsync(ct);
    }

    public async Task EnsurePartitionsAsync(int monthsBack, int monthsAhead, CancellationToken ct)
    {
        await db.Database.ExecuteSqlRawAsync(
            "SELECT fn_hist_ensure_partitions('hist_queue_intervals', {0}, {1})",
            [monthsBack, monthsAhead], ct);

        await db.Database.ExecuteSqlRawAsync(
            "SELECT fn_hist_ensure_partitions('hist_agent_intervals', {0}, {1})",
            [monthsBack, monthsAhead], ct);
    }
}
