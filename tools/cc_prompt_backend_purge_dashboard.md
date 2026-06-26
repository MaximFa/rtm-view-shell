# CC task — HARD-DEL-01b: PurgeDashboardCommand (permanent hard delete from Trash)
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T09:20Z). PERMISSION RULING (operator): Delete-perm (HasDashboardAccessAsync level=4) OR Superadmin + frontend confirmation — as authored, NO tighten. Grounded (existing HasDashboardAccessAsync; FK onDelete:Cascade → Remove(dashboard); GetDeletedByIdAsync + !IsDeleted reject; idempotent RTS sweep; audit Dashboard.PermanentlyDeleted; NO migration; 6 tests). All blocks present. CLEARED TO RUN (independent, parallel; publish signature for shell 01c). Note: flag techwriter to add Dashboard.PermanentlyDeleted + ReportScreen.PermanentlyDeleted to CLAUDE.md §16 audit list (doc, non-blocking).

> Owner: backend (slug backend-0620). Branch **v3**. Commit `feat:`. **NO push** (§37). FREE/MIT.
> Operator directive (coordinator-0624 2026-06-25T08:30Z): Trash delete-icon = HARD/permanent delete.
> You own the **DASHBOARDS** backend half (Application/Commands/Dashboards). bi owns the Reports half separately — DO NOT touch report_*.
> SCOPE = a NEW `PurgeDashboardCommand(Guid Id)` only: PHYSICAL delete of an ALREADY soft-deleted dashboard + cascade. NO UI, NO migration, NO report code.
> §4-REVIEW: PENDING — backend-0620 self-§4 PASS; posted to inbox/coordinator.md for coordinator bless BEFORE the operator runs it.

## ROOT / GROUNDING (object-store @ v3 — confirmed, do NOT re-derive)
- **Existing soft-delete** `DeleteDashboardCommand` (Commands/Dashboards/DeleteDashboardCommand.cs): `IRequest, ITransactional, IAuditable`, `AuditEventType="Dashboard.Deleted"`. Deps `IDashboardRepository dashboards, IRtsRepository rtsRepository, ICurrentUserAccessor currentUser, IDateTimeProvider clock`. It loads via `GetByIdWithWidgetsAsync(id, bypassTenantFilter: isSuperadmin, ct)`, cleans RTS rows per widget (AgentGrid → `GetColumnsSetIdByGridIdAsync`+`DeleteGridAsync`+`DeleteColumnsSetAsync`; QueueGrid → `ExtractQueueGridId(ConfigJson)`+`DeleteQueueGridAsync`), then sets `IsDeleted=true/DeletedAt/DeletedByUserId`. **NOTE: RTS rows are already cleaned at SOFT-delete time** — so a Trash item's RTS grids are normally already gone (purge re-runs the same cleanup IDEMPOTENTLY as a safety net; the Delete* calls are no-ops if the row is absent).
- **`RestoreDashboardCommand`**: fetches the soft-deleted item via `dashboards.GetDeletedByIdAsync(id, ct)` (bypasses the `!IsDeleted` GQF; tenant-scoped). This is the fetch pattern for a Trash item.
- **`IDashboardRepository`** (Application/Interfaces/IDashboardRepository.cs) ALREADY exposes everything needed — DO NOT add methods:
  - `Task<Dashboard?> GetByIdWithWidgetsAsync(Guid id, bool bypassTenantFilter=false, CancellationToken ct=default)`
  - `Task<Dashboard?> GetDeletedByIdAsync(Guid id, CancellationToken ct=default)` — returns the soft-deleted row (IsDeleted=true) within tenant scope
  - `void Remove(Dashboard dashboard)` — physical delete (EF `Remove` → DELETE)
