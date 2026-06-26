# CC task — Reports tenant selector (shell UI half): per-page Superadmin tenant filter on the Reports page — AWAITING §4-BLESS
> Operator: every admin page has a per-page tenant selector EXCEPT Reports — ADD it to the Reports page (NOT a global switch, NOT a security feature). A Superadmin picks tenant 019e03e9 → the Reports list + the report's BUs + the rendered data scope to it.
> bi's Application half LANDED (fcf5458): the 4 report queries now accept an optional `Guid? TenantId = null`, Superadmin-gated server-side (non-Superadmin → own tenant, param IGNORED — no leak):
>   `GetReportScreensQuery(ReportScreenListRequest Request, Guid? TenantId = null)`
>   `GetReportCategoriesQuery(Guid? TenantId = null)`
>   `GetMyBusinessUnitsQuery(Guid? TenantId = null)`
>   `RunReportWidgetQuery(WidgetType, ConfigJson, From, To, Page = 1, Guid? TenantId = null)`
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37). Report-page-scoped; NO MainLayout/global switcher, NO claim/command.

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
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_tenant_selector.md | status: open
### DIRECTIVE (spec->CC): Reports per-page tenant selector (Superadmin) + thread TenantId into 4 report queries. Claims: ReportsListPage.razor, ReportEditorPage.razor, ReportViewPage.razor, RenderReportWidget.razor, 5 type widgets, ReportWidgetConfigModal.razor. feat:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Reports/ReportsListPage.razor — MODIFY (selector + thread into list/categories)
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor — MODIFY (pass Report.TenantId to RenderReportWidget + ReportWidgetConfigModal)
- src/CcDashboard.Web/Components/Reports/ReportViewPage.razor — MODIFY (pass Report.TenantId to RenderReportWidget)
- src/CcDashboard.Web/Components/ReportWidgets/RenderReportWidget.razor — MODIFY (TenantId param → 5 type widgets)
- src/CcDashboard.Web/Components/ReportWidgets/{QueueInterval,QueueWaitTime,AgentMonthly,AgentShiftDetail,Distribution}ReportWidget.razor — MODIFY (TenantId param → RunReportWidgetQuery)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — MODIFY (TenantId param → GetMyBusinessUnitsQuery)
- src/CcDashboard.Web/Components/Admin/UserAdminPage.razor — READ-ONLY reference (selector pattern :27-35 markup + :363-415 @code)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
- bi's 4 signatures (above) are already in HEAD (fcf5458); existing callers compile (optional param defaults null).
- ReportScreenDto + ReportScreenDetailDto BOTH expose `TenantId` (ReportScreenDtos.cs:7, :26).
- `GetReportScreenQuery(Id)` loads cross-tenant (repo `GetByIdAsync` `.IgnoreQueryFilters()`; Superadmin accessLevel=7) → the editor/viewer CAN open another tenant's report, and `Report.TenantId` is the authoritative tenant for that report's BU-picker + render.
- UserAdminPage selector pattern (mirror): markup :27-35 (`@if (Tenants.Count>0)` → `<select value="@SelectedTenantId" @onchange="OnTenantChanged"><option value="">All Tenants</option>@foreach…</select>`, inside a Superadmin gate); @code :363-415 (`List<TenantDto> Tenants`, `Guid? SelectedTenantId`, load `Tenants = (await Mediator.Send(new GetTenantsQuery())).ToList()` when Superadmin, `OnTenantChanged` sets SelectedTenantId + reloads).
- ReportsListPage calls: GetReportCategoriesQuery (:483), GetReportScreensQuery (:527). RenderReportWidget used in ReportEditorPage:171 + ReportViewPage:92. The 5 type widgets each call `new RunReportWidgetQuery(...)`. ReportWidgetConfigModal calls `GetMyBusinessUnitsQuery()`.

