# WfmRealtimeLoop: N from the engine, and "unknown" instead of a substituted zero

Target file (v4): `src/CcDashboard.Infrastructure/Wfm/WfmRealtimeLoop.cs`. Snapped 2026-10-14T10:04:57Z.
Companion files in this folder: `WfmEngineAgentCountProvider.cs` (new), `PROJECT.md` (design).
Read from the v4 branch; line numbers are v4's.

## Edit 1 — per-queue N comes from the queue's BU, not from a roster

### BEFORE (`:104-105`, `:119-120`)

```csharp
        // Get N for all queues
        var agentCounts = await inputService.GetServingAgentCountsAsync(tenantId, servingGroups, ct);
```

```csharp
            var (lambda, aht) = lambdaAht.GetValueOrDefault(queueId, (0, 0));
            var nActual = agentCounts.GetValueOrDefault(queueId, 0);
```

### AFTER

```csharp
        // N is no longer derived per queue. The operator's rule (14.10) is "flow by queue, agents by
        // skill": lambda and AHT stay per queue, while N belongs to the BU's skill. The BU map is
        // fetched once here so a queue can find its owner.
        var bus = await inputService.GetActiveBusAsync(tenantId, ct);
        var busByQueue = bus
            .SelectMany(b => b.QueueIds.Select(q => (Queue: q, Bu: b)))
            .GroupBy(x => x.Queue, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Select(x => x.Bu).ToList(), StringComparer.OrdinalIgnoreCase);
```