- **CASCADE is DB-level** (InitialCreate DDL 20260507135247_InitialCreate.cs): `dashboard_widgets` FK→`dashboards` `onDelete: Cascade` (line ~463); `dashboard_permissions` FK→`dashboards` `onDelete: Cascade` (line ~489). → `Remove(dashboard)` physically cascade-deletes its widgets + permissions at the DB. No need to manually remove those child collections.
- **Permission helper EXISTS** — `IPermissionService.HasDashboardAccessAsync(Guid? permissionGroupId, Guid tenantId, Guid dashboardId, int requiredLevel, CancellationToken ct)` (Domain/Interfaces/IPermissionService.cs) — `requiredLevel` bitmask View=1/Edit=2/**Delete=4**. Mirror the Reports analogue `DeleteReportScreenCommand` which guards `if ((accessLevel & 4) == 0) throw ForbiddenException("Delete permission required")` and Superadmin-bypasses via `currentUser.Role=="Superadmin"`.
- `Dashboard.PermanentlyDeleted` audit event = FREE-FORM string written by `AuditBehavior` (audit_logs.EventType is varchar(64)) — NO enum/registration needed. (Doc note: add it to CLAUDE.md §16 dashboard audit list — flag to techwriter, NOT code-blocking, NOT in this commit.)

## THE WORK — NEW file `src/CcDashboard.Application/Commands/Dashboards/PurgeDashboardCommand.cs`
Mirror `DeleteDashboardCommand`'s structure/usings. One record + one handler:

```csharp
public record PurgeDashboardCommand(Guid Id) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.PermanentlyDeleted";
    public object? AuditDetails => new { Id };
}
```

Handler deps (ground exact signatures from DeleteDashboardCommand): `IDashboardRepository dashboards, IRtsRepository rtsRepository, IPermissionService permissionService, ICurrentUserAccessor currentUser`. `Handle`:
1. `var isSuperadmin = currentUser.Role == "Superadmin";`
2. **Fetch the Trash item** — `var dashboard = await dashboards.GetDeletedByIdAsync(cmd.Id, ct) ?? throw new NotFoundException(nameof(Dashboard), cmd.Id);` (need widgets for the RTS sweep — if `GetDeletedByIdAsync` does NOT include `.Widgets`, ground it: use the deleted-fetch then, if widgets aren't loaded, fall back to `GetByIdWithWidgetsAsync(cmd.Id, bypassTenantFilter:isSuperadmin, ct)` AND assert its `IsDeleted`. Pick the one that returns a soft-deleted dashboard WITH its widgets; VERIFY by reading the repo impl `GetDeletedByIdAsync`/`GetByIdWithWidgetsAsync` in Infrastructure before coding — do not assume.)
3. **GUARD (only Trash items)** — `if (!dashboard.IsDeleted) throw new DomainException("Only a soft-deleted (Trash) dashboard can be permanently deleted.");` (use the project's existing exception type — ground `DomainException`/`ForbiddenException` from Domain.Exceptions; if a more specific validation exception is the convention, use it).
4. **PERMISSION (CODE-03, App-layer)** — if `!isSuperadmin`: `var tenantId = currentUser.TenantId ?? throw new ForbiddenException("Tenant context required."); var ok = await permissionService.HasDashboardAccessAsync(currentUser.PermissionGroupId, tenantId, dashboard.Id, 4 /*Delete*/, ct); if (!ok) throw new ForbiddenException("Delete permission required");`
5. **RTS sweep (idempotent safety-net)** — mirror `DeleteDashboardCommand`'s per-widget RTS cleanup over `dashboard.Widgets` (AgentGrid GridId path + QueueGrid ConfigJson path; reuse/replicate `ExtractQueueGridId`). The Delete* repo calls are no-ops if the rows were already removed at soft-delete. (Guarantees zero orphan RTS rows regardless of the soft-delete/restore history.)
6. **PHYSICAL delete** — `dashboards.Remove(dashboard);` (DB ON DELETE CASCADE removes dashboard_widgets + dashboard_permissions). ONE transaction (TransactionBehavior via `ITransactional`).

DO NOT: add repo methods, touch DeleteDashboardCommand/RestoreDashboardCommand, add a migration, change EF config, or touch any report_* code.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A core + §C verify
- Object-store reads to GROUND before coding: `DeleteDashboardCommand.cs`, `RestoreDashboardCommand.cs`, `IDashboardRepository.cs`, the Infra `DashboardRepository` impl of `GetDeletedByIdAsync`+`GetByIdWithWidgetsAsync`+`Remove` (does GetDeletedByIdAsync include Widgets?), `IPermissionService.cs`, `DeleteReportScreenCommand.cs` (perm-guard analogue), `Domain.Exceptions` (NotFound/Forbidden/Domain).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; for every M file in your claim hash-verify vs HEAD (`git hash-object` vs `git rev-parse HEAD:<f>`, §0.5 — mount shows false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; verify `git rev-parse HEAD` == current v3 tip by FULL SHA (object-store, NOT just --abbrev-ref — post-incident branch-by-SHA). If the working tree disagrees, restore from HEAD; if HEAD itself is unexpected, STOP + flag.
- §0.3 Python+fsync for any `.coord/` write; after the source write: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP only on an OPEN FREEZE ACTIVE. Slug = backend-0620. **Claim (file-mode, NEW)** = `["src/CcDashboard.Application/Commands/Dashboards/PurgeDashboardCommand.cs", "tests/CcDashboard.Tests.Unit/Commands/Dashboards/PurgeDashboardCommandTests.cs"]` (ground the exact existing unit-test folder convention for Dashboards command tests and place the test there). ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY these new files; `git status --short` pre-commit; post-commit `git show --stat` = ZERO file-deletions + only your files, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_backend_purge_dashboard.md | status: open
### DIRECTIVE: NEW PurgeDashboardCommand(Guid Id) — physical hard-delete of a soft-deleted dashboard + cascade (widgets/permissions via DB ON DELETE CASCADE) + idempotent RTS sweep. Guards: IsDeleted-only + Delete-perm(4)/Superadmin. Audit Dashboard.PermanentlyDeleted. Claim: PurgeDashboardCommand.cs + test. gate: build 0 + unit GREEN (purge cascade, IsDeleted guard, Delete-perm deny, Superadmin, tenant isolation). commit-prefix feat:.
```

