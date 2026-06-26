# CC task — F-QA-9 / ARCH-11 Phase R2: move remaining 7 handler files → Architecture suite GREEN 8/8

> Coordinator-authored (operator-directed) per decisions/ADR-009. Owner: BACKEND. Executor: native CC.
> Branch **v3**. Commit `refactor:`. **NO push** (§37). FREE/MIT only.
> Builds on R1 (f4a9b93). SCOPE R2 = move the remaining **20 handlers across 7 files** out of Infrastructure
> into Application via the R1 seam, so `MediatR_handlers_should_live_in_Application_only` turns GREEN and
> **Tests.Architecture = 8/8**. This is the v3-push-unblocker. NO behaviour change to any handler logic.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A+§C (executing role)
- `decisions/ADR-009-mediatr-handlers-in-application.md` (R2 phasing + Special cases)
- The R1 result: `IAppDbContext`/`IBackendEmulationDbContext`/`IBackendEmulationDbContextFactory` interfaces (Application.Interfaces) + their impls — REUSE/EXTEND, do not duplicate.
Only after reading: proceed.

## INIT — branch v3 + integrity + sync + DISCIPLINE
- `git checkout v3`; verify BOTH `git rev-parse --abbrev-ref HEAD`=v3 AND `git rev-parse HEAD`==v3 tip by-SHA (object-store, §0.5). Expected tip at authoring = f4a9b93 — confirm current tip by-SHA before commit.
- §0.2 integrity. ⚠ Mount note (backend flagged R1): a STALE `Infrastructure/Handlers/AgentStateHandlers.cs` may linger in the Cowork mount (git CLEAN, unlink blocked §0.4) — benign; a native checkout won't have it. Confirm git object-store is clean, do NOT chase the mount ghost.
- §0.3 writes Python+os.fsync on the mount (native-CC editor OK on Windows — verify object-store after).
- §42.6 sync: S1 `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (CLOSED tombstone → proceed). Slug = backend slug. Claims (file-mode): the 7 `src/CcDashboard.Infrastructure/Handlers/*.cs` files (DELETE — moved) + their new `src/CcDashboard.Application/Handlers/*.cs` (ADD); `src/CcDashboard.Application/Interfaces/IAppDbContext.cs` (EXTEND) + new `IAppDbContextFactory.cs`; `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs` (expose any newly-needed DbSets on the interface — re-sync from HEAD first) + new `AppDbContextFactory` impl in Infrastructure; `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs` (remove Infra MediatR scan + register the new factory — re-sync first); Application DI extension if needed.
- ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY the files above; `git status --short` pre-commit; post-commit `git show --stat` deletions = EXACTLY the 7 moved Infra handler files and NOTHING else (each is a rename: delete Infra + add Application) — else `reset --hard HEAD~1` + STOP. commit.lock; §0.6b binding → `.coord/cc/backend.md`; NO push.

## THE WORK — move 7 files, route each ctor dep to the R1 seam (logic UNCHANGED)

Move each file `Infrastructure/Handlers/*.cs` → `Application/Handlers/*.cs`, namespace `CcDashboard.Application.Handlers`, remove `using CcDashboard.Infrastructure.Persistence;`. Swap ONLY the dependency TYPES (per the grounded map below). **Handler LINQ / logic / audit / UUIDNext / IgnoreQueryFilters / AsNoTracking — all UNCHANGED.**

| File | # | Ctor dep today | → route to |
|---|---|---|---|
| `HistoricalReportHandlers.cs` | 4 | `IHistoricalReportRepository` (already an Application abstraction) | **no change** — just move the file (deps already Application/Domain). |
| `DayTrendQueryHandler.cs` | 1 | `IDbContextFactory<BackendEmulationDbContext>` | `IBackendEmulationDbContextFactory` (R1, exists) |
| `GetUserWidgetSettingsQueryHandler.cs` | 1 | `IDbContextFactory<AppDbContext>` | **new `IAppDbContextFactory`** (add — mirror the BE factory) |
| `SaveUserWidgetSettingsCommandHandler.cs` | 1 | `IDbContextFactory<AppDbContext>` | `IAppDbContextFactory` |
| `DeleteUserWidgetSettingsCommandHandler.cs` | 1 | `IDbContextFactory<AppDbContext>` | `IAppDbContextFactory` |
| `InfoSlotHandlers.cs` | 12 | ground each (likely `AppDbContext` direct and/or `IDbContextFactory<AppDbContext>`) | `IAppDbContext` (extend with the DbSets they use) and/or `IAppDbContextFactory` |

### New `IAppDbContextFactory` (Application.Interfaces) + impl (Infrastructure)
Mirror R1's `IBackendEmulationDbContextFactory`: `Task<IAppDbContext> CreateDbContextAsync(CancellationToken ct = default)`, implemented over the EF `IDbContextFactory<AppDbContext>` in Infrastructure (the factory returns a context typed as `IAppDbContext`). Register it in `InfrastructureServiceExtensions`.

### Extend `IAppDbContext`
Add every `DbSet<T>` that InfoSlot (and any UserWidgetSettings access path) needs but R1 didn't include. Ground the exact sets from the handler bodies; `AppDbContext` already has the properties — just surface them on the interface. Keep raw-SQL/`Database` exposure from R1 if any handler needs it (CODE-01 parameterised only).

### Remove the Infrastructure MediatR scan
`InfrastructureServiceExtensions.cs:165-166` registers `AddMediatR(RegisterServicesFromAssemblyContaining<DayTrendQueryHandler>())`. After R2, ZERO handlers remain in Infrastructure → **remove that registration** (and the now-dangling `DayTrendQueryHandler` reference). ⚠ FIRST confirm the Infra assembly has NO OTHER MediatR types that scan needs (e.g. `INotificationHandler`, pipeline behaviours) — if it does, narrow the scan or relocate them; do NOT silently drop a needed registration. Ensure the **Application** `AddMediatR` scan now covers ALL moved handlers (it already scans the Application assembly).

## VERIFY (build + tests + object-store) — THIS IS THE GREEN GATE
- `dotnet build CcDashboard.sln` = 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` GREEN (logic unchanged).
- `dotnet test tests/CcDashboard.Tests.Architecture` = **8/8 GREEN** — specifically `MediatR_handlers_should_live_in_Application_only` now passes (ZERO IRequestHandler in Infrastructure) AND `Application_should_not_depend_on_Infrastructure` STILL GREEN (moved handlers depend only on Application interfaces + EF Core). Report both explicitly.
- Functional sanity: a moved query from each family resolves (InfoSlot, HistoricalReport, DayTrend, UserWidgetSettings) — via existing tests or a smoke resolve; no MediatR "handler not registered" at runtime.
- Object-store: committed deletions = EXACTLY the 7 Infra handler files (each a rename to Application); no other deletion; no CLAUDE.md/unrelated sweep.

## COMMIT (refactor:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the explicit paths → commit -m "refactor(arch): F-QA-9 R2 — move remaining 20 handlers (InfoSlot/HistoricalReport/DayTrend/UserWidgetSettings) to Application + IAppDbContextFactory; drop Infra MediatR scan → Architecture 8/8 GREEN (ADR-009, ARCH-11 complete) [backend]" → §0.6 post-commit (git show v3:, verify the 7 deletes = the moved files only) → `bash tools/cc_post_commit.sh <slug> <hash>` → PD-007 re-sync → sync.

## Binding RESULT → .coord/cc/backend.md: commit hash; 7 files moved + IAppDbContextFactory + IAppDbContext extended + Infra MediatR scan removed; build 0; unit GREEN; **Tests.Architecture 8/8 GREEN** (MediatR-handlers GREEN + Application↛Infra GREEN); only-claimed/7-deletes-only; NO push. verified: object-store.
## REPORT (chat) + flag coordinator: arch 8/8 confirmation (the two key tests), any handler that needed an extra interface member. ⇒ F-QA-9 CLOSED, v3-push-blocker cleared. Next: Ф3 (shell) + the v3 push barrier (QA consolidated regression + security + techwriter quorum).
