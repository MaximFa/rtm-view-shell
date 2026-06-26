# CC task — Ф4 FRONTEND: report-widget components + per-widget config modal (role-shell) — §4-PASS R2 (coordinator-0624) — CLEARED TO RUN (after Ф2.5=e9bbc89, satisfied)
> Reports-Frontend-v1-Spec §2. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37).
> Ф3 SEALED. ConfigJson §2 LOCKED by bi. Build the 5 report-widget components + config modal. Replace the Ф3 stubs in RenderReportWidget. Parity-guard: ZERO edits to ScreenEditorPage.razor / existing shared app.css selectors (F1).
> **REVISED per §4 (coordinator-0624 20:40):** widgets dispatch the SINGLE non-bypassable entry **`RunReportWidgetQuery(WidgetType, ConfigJson, From, To)`** (bi Ф2.5) — NOT the raw Q1/Q5/A4/A5 (that bypasses BU∩PG scope + ConfigJson validation + SF-BI-002 drop-log). **SEQUENCE GATE: EXECUTE ONLY AFTER bi Ф2.5 (`cc_prompt_hist_f25_scope_wiring.md`) lands** (RunReportWidgetQuery must exist to compile) AND bi's RESULT (.coord/cc/bi.md) publishes the exact return DTO/tagged-union shape — bind widgets to THAT.
> **§4-REVIEW (R2): PASS** (coordinator-0624 2026-06-24T21:45Z). Dispatch fixed (RunReportWidgetQuery ONLY + grep-guard zero raw Get*Query); server owns scope/validation/inclusive-To; parity-guards intact. SEQUENCE GATE SATISFIED — bi Ф2.5 LANDED (e9bbc89, RunReportWidgetQuery→ReportWidgetResult tagged-union published in cc/bi.md). CLEARED TO RUN.

