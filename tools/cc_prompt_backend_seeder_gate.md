# CC task — ⛔ЧП seeder-gate: rebuild-safety (operator #1 invariant) — DatabaseInitializer sample-seed gate
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `fix:`. **NO push** (§37). FREE/MIT.
> ⛔ЧП — operator's #1 invariant: after the prod-mirror data-load, REBUILDS/RESTARTS must NEVER re-seed sample/test CC data over the prod-mirror.
> Spec: docs/Prod-Mirror-Seed-Plan.md §3. Coordinator §4 RULINGS (2026-06-25T23:10Z): FORK1=(B) config-flag primary + data-presence belt, NO new table/migration; FORK2=(2.4b) prod data re-stamped to OUR working tenant (belt is real); ALSO gate the two Dev-RTS seeds.
> §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for coordinator bless BEFORE the operator runs it. No chat run-box until bless.
> RUN FIRST — the gate must be LIVE before dba's post-load app start.

## ROOT (object-store @ v3 — confirmed, do NOT re-derive)
`src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs`:
- `InitializeAsync` (l.32-75): runs migrations, then calls (in order) SeedRoles / SeedPlatformTenant / SeedSuperadmin / SeedWidgetCatalog / SeedRtsGridMetrics / SeedHistoryMetrics / **SeedSampleCcEntitiesAsync** (l.57) / SeedAgentStateDefinitions (l.58), then a `if (env.IsDevelopment())` block (l.61-72) calling **SeedDevRtsInteractionsAsync + SeedDevRtsUserStatusLogAsync**. The sample seed is UNCONDITIONAL (CLAUDE.md §29.8).
- `SeedSampleCcEntitiesAsync` (l.273-411) seeds SAMPLE: NgcQueues(Q001-5), NgcAgentGroups(AG001-5), **NgcSites — brittle `s.SiteId == "SITE001"` probe (l.318)**, NgcBusinessUnits (name-upsert), NgcSupergroups, NgcBusinessUnitQueueClassifications. All on `beDb` (BackendEmulationDbContext).
- ctor already injects `IConfiguration config` + `IHostEnvironment env` (l.26-27). No new DI needed.

## KEEP UNGATED (system seeds — must still run): Roles, PlatformTenant, Superadmin, WidgetCatalog, RtsGridMetrics, HistoryMetrics, AgentStateDefinitions. The gate is ONLY for SeedSampleCcEntitiesAsync + the two Dev-RTS seeds.

## DESIGN (no migration, no schema touch — coordinator FORK1=(B))
**1. New seam — `src/CcDashboard.Infrastructure/Seeding/SampleSeedGate.cs`** (internal static; testable without the heavy DatabaseInitializer ctor / Migrate):
```csharp
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Seeding;

internal static class SampleSeedGate
{
    /// <summary>
    /// True only when sample/test CC data should be seeded: the Seed:SampleData flag is on
    /// AND no real CC data already exists for the tenant (prod-mirror rebuild-safety, Prod-Mirror-Seed-Plan §3).
    /// Data-presence is the de-facto provenance sentinel (FORK1=B — no seed_provenance table).
    /// </summary>
    public static async Task<bool> ShouldSeedAsync(
        bool seedSampleData, BackendEmulationDbContext beDb, Guid tenantId, CancellationToken ct)
    {
        if (!seedSampleData) return false;                 // PRIMARY gate: flag off -> never seed sample
        // BELT: any real CC data for this tenant (prod-mirror re-stamped to OUR tenant, FORK2=2.4b) -> skip
        var hasRealData =
            await beDb.NgcQueues.IgnoreQueryFilters().AnyAsync(q => q.TenantId == tenantId, ct)
            || await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenantId, ct)
            || await beDb.NgcBusinessUnits.IgnoreQueryFilters().AnyAsync(b => b.TenantId == tenantId, ct);
        return !hasRealData;
    }
}
```
(If the real namespaces/DbSet names differ, match the file — object-store wins. The belt checks NGC tables: the prod-mirror load is atomic NGC+RTSData per plan §2, so NGC-presence is a correct proxy for "prod-mirror present".)

