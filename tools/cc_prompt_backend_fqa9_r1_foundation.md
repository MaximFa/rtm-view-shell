# CC task — F-QA-9 / ARCH-11 Phase R1: IAppDbContext foundation + move AgentStateHandlers (proof)

> Coordinator-authored (operator-directed) per decisions/ADR-009. Owner: BACKEND. Executor: native CC.
> Branch **v3**. Commit `refactor:`. **NO push** (§37). FREE/MIT only.
> SCOPE R1 = the IAppDbContext/IBackendEmulationDbContext abstraction + DI + move ONE handler file
> (`AgentStateHandlers.cs`, 9 handlers, the F-QA-9 origin) as the pattern proof. The arch test
> `MediatR_handlers_should_live_in_Application_only` will STILL be RED after R1 (21 handlers remain in
> the other 7 files) — that is EXPECTED; R2 finishes it. R1 gate = solution BUILDS + AgentState handlers
> run + the pattern is proven. NO behaviour change to any handler logic.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A+§C (executing role)
- `decisions/ADR-009-mediatr-handlers-in-application.md` (the authoritative design — Decision + Special cases + Phasing R1)
- CLAUDE.md §3 (dependency rules), §7 (EF conventions: AsNoTracking on reads, FromSqlInterpolated only — CODE-01)
Only after reading: proceed.

