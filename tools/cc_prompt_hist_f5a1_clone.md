# CC-HIST-F5a.1 — CloneReportScreenCommand (deep copy screen + widgets)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3 (tip d0fb4dd — checkout by SHA, §0.5). §4-bless BEFORE run. Unblocks shell Ф5b-2 Clone.
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T05:00Z). Mirrors Create+SaveReportWidgets; deep-copy screen+widgets (new Ids, configs preserved, deleted excluded); PG-01 cloner-Full; requires View on source (Superadmin bypass); 1 tx; FluentValidation; NO migration; 6 unit tests cover the cases; all process blocks. ⚠ v3 tip is now **d0fb4dd** (View-fix landed) — checkout v3 + use d0fb4dd, not 3de9dc9. PUBLISH the CloneReportScreenCommand signature in RESULT (shell binds the Clone action). CLEARED TO RUN.
> Mirrors CreateReportScreenCommand + SaveReportWidgetsCommand (Ф5a 463ea56). Entities EXIST — **NO migration**. SMALL slice.

## STEP 0 — integrity + branch-by-SHA (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — reads + sync block (file-mode): slug bi-0619, claims:
`src/CcDashboard.Application/Reports/Commands/CloneReportScreenCommand.cs`, `tests/CcDashboard.Tests.Unit/Reports/CloneReportScreenCommandTests.cs`
(+ IReportScreenRepository.cs ONLY if a Clone helper is needed; prefer reusing existing repo methods). NO shell overlap.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

## THE WORK — CloneReportScreenCommand (mirror Create + SaveReportWidgets, one transaction)
CloneReportScreenCommand(Guid SourceId) : IRequest<ReportScreenDto>, ITransactional, IAuditable
  AuditEventType="ReportScreen.Cloned"; AuditDetails=new{ SourceId, NewId }.
Handler:
1. Load source report_screen (+ its non-deleted report_widgets) via IReportScreenRepository (GQF TenantId+!IsDeleted).
   **Permission: requires View on source** (report_permissions View | IsPublic | Superadmin) — can only clone what you can see; deny -> Forbidden.
2. New ReportScreen: new UUIDv7 Id; Name = source.Name + " (copy)"; Status = Draft; copy Description, CategoryId, IsPublic,
   IsDarkMode, LayoutJson; Created/Updated audit = current user (interceptor). 
3. **PG-01: cloner's PG gets AccessLevel=7 (Full)** in report_permissions (mirror Create). (Superadmin: no PG row needed.)
4. Copy ALL non-deleted source widgets -> new report_widgets: new Ids, same WidgetType/PositionJson/ConfigJson, IsDeleted=false,
   ReportScreenId = new screen Id.
5. Single transaction (ITransactional). Return ReportScreenDto (new screen).
FluentValidation: SourceId non-empty. No new agg/repo/migration.

## Tests (unit, tests/CcDashboard.Tests.Unit/Reports/) — DoD GREEN
(1) clone copies screen fields (Description/Category/IsPublic/IsDarkMode/LayoutJson) + Status=Draft + Name endswith "(copy)";
(2) clone copies ALL non-deleted widgets with NEW Ids (count==source, configs preserved, deleted widgets NOT copied);
(3) PG-01: cloner PG gets Full on the new screen; (4) requires View on source -> deny when no access (non-Superadmin);
(5) Superadmin can clone any; (6) tenant isolation (can't clone another tenant's screen).

## ACCEPTANCE: Soma /ops/build 0 + /ops/test?suite=unit GREEN (6 clone tests) + serilog clean. NO migration; contour read-only. PUBLISH CloneReportScreenCommand signature in RESULT (shell binds the Clone action).
## STEP 3 — binding POSTAMBLE RESULT -> cc/bi.md (commit, build/test, signature). §0.6b CAPTURE if lesson. cc_post_commit.sh + §0.6/PD-007.
## COMMIT: feat: (Application Reports Clone), commit.lock 5x60s, object-store verify, NO push (§37, bundled barrier).
