# CC task — F-QA-10: fix DI captive-dependency (IAppDbContextFactory Singleton→Scoped)

> Owner: backend (slug backend-0620). Branch **v3**. Commit `fix(di):`. **NO push** (§37). FREE/MIT.
> v3-PUSH BLOCKER: v3 tip 9eb8c29 does NOT start — DI ValidateOnBuild (Development) trips a captive dependency. arch 8/8 + unit 146/146 + build are GREEN but CANNOT catch DI lifetime validation — only runtime startup does (QA test-5-0607 14:01).
> **§4-REVIEW: PASS** — coordinator-0624 2026-06-24T14:46Z. Object-store verified: line 50 AppDbContext factory inner = Scoped; line 74 = the captive Singleton; line 80 BE factory = Singleton-wraps-Singleton (default AddDbContextFactory, NOT captive — leave). 1-file/1-line narrow OK; binding PRE+POST present; branch-by-SHA 9eb8c29; NO push. **CLEARED TO RUN.**

## ROOT (confirmed, object-store @ v3 — do NOT re-derive)
- `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs:74`: `services.AddSingleton<IAppDbContextFactory, AppDbContextAbstractionFactory>();`
- `AppDbContextAbstractionFactory` (Persistence/AppDbContextFactory.cs) ctor consumes `IDbContextFactory<AppDbContext> inner`, which is registered **SCOPED** (`AddDbContextFactory<AppDbContext>(..., ServiceLifetime.Scoped)`, line 50).
- **Singleton consuming Scoped = captive dependency** → ValidateOnBuild: "Cannot consume scoped service IDbContextFactory`1[AppDbContext] from singleton IAppDbContextFactory" → host never binds 5239 (Soma healthy:false / conn-refused). Surfaced via the moved handler `GetUserWidgetSettings` (consumes IAppDbContextFactory).

## PRE-GROUND (already verified by backend-0620 @ v3 — context, do NOT re-litigate)
1. `AppDbContextAbstractionFactory` is STATELESS — it only wraps `inner` and delegates `CreateDbContextAsync` (no singleton-required state). → safe to register **Scoped** (no need for scope-per-call / IServiceScopeFactory).
2. ALL consumers of IAppDbContextFactory are MediatR handlers (DeleteUserWidgetSettings, GetUserWidgetSettings, InfoSlotHandlers, SaveUserWidgetSettings) = transient/scoped. NO singleton consumes it → Scoped registration is safe.
3. ⚠ DO NOT touch `IBackendEmulationDbContextFactory` (line 80): its wrapped `IDbContextFactory<BackendEmulationDbContext>` is **Singleton** (default `AddDbContextFactory`, line 63 — no ServiceLifetime arg), so Singleton-wrapping-Singleton = NO captive dep. Leave it. Only the App one is broken.

## FIX (exactly 1 line — narrow)
In `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs` line ~74, change:
```csharp
services.AddSingleton<IAppDbContextFactory, AppDbContextAbstractionFactory>();
```
to:
```csharp
services.AddScoped<IAppDbContextFactory, AppDbContextAbstractionFactory>();
```
Nothing else. Do NOT change line 80 (BackendEmulation factory), the DbContextFactory registrations, or any handler.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A core + §C verify
- The registration context: InfrastructureServiceExtensions.cs lines 43-80 (confirm the App factory is Scoped, the line is 74±, the BE one stays Singleton).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; for every M file in your claim hash-verify vs HEAD (`git hash-object` vs `git rev-parse HEAD:<f>`, §0.5 — mount shows false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; verify `git rev-parse HEAD` == v3 tip **9eb8c29** (full SHA, NOT just --abbrev-ref — post-incident branch-by-SHA). If HEAD != 9eb8c29, STOP + flag.
- §0.3 Python+fsync for any `.coord/` write; after the source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP only on an OPEN FREEZE ACTIVE. Slug = backend-0620. **Claim (narrow, file-mode)** = `["src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs"]` (ONLY this file, ONLY line 74). commit.lock around commit (retry 5×60s on busy). pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_backend_fqa10_di_scoped.md | status: open
### DIRECTIVE: IAppDbContextFactory registration Singleton->Scoped (fix DI captive-dep, F-QA-10). Claim: InfrastructureServiceExtensions.cs (1 line). gate: app starts (ValidateOnBuild passes) + arch 8/8 + unit 146/146 + GetUserWidgetSettings resolves. commit-prefix fix(di):.
```

## STEP 2 — apply the 1-line change (above).

## STEP 3 — VERIFY (the GREEN gate — must PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Architecture` → **8/8 GREEN** (unchanged). `dotnet test tests/CcDashboard.Tests.Unit` → **146/146 GREEN** (unchanged).
- STARTUP PROOF (the actual fix): run the Shell in Development so DI ValidateOnBuild executes (e.g. `dotnet run --project src/CcDashboard.Web` against a dev DB, or the operator's Soma `/shell/start`). ASSERT + PASTE: host STARTS (binds 5239 / no AggregateException "Cannot consume scoped service ... from singleton"); a `GetUserWidgetSettings` resolve does not throw "handler not registered" / captive-dep.
- (QA test-5-0607 will re-run the runtime smoke to SEAL — the commit is "done" only after QA live-green.)

## STEP 4 — commit (fix(di):, commit.lock, NO push)
`bash tools/pre-commit-check.sh` → `git add src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs` (ONLY) → `git status --short` (zero D, only this M) → commit `fix(di): F-QA-10 — IAppDbContextFactory Singleton->Scoped (resolves ValidateOnBuild captive-dependency; host starts) [backend]` → §0.6 post-commit (`git show v3:<file>` == working tree by hash; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0620 <hash>` → PD-007 re-sync → sync. **NO push.**

## STEP 5 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commits <hash> . files InfrastructureServiceExtensions.cs(1 line Singleton->Scoped) . build 0 . arch 8/8 . unit 146/146 . startup PASS (host binds, no captive-dep) . status done|failed . blockers . verified: object-store
<paste the startup output: host started / DI ValidateOnBuild passed>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md.

## ACCEPTANCE (GREEN gate)
- App STARTS clean (host binds 5239 / DI ValidateOnBuild passes) — the defining proof.
- Tests.Architecture still 8/8; unit still 146/146. Moved handler GetUserWidgetSettings resolves at runtime.
- 1-file / 1-line narrow change (line 74 only); BackendEmulation factory (line 80) UNTOUCHED. commit fix(di): on v3, commit.lock, NO push. Binding written.
- QA (test) re-runs the runtime smoke to SEAL — commit "done" only after QA live-green.
