# CC task — Ф3 IMPL: Reports mirror-scaffold (role-shell) — §4-PASS (coordinator-0624 2026-06-24T17:35Z) — CLEARED TO RUN
> FIRST impl phase of Reports-Frontend-v1-Spec (§1/§8). Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37).
> Mirror-scaffold ONLY — smallest first slice. NO data/query wiring (that is Ф4). Parity-guard: ZERO edits to ScreenEditorPage.razor and ZERO edits to existing shared app.css selectors (Reports-Frontend-v1-Spec §1.2/§1.3, F1).
> **§4-REVIEW: PASS** — coordinator-0624. Object-store verified: ReportWidgetType enum @v3 = exactly the 5 switched values (ns CcDashboard.Domain.Domain.Reports — @using correct, CS0246 guard valid); RenderWidget.razor pattern exists; Components/ReportWidgets/ is new. All blocks present: file-claim (3 files, NOT ScreenEditorPage), branch-by-SHA (051feea re-verify), binding PRE+POST, lock 5×60s, §0.6/PD-007, diff-proven 3-file scope, parity-guard (zero shared-selector/ScreenEditorPage/widget-resize.js edits), feat:, NO push. CLEARED TO RUN.

## INIT — branch v3 + role-shell §A/§C + §40
- **BRANCH RULE:** reports = **v3**. FIRST `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE; v3 tip at draft = 051feea — re-verify current, mount may fail rev-parse HEAD = L-SC-04, do NOT escalate). Do NOT cross to v2-backend.
- §0.2 v3 integrity: `cat .git/HEAD`=`ref: refs/heads/v3`.
- role-shell INIT §A + §C-green; §40 (widget-planner/widget-creator/session-coord).
- POST-VERIFY reliable floor (cat + git show v3:<f> + git hash-object), NOT -f/-s stat.

## §42.6 sync — slug shell-0609 (file-mode, web)
- S1: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> STOP if match (read FULL line; CLOSED tombstone contains "No FREEZE ACTIVE").
- S2 claims (coord_check_claims shell-0609 each):
  - src/CcDashboard.Web/Components/ReportWidgets/RenderReportWidget.razor (NEW)
  - src/CcDashboard.Web/wwwroot/app.css (ADDITIVE only)
  - src/CcDashboard.Web/Components/App.razor (app.css?v bump)
- S3 commit.lock around git add/commit (owner shell-0609; retry 5×60s). S4 cc_post_commit.sh. S5 NO push.
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; verify by cat/git.
- Binding PREAMBLE/POSTAMBLE -> .coord/cc/shell.md.
- **ZERO edits to src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor and ZERO edits to any EXISTING app.css selector** (F1 parity-guard).

## GROUNDING (object-store v3)
- Pattern to mirror: `Components/Dashboard/RenderWidget.razor` — a `@switch` over widget identity → component branch → default placeholder. (DO NOT overload/edit it.)
- Backend Ф1 ALREADY on v3: `CcDashboard.Domain.Domain.Reports.ReportWidgetType` enum = { QueueInterval, QueueWaitTime, AgentMonthly, AgentShiftDetail, Distribution }; `ReportWidget` entity { Id, ReportScreenId, TenantId, WidgetType, PositionJson, ConfigJson, IsDeleted }.
- Shared JS `wwwroot/js/widget-resize.js` (window.widgetResize) keys on `.dashboard-widget`/`.dashboard-canvas-grid` — report editor will reuse via those classes (Ф5); NO edit here in Ф3.

## THE WORK — Ф3 mirror-scaffold (NEW files + additive CSS only)
1. **NEW `Components/ReportWidgets/RenderReportWidget.razor`** — sibling dispatcher mirroring RenderWidget's PATTERN:
   - `@using CcDashboard.Domain.Domain.Reports`
   - Parameters: `[Parameter, EditorRequired] public ReportWidgetType WidgetType { get; set; }`, `[Parameter] public string? ConfigJson { get; set; }`, `[Parameter] public bool DarkMode { get; set; }`. (No DateRange/data params yet — Ф4.)
   - `<div class="report-widget-render">` + `@switch (WidgetType)` with a STUB branch per enum value (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail/Distribution) rendering a labelled placeholder (e.g. `<div class="report-widget-stub"><i class="bi bi-table"></i> @WidgetType — Ф4</div>`), + `default` placeholder. NO MediatR/IMediator inject, NO query — stubs only.
   - All visible text via @L (I18N-03) where it's a user-facing label; the "— Ф4" dev marker can be a literal (temporary).
2. **app.css — ADDITIVE report-scoped classes ONLY** (e.g. `.report-widget-render`, `.report-widget-stub`): place in a clearly-marked `/* ===== Reports (Ф3 scaffold) ===== */` block at end of file. Light + dark (`.dark-mode .report-widget-stub …`) + RTL logical props. **Do NOT modify any existing selector.** Bump `app.css?v=` in App.razor.
3. **widget-resize.js**: NO edit — add a one-line comment confirmation is NOT needed; just do not touch it. (Reuse path documented in spec §1.1; exercised in Ф5.)
4. **ZERO edits to ScreenEditorPage.razor.**

## VERIFY (build-cite or honest 'not run')
- Object-store: RenderReportWidget.razor exists with @switch over the 5 ReportWidgetType values + default; app.css has ONLY an appended Reports block (diff shows no change to pre-existing selectors); App.razor app.css?v bumped; ScreenEditorPage.razor NOT in the diff; widget-resize.js NOT in the diff.
- `git diff --name-only v3..HEAD` = exactly {RenderReportWidget.razor (A), app.css (M, additive), App.razor (M, ?v)}.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** @using CcDashboard.Domain.Domain.Reports present (CS0246 guard); ReportWidgetType resolves.

## ACCEPTANCE (parity-guard, QA floor)
Builds. Live dashboard editor UNCHANGED — QA runs the live-dashboard regression (ScreenEditorPage + RenderWidget + existing app.css selectors untouched -> must be byte-identical behaviour). New files + additive CSS only. NO data/query wiring (Ф4 next).

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson (e.g. mirror-dispatcher scaffolding pattern keeps the live editor regression-free).

## Commit (feat:, NO push) under commit.lock
pre-commit-check -> git add (RenderReportWidget.razor + app.css + App.razor [+ role-shell.md if CAPTURE -f]) -> commit -m "feat(web): Reports Ф3 mirror-scaffold — RenderReportWidget dispatcher (5 stub types) + report-scoped CSS; zero live-editor edits [shell-0609]" -> §0.6 post-commit (git show v3) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; RenderReportWidget (5 ReportWidgetType stub branches+default); app.css additive report block + ?v bump; ScreenEditorPage + widget-resize.js untouched (diff-proven); build cite OR 'not run'; CAPTURE if any. NO push. verified: object-store.

## Report (chat): commit hash; git diff --name-only (the 3 files only); build line OR honest not-run; confirm live-editor + shared selectors untouched (parity-guard); regression = QA floor. NO push.
