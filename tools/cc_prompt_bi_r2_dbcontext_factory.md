# CC TASK — R2: concurrent-DbContext fix on the report-render path (factory-isolated reads)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless (mechanism review).
> ⛔ ЧП — no-run-without-bless. SYMPTOM: Distribution / AgentShiftDetail / QueueWaitTime fail with
> "A command is already in progress: SELECT DISTINCT n.QueueId FROM NGC_BusinessUnitQueueClassification ...".
> CAUSE: the 5 report widgets render IN PARALLEL on ONE Blazor circuit; each RunReportWidgetQuery goes through
> ReportWidgetScopeService → ReportScopeResolver + BuMembershipResolver → HistoricalReportRepository, and they SHARE the
> circuit's single scoped AppDbContext / BackendEmulationDbContext. EF DbContext is NOT thread-safe → collision.
>
> ⚠ CORRECTION to the 04:14 directive (object-store): IDbContextFactory<AppDbContext> AND IDbContextFactory<BackendEmulationDbContext>
> ARE ALREADY REGISTERED (src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs:44 + :64, ServiceLifetime.Scoped),
> plus the AppDbContextAbstractionFactory wrapper (IAppDbContextFactory) and a working precedent: TenantSettingsRepository
> injects IDbContextFactory<AppDbContext> + `await using var ctx = await dbFactory.CreateDbContextAsync(ct)`. So the fix REUSES
> the existing factory — no Program.cs registration needed.

## Mechanism (PROPOSAL for §4) — factory-isolated READ contexts on the render path ONLY
Each parallel widget's read path gets its OWN short-lived context (mirror TenantSettingsRepository), so parallel widgets don't
share one context. The factory is Scoped → the per-call context resolves the SAME ITenantContext/ICurrentUserAccessor as today
→ cross-tenant (Superadmin) + GQF behaviour is PRESERVED; the report queries are already explicit-TenantId (ReportScopeResolver
7× `TenantId ==`/IgnoreQueryFilters, BuMembershipResolver 4× `TenantId ==`, HistoricalReportRepository IgnoreQueryFilters+explicit) so correctness is unaffected.

