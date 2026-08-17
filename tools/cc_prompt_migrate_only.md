# CC task — RED DEFECT B: `Web.exe migrate` must be MIGRATE-ONLY (+ exit) — AWAITING §4-REVIEW
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `fix:`. **NO push** (§37).
> ⛔ЧП — THE 140 Design-B shakedown finding. Must land before the next server.
> §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for coordinator §4-review BEFORE the operator runs it. No chat run-box until bless.

## ROOT (object-store @ v3 — confirmed, do NOT re-derive)
`db/tools/Provision-FreshDb.ps1` [3/7] runs `CcDashboard.Web.exe migrate` BEFORE `schema.sql` [4/7]. But Program.cs has **NO migrate-arg branch** — the arg is ignored and the FULL app boots:
- `src/CcDashboard.Web/Program.cs:143` `var app = builder.Build();` → **:146-150** `initializer.InitializeAsync()` (migrate + **SEED**) → :177 `app.Run()` (starts hosted services + web host).
- `DatabaseInitializer.InitializeAsync` (`src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs:32`) does App+Audit `MigrateAsync` (:36-37) THEN seeds (:46-72). The SEED reads backend-emulation tables — `RTSGrid_Metric` (SeedRtsGridMetricsAsync ~:629) — and hosted services `ArchiverService`/`HistoricalAggregationService` read `NGC_Queues` (HistoricalAggregationService ~:215). Those tables are created LATER by `schema.sql` [4/7].
- Result: seed hits `42P01 relation does not exist` (swallowed), hosted services keep logging/running → **[3/7] HANGS**, never reaching schema.sql. Canonical order (migrate BEFORE schema.sql) is broken because `migrate` is not migrate-only.

## FIX — encapsulated migrate-only path (minimal-churn, 3 files)
**1. `src/CcDashboard.Infrastructure/Seeding/IDatabaseInitializer.cs`** — add to the interface:
```csharp
Task MigrateOnlyAsync(CancellationToken ct = default);
```

**2. `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs`** — extract the migration calls into `MigrateOnlyAsync`, and make `InitializeAsync` call it first (DRY, same MigrateAsync calls, incl the CC-1 drop-migration 46c6d4b which is an App migration applied by App `MigrateAsync`):
```csharp
public virtual async Task MigrateOnlyAsync(CancellationToken ct = default)
{
    logger.LogInformation("Applying EF migrations (App + Audit)...");
    await db.Database.MigrateAsync(ct);
    await auditDb.Database.MigrateAsync(ct);
    logger.LogInformation("EF migrations applied (App + Audit).");
}

public virtual async Task InitializeAsync(CancellationToken ct = default)
{
    logger.LogInformation("Running database seed...");
    await MigrateOnlyAsync(ct);            // App + Audit migrations (was inline :36-37)

    // Apply backend emulation migrations only in dev/test (UNCHANGED — keep the existing :40-44 block)
    if (env.IsDevelopment() || env.EnvironmentName == "Testing")
    {
        logger.LogInformation("Applying BackendEmulationDbContext migrations (dev/test mode)...");
        await beDb.Database.MigrateAsync(ct);
    }

    await SeedRolesAsync(ct);
    // ... REST OF THE EXISTING SEED BODY UNCHANGED (platform tenant, superadmin, widget, RtsGrid, history, sample-gate, agent-state, dev-rts) ...
}
```
⚠ Only REMOVE the two inline `await db.Database.MigrateAsync(ct); await auditDb.Database.MigrateAsync(ct);` lines at the top of InitializeAsync (now inside MigrateOnlyAsync) — DELETE NOTHING ELSE; the BE-migrate block + entire seed body stay byte-identical.

**3. `src/CcDashboard.Web/Program.cs`** — add the migrate-only branch immediately after `var app = builder.Build();` (:143), BEFORE the InitializeAsync block (:146):
```csharp
var app = builder.Build();

// migrate-only: apply EF migrations and EXIT — no seed, no hosted services, no web host.
// Canonical fresh-install ordering (DEPLOY-14): `Web.exe migrate` runs BEFORE schema.sql, so backend tables don't exist yet.
if (args.Any(a => string.Equals(a, "migrate", StringComparison.OrdinalIgnoreCase)))
{
    using var migrateScope = app.Services.CreateScope();
    var migrator = migrateScope.ServiceProvider.GetRequiredService<IDatabaseInitializer>();
    await migrator.MigrateOnlyAsync();
    Log.Information("migrate-only complete — exiting (no seed, no hosted services, no web host).");
    return;   // exits the top-level try -> finally (Log.CloseAndFlush) -> process exits. app.Run() never called => hosted services never start.
}

// Run database seed on normal startup (backend tables exist by now in the canonical flow)
using (var scope = app.Services.CreateScope())
{
    var initializer = scope.ServiceProvider.GetRequiredService<IDatabaseInitializer>();
    await initializer.InitializeAsync();
}
```
- `IDatabaseInitializer` is already resolved here; `using CcDashboard.Infrastructure.Seeding;` is already present (:11). No new usings needed. `System.Linq` (for `args.Any`) is implicit-usings-on.
- Do NOT touch any other Program.cs line (middleware/hosted-service registration/app.Run stay as-is).