**2. `DatabaseInitializer.InitializeAsync`** — read the flag once + gate the sample + Dev-RTS seeds (replace l.57 + l.61-72 region):
```csharp
// Sample/test CC data gate — prod-mirror rebuild-safety (CLAUDE.md §29.8 + Prod-Mirror-Seed-Plan §3).
// Default FALSE: rebuilds NEVER re-seed sample data over a prod-mirror. (config[] parse — no Binder dep.)
var seedSampleFlag = bool.TryParse(config["Seed:SampleData"], out var f) && f;
var shouldSeedSample = await SampleSeedGate.ShouldSeedAsync(seedSampleFlag, beDb, platformTenant.Id, ct);

if (shouldSeedSample)
    await SeedSampleCcEntitiesAsync(platformTenant, ct);
else
    logger.LogInformation(
        "Sample CC seed SKIPPED (Seed:SampleData={Flag}) — prod-mirror rebuild-safety (flag off, or real CC data already present for the tenant).",
        seedSampleFlag);

await SeedAgentStateDefinitionsAsync(ct);   // SYSTEM — stays ungated, unchanged

// Dev-only RTSData test rows — ALSO gated (else FAKE interactions injected over real prod RTSData on a Dev-env box)
if (env.IsDevelopment() && shouldSeedSample)
{
    try
    {
        await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
        await SeedDevRtsUserStatusLogAsync(platformTenant.Id, ct);
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Dev RTS data seed skipped (non-critical)");
    }
}
```
Keep the exact existing method names/signatures; only ADD the flag read + the two `if` gates. Do NOT reorder the system seeds.

**3. Harden the brittle SITE001 probe inside `SeedSampleCcEntitiesAsync` (l.318)** — defense-in-depth (this method now only runs when no NGC data exists, but the directive explicitly requires removing the point-probe):
```csharp
// before:  !await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id && s.SiteId == "SITE001", ct)
// after:   !await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct)
```
(Replace the `SiteId == "SITE001"` point-probe with "any site for this tenant -> skip".)

