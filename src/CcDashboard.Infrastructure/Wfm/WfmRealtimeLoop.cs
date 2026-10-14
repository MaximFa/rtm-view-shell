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
/// Also emits per-BU AGGREGATE snapshots (pooled λ/AHT + dedup-N + Erlang re-run).
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
        // Both are singletons; resolved through the scope because that is how every other
        // dependency is reached in this method. Added by shell - FRAGMENT_LOOP.md uses
        // `agentCounts` and `logGate` but does not say where they come from.
        var agentCounts = scope.ServiceProvider.GetRequiredService<IWfmEngineAgentCountProvider>();
        var logGate = scope.ServiceProvider.GetRequiredService<IWfmLogGate>();

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

        // N is no longer derived per queue. The operator's rule (14.10) is "flow by queue, agents by
        // skill": lambda and AHT stay per queue, while N belongs to the BU's skill. The BU map is
        // fetched once here so a queue can find its owner.
        var bus = await inputService.GetActiveBusAsync(tenantId, ct);
        var busByQueue = bus
            .SelectMany(b => b.QueueIds.Select(q => (Queue: q, Bu: b)))
            .GroupBy(x => x.Queue, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Select(x => x.Bu).ToList(), StringComparer.OrdinalIgnoreCase);

        var asOfUtc = DateTime.UtcNow;

        // Track queue keys for collision guard
        var queueKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Process each queue.
        // The old shape unioned the N dictionary's keys; the provider is not a dictionary, so that
        // source is gone. Taking λ/AHT keys ALONE would silently drop a queue with no calls in the
        // window - it used to appear through the N side - and that queue still needs a snapshot:
        // zero traffic with staffed agents is a real, reportable state. The BU classification is
        // the right second source: it lists the tenant's queues regardless of traffic.
        var allQueues = lambdaAht.Keys.Union(busByQueue.Keys, StringComparer.OrdinalIgnoreCase)
                                      .Distinct(StringComparer.OrdinalIgnoreCase)
                                      .ToList();

        foreach (var queueId in allQueues)
        {
            queueKeys.Add(queueId);

            // (0d, 0d), not (0, 0): the dictionary value is (double, double) and an int literal
            // pair leaves the deconstruction untyped (CS8130).
            var (lambda, aht) = lambdaAht.GetValueOrDefault(queueId, (0d, 0d));

            // One queue, one BU, one skill - that is the whole point of "isolated calculations".
            // A queue owned by several BUs has no single skill behind it, so N is UNKNOWN rather
            // than a sum or a pick: summing would double-count agents who hold both skills, and
            // picking one BU would answer about a different population than the caller asked about.
            var owners = busByQueue.GetValueOrDefault(queueId, new List<BuInfo>());
            WfmAgentCount n;
            if (owners.Count == 1)
            {
                n = await agentCounts.GetBuServingCountAsync(tenantId, owners[0].BusinessUnitId, servingGroups, ct);
            }
            else
            {
                n = WfmAgentCount.Unknown(owners.Count == 0
                    ? $"queue {queueId} belongs to no BU"
                    : $"queue {queueId} belongs to {owners.Count} BUs, so no single skill defines N");
            }
            var nActual = n;

            var snapshot = BuildSnapshot(
                tenantId, queueId, asOfUtc, windowMin,
                lambda, aht, nActual,
                slTargetPct, slThresholdSec, trunkCapacity,
                erlang);

            snapshotStore.Set(snapshot);
        }

        logger.LogInformation("WfmRealtimeLoop: processed {QueueCount} queues for tenant {TenantId}",
            allQueues.Count(), tenantId);

        // --- Per-BU AGGREGATE snapshots ---
        // Reuses this tick's per-queue λ/AHT; pools inputs + re-runs Erlang (NOT summing outputs)
        await ProcessBuAggregatesAsync(
            tenantId, inputService, erlang, agentCounts, logGate,
            lambdaAht, servingGroups,
            windowMin, slTargetPct, slThresholdSec, trunkCapacity,
            asOfUtc, queueKeys, ct);
    }

    /// <summary>
    /// Compute per-BU aggregate WFM snapshots.
    /// Pooled λ = Σ per-queue λ; Pooled AHT = arrival-weighted avg; N = DISTINCT agents (§36a BU pool).
    /// Erlang is re-run on pooled inputs (outputs are NOT additive).
    /// </summary>
    private async Task ProcessBuAggregatesAsync(
        Guid tenantId,
        IWfmInputQueryService inputService,
        IErlangCalculatorService erlang,
        // Passed in rather than resolved again: both are singletons, and resolving a second time
        // from another scope would hand this method a different view of the same subscriptions.
        IWfmEngineAgentCountProvider agentCounts,
        IWfmLogGate logGate,
        IReadOnlyDictionary<string, (double LambdaPerHour, double AhtSec)> lambdaAht,
        IReadOnlyList<string> servingGroups,
        int windowMin,
        double slTargetPct,
        int slThresholdSec,
        int trunkCapacity,
        DateTime asOfUtc,
        HashSet<string> queueKeys,
        CancellationToken ct)
    {
        // Get all BUs with their queue mappings
        var bus = await inputService.GetActiveBusAsync(tenantId, ct);

        int buCount = 0;
        foreach (var bu in bus)
        {
            try
            {
                // BU key = the ID string the widget Gets (Config.BusinessUnit = BusinessUnitId.ToString())
                var buKey = bu.BusinessUnitId.ToString();

                // Collision guard: check if BU key collides with a Workgroup key
                // (numeric BU-id effectively never collides with Workgroup NAME — disjoint namespaces)
                if (queueKeys.Contains(buKey))
                {
                    logger.LogWarning("WFM key collision: '{Key}' is both a Workgroup and a BusinessUnit", buKey);
                }

                // Pool λ and AHT from queues belonging to this BU
                double pooledLambda = 0;
                double weightedAhtSum = 0;
                double lambdaSum = 0;

                foreach (var queueId in bu.QueueIds)
                {
                    if (lambdaAht.TryGetValue(queueId, out var queueData))
                    {
                        pooledLambda += queueData.LambdaPerHour;
                        weightedAhtSum += queueData.LambdaPerHour * queueData.AhtSec;
                        lambdaSum += queueData.LambdaPerHour;
                    }
                }

                // Arrival-weighted AHT = Σ(λ_q * aht_q) / Σλ_q
                double pooledAht = lambdaSum > 0 ? weightedAhtSum / lambdaSum : 0;

                // N for the BU = sum of the engine's current per-group counts over the serving
                // groups. Per-skill by construction: the engine admits an agent to a union only
                // when the agent's activated skills contain every group the union requires
                // (RTM/RTM/UserManager.cs:572), and the per-group metric counts that union's users
                // (RTM/RTM/Union.cs:859-865).
                var pooledN = await agentCounts.GetBuServingCountAsync(tenantId, bu.BusinessUnitId, servingGroups, ct);

                if (!pooledN.IsKnown)
                {
                    // Once per hour per BU through the same gate as the mixed-TimeZone line, for the
                    // same reason: a missing metric stays missing until somebody fixes the setting,
                    // and repeating it every 30 s buries the log (measured there: 42 lines/min).
                    if (logGate.ShouldLog($"wfm-n-unknown:{tenantId}:{bu.BusinessUnitId}",
                                          pooledN.UnknownReason, TimeSpan.FromHours(1)))
                    {
                        logger.LogWarning(
                            "WfmRealtimeLoop: N unknown for BU {BuName} (id={BuId}): {Reason}. Missing groups: [{Missing}]. "
                          + "Configured serving groups: [{Configured}]. Repeats suppressed for an hour unless the reason changes.",
                            bu.BusinessUnitName, bu.BusinessUnitId, pooledN.UnknownReason,
                            string.Join(", ", pooledN.MissingGroups),
                            string.Join(", ", servingGroups));
                    }
                }

                // Build and store BU aggregate snapshot (keyed by BusinessUnitId — matches widget Get)
                var snapshot = BuildSnapshot(
                    tenantId, buKey, asOfUtc, windowMin,
                    pooledLambda, pooledAht, pooledN,
                    slTargetPct, slThresholdSec, trunkCapacity,
                    erlang);

                snapshotStore.Set(snapshot);
                buCount++;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // Per-BU error: log and continue with other BUs
                logger.LogError(ex, "WfmRealtimeLoop: error processing BU aggregate for {BuName} (id={BuId})",
                    bu.BusinessUnitName, bu.BusinessUnitId);
            }
        }

        // No `if (buCount > 0)`: zero IS the answer we were missing — it separates
        // "no BU aggregates built" from "the loop never reached the aggregate stage".
        logger.LogInformation(
            "WfmRealtimeLoop: processed {BuCount} BU aggregates of {BuTotal} BUs for tenant {TenantId}",
            buCount, bus.Count, tenantId);

        var busWithoutQueues = bus.Count(b => b.QueueIds.Count == 0);
        if (busWithoutQueues > 0)
        {
            // Today this case is logged nowhere at any level, yet it yields a snapshot full of zeros:
            // the queue loop makes no pass, so lambda = 0 and AHT = 0, and State becomes NoData.
            logger.LogWarning(
                "WfmRealtimeLoop: {Count} of {Total} BUs have no queues (missing 'ALL' classification) "
              + "for tenant {TenantId} — their snapshots are published with zero inputs",
                busWithoutQueues, bus.Count, tenantId);
        }
    }

    /// <summary>
    /// Build a WfmSnapshot from inputs, running Erlang calculations.
    /// </summary>
    private static WfmSnapshot BuildSnapshot(
        Guid tenantId,
        string queueId,
        DateTime asOfUtc,
        int windowMin,
        double lambda,
        double aht,
        WfmAgentCount nActual,
        double slTargetPct,
        int slThresholdSec,
        int trunkCapacity,
        IErlangCalculatorService erlang)
    {
        // Determine state. An unknown N is its own case and must come FIRST: it is not the same
        // thing as N = 0. Zero means nobody is serving (a real, computable situation); unknown means
        // the engine has not told us, and the operator's standing rule is to show empty and log the
        // anomaly rather than compute on a stand-in.
        string state;
        if (!nActual.IsKnown || aht <= 0 || nActual.Value <= 0)
        {
            state = WfmSnapshot.StateNoData;
        }
        else
        {
            var trafficA = erlang.TrafficIntensity(lambda, aht);
            if (nActual.Value <= trafficA)
                state = WfmSnapshot.StateOverloaded;
            else
                state = WfmSnapshot.StateOk;
        }

        // Unknown N -> no Erlang at all. Returning the snapshot in StateNoData with null inputs is
        // what makes the widget show empty; a zeroed snapshot would show numbers that look real.
        if (!nActual.IsKnown)
        {
            return new WfmSnapshot(
                TenantId: tenantId,
                QueueId: queueId,
                AsOfUtc: asOfUtc,
                WindowMin: windowMin,
                Inputs: new WfmInputs(lambda, aht, NActual: null, WrapIncluded: false),
                Erlang: null,
                State: WfmSnapshot.StateNoData,
                Rag: new Dictionary<string, string>(),
                UnknownReason: nActual.UnknownReason);
        }

        // Past the guard above N is known, so unwrap it once. WfmAgentCount.Value is int? (unknown
        // is expressed by null), hence the second .Value - the guard is what makes it safe, and
        // GetValueOrDefault() would hide a future guard regression behind a silent 0.
        var nValue = nActual.Value.Value;

        // Compute Erlang metrics
        var trafficAComputed = aht > 0 ? erlang.TrafficIntensity(lambda, aht) : 0;
        var pWaitC = erlang.ErlangC(nValue, trafficAComputed);
        var predictedSlPct = erlang.PredictedSl(nValue, trafficAComputed, aht, slThresholdSec);
        var predictedAsaSec = erlang.PredictedAsaSec(nValue, trafficAComputed, aht);
        var (reqAgents, reqCapped) = erlang.RequiredAgents(trafficAComputed, aht, slThresholdSec, slTargetPct / 100.0);
        var erlangBPct = erlang.ErlangB(trunkCapacity, trafficAComputed) * 100.0;
        var occupancyPct = erlang.OccupancyPct(trafficAComputed, nValue);
        var understaffPct = erlang.UnderstaffPct(reqAgents, nValue);
        var staffVariance = erlang.StaffVariance(nValue, reqAgents);

        // Build snapshot
        var inputs = new WfmInputs(lambda, aht, nValue, WrapIncluded: false);
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

        // RAG thresholds
        var rag = ComputeRag(erlangMetrics, slTargetPct);

        return new WfmSnapshot(
            TenantId: tenantId,
            QueueId: queueId,
            AsOfUtc: asOfUtc,
            WindowMin: windowMin,
            Inputs: inputs,
            Erlang: erlangMetrics,
            State: state,
            Rag: rag);
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
