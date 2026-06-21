using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Historical;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class HistoricalReportRepository(AppDbContext db) : IHistoricalReportRepository
{
    public async Task<IReadOnlyList<HistQueueInterval>> GetQueueIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        IReadOnlyList<string>? workgroups,
        CancellationToken ct)
    {
        var query = db.HistQueueIntervals
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to);

        if (workgroups is { Count: > 0 })
            query = query.Where(x => workgroups.Contains(x.Workgroup));

        return await query
            .OrderBy(x => x.IntervalStart)
            .ThenBy(x => x.Workgroup)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<HistAgentInterval>> GetAgentIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        IReadOnlyList<string>? agentExternalIds,
        CancellationToken ct)
    {
        var query = db.HistAgentIntervals
            .IgnoreQueryFilters()
            .AsNoTracking()
            .Where(x => x.TenantId == tenantId
                     && x.IntervalStart >= from
                     && x.IntervalStart < to);

        if (agentExternalIds is { Count: > 0 })
            query = query.Where(x => agentExternalIds.Contains(x.AgentExternalId));

        return await query
            .OrderBy(x => x.IntervalStart)
            .ThenBy(x => x.AgentExternalId)
            .ToListAsync(ct);
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
