# CC task — R3-primary: GetQueuesQuery Superadmin tenant fallback (report Scope picker empty)
> **§4-REVIEW: PASS — siblings-included** (coordinator-0624 2026-06-25T16:35Z). Root + the 1-line collapse `q.TenantId ?? user.TenantId!.Value` object-store-confirmed (non-Superadmin branch byte-identical → ZERO dashboard-picker regression). RULING: **siblings-included = YES** — object-store confirms the IDENTICAL Superadmin-null pattern at GetSites:20 / GetSupergroups:114 / GetQueues:159 / GetAgentGroups:174; the report agent-scope picker (BU→supergroups→agentgroups, Ф2) hits the same bug → apply the same collapse to ALL 4 + a Superadmin-fallback test for each, one narrow commit (same file), subject append '+ Sites/Supergroups/AgentGroups'. Integrity/branch-by-SHA + BINDING + commit.lock + narrow-add + NO push all present. CLEARED TO RUN.

> Owner: backend (slug backend-0620). Branch **v3**. Commit `fix:`. **NO push** (§37). FREE/MIT.
> HIGH — unblocks the report editor: the v1 editor core is non-functional until Scope (queues) is settable.
> §4-REVIEW: PENDING — backend-0620 self-§4 PASS; posted to inbox/coordinator.md for coordinator bless BEFORE the operator runs it.
> Coordinator-pinned root (object-store confirmed). Signature UNCHANGED (publish nothing new); shell re-checks the picker after.

## ROOT (object-store @ v3 — confirmed, do NOT re-derive)
- `GetQueuesQueryHandler.Handle` (src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs:159):
  ```csharp
  var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
  var items = await repo.GetAllByTenantAsync(tenantId, ct);
  ```
- `ReportWidgetConfigModal` calls `new GetQueuesQuery()` (no TenantId) → for **Superadmin** `tenantId = q.TenantId = null` → `repo.GetAllByTenantAsync(null)` → **EMPTY** picker. (Non-superadmin already falls back to `user.TenantId` → fine.)
- The intended behaviour (mirror `GetMyBusinessUnitsQuery` / `GetBusinessUnitsQuery:36` which uses `q.TenantId ?? user.TenantId` for ALL roles): a no-arg `GetQueuesQuery` resolves the caller's CURRENT tenant for Superadmin too. Superadmin uses impersonation (ARCH-02), so `user.TenantId` reflects the active tenant.

## FIX (exactly 1 line — narrow)
In `src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs` line ~159, change:
```csharp
var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
```
to:
```csharp
var tenantId = q.TenantId ?? user.TenantId!.Value;
```
WHY this exact form: the non-Superadmin branch was ALREADY `q.TenantId ?? user.TenantId!.Value` — collapsing to the uniform expression leaves the non-Superadmin path **byte-identical** (zero regression on the dashboard queue picker). It changes ONLY the Superadmin path: from `q.TenantId` (null when no-arg → empty) to `q.TenantId ?? user.TenantId` (current tenant when no-arg; an explicit q.TenantId for cross-tenant is STILL honoured). Strictly better.
Touch ONLY the GetQueuesQueryHandler line. Do NOT change GetQueuesQuery's record signature, the repo, or any sibling query (Sites/Supergroups/AgentGroups) in this commit — see SIBLINGS note below; those are gated on the coordinator's §4 ruling.

