# CC-HIST-HARD-DEL-01a — PurgeReportScreenCommand (permanent delete from Trash)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3 (tip 2a81b52 — checkout by SHA, §0.5). §4-bless BEFORE run.
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T09:20Z). PERMISSION RULING (operator): Delete-perm (AccessLevel&4) OR Superadmin + frontend confirmation — as authored, NO tighten. Grounded (IgnoreQueryFilters+TenantId for Trash; IsDeleted guard; explicit cascade remove widgets+permissions+schedules; CODE-03 non-bypassable; audit ReportScreen.PermanentlyDeleted; NO migration; 6 tests). All blocks present. CLEARED TO RUN (independent, parallel; publish signature for shell 01c).
> Operator: Trash gets a permanent-delete icon. This is the REPORTS half (PurgeDashboardCommand = backend, 01b). Entities EXIST — **NO migration**. INDEPENDENT (parallel with shell D).

## STEP 0 — integrity + branch-by-SHA (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD   # expect 2a81b52 (verify object-store)
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — reads (role-bi §A/§C + session-coord) + §C VERIFY + sync block (file-mode): slug bi-0619, claims:
`src/CcDashboard.Application/Reports/Commands/PurgeReportScreenCommand.cs`,
`src/CcDashboard.Application/Reports/Interfaces/IReportScreenRepository.cs` (add purge/load-incl-deleted helper if needed),
`src/CcDashboard.Infrastructure/Persistence/Repositories/ReportScreenRepository.cs`,
`tests/CcDashboard.Tests.Unit/Reports/PurgeReportScreenCommandTests.cs`. NO shell overlap.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

## THE WORK — PurgeReportScreenCommand (physical delete of a soft-deleted screen + cascade)
PurgeReportScreenCommand(Guid Id) : IRequest, ITransactional, IAuditable
  AuditEventType="ReportScreen.PermanentlyDeleted"; AuditDetails=new{ Id, Name, WidgetCount, ScheduleCount, PermissionCount }.
Handler:
1. Load the screen WITH children using **IgnoreQueryFilters()** (a Trash item has IsDeleted=true -> the default GQF
   TenantId&&!IsDeleted HIDES it; must bypass the !IsDeleted filter but STILL scope TenantId explicitly). Include
   Widgets + Schedules; load Permissions for the screen. Not found -> NotFoundException.
2. **GUARD: only purge IsDeleted==true** (a Trash item). If IsDeleted==false -> reject (ValidationException/Conflict
   "must soft-delete first") — never hard-delete a live screen.
3. **PERMISSION (CODE-03, App-layer, non-bypassable):** require Delete (report_permissions AccessLevel & 4) on the screen
   OR Superadmin; else ForbiddenException. ⚠ FLAG for operator: default = Delete-perm + frontend confirmation; if operator
   wants permanent-purge to be Admin/Superadmin-ONLY, tighten to role check — surface, do NOT decide unilaterally.
4. PHYSICAL delete, ONE transaction, TenantId-scoped, cascade-config-agnostic (do NOT rely solely on EF OnDelete):
   explicitly remove report_widgets + report_permissions + report_schedules for the screen, THEN the report_screen row
   (RemoveRange / ExecuteDelete). (If EF cascade IS configured Cascade, the explicit child-deletes are harmless/idempotent.)
5. Audit counts captured BEFORE delete.

## Tests (unit, tests/CcDashboard.Tests.Unit/Reports/) — DoD GREEN
(1) purge a soft-deleted screen -> screen + all widgets/permissions/schedules physically gone (counts 0);
(2) GUARD: purge a NON-soft-deleted (live) screen -> rejected, nothing deleted; (3) Delete-perm required -> deny when
user lacks Delete (non-Superadmin); (4) Superadmin can purge; (5) tenant isolation (can't purge another tenant's Trash item);
(6) audit event ReportScreen.PermanentlyDeleted with counts.

## ACCEPTANCE: Soma /ops/build 0 + /ops/test?suite=unit GREEN (6 tests) + serilog clean. NO migration; physical-delete scoped+guarded; permission non-bypassable. PUBLISH PurgeReportScreenCommand signature in RESULT (shell binds the Trash delete icon).
## STEP 3 — binding POSTAMBLE RESULT -> cc/bi.md (commit, build/test, signature). §0.6b CAPTURE if lesson. cc_post_commit.sh + §0.6/PD-007.
## COMMIT: feat: (Application Reports Purge), commit.lock 5x60s, object-store verify, NO push (§37, bundled barrier).
