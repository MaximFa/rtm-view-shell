# CC task — Reports create-under-selected-tenant (shell): pass SelectedTenantId into CreateReportScreenCommand — AWAITING §4-BLESS
> Operator confirmed (a): when a Superadmin has a tenant selected on the Reports page, a NEW report must be created UNDER that tenant (not Platform). bi is extending `CreateReportScreenCommand` with an optional `Guid? TenantId` (Superadmin-honored; null → session tenant). This is the shell UI half: pass the page's current `SelectedTenantId` into the create command.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37). Lands WITH bi's CreateReportScreenCommand extension (compiles only once bi's 2nd param exists — sequence accordingly).
> Completes the per-page tenant filter on Reports (create + list + view all honor the selected tenant for Superadmin).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`. Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_create_under_tenant.md | status: open
### DIRECTIVE (spec->CC): ReportsListPage create modal passes SelectedTenantId into CreateReportScreenCommand. Claim: ReportsListPage.razor. feat:, NO push, §4 + lands-with-bi.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Reports/ReportsListPage.razor — MODIFY (create flow only)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
- Current: `CreateReportScreenCommand(CreateReportScreenRequest Request)` (no TenantId yet — bi is adding it). ReportsListPage: `OpenCreate()` (~:645) opens the modal; the submit (~:691-697) builds `CreateReportScreenRequest` and calls `await Mediator.Send(new CreateReportScreenCommand(request))`.
- `SelectedTenantId` (Guid?) already exists on ReportsListPage (from the tenant-selector commit 182ee94) — Superadmin-set or null ("All Tenants").

## THE WORK (ReportsListPage.razor — create flow only)
1. **CONFIRM bi's published signature first** (object-store): inspect `CreateReportScreenCommand.cs` in the current tree. It should now be `CreateReportScreenCommand(CreateReportScreenRequest Request, Guid? TenantId = null)` (or bi's exact shape). If bi's extension is NOT yet in the tree → STOP and report to spec (this lands WITH bi; do not guess a divergent shape).
2. Pass `SelectedTenantId` into the command at the create call (~:697):
   `await Mediator.Send(new CreateReportScreenCommand(request, SelectedTenantId));`
   (match bi's exact param name/position). SelectedTenantId set → create under it; null ("All Tenants" / non-Superadmin) → null → server uses session tenant.
3. No other change. (The new report then opens under its Report.TenantId, which already drives the editor BU-picker + render via commit 182ee94.)

## VERIFY / DoD (role-shell §A — ЧП: LIVE gate, NOT object-store)
- **Object-store:** the create call passes SelectedTenantId into CreateReportScreenCommand matching bi's published signature; no other behavioural change; non-Superadmin path unchanged (SelectedTenantId null → own tenant).
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator):** as Superadmin, select 019e03e9 → create a new report → it lands under 019e03e9 (appears in the 019e03e9 list, opens with 019e03e9 BUs/data); with "All Tenants" → lands under session tenant; non-Superadmin → own tenant. Do NOT report from object-store.
- **Coordinate:** lands WITH bi's CreateReportScreenCommand extension (won't compile before it).

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY ReportsListPage.razor (+ role-shell.md via `git add -f` if CAPTURE). Commit `feat(web): reports — create new report under page-selected tenant (pass SelectedTenantId to CreateReportScreenCommand) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed file from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Per-page tenant filter on Reports = create + list + view all honor SelectedTenantId for Superadmin; the create modal passes SelectedTenantId into CreateReportScreenCommand (null→session). Completes the UserAdminPage-style per-page selector for Reports." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportsListPage.razor . status done|failed . blockers . verified: object-store (LIVE create-under-tenant = operator gate, pending)
```
