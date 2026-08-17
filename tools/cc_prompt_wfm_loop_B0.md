# CC Task — WFM Phase 1 (B0): TenantSettings WFM config + WfmSnapshot contract + in-mem store

> Carve of prompt B with ZERO window-frame dependency (B1 = query+loop stays HELD on dba's frame lock).
> Delivers the config schema + the snapshot contract + the in-memory hand-off store (the surface shell will read).
> Does NOT register the HostedService loop and does NOT add any λ/AHT/N query. Territory: **web**. NO push. Prefix `web:`.

## STEP 0 — §0.6a integrity (branch v3). §40 reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock.
## STEP 1 — Sync slug backend-0626. Claims:
##   - src/CcDashboard.Domain/Domain/TenantSettings.cs                         (MODIFY: +WFM §5 fields)
##   - src/CcDashboard.Infrastructure/Persistence/Migrations/App/<gen>_WfmTenantSettings.cs  (EF migration, generated)
##   - src/CcDashboard.Application/Wfm/WfmTypes.cs                              (MODIFY: +WfmSnapshot §4 records)
##   - src/CcDashboard.Application/Interfaces/IWfmSnapshotStore.cs             (new)
##   - src/CcDashboard.Infrastructure/Wfm/WfmSnapshotStore.cs                  (new, Singleton, in-mem)
##   - src/CcDashboard.Web/Program.cs                                          (MODIFY: AddSingleton<IWfmSnapshotStore,WfmSnapshotStore> — STORE ONLY, no HostedService)
## STEP 2 — BINDING preamble to .coord/cc/backend.md.

---

## 1. TenantSettings WFM config (spec §5) — add fields + EF migration
Add to `TenantSettings` (Domain) with §5 defaults:
`WfmServingStateGroups` string[] default `{Available, On Phone, Paperwork}`, `WfmWindowMinutes` int=30,
`SlTargetPct` double=80, `SlThresholdSec` int=20, `TrunkCapacity` int=100, `DefaultShrinkage` double=0.28,
`EnableWfmRealtime` bool=true, `WfmThresholds` string (jsonb) with the spec §3 per-metric RAG defaults.
- EF AlterTable migration, **App context** (§MAINT-04 EF-only). Non-null defaults for existing rows (idempotent).
- text[] -> `string[]` mapped as Postgres `text[]`; jsonb -> `string`/`JsonDocument` per existing project convention.
- DTO (TenantSettingsDto) fields OPTIONAL in this prompt (no Tenant UI change — shell later).

## 2. WfmSnapshot contract (spec §4) — src/CcDashboard.Application/Wfm/WfmTypes.cs
Add records matching §4 exactly:
- `WfmInputs(double LambdaPerHour, double AhtSec, int NActual, bool WrapIncluded)`
- `WfmErlang(double TrafficA, double? PWaitC, double? PredictedSlPct, double? PredictedAsaSec, int RequiredAgents, bool RequiredCapped, double ErlangBPct, double? OccupancyPct, double? UnderstaffPct, int StaffVariance)`
- `WfmSnapshot(Guid TenantId, string QueueId, DateTime AsOfUtc, int WindowMin, WfmInputs Inputs, WfmErlang Erlang, string State, IReadOnlyDictionary<string,string> Rag)`
- `State` constants: "ok" | "overloaded" | "nodata". (No producer here — B1 fills them from ErlangCalculatorService.)

## 3. IWfmSnapshotStore + WfmSnapshotStore (in-mem, Singleton)
- `IWfmSnapshotStore` (Application/Interfaces): `void Set(WfmSnapshot snap); WfmSnapshot? Get(Guid tenantId, string queueId); IReadOnlyList<WfmSnapshot> GetForTenant(Guid tenantId);`
- `WfmSnapshotStore` (Infrastructure/Wfm): thread-safe `ConcurrentDictionary<(Guid,string),WfmSnapshot>`. Singleton. No I/O, no DB. This is the hand-off surface B1's loop writes and shell reads.
- Program.cs: `services.AddSingleton<IWfmSnapshotStore, WfmSnapshotStore>();` — STORE ONLY. Do NOT add AddHostedService (B1).

## STEP 3 — build (+ tests if any trivially added)
`dotnet build src/CcDashboard.Web` — Build succeeded, 0 errors. (EF migration compiles; store compiles.)
Optional: `dotnet ef migrations list --context AppDbContext ...` sanity if the harness supports it.

## STEP 4 — pre-commit + commit (commit.lock) — ONE commit:
`web: WFM Phase1 B0 — TenantSettings WFM config + WfmSnapshot contract + in-mem store (no loop) [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT: commit hash, files, EF migration name, build result, status.

## Acceptance
- [ ] TenantSettings §5 fields + App EF migration (idempotent defaults). WfmSnapshot/WfmInputs/WfmErlang records (§4). IWfmSnapshotStore + WfmSnapshotStore (Singleton, ConcurrentDictionary). Program.cs registers the STORE only.
- [ ] NO HostedService, NO λ/AHT/N query, NO window-frame logic (all B1). build green. Prefix web:. NO push.

## Git push: do NOT run git push. Commit only.
