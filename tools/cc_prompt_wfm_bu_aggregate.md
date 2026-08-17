# CC Task — WFM (a): per-BU AGGREGATE snapshot in the loop (fix "Waiting for data")

> C2 live finding: BU-scoped WfmWidget shows "Waiting for data" — store is keyed per-Workgroup, widget Gets by BU.
> Fix (coordinator-approved a): the loop ALSO emits a per-BU AGGREGATE WfmSnapshot, POOLING inputs + RE-RUNNING Erlang
> (Erlang outputs are NOT additive). Territory: **web** (Infrastructure loop/query). NO push. Prefix `feat:`.

## KEY CONTRACT (PINNED — zero widget change)
The widget's BU-scope Get passes EXACTLY `Config.BusinessUnit` = the BU NAME string (e.g. "DE All"), UNPREFIXED
(WfmWidget.razor:181-185/200; both WfmQueueId and BusinessUnit are plain strings). Per-queue snapshots stay keyed by
`<Workgroup>` (unchanged — existing queue widgets keep working). => Key the per-BU snapshot by EXACTLY the BU NAME
string (`WfmSnapshot.QueueId = <BusinessUnitName>`), so the BU widget matches with NO widget change.
COLLISION GUARD: at Set time, if a BU-name key would collide with a Workgroup key already Set this tick (or vice-versa),
log a Serilog WARN (`WFM key collision: '<key>' is both a Workgroup and a BusinessUnit`). Names differ in practice
("DE All" BU vs "DE - Support" Workgroup); the guard surfaces any real clash without breaking the widget.

## STEP 0 — §0.6a integrity (v3). §40 reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock.
## STEP 1 — Sync slug backend-0626. Claims:
##   - src/CcDashboard.Infrastructure/Wfm/WfmRealtimeLoop.cs        (MODIFY: after per-queue loop, emit per-BU aggregates)
##   - src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs   (MODIFY: add BU-level distinct-N query if needed)
##   - src/CcDashboard.Application/Interfaces/IWfmInputQueryService.cs (MODIFY if a BU-N method is added)
## STEP 2 — BINDING preamble to .coord/cc/backend.md.

## Implement — per-BU aggregate, SAME 30s tick, reuse this tick's per-queue λ/AHT (do NOT re-query λ/AHT per BU)
For each active BU of the tenant (NGC_BusinessUnit: BusinessUnitId + BusinessUnitName):
1. Resolve the BU's queues = its Workgroups via `NgcBusinessUnitQueueClassification` (BusinessUnitId) — the SAME queue
   set already computed this tick. (Reuse the existing per-queue `lambdaAht` dict; do NOT re-run the λ/AHT SQL.)
2. **pooled λ** = Σ per-queue λ over the BU's queues.
3. **pooled AHT** = arrival-weighted avg = `Σ(λ_q * aht_q) / Σ λ_q` over the BU's queues (λ ∝ arrivals in the fixed
   window, so this is arrival-weighted with no extra data). Guard Σλ==0 → aht 0 → nodata.
4. **pooled N** = COUNT DISTINCT serving agents across the BU's queues — DEDUP. Reuse `BuMembershipResolver`/§36a at
   **BU scope** (BU→SG union→AG intersection = the BU's distinct agent pool), then count those in `servingGroups`
   (current RTSData_UserStatus). Do NOT sum per-queue N (double-counts agents on multiple queues). CACHE the BU pool
   (changes slowly), resolve NOT per-tick. Add a BU-level distinct-N path in WfmInputQueryService (SqlQueryRaw with a
   TYPED record OR scalar aliased `AS "Value"` — heed the N-42703 lesson: never a scalar with a non-"Value" alias).
5. `A = TrafficIntensity(pooledλ, pooledAHT)`; ErlangCalculatorService (ErlangC/PredictedSl/PredictedAsaSec/RequiredAgents/
   OccupancyPct/UnderstaffPct/StaffVariance/ErlangB) → nullable→state (overloaded N<=A; nodata aht<=0 or N=0); RAG from config.
6. `WfmSnapshot(QueueId = BusinessUnitName, ...)` → `IWfmSnapshotStore.Set`. Apply the COLLISION GUARD WARN.
- Per-BU errors caught per-BU (one BU failing must not kill the tick). Serilog structured, no PII.

## STEP 3 — build0
`dotnet build src/CcDashboard.Web` — 0 errors. Optional unit test: pooled λ/AHT weighting + BU N dedup on a small fixture.

## STEP 4 — commit (commit.lock) — ONE commit:
`feat: WFM per-BU aggregate snapshot (pooled λ/AHT + dedup-N + Erlang re-run, keyed by BU name) [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT: commit hash, files, build; STATE the EXACT BU Get-key (`<BusinessUnitName>`, e.g. "DE All")
and CONFIRM **no widget change needed** (loop keys by exactly what the widget already Gets). Note the collision-guard WARN.

## Acceptance
- [ ] Per-BU aggregate emitted SAME tick, reusing per-queue λ/AHT (no per-BU λ/AHT re-query); pooled λ=Σ, AHT=arrival-weighted, N=DISTINCT via §36a BU pool (cached, deduped); Erlang RE-RUN (not summed outputs).
- [ ] Snapshot keyed by BusinessUnitName (matches widget Get, zero widget change). Collision-guard WARN present.
- [ ] BU-N query heeds N-42703 (typed record or `AS "Value"`). build green. Prefix feat:. NO push.

## Git push: do NOT run git push. Commit only.