## WHY this is correct
- migrate-only resolves `IDatabaseInitializer` and calls ONLY `MigrateOnlyAsync` (App+Audit) → creates ONLY shell tables → NO seed (no `RTSGrid_Metric`/backend reads) → NO `42P01`.
- `return` before `app.Run()` → hosted services (`ArchiverService`/`HistoricalAggregationService`) NEVER start → no `NGC_Queues` read → no hang; process exits promptly.
- Normal Shell startup (no `migrate` arg) is byte-unchanged: `InitializeAsync` still migrates THEN seeds — and in the canonical flow that start happens AFTER schema.sql + data, so backend tables exist.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`; `.claude/skills/role-backend/role-backend.md` §A core (⛔ЧП) + §C.
- Object-store grounding: Program.cs (18-30 top-level try/Serilog, 143-150 build+init, 174-177 app.Run); DatabaseInitializer.cs (32-75 InitializeAsync); IDatabaseInitializer.cs.

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; hash-verify each claimed M file vs HEAD (§0.5 false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; `git rev-parse HEAD` == v3 tip by FULL SHA (object-store). If HEAD unexpected STOP + flag.
- §0.3 Python+fsync; Edit BANNED. After each edit: `sync` + `tail -3` + `wc -l` + NUL-check(0). Preserve file LF/no-BOM.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP on OPEN FREEZE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Infrastructure/Seeding/IDatabaseInitializer.cs", "src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs", "src/CcDashboard.Web/Program.cs"]`. ⚠ Program.cs is in shell's [web] — coordinator de-conflicts (see §4 note); do NOT touch other Web files. NARROW-ADD (L-SC-09): explicit `git add` of ONLY these 3; post-commit `git show --stat` = zero deletions + only these files, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync. **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_migrate_only.md | status: open
### DIRECTIVE: RED DEFECT B — Web.exe migrate = migrate-only+exit. Add IDatabaseInitializer.MigrateOnlyAsync (App+Audit), InitializeAsync calls it then seeds; Program.cs migrate-arg branch calls MigrateOnlyAsync + return (no seed/hosted/web). Claim: IDatabaseInitializer.cs + DatabaseInitializer.cs + Program.cs. gate: build 0 + unit failed 0. fix:.
```

## STEP 2 — implement the 3 edits above.

## STEP 3 — TESTS
No new unit test is required (the acceptance is a fresh-DB runtime behavior — see below — owned by devops/QA on the Provision flow; DatabaseInitializer's host-heavy ctor makes a migrate-only unit test brittle). REQUIRED: existing suite must not regress.

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors (report W count).
- `dotnet test tests/CcDashboard.Tests.Unit` → failed=0 (report passed/failed counts). (Soma `/ops/build` + `/ops/test?suite=unit` OK.)
- Object-store: only the 3 claimed files; zero deletions.
- ⚠ DEFINITIVE acceptance is a FRESH-DB RUNTIME check (owned by devops/QA on Provision-FreshDb.ps1, NOT this prompt): `Web.exe migrate` on a fresh DB creates ONLY App+Audit tables, logs NO seed / NO Archiver/HistoricalAggregation, and EXITS (no hang, no 42P01); then schema.sql applies clean; normal Shell start seeds with backend present. State this for their seal.

## STEP 5 — commit (fix:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the 3 files ONLY → `git status --short` (zero D) → commit `fix(deploy): Web.exe migrate = migrate-only + exit (no seed/hosted services) — fresh-install ordering [backend]` → §0.6 post-commit (hash==HEAD; zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> . files IDatabaseInitializer.cs(+MigrateOnlyAsync) + DatabaseInitializer.cs(extract migrate) + Program.cs(migrate-arg branch) . build 0 . unit passed/failed <N>/<N> . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store . fresh-DB acceptance -> devops/QA seal pending
<paste build + unit output>
```
Relay a 2-line digest to inbox/coordinator.md (commit + confirm normal-startup seed path byte-unchanged + note devops/QA owns the fresh-DB migrate-only seal).

## ACCEPTANCE (GREEN gate)
- `Web.exe migrate` path calls ONLY MigrateOnlyAsync (App+Audit) + exits before seed/hosted-services/app.Run.
- Normal startup (no arg) byte-unchanged: InitializeAsync migrates then seeds.
- MigrateOnlyAsync on the interface + impl; InitializeAsync DRY (calls it). CC-1 drop-migration 46c6d4b applied by App MigrateAsync.
- build 0 + unit failed 0 (no regression); 3 files; ZERO deletions; fix: on v3; commit.lock; NO push. Binding PRE+POST. Fresh-DB acceptance flagged to devops/QA.
