# CC task — Ф5b-2 FIX R2 (HIGH): report config-modal must be VISIBLE + have a SCOPE selector (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Found in E visual gate (2026-06-25): in the report editor, clicking a widget's gear opens `<ReportWidgetConfigModal>` but (1) it renders BEHIND the editor overlay (invisible) and (2) it has no Scope selector → the server-required `Scope` can't be set → placed widgets stay invalid ("missing Scope, Columns"). Owner: role-shell. Executor: native CC. Branch: **v3** (tip 33a4f8d). Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / existing shared app.css selectors / widget-resize.js.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push. Compile via /shell/start (one clean attempt; NEVER a 2nd build-class Soma op while one is in flight — see role-shell §B).

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor (MODIFY — z-index + new Scope tab)
- src/CcDashboard.Web/wwwroot/app.css (ADDITIVE report-scoped z-index rule only, if a CSS approach is used)
- src/CcDashboard.Web/Components/App.razor (?v if css changed) ; 3x Resources/SharedResources.{en-US,ru-RU,he-IL}.resx (new Scope strings)
- (role-shell.md via git add -f if CAPTURE)

## DEFECT A — modal hidden behind the editor overlay (z-index)  [GROUNDED]
ReportWidgetConfigModal root = `<div class="modal show d-block">` → computed `z-index:1050`. The report editor overlay `.editor-fullscreen` = `z-index:9999` → the modal renders underneath (display:flex, opacity:1, but not visible). The dashboard editor's own modal works because `.editor-modal` = `position:fixed!important; z-index:10001!important` (app.css:2563) — above the overlay.
**Fix A:** make the config modal sit ABOVE the editor overlay — set the modal root (and its backdrop if any) to `z-index:10001` (match `.editor-modal`). Use an explicit style/class on the modal root or a report-scoped CSS rule; do NOT edit the shared `.editor-modal`/`.modal` base selectors. Verify computed z-index of the open modal > 9999.

## DEFECT B — no Scope selector → required Scope unsettable  [GROUNDED]
Modal tabs today = General / Columns / Thresholds / Appearance. The server (RunReportWidgetQuery / FluentValidation, SF-BI-001) REQUIRES `Scope`. Model: `ReportScope { string? Mode ("queues"|"bu"); List<int>? QueueIds; List<int>? BusinessUnitIds; string? AgentAxis ("detail"|"cumulative") }` (Application/HistoricalReports/ReportScope.cs; mirrored in Components/ReportWidgets/ReportWidgetConfig.cs).
**Fix B:** add a **Scope** tab (first/most-prominent) to ReportWidgetConfigModal that sets `ReportScope`:
- Mode selector: Queues vs Business Units.
- Mode=queues → PG-scoped multi-select of Queues → `QueueIds`. Mode=bu → PG-scoped multi-select of Business Units → `BusinessUnitIds`.
- For agent widgets (AgentMonthly/AgentShiftDetail) → `AgentAxis` (detail|cumulative).
- Persist into `ReportWidgetConfig.Scope` on Save (OnSave→ConfigJson).
**Data source for the pickers (PG-scoped lists):** reuse the SAME PG-scoped Queues/BUs source the dashboard widget-config uses (the existing Configuration queries for the user's allowed Queues / Business Units). CONFIRM the exact query name by object-store before binding. If NO suitable PG-scoped "my allowed queues/BUs" query exists, STOP and flag a small bi dependency (do not invent an unscoped list — SF-BI-001 scope must hold). Widget-type awareness: if the modal needs WidgetType to choose queues-vs-agent fields and it has no such param, add `[Parameter] public ReportWidgetType WidgetType` (additive).

## VERIFY / DoD (role-shell §A)
- Object-store: modal root z-index raised above the editor overlay; new Scope tab sets ReportScope (Mode + Queue/BU pickers + AgentAxis) bound to a PG-scoped source; OnSave writes Scope into ConfigJson; ScreenEditorPage/ScreenFullscreenPage/shared selectors/widget-resize UNTOUCHED; @L 3 locales.
- **Soma: /ops/build 0 + /ops/test?suite=unit 0-failed + serilog [ERR]/[FTL] clean + /ops/health.**
- **VISUAL CHROME (light+dark):** report editor → drag a widget → gear → the config modal is **VISIBLE above the editor** → Scope tab present → pick BU/Queue + Columns → Save → widget NO LONGER shows "missing Scope/Columns" (renders data or a valid empty state). + live-dashboard editor regression byte-identical.

## §0.6b CAPTURE -> role-shell §B: "a Bootstrap .modal (z-index 1050) opened inside a fixed editor overlay (z-index 9999) renders invisible — match the editor-modal z-index (10001); and a server-validated config (Scope required) needs its selector in the UI, not just the model." Commit fix:, NO push. Binding RESULT -> cc/shell.md (computed z-index before/after + visual evidence that a configured widget stops erroring).