## INIT — branch v3 + integrity + sync + DISCIPLINE
- `git checkout v3`; verify BOTH `git rev-parse --abbrev-ref HEAD`=v3 AND `git rev-parse HEAD`==v3 tip (object-store, post-incident branch-by-SHA; NOT just --abbrev-ref, §0.5). Expected v3 tip at authoring = e40a3dc — confirm current tip by-SHA before commit.
- §0.2 integrity. §0.3 writes Python+os.fsync on the mount (native-CC editor OK on Windows — verify object-store after).
- §42.6 sync: S1 `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (CLOSED tombstone → proceed). Slug = backend slug. Claims (file-mode): `src/CcDashboard.Application/Interfaces/IAppDbContext.cs` + `IBackendEmulationDbContext.cs` + `IBackendEmulationDbContextFactory.cs` (new); `src/CcDashboard.Application/CcDashboard.Application.csproj` (add EF Core ref — re-sync from HEAD first); `src/CcDashboard.Application/Handlers/AgentStateHandlers.cs` (new, moved); `src/CcDashboard.Infrastructure/Handlers/AgentStateHandlers.cs` (DELETE — the move); `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs` + `BackendEmulationDbContext.cs` (implement interface — re-sync from HEAD first); the Infrastructure + Application DI extension files (`*ServiceExtensions.cs` — re-sync first).
- ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY the files above; `git status --short` pre-commit; post-commit `git show --stat` = the moved file shows as DELETE in Infrastructure + ADD in Application and NOTHING ELSE deleted — else `reset --hard HEAD~1` + STOP. commit.lock; §0.6b binding → `.coord/cc/backend.md`; NO push.

## THE WORK (ADR-009 §Decision — the IAppDbContext seam)

### 1. EF Core ref in Application
Add `<PackageReference Include="Microsoft.EntityFrameworkCore" Version="<MATCH Infrastructure's EF Core version>" />` to `CcDashboard.Application.csproj` (ground Infrastructure's exact version by object-store and match it; EF Core 8.x). This is permitted (arch test forbids the `CcDashboard.Infrastructure` namespace, not the EF Core NuGet).

### 2. Interfaces in `CcDashboard.Application/Interfaces/`
- **`IAppDbContext`** — expose every `DbSet<T>` that the AgentState handlers (and, looking ahead, R2 handlers — but R1 only NEEDS the AgentState sets; add the rest in R2 or now if trivial) reference, e.g. `DbSet<AgentStateDefinition> AgentStateDefinitions { get; }`, `DbSet<AgentState> AgentStates { get; }`, `DbSet<AgentStateGroup> AgentStateGroups { get; }`, plus `Task<int> SaveChangesAsync(CancellationToken ct = default)`. For raw-SQL/transaction needs expose `DatabaseFacade Database { get; }` (Microsoft.EntityFrameworkCore.Infrastructure — EF namespace, allowed). Keep R1 minimal — only what AgentStateHandlers uses; R2 extends.
- **`IBackendEmulationDbContext`** — expose the `DbSet<>`s the AgentState handler uses (`RtsGridMetrics`) + `SaveChangesAsync`.
- **`IBackendEmulationDbContextFactory`** — `Task<IBackendEmulationDbContext> CreateDbContextAsync(CancellationToken ct = default)` (wraps EF `IDbContextFactory<BackendEmulationDbContext>`; GetAgentStateDefinitions uses the factory for isolated context — preserve that).

### 3. Implement on the contexts (Infrastructure)
- `AppDbContext : DbContext, IAppDbContext` — the `DbSet<>` properties already exist; just add the interface to the class declaration (and `DatabaseFacade Database` is inherited). No behaviour change.
- `BackendEmulationDbContext : DbContext, IBackendEmulationDbContext` — same.
- New `BackendEmulationDbContextFactory : IBackendEmulationDbContextFactory` in Infrastructure wrapping the injected `IDbContextFactory<BackendEmulationDbContext>`.

### 4. Move `AgentStateHandlers.cs` → `src/CcDashboard.Application/Handlers/AgentStateHandlers.cs`
- Change namespace to `CcDashboard.Application.Handlers`.
- Swap ctor deps: `AppDbContext db` → `IAppDbContext db`; `IDbContextFactory<BackendEmulationDbContext> beDbFactory` → `IBackendEmulationDbContextFactory beDbFactory` (call `await beDbFactory.CreateDbContextAsync(ct)`). All 9 handlers (3 query + 6 command).
- Handler **logic UNCHANGED** — same LINQ, same IgnoreQueryFilters/AsNoTracking, same UUIDNext, same audit calls. Only the dependency TYPES change. Remove the `using CcDashboard.Infrastructure.Persistence;` (now via interface).
- DELETE `src/CcDashboard.Infrastructure/Handlers/AgentStateHandlers.cs`.

### 5. DI wiring
- Infrastructure `InfrastructureServiceExtensions`: `services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());` + same for `IBackendEmulationDbContext` (scoped over the existing registration) + `services.AddSingleton<IBackendEmulationDbContextFactory, BackendEmulationDbContextFactory>();`.
- MediatR handler registration: the moved handlers are now in the Application assembly — ensure MediatR scans Application (it already does for existing Application handlers). Confirm the AgentState handlers are discovered (build + a quick resolve), and that they are NO LONGER registered from the Infrastructure assembly scan (if Infrastructure had an explicit MediatR scan, the moved types are gone from it automatically).

## VERIFY (build + tests + object-store)
- `dotnet build CcDashboard.sln` = 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` GREEN (AgentState handler unit tests, if any, still pass — logic unchanged).
- `dotnet test tests/CcDashboard.Tests.Architecture` — `Application_should_not_depend_on_Infrastructure` MUST stay GREEN (the moved handlers depend only on Application interfaces + EF Core, NOT the Infrastructure namespace — confirm). `MediatR_handlers_should_live_in_Application_only` will still be RED (21 handlers remain) — REPORT the exact remaining failing-type count to confirm only the non-moved handlers remain.
- Functional sanity: AgentState Definitions query resolves + returns (the F-QA-9 origin handler) — via existing test or a smoke resolve.
- Object-store: committed set = ONLY the claimed paths; the ONLY deletion is `Infrastructure/Handlers/AgentStateHandlers.cs`; no other file deleted; no CLAUDE.md/unrelated sweep.

## COMMIT (refactor:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the explicit paths → commit -m "refactor(arch): F-QA-9 R1 — IAppDbContext/IBackendEmulationDbContext seam + move AgentStateHandlers to Application (ADR-009, ARCH-11 foundation) [backend]" → §0.6 post-commit (git show v3:, verify single-delete) → `bash tools/cc_post_commit.sh <slug> <hash>` → PD-007 re-sync → sync.

## Binding RESULT → .coord/cc/backend.md: commit hash; interfaces + 2 context impls + factory + moved AgentStateHandlers + DI; build 0; unit GREEN; Application_should_not_depend_on_Infrastructure GREEN; MediatR-handlers test still RED with exactly N remaining (report N); only-claimed/single-delete; NO push. verified: object-store.
## REPORT (chat) + flag coordinator: build status, remaining-handler count, any interface-surface gap discovered (e.g. a raw-SQL/Database use needing extra interface members). R2 (move remaining 7 files → arch test GREEN) is the next phase.