```csharp
            var (lambda, aht) = lambdaAht.GetValueOrDefault(queueId, (0, 0));

            // One queue, one BU, one skill - that is the whole point of "isolated calculations".
            // A queue owned by several BUs has no single skill behind it, so N is UNKNOWN rather
            // than a sum or a pick: summing would double-count agents who hold both skills, and
            // picking one BU would answer about a different population than the caller asked about.
            // BuInfo is the existing record declared beside IWfmInputQueryService:
            // `public record BuInfo(int BusinessUnitId, string BusinessUnitName,
            // IReadOnlyList<string> QueueIds)`. No new type is introduced here.
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
```

## Edit 2 — BU aggregate N from the provider

### BEFORE (`:198-199`)

```csharp
                // Distinct N for BU (§36a resolution, cached, deduped)
                int pooledN = await inputService.GetBuServingAgentCountAsync(tenantId, bu.BusinessUnitId, servingGroups, ct);
```

### AFTER

```csharp
                // N for the BU = sum of the engine's current per-group counts over the serving
                // groups. Per-skill by construction: the engine admits an agent to a union only
                // when the agent's activated skills contain every group the union requires
                // (RTM/RTM/UserManager.cs:572), and the per-group metric counts that union's users
                // (RTM/RTM/Union.cs:859-865).
                var pooledN = await agentCounts.GetBuServingCountAsync(tenantId, bu.BusinessUnitId, servingGroups, ct);
```

## Edit 3 — an unknown N does not reach Erlang

`BuildSnapshot` takes `int nActual` and computes unconditionally. With an unknown N there is nothing
to compute, and substituting 0 would publish a confident wrong answer: every Erlang output would
read as "infinitely understaffed" instead of "we do not know".

### BEFORE (signature and state, `BuildSnapshot`)

```csharp
        int nActual,
```

```csharp
        // Determine state
        string state;
        if (aht <= 0 || nActual <= 0)
        {
            state = WfmSnapshot.StateNoData;
        }
```

### AFTER

```csharp
        WfmAgentCount nActual,
```

```csharp
        // Determine state. An unknown N is its own case and must come FIRST: it is not the same
        // thing as N = 0. Zero means nobody is serving (a real, computable situation); unknown means
        // the engine has not told us, and the operator's standing rule is to show empty and log the
        // anomaly rather than compute on a stand-in.
        string state;
        if (!nActual.IsKnown || aht <= 0 || nActual.Value <= 0)
        {
            state = WfmSnapshot.StateNoData;
        }
```

And at the top of the Erlang block:

```csharp
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
```

**This changes the shared contract in `src/CcDashboard.Application/Wfm/WfmTypes.cs`**, measured as it
stands today (`:21-57`): `WfmInputs.NActual` is `int` and must become `int?`; `WfmSnapshot.Erlang` is
`WfmErlang` (non-nullable) and must become `WfmErlang?`; and `string? UnknownReason` has to be added
after the existing `Rag` parameter, which the call above keeps in place.

`WfmSnapshot` is read by the widget side, so **shell must agree before this lands** — I am not
changing a shared record unilaterally. Two alternatives, both worse in my view, named so the choice
is real:

1. keep `Erlang` non-null and zero it, relying on `State == "nodata"` to tell the widget to ignore
   the numbers — that leaves figures on the wire that mean nothing, and the 13.10 lesson was exactly
   that a plausible wrong number beats an empty cell at being believed;
2. reuse the existing `WfmSentinel.NoData` (`WfmTypes.cs:8`) rather than touch the snapshot — but the
   snapshot carries no `WfmMetricResult`, so that would mean a second parallel shape for one answer.

## Edit 4 — the Warning changes subject

The old N=0 branch (today's `.coord/measure/wfm-n0-warning-1014/`) dies with the roster query. Its
replacement, in the BU loop right after the count:

```csharp
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
```

Both sides are printed, as before: the configured groups and what is actually missing. "N unknown"
alone sends the reader back to the database.

## Edit 5 — removals (scope measured before deleting)

`WfmInputQueryService.GetServingAgentCountsAsync` (`:128-255`) and `GetBuServingAgentCountAsync`
(`:316-...`) go, together with the private `GetOrRefreshBuAgentPoolsAsync` (`:392`) and the
`_buAgentPoolCache` field they serve.

Scope check, as agreed — call sites of all three, across `src/**`:

- `GetServingAgentCountsAsync` — declaration `WfmInputQueryService.cs:128`, one caller:
  `WfmRealtimeLoop.cs:105`;
- `GetBuServingAgentCountAsync` — declaration `:316`, one caller: `WfmRealtimeLoop.cs:199`;
- `GetOrRefreshBuAgentPoolsAsync` — private, one caller: `:328` inside the method above.

Nothing else in the solution calls them, so the §36a walk inside them is used **for N only** and goes
with them. The NGC_* tables themselves are untouched — other code reads them, and this is a removal
of two methods, not of a data model.

`IWfmInputQueryService` loses both members. `GetActiveBusAsync`, `GetLambdaAndAhtAsync` and the
timezone map stay: lambda and AHT remain per queue, which is the other half of the operator's rule.

## CORRECTION (coordinator 10:03:45Z / 10:13:07Z): the BU link is on the ROW

My earlier text said the save path sets `UnionId` on both the grid and the row. **Withdrawn — it was
wrong, and the data says so.** devops measured on 234: `RTSGrid_Grid.UnionId` = -1 in all 60 rows and
`RTSGrid_Cell.UnionId` = -1 in all 509; only `RTSGrid_Row.UnionId` carries the BusinessUnitId.

Shown by file:line, as asked:

- the row IS written with the BU: `RtsRepository.InsertQueueGridRowAsync` (`:217-226`) runs a raw
  `INSERT INTO "RTSGrid_Row" (..., "UnionId", ...)` with `@unionId`, called from
  `SaveDataSlotRtsCommand.cs:63` as `InsertQueueGridRowAsync(gridId, 1, cmd.BusinessUnitId, ct)`;
- the code I had cited for the grid level — `SaveAgentGridRtsCommand.cs:95` and
  `RtsRepository.UpdateGridAsync` (`:66`) — writes **`RtsUserGridGrid`**, the `RTSUserGrid_Grid`
  table. That is a different entity from `RtsGridGrid`/`RTSGrid_Grid`. I read one table and wrote
  about another; the claim is removed, not re-argued.

What changed in the code because of it (`WfmEngineAgentCountProvider.cs`, blob below):

- resolution is `BU -> rows with that UnionId -> their cells`. The grid level is not consulted at
  all, not even as a hint;
- one BU spans several grids (devops: BU 22 = 17 rows in 15 grids), so the provider subscribes to
  **every** grid holding one of the BU's rows;
- values are kept per `CellId`, not per MetricId: the same MetricId appears in each of those grids,
  and keying on the metric would let one grid's value overwrite another's;
- only the BU's own rows are read. A grid shared with another BU is normal, and reading the grid
  instead of the rows would add the neighbour's agents to ours — a wrong number that looks right.
  The test `RowsOfAnotherBuInTheSameGrid_AreNotCounted` is what makes that load-bearing;
- when the same group has cells in several grids the **max** is taken, not the sum: every such cell
  reports the same engine counter for the same union, so summing would multiply one group's agents
  by the number of grids showing it. A disagreement between them means one grid is stale, and it is
  logged rather than averaged away.

Every seed in the tests writes `Grid.UnionId = -1` on purpose — that is the negative half you asked
for: a resolve that looked at the grid level would find nothing and the tests would go red.

## Named while writing the tests, NOT fixed here

`RTSGrid_Grid` has **no `TenantId` column**, and neither does `RTSGrid_Row` (measured: the entity is
`RtsGridGrid(GridId, UnionId, StyleId, Title, ThresholdScript)`, `RtsEntities.cs:42-49`). The grid is
therefore resolved by `UnionId` alone, with no tenant gate. In production that is safe because
`BusinessUnitId` is a database identity in `NGC_BusinessUnit` and so unique across tenants — but the
safety rests on that identity, not on a filter. If BU ids ever become per-tenant, N would be read
from another tenant's grid and look perfectly plausible. Same family as
`GetCellMapForGridAsync` (no `TenantId` either), which the coordinator has already attached to
`BL-PREPROD-AUTHZ-01`. Named for the registry; not touched in this leg.

## Blobs

- `WfmEngineAgentCountProvider.cs` — `67dcfec5722756588defc56501954a2a06768cf2`, 13934 B
  (row-level resolve; supersedes `dae5fc74`); target `src/CcDashboard.Infrastructure/Wfm/`
- `WfmEngineAgentCountProviderTests.cs` — `907e54242e1a455f75ec1c87911cc69f47afb291`, 17089 B,
  12 `[Fact]`, CR 0 (supersedes `c618046b`); target `tests/CcDashboard.Tests.Security/Wfm/`
- `GetWfmServingGroupCandidatesQuery.cs` — `7bfd98cb396c0ef88560f155d346cf34743da43c`, 4033 B;
  target `src/CcDashboard.Application/Queries/TenantSettings/`
- `FRAGMENT_TYPES.md` — `202f9edec258964c3db678719aaf8ed048a16f08`, 3125 B (the nullable contract)
- `FRAGMENT_LOOP.md` — this file
- `PROJECT.md` — `ab540f91b465b73324b834633f340f63713a5a00` (design, accepted 08:33Z)

Registration, beside the other Wfm lines in `InfrastructureServiceExtensions.cs`:

```csharp
        // Singleton: it holds relay subscriptions that must outlive the per-tick scope.
        services.AddSingleton<IWfmEngineAgentCountProvider, WfmEngineAgentCountProvider>();
```

Not built and not run here: no `dotnet` in this environment and the v4 working directory is not
mounted. Verification is the coordinator's box.