## APPSETTINGS — NOT in this commit (territory + scope)
- Code default = FALSE ⇒ on the prod-mirror box, with NO config, sample seed is already skipped — the #1 invariant holds with zero extra config.
- Restoring normal-dev sample data (`"Seed": { "SampleData": true }`) is **RULED OUT on this machine** (coordinator 2026-06-26T01:00Z): our box IS the prod-mirror env AND runs as Development (§29.8) → setting the flag true would re-seed sample data over the mirror every rebuild = defeats the #1 invariant. Flag STAYS false (default). Do NOT touch appsettings; do NOT route to shell. (Restoring it on a SEPARATE real dev box = backlog, not now.)
- The prod-mirror box must NOT set the flag true (default-false = safe; devops/operator config step) — note only.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A core (⛔ЧП block) + §C verify
- Object-store grounding: `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` (InitializeAsync 32-75 + SeedSampleCcEntitiesAsync 273-411, esp. SITE001 l.318); `BackendEmulationDbContext` (DbSet names NgcQueues/NgcSites/NgcBusinessUnits + entity TenantId); an existing unit test that builds an EF in-memory context (e.g. tests/CcDashboard.Tests.Unit/Reports/ReportScreenCrudTests.cs) for the test harness pattern.

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; for every M file in your claim hash-verify vs HEAD (`git hash-object` vs `git rev-parse HEAD:<f>`, §0.5 — mount shows false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; verify `git rev-parse HEAD` == current v3 tip by FULL SHA (object-store, not just --abbrev-ref). If WT disagrees, restore from HEAD; if HEAD itself is unexpected, STOP + flag.
- §0.3 Python+fsync for any `.coord/` write; after each source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0). Edit tool BANNED — Python read→modify→write only.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP only on an OPEN FREEZE ACTIVE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs", "src/CcDashboard.Infrastructure/Seeding/SampleSeedGate.cs", "tests/CcDashboard.Tests.Unit/Seeding/SampleSeedGateTests.cs"]`. ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY these; `git status --short` pre-commit; post-commit `git show --stat` = ZERO deletions + only your files, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_backend_seeder_gate.md | status: open
### DIRECTIVE: prod-mirror rebuild-safety seeder gate — Seed:SampleData flag (default false) + data-presence belt (SampleSeedGate) gating SeedSampleCcEntitiesAsync + Dev-RTS seeds; SITE001 point-probe hardened. System seeds ungated. Claim: DatabaseInitializer.cs + SampleSeedGate.cs + SampleSeedGateTests.cs. gate: build 0 + unit GREEN. commit-prefix fix:.
```

## STEP 2 — implement (1) SampleSeedGate.cs new, (2) InitializeAsync gates, (3) SITE001 hardening. Match real namespaces/DbSet names from the object store.

## STEP 3 — TESTS — `tests/CcDashboard.Tests.Unit/Seeding/SampleSeedGateTests.cs` (xUnit + FluentAssertions; EF InMemory BackendEmulationDbContext, model on an existing unit test's context build)
Cases (all assert `SampleSeedGate.ShouldSeedAsync(...)`):
1. flag=false, empty DB → **false** (primary gate).
2. flag=true, empty DB → **true** (normal dev seeds).
3. flag=true, DB has one NgcQueue for tenant T → **false** (data-presence belt).
4. flag=true, DB has one NgcSite for tenant T (NO "SITE001") → **false** (replaces brittle SITE001 probe).
5. flag=false, DB has data → **false**.
6. flag=true, DB has data for a DIFFERENT tenant only → **true** (belt is per-tenant; FORK2=2.4b means prod lands in OUR tenant, so a foreign-tenant row must NOT block).

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → all GREEN incl. new SampleSeedGateTests (6/6). (Soma `/ops/build` + `/ops/test?suite=unit` OK as the run vehicle.)
- Object-store: only the 3 claimed files; zero deletions.
- ⚠ DEFINITIVE acceptance is RUNTIME (owned by QA on the prod-mirror box, NOT this prompt): with flag=false + prod-mirror loaded, N rebuilds/restarts leave NGC/RTSData_* counts IDENTICAL, ZERO sample/dev-fake rows reappear, login+reports work. State this in the RESULT for QA's seal.

## STEP 5 — commit (fix:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the 3 files ONLY → `git status --short` (zero D) → commit `fix(seed): gate sample/dev CC seeds behind Seed:SampleData flag + data-presence belt (prod-mirror rebuild-safety; harden SITE001 probe) [backend]` → §0.6 post-commit (`git show v3:<file>` == WT by hash; `git show --stat` zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 PD-007 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commit <hash> . files SampleSeedGate.cs(new) + DatabaseInitializer.cs(flag+2 gates+SITE001) + SampleSeedGateTests.cs(6) . build 0 . unit <N>/<N> GREEN . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store . RUNTIME N-rebuild acceptance -> QA seal pending
<paste build + unit output>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md (commit hash + confirm system seeds ungated + note QA owns the runtime N-rebuild seal). Do NOT route any appsettings dev-opt-in to shell — RULED OUT (this machine IS the prod-mirror + runs Development; flag stays false).

## ACCEPTANCE (GREEN gate)
- `SeedSampleCcEntitiesAsync` + both Dev-RTS seeds run ONLY when `SampleSeedGate.ShouldSeedAsync` is true (flag on AND no real CC data for the tenant). System seeds (Roles..AgentStateDefinitions) UNCHANGED + ungated.
- SITE001 point-probe replaced with per-tenant "any site → skip".
- Default false ⇒ zero-config prod-mirror box is safe. No migration / no schema change / no new DI.
- 2 source files + 1 test file (6 cases incl. per-tenant + SITE001-removal guard); ZERO deletions; fix: on v3; commit.lock; NO push. Binding PRE+POST written. Appsettings dev-opt-in flagged to coordinator (Web territory), NOT in this commit.
