# CC task — Defect K fix: NGC config handlers must flush BackendEmulationDbContext — AWAITING §4-REVIEW
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `fix(web):`. **NO push** (§37). ⛔ЧП.
> Operator OK'd option (a). §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for coordinator §4 BEFORE any run. No chat run-box until bless.

## ROOT (object-store @ v3 HEAD f486e4c — diagnosed + operator-confirmed)
NGC config command handlers (Site/BusinessUnit/Supergroup Save+Delete) Add/Update/Delete NGC entities in `BackendEmulationDbContext` (beDb) via their repo, but NEVER flush beDb. `TransactionBehavior` → `IUnitOfWork.SaveChangesAsync` saves ONLY `AppDbContext` (UnitOfWork.cs:8-14, by design — "beDb saved directly ... including it caused concurrent SaveChangesAsync"). `beDb.SaveChangesAsync` is called ONLY by the seeder. ⇒ each handler returns `Result.Success` while the NGC write sits unflushed → SILENT non-persist (modal closes, row never written, absent on reload). Existing rows render because the SEEDER flushed them.

## FIX — option (a): flush beDb explicitly in the config path (layering-safe via repo method)
⚠ Handlers are in **Application**; `BackendEmulationDbContext` is **Infrastructure** — do NOT inject beDb into an Application handler (ARCH dep rule). Instead expose `SaveChangesAsync` on the NGC repo interfaces (matches the existing repo/DI shape).

**1. `src/CcDashboard.Domain/Interfaces/INgcRepositories.cs`** — add to `INgcSiteRepository` (:5-11), `INgcBusinessUnitRepository` (:14-20), `INgcSupergroupRepository` (:23-29):
```csharp
Task SaveChangesAsync(CancellationToken ct = default);
```

**2. `src/CcDashboard.Infrastructure/Persistence/Repositories/NgcRepositories.cs`** — add to `NgcSiteRepository`, `NgcBusinessUnitRepository`, `NgcSupergroupRepository` (each ctor-injects `BackendEmulationDbContext db`):
```csharp
public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
```

**3. `src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs`** — in each of the 6 handlers, add `await repo.SaveChangesAsync(ct);` AFTER the Add/Update/Delete and (for Save handlers) BEFORE the `apiHook.NotifyAsync` (so RTM notify reads persisted data), else before `return`:
- `SaveSiteCommandHandler` — before `await apiHook.NotifyAsync("Site", ...)` (~:56).
- `DeleteSiteCommandHandler` — after `repo.Delete(site);`, before `return` (~:75-76).
- `SaveBusinessUnitCommandHandler` — before `await apiHook.NotifyAsync("BusinessUnit", ...)` (~:152).
- `DeleteBusinessUnitCommandHandler` — after `repo.Delete(bu);`, before `return` (~:171-172).
- `SaveSupergroupCommandHandler` — before `await apiHook.NotifyAsync("Supergroup", ...)` (~:232).
- `DeleteSupergroupCommandHandler` — after `repo.Delete(sg);`, before `return` (~:251-252).

⚠ CONCURRENCY GUARD (coordinator condition): `repo.SaveChangesAsync(ct)` (beDb) runs INSIDE the handler body (i.e. inside `next()`), which completes BEFORE `TransactionBehavior` calls `uow.SaveChangesAsync(ct)` (AppDbContext). They are SEQUENTIAL, on DIFFERENT contexts — never concurrent (that was the original concern that removed beDb from UoW). Do NOT add beDb to UnitOfWork. Do NOT call beDb + AppDbContext SaveChanges concurrently.