## ⚠ SIBLINGS (flagged to coordinator — do NOT touch unless the §4-PASS header says "siblings-included")
The IDENTICAL broken pattern (`Superadmin ? q.TenantId : (q.TenantId ?? user.TenantId!.Value)`) also exists in the SAME file at:
- `GetSitesQueryHandler` (:20), `GetSupergroupsQueryHandler` (:114), `GetAgentGroupsQueryHandler` (:174).
The report agent-scope picker (BU membership → supergroups/agentgroups, Ф2) will be EMPTY for Superadmin for the same reason. RECOMMENDED to fold all 4 into this one narrow commit (same file, same 1-line transform, same test pattern). PENDING coordinator decision at §4-bless:
- If header = **siblings-included**: apply the same `q.TenantId ?? user.TenantId!.Value` collapse to :20/:114/:174 too, and add the same Superadmin-fallback test for each. Claim unchanged (same file). Commit subject append "+ Sites/Supergroups/AgentGroups".
- Else: GetQueuesQuery ONLY (this prompt as written); siblings → separate R3-secondary.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A core + §C verify
- Object-store grounding: `ConfigurationQueries.cs` (GetQueuesQueryHandler:154-163 + GetMyBusinessUnitsQuery:54-90 + GetBusinessUnitsQuery:30-38 for the fallback pattern); `ICurrentUserAccessor` (Role/TenantId); existing unit-query test style in `tests/CcDashboard.Tests.Unit/Queries/`.

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; for every M file in your claim hash-verify vs HEAD (`git hash-object` vs `git rev-parse HEAD:<f>`, §0.5 — mount shows false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; verify `git rev-parse HEAD` == current v3 tip by FULL SHA (object-store, NOT just --abbrev-ref). If WT disagrees, restore from HEAD; if HEAD itself is unexpected, STOP + flag.
- §0.3 Python+fsync for any `.coord/` write; after the source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP only on an OPEN FREEZE ACTIVE. Slug = backend-0620. **Claim (file-mode)** = `["src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs", "tests/CcDashboard.Tests.Unit/Queries/GetQueuesQueryHandlerTests.cs"]`. ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY these; `git status --short` pre-commit; post-commit `git show --stat` = ZERO file-deletions + only your files, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_backend_r3_getqueues_superadmin_fallback.md | status: open
### DIRECTIVE: GetQueuesQuery Superadmin tenant fallback (q.TenantId ?? user.TenantId) so a no-arg query resolves current tenant for Superadmin (report Scope picker). Claim: ConfigurationQueries.cs + test. gate: build 0 + unit GREEN (Superadmin no-arg -> current-tenant queues; non-Superadmin unchanged; Superadmin explicit-TenantId honoured). commit-prefix fix:.
```

## STEP 2 — apply the 1-line change (above). (Siblings only if header = siblings-included.)

## STEP 3 — TESTS — `tests/CcDashboard.Tests.Unit/Queries/GetQueuesQueryHandlerTests.cs` (xUnit + FluentAssertions + mocks)
Mock `INgcQueueRepository` + `ICurrentUserAccessor`. Cases:
1. **Superadmin, no TenantId (the fix)** — `user.Role="Superadmin"`, `user.TenantId=T`, `new GetQueuesQuery()` ⇒ `repo.GetAllByTenantAsync(T, ...)` called (NOT null) ⇒ returns T's queues (assert non-empty mapped to QueueDto).
2. **Superadmin, explicit TenantId (cross-tenant preserved)** — `new GetQueuesQuery(Other)` ⇒ `repo.GetAllByTenantAsync(Other, ...)`.
3. **Non-Superadmin, no TenantId (regression guard)** — `user.Role="Administrator"`, `user.TenantId=T` ⇒ `repo.GetAllByTenantAsync(T, ...)` (unchanged behaviour).
(If siblings-included: add case 1 for Sites/Supergroups/AgentGroups handlers too.)

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → all GREEN incl. new GetQueuesQueryHandlerTests. (Soma `/ops/build` + `/ops/test?suite=unit` OK as the run vehicle.)
- Object-store: only the 2 claimed files; zero deletions.

## STEP 5 — commit (fix:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the 2 files ONLY → `git status --short` (zero D) → commit `fix(reports): GetQueuesQuery Superadmin tenant fallback — no-arg query resolves current tenant (report Scope picker no longer empty) [backend]` → §0.6 post-commit (`git show v3:<file>` == WT by hash; `git show --stat` zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0620 <hash>` → PD-007 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commits <hash> . files ConfigurationQueries.cs(1 line, GetQueuesQuery) + GetQueuesQueryHandlerTests.cs(+) . build 0 . unit <N>/<N> GREEN . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store
<paste build + unit output>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md (commit hash + confirm non-Superadmin unchanged + restate the siblings decision taken).

## ACCEPTANCE (GREEN gate)
- GetQueuesQueryHandler tenantId = `q.TenantId ?? user.TenantId!.Value` (uniform). Superadmin no-arg → current-tenant queues (not empty); non-Superadmin path byte-identical; Superadmin explicit-TenantId still honoured.
- Tests cover Superadmin-no-arg / Superadmin-explicit / non-Superadmin-regression — output pasted.
- Signature UNCHANGED (no new publish). 1-file logic change + 1 test file; ZERO deletions; NO migration. fix: on v3, commit.lock, NO push. Binding PRE+POST written.