## INIT — branch v3 + role-shell §A/§C + §40
- **BRANCH RULE:** reports = **v3**. FIRST `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE; v3 tip now = e9bbc89 (Ф2.5 landed) — re-verify; mount may fail rev-parse HEAD = L-SC-04, do NOT escalate). Do NOT cross to v2-backend.
- §0.2 v3 integrity: `cat .git/HEAD`=`ref: refs/heads/v3`.
- role-shell INIT §A (incl. the DoD block) + §C-green; §40 (widget-planner/widget-creator/session-coord).
- POST-VERIFY reliable floor (cat + git show v3:<f> + git hash-object), NOT -f/-s stat.

## §42.6 sync — slug shell-0609 (file-mode, web). CLAIM:
- src/CcDashboard.Web/Components/ReportWidgets/RenderReportWidget.razor (MODIFY — stubs -> real components)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfig.cs (NEW — config record per bi §2)
- src/CcDashboard.Web/Components/ReportWidgets/QueueIntervalReportWidget.razor (NEW)
- src/CcDashboard.Web/Components/ReportWidgets/QueueWaitTimeReportWidget.razor (NEW)
- src/CcDashboard.Web/Components/ReportWidgets/AgentMonthlyReportWidget.razor (NEW)
- src/CcDashboard.Web/Components/ReportWidgets/AgentShiftDetailReportWidget.razor (NEW)
- src/CcDashboard.Web/Components/ReportWidgets/DistributionReportWidget.razor (NEW)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor (NEW — per-widget config modal)
- src/CcDashboard.Web/wwwroot/js/reportDistributionChart.js (NEW — Chart.js interop, mirror agentStateDistributionChart.js)
- src/CcDashboard.Web/wwwroot/app.css (ADDITIVE report-scoped only) ; src/CcDashboard.Web/Components/App.razor (app.css?v bump + the new chart js <script>) ; 3× Resources/SharedResources.{en-US,ru-RU,he-IL}.resx
- S1 freeze-check (read FULL line). S3 commit.lock 5×60s. S4 cc_post_commit.sh. S5 NO push. §0.3 Python+fsync. Binding PRE+POST -> .coord/cc/shell.md.
- **ZERO edits to ScreenEditorPage.razor / any EXISTING app.css selector.**

## GROUNDING (object-store v3 — reuse, don't reinvent)
- Stubs to replace: RenderReportWidget.razor @switch (5 ReportWidgetType cases). Add `[Parameter] public DateRange Range` (or From/To) + parse ConfigJson -> ReportWidgetConfig; each case renders the real widget passing (config, range, DarkMode).
- REUSE the PROVEN TABLE MARKUP/FORMATTING from the existing `Components/Reports/{QueueIntervalReport,QueueWaitTimeReport,AgentMonthlyReport,AgentShiftDetailReport}.razor` (table-responsive table-sm; ms->h:mm:ss, pct F1; TotalCount/paging; empty/loading; `@inject ILogger<T>` + non-bare catch). REUSE ONLY presentation — do NOT copy their LoadData date/scope logic (UTC SpecifyKind/inclusive-To/raw-query): that now lives SERVER-SIDE inside RunReportWidgetQuery. The new widgets render the entry's per-type DTO, driven by ReportWidgetConfig + a screen-level DateRange (not ReportFilterBar), embeddable.
- **CANONICAL ENTRY (bi Ф2.5 LANDED v3 e9bbc89, non-bypassable) — EXACT contract (bi 21:30):**
  `RunReportWidgetQuery(ReportWidgetType WidgetType, string ConfigJson, DateTime From, DateTime To, int Page = 1) : IRequest<ReportWidgetResult>` (src/CcDashboard.Application/HistoricalReports/Queries/RunReportWidgetQuery.cs).
  `ReportWidgetResult { ReportWidgetType WidgetType; bool Denied; string? Error; QueueIntervalReportResult? QueueInterval; QueueWaitTimeReportResult? QueueWaitTime; AgentMonthlyReportResult? AgentMonthly; AgentShiftDetailReportResult? AgentShiftDetail; DistributionReportResult? Distribution; }` — tagged-union: read the per-type field matching WidgetType. **Denied=true -> render PG-denied state; Error!=null -> error state.** Distribution = `DistributionReportResult { DistributionBucket[] ... }`.
  Inside the entry (SERVER): BU∩PG scope resolve + ConfigJson FluentValidation + inclusive-To (To.Date.AddDays(1)) + dispatch Q1/Q5/A4/A5 (Distribution derives Q1/Q5) + SF-BI-002 drop-log. Widgets dispatch ONLY this entry via `@inject IMediator`; pass Range.From/Range.To raw + Page; NEVER call Q1/Q5/A4/A5, compute scope, or compute inclusive-To. Confirm exact member names against the landed RunReportWidgetQuery.cs / ReportWidgetResult on v3.
- Chart.js MIT ALREADY loaded: `wwwroot/js/chart.umd.min.js` + App.razor scripts; mirror `wwwroot/js/agentStateDistributionChart.js` interop for the new reportDistributionChart.js. NO new lib, NO new query (Distribution charts over Q1/Q5 output).

## THE WORK
1. **ReportWidgetConfig.cs** — record matching bi LOCKED §2 EXACTLY: `{ string? Title; ReportScope Scope; List<string> Columns; Dictionary<string,object>? Thresholds; int? Interval (30|60); int? PageSize; string? Metric; AppearanceConfig? Appearance }` where `ReportScope { string Mode ("queues"|"bu"); List<int>? QueueIds; List<int>? BusinessUnitIds; string? AgentAxis ("detail"|"cumulative") }`. System.Text.Json (de)serialize from ConfigJson. (Confirm field NAMES vs bi §2.)
2. **5 widget components** (Components/ReportWidgets/): each `@inject IMediator` + `@inject ILogger<T>`; param (ReportWidgetConfig Config, DateRange Range, bool DarkMode). On render/Range-change: `var res = await Mediator.Send(new RunReportWidgetQuery(WidgetType, ConfigJson, Range.From, Range.To, Page))` — the ONE entry; if `res.Denied` render PG-denied state, if `res.Error!=null` render error state, else render from the per-type field (res.QueueInterval / res.QueueWaitTime / res.AgentMonthly / res.AgentShiftDetail / res.Distribution) matching WidgetType. Do NOT call Q1/Q5/A4/A5 directly; do NOT SpecifyKind/AddDays(1)/compute scope (server owns scope+validation+inclusive-To). Pass Range as the screen DateRange (UTC from the Ф5 date-bar). loading/empty/error states; `catch(Exception ex){Logger.LogError(ex,...)}` NEVER bare. Table 4 = the existing reports' table layouts (reuse markup) bound to the entry result; QueueWaitTime shows OverallAsa header; Distribution = Chart.js over the entry's Q1/Q5-derived result via reportDistributionChart.js. a11y: `<table>` with `<caption>` + `<th scope="col">`.
3. **RenderReportWidget.razor**: replace each stub with `<XxxReportWidget Config="cfg" Range="Range" DarkMode="DarkMode" />`; add Range param + ParseConfig(ConfigJson).
4. **ReportWidgetConfigModal.razor** — mirror the dashboard widget config modal; tabs: General(Title, PageSize 25/50/100 def 25) · Columns(show/order/labels) · Thresholds(colour bands) · Appearance(table+header fonts, light+dark colours — frontend-only) · Business Unit(PG-scoped picker -> scope{mode:"bu",businessUnitIds,agentAxis:detail|cumulative}; frontend does NOT compute membership) · Chart(Distribution only). Save -> ReportWidgetConfig -> ConfigJson (bi §2). Reuse dashboard config-modal CSS classes (shared by reference, no edits to them).
5. **app.css** additive report-widget styles (light+dark+RTL logical props); **App.razor** app.css?v bump + `<script src="js/reportDistributionChart.js">`. **resx** all strings @L (en/ru/he, real translations).

## OUT OF SCOPE (Ф5/later): mounting widgets on a screen/editor (Ф5); export/schedule (Ф6/7). Widgets are built + unit-buildable now; placed on /reports edit at Ф5.

## SEQUENCE GATE (HARD)
DO NOT EXECUTE until: (a) bi Ф2.5 (`cc_prompt_hist_f25_scope_wiring.md`) is committed on v3 so `RunReportWidgetQuery` exists (widgets won't compile otherwise), AND (b) bi's RESULT in .coord/cc/bi.md states the RunReportWidgetQuery signature + return DTO/tagged-union shape. Coordinator confirms Ф2.5 landed before issuing this to the operator. ALL scope (BU∩PG) + ConfigJson validation + inclusive-To + SF-BI-002 drop-log live in the entry (server) — the frontend NEVER bypasses or re-implements them. Full BU verified at Ф5.

## VERIFY (DoD — role-shell §A, MANDATORY via Soma host-Chrome)
- Object-store: 5 widgets + ReportWidgetConfig + modal + reportDistributionChart.js exist; widgets dispatch **RunReportWidgetQuery ONLY** (grep: ZERO `new GetQueueIntervalReportQuery`/`GetQueueWaitTimeReportQuery`/`GetAgentMonthlyReportQuery`/`GetAgentShiftDetailReportQuery` in Components/ReportWidgets — the bypass must not exist); RenderReportWidget dispatches real components (no stubs); ConfigJson (de)serialize matches bi §2; ScreenEditorPage.razor + shared app.css selectors UNCHANGED (`git diff --name-only v3..HEAD` within claim).
- **Soma /ops/build = exitCode 0** (cite) + **/ops/test?suite=unit 0 failed** (cite) + **/logs/tail serilog [ERR]/[FTL] scan clean** + **/ops/health**. (CS0246/CS0103: @inject IMediator/ILogger + @using the Queries + Domain.Reports ns.)
- VISUAL Chrome check: **DEFERRED to Ф5** (widgets not yet on a screen — operator ruling). Note in RESULT.

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson.

## Commit (feat:, NO push) under commit.lock
pre-commit-check -> git add (claim + role-shell.md if CAPTURE -f) -> commit -m "feat(web): Reports Ф4 — 5 report-widget components (Q1/Q5/A4/A5 tables + Distribution chart) + config modal on LOCKED ConfigJson §2 [shell-0609]" -> §0.6 post-commit (git show v3) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; the files; ConfigJson §2 conformance; Soma build/unit/serilog/health lines; ScreenEditorPage+shared-selectors untouched; visual DEFERRED Ф5; CAPTURE if any. NO push. verified: object-store + Soma.

## Report (chat): commit hash; git diff --name-only; Soma build+unit+log+health lines; ConfigJson §2 conformed; parity-guard held; visual deferred Ф5. NO push.
