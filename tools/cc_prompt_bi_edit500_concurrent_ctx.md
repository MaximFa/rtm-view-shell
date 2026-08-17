# CC TASK — EDIT-500: concurrent-DbContext root fix (InfoSlot widget-data path)

> Owner: role-bi (bi-0626). Branch: v3 (ONLY branch). status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП PRIORITY #1 BLOCKER — no-run-without-bless. Operator: nothing moves until screen "12" (ca5c23ac) view/edit stops 500-ing.
> 234 Serilog: `System.InvalidOperationException: A second operation was started on this context instance ... concurrently
> using the same DbContext` at GetInfoSlotWidgetDataQuery → unhandled in Blazor Renderer → HTTP 500. Same CLASS as R2. NO push.

## TRACE — CONFIRMED (object-store, origin/v3; NOT a guess)
- `GetInfoSlotWidgetDataQueryHandler` (InfoSlotHandlers.cs:187-233) IS factory-isolated for ITS OWN queries: `await using var db = await dbFactory.CreateDbContextAsync(ct)` (L196) — InfoSlots/InfoSlotMessages read on the FRESH context. GOOD.
- **THE RACE (L218):** `var users = await userRepo.GetDisplayNamesAsync(userIds, ct);` — `IUserRepository userRepo` (ctor L189) is `UserRepository(AppDbContext db, UserManager ...)` (UserRepository.cs:8) → holds the **SHARED request-scoped AppDbContext**. GetDisplayNamesAsync (UserRepository.cs:80-91) queries THAT shared context. Screen "12" has ≥2 InfoSlot widgets rendering IN PARALLEL on one Blazor circuit → each GetInfoSlotWidgetDataQuery calls userRepo.GetDisplayNamesAsync CONCURRENTLY on the ONE shared scoped AppDbContext → "second operation started on this context" → 500. (The handler's own ctx is fine; the shared userRepo dependency is the site.)
- AuthorizationBehavior is NOT the site: GetInfoSlotWidgetDataQuery (InfoSlotQueries.cs:19) is `: IRequest<...>` only — NOT IRequiresPermission → the behavior's permission-resolve (PermissionService, shared ctx) never runs for it. Ruled out by code.
- CLASS scan: the OTHER factory widget-data handlers (GetUserWidgetSettings / SaveUserWidgetSettings / DeleteUserWidgetSettings) inject ONLY IAppDbContextFactory (no shared-scoped repo/service) → already clean. GetInfoSlotWidgetDataQueryHandler is the ONLY widget-data handler with the factory+shared-scoped-dependency anti-pattern.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + BRANCH SYNC + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD            # == v3 (only branch)
git rev-parse HEAD                          # local tip 6945fc0 = origin/v3 (1b5778a) + 1 no-op reconcile commit — NO divergence (coordinator-verified)
git status --short                          # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
BRANCH: work on the LOCAL tip (v3, 6945fc0 or later) and commit ON TOP. Do NOT `git reset --hard origin/v3` / do NOT "align" — it would wipe the reconcile_efmig_234 no-op commit. Step 0 = HEAD on v3 + hash-verify M files; that is all.
CLAIM (file-mode): src/CcDashboard.Application/Handlers/InfoSlotHandlers.cs + tests/CcDashboard.Tests.Unit/** (InfoSlot handler test) + .claude/skills/role-bi/role-bi.md (§B).
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## THE FIX — make GetInfoSlotWidgetDataQueryHandler fully self-contained on its factory context
Root-fix the class for the widget-data path: the factory-isolated handler must NOT call a shared-scoped dependency. Replace the shared-scoped userRepo call with an equivalent lookup on the handler's OWN factory `db`.
- EDIT 1 (L218): replace
  ```csharp
  var users = await userRepo.GetDisplayNamesAsync(userIds, ct);
  ```
  with (same query GetDisplayNamesAsync runs, but on the handler's OWN `db`):
  ```csharp
  var users = userIds.Count == 0
      ? new Dictionary<Guid, string>()
      : await db.Users.AsNoTracking().IgnoreQueryFilters()
          .Where(u => userIds.Contains(u.Id))
          .ToDictionaryAsync(u => u.Id, u => $"{u.FirstName} {u.LastName}".Trim(), ct);
  ```
  (`db` is the fresh factory `IAppDbContext` from L196; it exposes `.Users`. This is a VERBATIM copy of UserRepository.GetDisplayNamesAsync UserRepository.cs:80-91 — AsNoTracking + IgnoreQueryFilters + same Where(ids.Contains(u.Id)) + same `$"{FirstName} {LastName}".Trim()` format. **VERIFY semantic identity against the original BEFORE commit** (same filter incl IgnoreQueryFilters, same name format) — the handler test asserts it.)
- EDIT 2: REMOVE `IUserRepository userRepo` from the GetInfoSlotWidgetDataQueryHandler ctor (L189) — no longer used. Remove any now-unused using.
RESULT: the handler touches ONLY its own factory context → parallel InfoSlot widgets never share a context → no "second operation" → no 500 (view AND edit).
DO NOT touch UserRepository (it stays shared-scoped for its OTHER, sequential callers — user CRUD; factory-izing the whole repo would risk user-write transactions, R2-style read/write concern). DO NOT change data-semantics — this is concurrency/plumbing only.

## CLASS NOTE (report, no code unless found)
Confirmed the other factory widget-data handlers are already clean (no shared-scoped dependency). If, while building, the compiler/usage reveals ANOTHER widget-data handler with the same factory+shared-scoped anti-pattern, apply the same own-context fix + report it. The general rule: a factory-isolated widget-data handler must do ALL its DB work on its own context.

## ACCEPTANCE (DoD — hard)
1. **BUILD=0** (Soma /ops/build --no-incremental) — report it. 2. **UNIT failed=0 WITH COUNTS** (Soma /ops/test?suite=unit) — report passed/failed/skipped/total. 3. Add/adjust a unit test for GetInfoSlotWidgetDataQueryHandler that it resolves display names on its own context (no IUserRepository dependency) and returns the DTO. 4. Tests-only + the one handler; NO other prod change; NO migration. 5. NO push.
CLOSURE GATE (QA, prod-parity 234 mirror, coordinator-sequenced rebuild): a screen with ≥2 InfoSlot widgets → **view AND edit open without HTTP 500**.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify post-commit. commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `fix: InfoSlot widget-data handler self-contained on factory ctx — no shared-scoped userRepo (EDIT-500 concurrent DbContext) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT: the fix + BUILD result + UNIT COUNTS (failed=0) + object-store verify + status done. This is REBUILD-REQUIRING — coordinator sequences the rebuild/redeploy; do NOT expect it live from this commit alone.
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-07-03 · EDIT-500 concurrent-DbContext CLASS: a factory-isolated widget handler that CALLS a shared-scoped repo/service (IUserRepository on shared scoped AppDbContext) re-introduces the R2 race — parallel widgets on one Blazor circuit collide ("second operation on this context") → 500. Fix: the handler does ALL DB work on its OWN factory context (no shared-scoped dependency). Don't factory-ize the whole shared repo (write-transaction risk) — isolate the widget-read path. AuthorizationBehavior ruled out (query wasn't IRequiresPermission). · SOURCE: InfoSlotHandlers.cs:218 + UserRepository.cs:8 + coordinator EDIT-500 2026-07-03 · status: active`

## DO NOT
- Do NOT factory-ize / refactor UserRepository (shared-scoped is fine for its sequential callers).
- Do NOT touch data-semantics / AuthorizationBehavior / PermissionService. Do NOT commit to any branch except v3. NO migration / NO push.

## NOTE (coordinator-resolved)
The earlier mount "divergence" (local 6945fc0 ⊄ origin/v3) was an L-SC-20 FALSE ALARM: coordinator verified `git merge-base --is-ancestor 1b5778a 6945fc0` = YES → 6945fc0 = origin/v3 + 1 no-op reconcile commit, origin NOT ahead. Work on the local tip, do NOT reset.
