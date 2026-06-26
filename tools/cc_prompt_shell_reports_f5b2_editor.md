# CC task — Ф5b-2 FRONTEND: ReportEditorPage = fullscreen mirror of ScreenEditorPage (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Reports-Frontend-v1-Spec §3.3. Operator parity directive (2026-06-25): Edit mode must be IDENTICAL to dashboards (out-of-shell `.editor-fullscreen` overlay), same UX/UI. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / any EXISTING app.css selector / widget-resize.js. The report editor MIRRORS (reuses classes), never edits, the live editor.

## ✅ DEP RESOLVED (coordinator §4 + OPERATOR RULING 2026-06-25T05:20Z) — no gate
ScreenEditorPage has Clone + Templates + Publish/Unpublish + Save. Backend status, ALL resolved:
- **Publish/Unpublish** → `UpdateReportScreenCommand` (Status Draft/Published). EXISTS. OK.
- **Save** → `SaveReportWidgetsCommand` + `UpdateReportScreenCommand`. EXISTS. OK.
- **Clone** → **LANDED** v3 `5c46daf`: `CloneReportScreenCommand(Guid SourceId) : IRequest<ReportScreenDto>` (deep-copy screen+widgets, Name+" (copy)", Status=Draft, PG-01 cloner-Full, requires View on source). BIND TO THIS exact signature.
- **Templates** → **DEFER v1.1 (operator-ratified)**: needs an IsTemplate/IsSystem column = migration tied to the parked Ф8 schema decision. Per "no fake actions": **HIDE the Templates control/palette-section entirely in v1** — do NOT render it (NOT a disabled stub, simply absent). It returns in v1.1 with the Ф8 migration.
All four backed or consciously hidden → CLEARED TO RUN.

## INIT — branch v3 + role-shell §A/§C + §40
- BRANCH: `git checkout v3`; verify rev-parse=v3 + `git rev-parse v3` (object-store; mount L-SC-04 -> no escalate). role-shell §A (DoD block) + §C-green; §40.
- POST-VERIFY reliable floor (cat + git show v3 + hash-object). §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> .coord/cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor (NEW, @page "/reports/{Id:guid}/edit")
- src/CcDashboard.Web/wwwroot/app.css (ADDITIVE report-editor-scoped ONLY, if any) ; src/CcDashboard.Web/Components/App.razor (?v) ; 3x Resources/SharedResources.{en-US,ru-RU,he-IL}.resx
- (role-shell.md via git add -f if CAPTURE)
- S1 freeze-check (FULL line). **ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / existing app.css selectors / widget-resize.js.**

## THE MODEL TO MIRROR (object-store v3 — read ScreenEditorPage.razor, copy structure 1:1)
`@page "/screens/{Id:guid}/edit"` · `@attribute [Authorize(Roles="Superadmin,Administrator,Editor")]` · NO @layout (overlay covers shell) · `@implements IDisposable`.
Wrapper `<div class="editor-fullscreen @(_darkMode?"dark-mode":"")">`. Structure:
- **`.editor-header`** — LEFT group: palette-toggle btn (`bi-layout-sidebar-inset`) + close `<a href="/reports"><i bi-x-lg></a>` + inline name `<input @bind=EditName>` (250px) + StatusBadge (Published=bg-success / Draft=bg-warning). RIGHT group: dark toggle (`bi-moon/sun`) + [modal/error indicators] + **Publish** (Draft) / **Unpublish** (Published) + **Clone** (`bi-copy`) + **Save** (`bi-check-lg`, **btn-primary** — operator: primary=blue, ux-ui-expert §1).
- **`.editor-body`** flex → **`.editor-palette @(PaletteOpen?"open":"")`** (`.palette-header` + `.palette-content`): the **5 ReportWidgetType** grouped (mirror category grouping), each `.widget-palette-item draggable @ondragstart/@ondragend` (icon+name+desc). **OMIT the Templates palette section entirely (deferred v1.1 — not rendered).** → **canvas** `.editor-canvas`/`.dashboard-canvas-grid` reusing `window.widgetResize` (drag from palette, 8-way resize, alignment guides — all via the SAME `.dashboard-widget`/`.dashboard-canvas-grid` DOM classes, §B 2026-06-17 lesson: JS keys on the RENDERED class).
- **`ReportWidgetConfigModal`** (Ф4) per widget for config. Save → Ф5a `SaveReportWidgetsCommand` (Position/Config JSON) + `UpdateReportScreenCommand` (name/status/layout).
REUSE existing classes (`.editor-fullscreen/.editor-header/.editor-body/.editor-palette/.palette-*/.widget-palette-*/.editor-canvas/.dashboard-canvas-grid/.dashboard-widget`) — they exist (app.css 1448/2457/2655+). NO CSS edits beyond additive report-only if strictly needed.

## THE WORK
- Mirror ScreenEditorPage 1:1 swapping: dashboard widget catalog → the 5 ReportWidgetType palette; RenderWidget → RenderReportWidget; dashboard CRUD → Ф5a report CRUD (Create already done from list; this page = load+edit+save). PG-scope server-enforced (CODE-03). Drag/drop + resize via shared widget-resize.js (reuse, no edit). Per-widget config via ReportWidgetConfigModal. Publish/Unpublish via UpdateReportScreenCommand status. Clone via `CloneReportScreenCommand(Guid SourceId)`→ReportScreenDto (5c46daf) — on success Nav to the clone's edit (or list). Templates control HIDDEN (v1.1). DARK-SCHEME: editor dark must use the neutral-grey overlay/editor palette (#1E1E1E/#2D2D2D/#E4E4E7, rgba-white borders) for header buttons + inputs (see cc_prompt_shell_reports_ux_colour_consistency.md) — NOT slate; Save = btn-primary.
- Dark/Light parity; RTL logical props; a11y (palette keyboard, modal focus-trap, name input label); @L en/ru/he real; app.css additive only; App.razor ?v bump.
- bare-catch BAN (role-shell §B 2026-06-23): every load/save catch → `Logger.LogError(ex, ...)`, never bare.

## VERIFY / DoD (role-shell §A — MANDATORY)
- Object-store: ReportEditorPage uses `.editor-fullscreen` overlay (NO @layout), `.editor-header` control set = ScreenEditorPage parity (palette-toggle, close-X, name, status, dark, Publish/Unpublish, Clone, Save), `.editor-palette` of 5 types + canvas via widget-resize.js + ReportWidgetConfigModal; Save binds Ф5a SaveReportWidgets+Update; Clone binds CloneReportScreenCommand(Guid SourceId); Templates control ABSENT (v1.1 defer); ScreenEditorPage/ScreenFullscreenPage/existing app.css/widget-resize.js UNCHANGED (diff-proven); @L 3 locales.
- **Soma (host-Chrome): /ops/build exit 0 + serilog [ERR]/[FTL] clean + /ops/health.** (suite=unit if F-QA-4 fixed else 'deferred'.)
- **VISUAL CHROME GATE (light+dark):** open `/reports/{id}/edit` → editor COVERS the shell, byte-for-byte the same UX as `/screens/{id}/edit` (palette slide-out, drag a widget onto canvas, resize, open config modal, Save). Screenshot light+dark. + parity regression: `/screens/{id}/edit` still byte-identical.

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson. Commit feat:, NO push, commit.lock. Binding RESULT -> cc/shell.md (Soma + visual evidence light+dark + parity-regression). Report: commit, files, build/serilog/health, screenshots, Clone/Templates resolution, parity confirm.
