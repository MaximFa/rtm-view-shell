using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Wfm;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// WFM Phase 1: 30-second hosted loop that computes Erlang metrics for all active queues.
/// Per ARCH-07: creates DI scope per tenant, sets ITenantContext explicitly.
/// Writes WfmSnapshot to IWfmSnapshotStore (in-mem hand-off to widgets). NO SignalR.
/// </summary>
public sealed class WfmRealtimeLoop(
    IServiceScopeFactory scopeFactory,
    IWfmSnapshotStore snapshotStore,
    ILogger<WfmRealtimeLoop> logger) : BackgroundService
{
    private static readonly TimeSpan LoopInterval = TimeSpan.FromSeconds(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("WfmRealtimeLoop: starting, interval = {Interval}s", LoopInterval.TotalSeconds);

        // Initial delay to let app warm up
        await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);

        using var timer = new PeriodicTimer(LoopInterval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await RunTickAsync(stoppingToken);
        }
    }

    private async Task RunTickAsync(CancellationToken ct)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            // Get all active tenants with WFM enabled
            var tenants = await db.TenantSettings
                .AsNoTracking()
                .Where(ts => ts.WfmEnableRealtime)
                .Select(ts => ts.TenantId)
                .ToListAsync(ct);

            foreach (var tenantId in tenants)
            {
                try
                {
                    await ProcessTenantAsync(tenantId, ct);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // Per-tenant try/catch: one tenant's failure must NOT kill the loop
                    logger.LogError(ex, "WfmRealtimeLoop: error for tenant {TenantId}", tenantId);
                }
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogError(ex, "WfmRealtimeLoop: error during tick");
        }
    }

    private async Task ProcessTenantAsync(Guid tenantId, CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();

        // ARCH-07: set tenant context before any DB operations
        var tenantContext = scope.ServiceProvider.GetRequiredService<ITenantContext>();
        tenantContext.Set(tenantId, string.Empty);

        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var inputService = scope.ServiceProvider.GetRequiredService<IWfmInputQueryService>();
        var erlang = scope.ServiceProvider.GetRequiredService<IErlangCalculatorService>();

        // Load tenant settings
        var settings = await db.TenantSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(ts => ts.TenantId == tenantId, ct);

        if (settings == null)
        {
            logger.LogWarning("WfmRealtimeLoop: no TenantSettings for {TenantId}", tenantId);
            return;
        }

        var windowMin = settings.WfmWindowMinutes;
        var slTargetPct = settings.WfmSlTargetPct;
        var slThresholdSec = settings.WfmSlThresholdSec;
        var trunkCapacity = settings.WfmTrunkCapacity;
        var servingGroups = settings.WfmServingStateGroups ?? Array.Empty<string>();

        // Get λ and AHT for all queues
        var lambdaAht = await inputService.GetLambdaAndAhtAsync(tenantId, windowMin, ct);

        // Get N for all queues
        var agentCounts = await inputService.GetServingAgentCountsAsync(tenantId, servingGroups, ct);

        var asOfUtc = DateTime.UtcNow;

        // Process each queue
        var allQueues = lambdaAht.Keys.Union(agentCounts.Keys).Distinct();

        foreach (var queueId in allQueues)
        {
            var (lambda, aht) = lambdaAht.GetValueOrDefault(queueId, (0, 0));
            var nActual = agentCounts.GetValueOrDefault(queueId, 0);

            // Determine state
            string state;
            if (aht <= 0 || nActual <= 0)
            {
                state = WfmSnapshot.StateNoData;
            }
            else
            {
                var trafficA = erlang.TrafficIntensity(lambda, aht);
                if (nActual <= trafficA)
                    state = WfmSnapshot.StateOverloaded;
                else
                    state = WfmSnapshot.StateOk;
            }

            // Compute Erlang metrics
            var trafficAComputed = aht > 0 ? erlang.TrafficIntensity(lambda, aht) : 0;
            var pWaitC = erlang.ErlangC(nActual, trafficAComputed);
            var predictedSlPct = erlang.PredictedSl(nActual, trafficAComputed, aht, slThresholdSec);
            var predictedAsaSec = erlang.PredictedAsaSec(nActual, trafficAComputed, aht);
            var (reqAgents, reqCapped) = erlang.RequiredAgents(trafficAComputed, aht, slThresholdSec, slTargetPct / 100.0);
            var erlangBPct = erlang.ErlangB(trunkCapacity, trafficAComputed) * 100.0;
            var occupancyPct = erlang.OccupancyPct(trafficAComputed, nActual);
            var understaffPct = erlang.UnderstaffPct(reqAgents, nActual);
            var staffVariance = erlang.StaffVariance(nActual, reqAgents);

            // Build snapshot
            var inputs = new WfmInputs(lambda, aht, nActual, WrapIncluded: false);
            var erlangMetrics = new WfmErlang(
                TrafficA: trafficAComputed,
                PWaitC: pWaitC,
                PredictedSlPct: predictedSlPct.HasValue ? predictedSlPct.Value * 100.0 : null,
                PredictedAsaSec: predictedAsaSec,
                RequiredAgents: reqAgents,
                RequiredCapped: reqCapped,
                ErlangBPct: erlangBPct,
                OccupancyPct: occupancyPct,
                UnderstaffPct: understaffPct,
                StaffVariance: staffVariance);

            // RAG thresholds (basic defaults for now; WfmThresholds JSON parsing in follow-up)
            var rag = ComputeRag(erlangMetrics, slTargetPct);

            var snapshot = new WfmSnapshot(
                TenantId: tenantId,
                QueueId: queueId,
                AsOfUtc: asOfUtc,
                WindowMin: windowMin,
                Inputs: inputs,
                Erlang: erlangMetrics,
                State: state,
                Rag: rag);

            snapshotStore.Set(snapshot);
        }

        logger.LogDebug("WfmRealtimeLoop: processed {QueueCount} queues for tenant {TenantId}",
            allQueues.Count(), tenantId);
    }

    /// <summary>
    /// Basic RAG computation. Full WfmThresholds JSON override in follow-up.
    /// </summary>
    private static IReadOnlyDictionary<string, string> ComputeRag(WfmErlang e, double slTargetPct)
    {
        var rag = new Dictionary<string, string>();

        // Predicted SL: red if <target-10, amber if <target, green if >=target
        if (e.PredictedSlPct.HasValue)
        {
            var sl = e.PredictedSlPct.Value;
            if (sl >= slTargetPct) rag["predictedSl"] = "green";
            else if (sl >= slTargetPct - 10) rag["predictedSl"] = "amber";
            else rag["predictedSl"] = "red";
        }

        // Occupancy: green 50-85, amber 85-95, red >95 or <50
        if (e.OccupancyPct.HasValue)
        {
            var occ = e.OccupancyPct.Value;
            if (occ >= 50 && occ <= 85) rag["occupancy"] = "green";
            else if (occ > 85 && occ <= 95) rag["occupancy"] = "amber";
            else rag["occupancy"] = "red";
        }

        // Staff variance: green if >=0, amber if -1 to -2, red if <-2
        if (e.StaffVariance >= 0) rag["staffVariance"] = "green";
        else if (e.StaffVariance >= -2) rag["staffVariance"] = "amber";
        else rag["staffVariance"] = "red";

        return rag;
    }
}