## STEP 2 — implement PurgeDashboardCommand.cs (above).

## STEP 3 — TESTS (mandatory) — `PurgeDashboardCommandTests.cs` (xUnit + FluentAssertions + mocks)
Cover: (a) **purge cascade** — Remove(dashboard) called on the loaded soft-deleted dashboard (assert handler invokes `dashboards.Remove(...)`; cascade itself is DB-enforced — assert the Remove call, not EF cascade); (b) **IsDeleted guard** — a non-deleted dashboard ⇒ rejected (DomainException), no Remove; (c) **Delete-perm deny** — non-superadmin, `HasDashboardAccessAsync(...,4,...)==false` ⇒ ForbiddenException, no Remove; (d) **Superadmin bypass** — Role=="Superadmin" ⇒ no perm call, Remove invoked; (e) **tenant isolation** — `GetDeletedByIdAsync` returns null (other tenant / not found) ⇒ NotFoundException; (f) **RTS sweep idempotent** — widget with a GridId ⇒ the RTS Delete* call is attempted (mock verifies), absence ⇒ no throw. Mock `IDashboardRepository`, `IRtsRepository`, `IPermissionService`, `ICurrentUserAccessor`.

## STEP 4 — VERIFY (GREEN gate — must PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → all GREEN (incl. the new PurgeDashboardCommandTests). (Soma `/ops/build` + `/ops/test?suite=unit` acceptable as the run vehicle.)
- Object-store: only the 2 claimed files in the commit; zero deletions.

## STEP 5 — commit (feat:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the 2 new files ONLY → `git status --short` (zero D, only your A files) → commit `feat(dashboards): PurgeDashboardCommand — permanent hard-delete from Trash (IsDeleted guard + Delete-perm(4)/Superadmin + cascade + idempotent RTS sweep; audit Dashboard.PermanentlyDeleted) [backend]` → §0.6 post-commit (`git show v3:<file>` == working tree by hash; `git show --stat` zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0620 <hash>` → PD-007 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commits <hash> . files PurgeDashboardCommand.cs(+) + PurgeDashboardCommandTests.cs(+) . build 0 . unit <N>/<N> GREEN . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store
SIGNATURE (for shell to bind the dashboards-Trash delete icon): PurgeDashboardCommand(Guid Id) -> IRequest ; MediatR send ; throws NotFound(not-in-Trash) / Domain(not-IsDeleted) / Forbidden(no Delete-perm).
<paste the build + unit-test output>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md (commit hash + the published signature + flag techwriter: add `Dashboard.PermanentlyDeleted` to §16 audit list).

## ACCEPTANCE (GREEN gate)
- NEW PurgeDashboardCommand.cs: physical `Remove` of an already-soft-deleted dashboard (DB cascade removes widgets+permissions) + idempotent RTS sweep, in ONE transaction.
- GUARD: rejects a non-IsDeleted dashboard. PERMISSION: non-superadmin needs Delete(4) on the dashboard via `HasDashboardAccessAsync`; Superadmin bypasses; deny ⇒ Forbidden. AUDIT `Dashboard.PermanentlyDeleted`.
- Tests cover cascade-Remove / IsDeleted-guard / Delete-perm-deny / Superadmin / tenant-isolation / RTS-idempotent. build 0 + unit GREEN — output pasted.
- 2 new files only; ZERO deletions; NO migration; NO report code touched. feat: on v3, commit.lock, NO push. §0.6b binding PRE+POST written. Signature published in RESULT for shell.
```