WHY correct: for a NEW BU/Supergroup, `SaveChangesAsync` generates the IDENTITY id and (via the configured NgcSupergroup↔AgentGroupAssignments relationship @BackendEmulationDbContext:147) fixes up the child FK → the returned `sg.SupergroupId`/`bu.BusinessUnitId` is now the real id (was 0). The row + mappings persist; reload shows them.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`; `.claude/skills/role-backend/role-backend.md` §A (⛔ЧП) + §C.
- Object-store grounding: ConfigurationCommands.cs (6 handlers Site/BU/SG Save+Delete); INgcRepositories.cs; NgcRepositories.cs; UnitOfWork.cs (only-AppDbContext); TransactionBehavior.

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git rev-parse --abbrev-ref HEAD` == **v3**; `git status --short`; hash-verify claimed files vs HEAD (§0.5); restore PD-007 truncation from HEAD first.
- §0.3 Python+fsync; Edit BANNED. After edits: `sync`+`tail -3`+`wc -l`+NUL(0). LF/no-BOM.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP on OPEN FREEZE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Domain/Interfaces/INgcRepositories.cs", "src/CcDashboard.Infrastructure/Persistence/Repositories/NgcRepositories.cs", "src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs", "tests/CcDashboard.Tests.Unit/Commands/Configuration/**"]`. NARROW-ADD (L-SC-09): `git add` ONLY these; post-commit `git show --stat` = only these files, zero deletions, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync. **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_defect_k_flush_bedb.md | status: open
### DIRECTIVE: Defect K — NGC config handlers flush beDb. Add repo.SaveChangesAsync (Site/BU/SG interfaces+impls) + call it in the 6 Save/Delete handlers before apiHook/return (sequential, inside next(), before UoW AppDbContext save). Claim: INgcRepositories.cs + NgcRepositories.cs + ConfigurationCommands.cs + test. gate: build 0 + unit failed 0. fix(web):.
```

## STEP 2 — implement (1)+(2)+(3) above.

## STEP 3 — TEST — `tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveSupergroupPersistTests.cs` (xUnit + FluentAssertions + mocked INgcSupergroupRepository + ICurrentUserAccessor + IDateTimeProvider + IConfigurationApiHook)
Assert the handler now FLUSHES: mock `INgcSupergroupRepository`; SaveSupergroupCommandHandler on a new SG → verify `repo.AddAsync` AND `repo.SaveChangesAsync` were called (SaveChangesAsync at least once); DeleteSupergroupCommandHandler → verify `repo.Delete` AND `repo.SaveChangesAsync` called. (This locks the regression: no SaveChangesAsync = the bug.)

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → failed=0 (counts) incl. the new persist tests. (Soma /ops/build + /ops/test?suite=unit.)
- Object-store: only the 4 claimed paths; zero deletions.
- ⚠ ACCEPTANCE (runtime, coordinator/operator on 140 after Shell rebuild+redeploy): create Super Group "ZZTestSG" → RELOAD → it PERSISTS in the list; same for Site + BusinessUnit create/update/delete.

## STEP 5 — commit (fix(web):, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` claimed files ONLY → `git status --short` (zero unrelated D) → commit `fix(web): NGC config handlers flush BackendEmulationDbContext (Site/BU/Supergroup Save+Delete) - silent non-persist [backend]` → §0.6 post-commit → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> . files INgcRepositories.cs + NgcRepositories.cs + ConfigurationCommands.cs(6 handlers) + SaveSupergroupPersistTests.cs . build 0 . unit passed/failed <N>/<N> . only-claimed/zero-deletion . status done|failed . verified: object-store . 140 persist-seal -> coordinator/operator
<paste build + unit output>
```
Relay a 2-line digest to inbox/coordinator.md (commit + confirm all 6 handlers flush beDb + concurrency ordering held).

## ACCEPTANCE (GREEN gate)
- `SaveChangesAsync` on the 3 NGC repo interfaces + impls (=> beDb.SaveChangesAsync). All 6 Save/Delete handlers (Site/BU/SG) call `await repo.SaveChangesAsync(ct)` after Add/Update/Delete, before apiHook/return — sequential, before UoW AppDbContext save; beDb NOT added to UoW.
- Unit test locks the regression (repo.SaveChangesAsync called on save+delete).
- build 0 + unit failed 0; 4 paths; ZERO deletions; fix(web): on v3; commit.lock; NO push. Binding PRE+POST. Concurrency ordering stated.