⚠ TRANSACTION SAFETY (critical): `HistoricalReportRepository` is ALSO used by HistoricalAggregationService for transactional
DELETE+INSERT per interval window. Do NOT factory-ize the WRITE methods (DeleteQueueIntervalsAsync / InsertQueueIntervalsAsync /
UpsertWatermarkAsync / agent equivalents) — they must keep the shared scoped `db` so the aggregation transaction stays atomic.
ONLY the report-READ methods get the factory.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short
```
CLAIM (file-mode):
- src/CcDashboard.Infrastructure/Persistence/Repositories/HistoricalReportRepository.cs
- src/CcDashboard.Infrastructure/Services/BuMembershipResolver.cs
- src/CcDashboard.Infrastructure/Services/ReportScopeResolver.cs
- tests/CcDashboard.Tests.Unit/** + .claude/skills/role-bi/role-bi.md (§B)
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## EDITS (factory-per-method on the report-READ path; mirror TenantSettingsRepository)
The pattern in every refactored method:
```csharp
await using var ctx = await dbFactory.CreateDbContextAsync(ct);   // AppDbContext OR BackendEmulationDbContext
// ... use ctx instead of the shared db/appDb/beDb ...
```

### EDIT 1 — HistoricalReportRepository.cs (READ methods only)
- Ctor: inject `IDbContextFactory<AppDbContext> dbFactory` ALONGSIDE the existing `AppDbContext db` (keep `db` for the write/transaction methods).
- `GetQueueIntervalsAsync` + `GetAgentIntervalsAsync` (the report-read methods): create `await using var ctx = await dbFactory.CreateDbContextAsync(ct);` and run the existing query against `ctx` (keep IgnoreQueryFilters + explicit TenantId + effectiveWorkgroups/effectiveAgentIds exactly as today).
- Also `GetWatermarkAsync` if it is on the read/report path — but DO NOT touch DeleteQueueIntervalsAsync / InsertQueueIntervalsAsync / UpsertWatermarkAsync / agent write equivalents (HistoricalAggregationService transaction — keep shared `db`). Confirm by usage which methods are read-only vs aggregation-write before refactoring.

### EDIT 2 — BuMembershipResolver.cs (read-only → factory)
- Ctor: replace `BackendEmulationDbContext beDb` with `IDbContextFactory<BackendEmulationDbContext> beFactory` (+ any AppDbContext use → its factory).
- `ResolveQueuesAsync` + `ResolveAgentsAsync`: `await using var ctx = await beFactory.CreateDbContextAsync(ct);` ONE ctx per method (the method's multiple sequential queries share its own ctx — like TenantSettingsRepository), run all existing queries (NGC_BusinessUnitQueueClassification ClassificationId='ALL', BU→SG→AG→User) against `ctx`. Same explicit TenantId filters; IntersectWithPgScope unchanged.

### EDIT 3 — ReportScopeResolver.cs (read-only → factory)
- Ctor: replace `AppDbContext appDb` + `BackendEmulationDbContext beDb` with their factories.
- `ResolveQueueScopeAsync` + `ResolveAgentScopeAsync`: Superadmin short-circuits to ReportScope.Full() (no query) — keep. For the non-Superadmin branch, `await using var ctx`/`bectx` per method, run the existing PgQueues/PgSupergroups/PgBusinessUnits + NGC queries against them. Same explicit TenantId.

NOTE: these 3 classes are also used by other report paths (CRUD/legacy handlers) — the change is TRANSPARENT (same queries, just an isolated per-call context); it does not alter behaviour, only the context lifetime. ReportWidgetScopeService is unchanged (it holds no DbContext directly — only buResolver+scopeResolver).

## ACCEPTANCE (DoD)
1. Build 0. 2. All 4+ widgets on ONE screen render SIMULTANEOUSLY with NO "A command is already in progress". 3. QueueInterval still shows data; cross-tenant Superadmin (bypassTenantFilter / 019e03e9) still works. 4. HistoricalAggregationService transaction intact (write methods still use the shared `db`; backfill/aggregation unaffected). 5. NO migration. 6. NO push.
Tests: a focused concurrency test (two parallel RunReportWidgetQuery on the same scope) OR at minimum unit tests that the refactored read methods return the same results via the factory context.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify post-commit.
- commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `fix: report-render reads use IDbContextFactory (parallel-widget DbContext isolation) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT.
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · Blazor report widgets render in PARALLEL on one circuit sharing ONE scoped AppDbContext/BackendEmulationDbContext → "A command is already in progress". Fix: report-READ path (HistoricalReportRepository read methods + BuMembershipResolver + ReportScopeResolver) uses IDbContextFactory per-call (already registered, ServiceLifetime.Scoped; precedent TenantSettingsRepository) → isolated short-lived contexts, same ITenantContext (cross-tenant preserved). Keep aggregation WRITE methods on the shared scoped db (transaction atomicity). · SOURCE: InfrastructureServiceExtensions:44/64 + TenantSettingsRepository + coordinator 2026-06-26 · status: active`

## DO NOT
- Do NOT factory-ize the HistoricalReportRepository aggregation WRITE/transaction methods (breaks atomicity).
- Do NOT add a new DI scope (breaks ICurrentUserAccessor/ITenantContext) — use the factory (same scope, isolated context).
- Do NOT register a new factory (already registered). Do NOT change Program.cs / ReportWidgetScopeService. NO migration / NO push.

## FLAG TO COORDINATOR
Correction: the factory IS already registered (your 04:14 "no factory in Program.cs" — it's in InfrastructureServiceExtensions, not Program.cs). This is a mechanism PROPOSAL per §26.8 — review the read-vs-write split (transaction safety) before run.