## THE WORK
### A. ReportsListPage.razor — the selector (mirror UserAdminPage, Superadmin-only)
1. Add `List<TenantDto> Tenants`, `Guid? SelectedTenantId`, `IsSuperadmin` (from CurrentUser.Role). On init, if Superadmin: `Tenants = (await Mediator.Send(new GetTenantsQuery())).ToList()`.
2. Render the selector ONLY for Superadmin (mirror UserAdminPage :27-35: "Tenant:" label + `<select>` with an "All Tenants" option + the tenant list), placed in the toolbar. `OnTenantChanged` sets `SelectedTenantId` and reloads the list + categories.
3. Thread `SelectedTenantId` into the queries: `new GetReportScreensQuery(request, SelectedTenantId)` (:527) and `new GetReportCategoriesQuery(SelectedTenantId)` (:483).
4. For non-Superadmin: NO selector (don't render it); calls pass null (own tenant) — unchanged behaviour.

### B. Editor / Viewer → render + BU-picker use Report.TenantId
5. `ReportEditorPage.razor`: pass `TenantId="Report.TenantId"` to `<RenderReportWidget …>` (:171) AND to `<ReportWidgetConfigModal …>` (the config modal). The editor already loads `Report` (cross-tenant) so `Report.TenantId` is the report's tenant.
6. `ReportViewPage.razor`: pass `TenantId="Report.TenantId"` to `<RenderReportWidget …>` (:92).

### C. Thread TenantId through the render chain
7. `RenderReportWidget.razor`: add `[Parameter] public Guid? TenantId { get; set; }`; pass `TenantId="TenantId"` to each of the 5 type widgets in the switch.
8. Each of the 5 type widgets (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail/Distribution): add `[Parameter] public Guid? TenantId { get; set; }`; pass it as the new last arg to `new RunReportWidgetQuery(…, TenantId)`.
9. `ReportWidgetConfigModal.razor`: add `[Parameter] public Guid? TenantId { get; set; }`; pass it to `GetMyBusinessUnitsQuery(TenantId)` so the BU-picker lists the report's tenant's BUs.

### Notes
- NO MainLayout change, NO global switcher, NO claim/command (that was the reverted ARCH-02 — do not reintroduce). Non-Superadmin path must be byte-unchanged (param null → server uses own tenant).
- Creating a NEW report under a selected tenant is OUT OF SCOPE here (the create command wasn't extended) — if the New-report modal is open while a tenant is selected, leave create behaviour as-is; flag to spec if the operator wants create-under-selected-tenant.

## VERIFY / DoD (role-shell §A — ЧП: LIVE gate, NOT object-store)
- **Object-store:** ReportsListPage has a Superadmin-only Tenants selector + threads SelectedTenantId into GetReportScreensQuery + GetReportCategoriesQuery; ReportEditorPage/ReportViewPage pass Report.TenantId to RenderReportWidget (+ modal); RenderReportWidget + 5 type widgets + ReportWidgetConfigModal have a TenantId param threaded into RunReportWidgetQuery / GetMyBusinessUnitsQuery; NO MainLayout/global/claim changes; non-Superadmin renders no selector.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE — MANDATORY (operator/coordinator on 234):** as Superadmin on /reports → the Tenant selector appears → pick **019e03e9** → the Reports list shows 019e03e9's reports; open one → the editor/viewer BU-picker lists 019e03e9's BUs and the widgets render 019e03e9's real data. As a non-Superadmin: NO selector, own-tenant behaviour unchanged. Do NOT report from object-store.
- **Coordinate:** bi's half is already in HEAD (fcf5458) — this compiles against it; functionally both needed (both now present after this lands).

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `feat(web): reports — per-page Superadmin tenant selector + thread TenantId through list/categories/BU-picker/render [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Reports got the EXISTING per-page tenant selector (mirror UserAdminPage), NOT a global switch — Superadmin-only dropdown threading SelectedTenantId into the 4 report queries; the editor/viewer derive tenant from the loaded Report.TenantId (cross-tenant GetReportScreenQuery) for BU-picker + render. Per-page filter > global switcher (no scoped-DbContext concurrency hazard)." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportsListPage/ReportEditorPage/ReportViewPage/RenderReportWidget/5 type widgets/ReportWidgetConfigModal . status done|failed . blockers . verified: object-store (LIVE tenant-filter = operator gate, pending)
```
