using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using UUIDNext;

namespace CcDashboard.Infrastructure.BackgroundServices;

/// <summary>
/// Background service that aggregates real-time data into historical intervals.
/// Timers: startup lookback 24h; periodic every 2h with 2h lookback; daily ensure_partitions.
/// Per ARCH-07: creates fresh DI scope per tenant, sets ITenantContext explicitly.
/// Idempotent: DELETE interval-window + INSERT recomputed (re-aggregation safe).
/// </summary>
public class HistoricalAggregationService(
    IServiceScopeFactory scopeFactory,
    ILogger<HistoricalAggregationService> logger) : BackgroundService
{
    private const int IntervalMinutes = 30;
    private const int SlThresholdSec = 20;
    private static readonly TimeSpan StartupLookback = TimeSpan.FromHours(24);
    private static readonly TimeSpan PeriodicLookback = TimeSpan.FromHours(2);
    private static readonly TimeSpan PeriodicInterval = TimeSpan.FromHours(2);
    private static readonly TimeSpan PartitionCheckInterval = TimeSpan.FromDays(1);

    private DateTime _lastPartitionCheck = DateTime.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("HistoricalAggregationService: starting, initial lookback = {Hours}h", StartupLookback.TotalHours);
        await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

        var startupTo = DateTime.UtcNow;
        var startupFrom = startupTo - StartupLookback;
        await RunAggregationAsync(startupFrom, startupTo, stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (DateTime.UtcNow - _lastPartitionCheck > PartitionCheckInterval)
                {
                    await EnsurePartitionsAsync(stoppingToken);
                    _lastPartitionCheck = DateTime.UtcNow;
                }

                var to = DateTime.UtcNow;
                var from = to - PeriodicLookback;
                await RunAggregationAsync(from, to, stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "HistoricalAggregationService: error during aggregation");
            }

            await Task.Delay(PeriodicInterval, stoppingToken);
        }
    }

    private async Task RunAggregationAsync(DateTime from, DateTime to, CancellationToken ct)
    {
        logger.LogInformation("HistoricalAggregationService: aggregating {From:O} to {To:O}", from, to);

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tenants = await db.Tenants.AsNoTracking().Select(t => t.Id).ToListAsync(ct);

        foreach (var tenantId in tenants)
        {
            try
            {
                await AggregateForTenantAsync(tenantId, from, to, ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "HistoricalAggregationService: error for tenant {TenantId}", tenantId);
            }
        }
    }

    private async Task AggregateForTenantAsync(Guid tenantId, DateTime from, DateTime to, CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var tenantContext = scope.ServiceProvider.GetRequiredService<ITenantContext>();
        tenantContext.Set(tenantId, string.Empty);

        var appDb = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var beDb = scope.ServiceProvider.GetRequiredService<BackendEmulationDbContext>();
        var repo = scope.ServiceProvider.GetRequiredService<IHistoricalReportRepository>();

        var fromBucket = FloorToInterval(from);
        var toBucket = FloorToInterval(to).AddMinutes(IntervalMinutes);

        await AggregateQueueIntervalsAsync(tenantId, fromBucket, toBucket, appDb, beDb, repo, ct);
        await AggregateAgentIntervalsAsync(tenantId, fromBucket, toBucket, appDb, beDb, repo, ct);
        await repo.UpsertWatermarkAsync(tenantId, toBucket, ct);

        logger.LogDebug("HistoricalAggregationService: tenant {TenantId} aggregated {From:O} to {To:O}", tenantId, fromBucket, toBucket);
    }

    private async Task AggregateQueueIntervalsAsync(
        Guid tenantId, DateTime from, DateTime to,
        AppDbContext appDb, BackendEmulationDbContext beDb,
        IHistoricalReportRepository repo, CancellationToken ct)
    {
        await repo.DeleteQueueIntervalsAsync(tenantId, from, to, ct);

        var queueLookup = await appDb.Database
            .SqlQueryRaw<QueueLookupRow>(
                """SELECT "Id", "ExternalId" FROM "NGC_Queues" WHERE "TenantId" = {0}""",
                tenantId)
            .ToDictionaryAsync(q => q.ExternalId, q => q.Id, ct);

        var interactions = await beDb.RtsDataInteractions
            .AsNoTracking()
            .Where(i => i.TenantId == tenantId
                     && i.InQueueDateTime >= from
                     && i.InQueueDateTime < to
                     && i.InteractionType == "Call"
                     && i.CallType == "External"
                     && i.Direction == "Incoming")
            .ToListAsync(ct);

        var groups = interactions
            .Where(i => i.InQueueDateTime.HasValue)
            .GroupBy(i => new { IntervalStart = FloorToInterval(i.InQueueDateTime!.Value), i.Workgroup });

        var intervals = new List<HistQueueInterval>();
        var now = DateTime.UtcNow;

        foreach (var g in groups)
        {
            var offered = g.Count();
            var answered = g.Count(i => i.IsAnswered == true);
            var abandoned = g.Count(i => i.IsAbandoned == true);
            var answeredInSl = g.Count(i => i.IsAnswered == true && i.TimeInQueue.HasValue && i.TimeInQueue.Value <= SlThresholdSec);
            var sumWaitAnswered = g.Where(i => i.IsAnswered == true && i.TimeInQueue.HasValue).Sum(i => (long)i.TimeInQueue!.Value);
            var sumTalk = g.Where(i => i.IsAnswered == true && i.TalkTime.HasValue).Sum(i => (long)i.TalkTime!.Value);

            queueLookup.TryGetValue(g.Key.Workgroup, out var queueId);

            intervals.Add(new HistQueueInterval
            {
                Id = Uuid.NewSequential(),
                TenantId = tenantId,
                IntervalStart = g.Key.IntervalStart,
                Workgroup = g.Key.Workgroup,
                QueueId = queueId == Guid.Empty ? null : queueId,
                Offered = offered,
                Answered = answered,
                Abandoned = abandoned,
                AnsweredInSl = answeredInSl,
                SumWaitAnswered = sumWaitAnswered,
                SumTalk = sumTalk,
                CreatedAt = now,
                UpdatedAt = now
            });
        }

        if (intervals.Count > 0)
            await repo.InsertQueueIntervalsAsync(intervals, ct);
    }

    private async Task AggregateAgentIntervalsAsync(
        Guid tenantId, DateTime from, DateTime to,
        AppDbContext appDb, BackendEmulationDbContext beDb,
        IHistoricalReportRepository repo, CancellationToken ct)
    {
        await repo.DeleteAgentIntervalsAsync(tenantId, from, to, ct);

        var statusLogs = await beDb.RtsDataUserStatusLogs
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                     && s.StartTime >= from
                     && s.StartTime < to
                     && s.Duration.HasValue)
            .ToListAsync(ct);

        var interactions = await beDb.RtsDataInteractions
            .AsNoTracking()
            .Where(i => i.TenantId == tenantId
                     && i.AnsweredDateTime >= from
                     && i.AnsweredDateTime < to
                     && i.IsAnswered == true
                     && !string.IsNullOrEmpty(i.UserId))
            .ToListAsync(ct);

        var handledCounts = interactions
            .Where(i => i.AnsweredDateTime.HasValue)
            .GroupBy(i => new { IntervalStart = FloorToInterval(i.AnsweredDateTime!.Value), i.UserId })
            .ToDictionary(g => g.Key, g => g.Count());

        var statusLogsByAgent = statusLogs
            .Where(s => s.StartTime.HasValue && !string.IsNullOrEmpty(s.UserId))
            .GroupBy(s => new { IntervalStart = FloorToInterval(s.StartTime!.Value), s.UserId });

        var intervals = new List<HistAgentInterval>();
        var now = DateTime.UtcNow;

        foreach (var g in statusLogsByAgent)
        {
            var sumAvailable = g.Where(s => s.StatusGroup == "AVAILABLE").Sum(s => s.Duration ?? 0);
            var sumOnphone = g.Where(s => s.StatusGroup == "ONPHONE").Sum(s => s.Duration ?? 0);
            var sumHold = g.Where(s => s.StatusGroup == "ONPHONE" && s.StatusId == "Hold").Sum(s => s.Duration ?? 0);
            var sumPaperwork = g.Where(s => s.StatusGroup == "PAPERWORK").Sum(s => s.Duration ?? 0);
            var sumBreak = g.Where(s => s.StatusGroup == "BREAK").Sum(s => s.Duration ?? 0);
            var sumTraining = g.Where(s => s.StatusGroup == "TRAINING").Sum(s => s.Duration ?? 0);
            var sumUnavailable = g.Where(s => s.StatusGroup == "UNAVAILABLE").Sum(s => s.Duration ?? 0);
            var sumLoggedIn = g.Sum(s => s.Duration ?? 0);

            handledCounts.TryGetValue(new { g.Key.IntervalStart, UserId = g.Key.UserId! }, out var handled);

            intervals.Add(new HistAgentInterval
            {
                Id = Uuid.NewSequential(),
                TenantId = tenantId,
                IntervalStart = g.Key.IntervalStart,
                AgentExternalId = g.Key.UserId!,
                AgentDisplayName = null,
                SumAvailableMs = sumAvailable,
                SumOnphoneMs = sumOnphone,
                SumHoldMs = sumHold,
                SumPaperworkMs = sumPaperwork,
                SumBreakMs = sumBreak,
                SumTrainingMs = sumTraining,
                SumUnavailableMs = sumUnavailable,
                SumLoggedInMs = sumLoggedIn,
                Handled = handled,
                CreatedAt = now,
                UpdatedAt = now
            });
        }

        if (intervals.Count > 0)
            await repo.InsertAgentIntervalsAsync(intervals, ct);
    }

    private async Task EnsurePartitionsAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var repo = scope.ServiceProvider.GetRequiredService<IHistoricalReportRepository>();
        await repo.EnsurePartitionsAsync(monthsBack: 1, monthsAhead: 2, ct);
        logger.LogInformation("HistoricalAggregationService: ensured partitions (back=1, ahead=2)");
    }

    private static DateTime FloorToInterval(DateTime dt)
    {
        var minutes = (dt.Minute / IntervalMinutes) * IntervalMinutes;
        return new DateTime(dt.Year, dt.Month, dt.Day, dt.Hour, minutes, 0, DateTimeKind.Utc);
    }

    private record QueueLookupRow(Guid Id, string ExternalId);
}
