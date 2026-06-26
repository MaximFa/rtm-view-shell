# CC task — Ф5b-1 FIX: ReportViewPage must be FULLSCREEN OVERLAY (identical to dashboards) (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Operator parity defect (2026-06-25): Reports View opens INSIDE the shell (sidebar+header visible); dashboards open View OUTSIDE as a fullscreen overlay. Spec Reports-Frontend-v1-Spec §3.2 = "mirror ScreenFullscreenPage". Ф5b-1 (3de9dc9) shipped an in-shell `.report-view-page` instead. Operator: "ВСЁ должно быть ИДЕНТИЧНО дашбордам" — View AND Edit. (List stays in-shell — already identical to ScreenListPage, do NOT change.)
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T03:40Z). Object-store verified ScreenFullscreenPage.razor IS the canonical mirror (L1-3 routes no-@layout, L19 .fullscreen-dashboard overlay, L44/55/68 canvas/design-layer/.dashboard-widget, L189 applyAllWidgetPositions, L197 viewerScale.init, L299 dispose). Fix correctly reuses those EXISTING classes+JS (zero edits to ScreenFullscreenPage/ScreenEditorPage/app.css selectors/widget-resize.js — diff-proven); header per operator audit (title + dark + Export/Schedule stub + close-X; drop Edit/back/StatusBadge); date sub-bar additive scoped; bare-catch→Logger.LogError; VISUAL gate light+dark + live-dashboard regression. CLEARED TO RUN (after/around your Unit-green work — your sequencing).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). Parity-guard: ZERO edits to ScreenFullscreenPage.razor / ScreenEditorPage.razor / any EXISTING app.css selector / widget-resize.js.

## INIT — branch v3 + role-shell §A/§C + §40
- BRANCH: `git checkout v3`; verify rev-parse=v3 + `git rev-parse v3` (object-store; mount L-SC-04 -> no escalate). role-shell §A (incl. DoD block) + §C-green; §40.
- POST-VERIFY reliable floor (cat + git show v3 + hash-object). §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> .coord/cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportViewPage.razor (REWRITE to mirror ScreenFullscreenPage)
- src/CcDashboard.Web/wwwroot/app.css (ADDITIVE report-date-bar scoped class ONLY, if needed) ; src/CcDashboard.Web/Components/App.razor (?v bump)
- (role-shell.md via git add -f if CAPTURE)
- S1 freeze-check (FULL line). **ZERO edits to ScreenFullscreenPage.razor / ScreenEditorPage.razor / existing app.css selectors / widget-resize.js.**

## THE MODEL TO MIRROR (object-store v3 — read it, copy structure 1:1)
`src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor` is the canonical viewer:
- Routes: `@page "/screens/{Id:guid}/fullscreen"` + `/view` + bare `/{id}`. NO `@layout` line (default MainLayout applies, but the page renders a `position:fixed; inset:0` overlay via `.fullscreen-dashboard` that COVERS the shell — that is HOW it appears "outside").
- Wrapper `<div class="fullscreen-dashboard @(_darkMode?"dark-mode":"")">`; `.fullscreen-header` (title + dark toggle `bi-moon/bi-sun` + close `bi-x-lg` -> ExitToList); `.fullscreen-canvas`; `.fullscreen-scale-wrap` > `.fullscreen-design-layer @ref=_designLayerRef` (width=_designWidth/height=_designHeight) > per-widget `.dashboard-widget` absolutely positioned.
- OnAfterRenderAsync(firstRender): `JS.InvokeVoidAsync("widgetResize.applyAllWidgetPositions", (object)positions)` then `JS.InvokeVoidAsync("viewerScale.init", _designLayerRef, _designWidth, _designHeight)`. Dispose: `JS.InvokeVoidAsync("viewerScale.dispose")` (IDisposable).
ALL these classes + `viewerScale.*` + `widgetResize.applyAllWidgetPositions` ALREADY EXIST (app.css 2212+/1448+/2607+; widget-resize.js) — REUSE, do not redefine/edit.

## THE WORK — rewrite ReportViewPage as a fullscreen overlay
1. **Drop `@layout MainLayout`.** Add route aliases to match dashboards: `@page "/reports/{Id:guid}"` + `@page "/reports/{Id:guid}/view"` + `@page "/reports/{Id:guid}/fullscreen"`.
2. **Wrapper -> `.fullscreen-dashboard @(_darkMode?"dark-mode":"")`** (replace `.report-view-page`). loading / denied / not-found states stay.
3. **`.fullscreen-header`** EXACTLY mirroring ScreenFullscreenPage layout (operator parity audit 2026-06-25):
   - LEFT: `<h1 class="fullscreen-title mb-0">@_report.Name</h1>` ONLY. **REMOVE the back-arrow (`bi-arrow-left`)** and **REMOVE the in-header StatusBadge** — dashboards show neither on the viewer.
   - RIGHT cluster `<div class="d-flex gap-2">`: dark toggle (`bi-moon/bi-sun`) + **Export ▾** (disabled stub, Ф6) + **Schedule** (disabled stub, Ф7) + **close `bi-x-lg` `.fullscreen-close`** -> BackToList (X on the RIGHT, like dashboards).
   - **REMOVE the Edit button entirely** — editing is reached from the list pencil (identical to dashboards; operator flagged the viewer Edit button as wrong).
   - Export/Schedule are the ONLY report-only viewer controls (operator-CONFIRMED keep). Style them with the SAME classes as dashboard buttons: `btn btn-sm @(_darkMode ? "btn-outline-light" : "btn-outline-secondary")`.
4. **Report date sub-bar**: dashboards have no date-bar (realtime) — Reports need one. Render it as a slim bar directly under `.fullscreen-header`, INSIDE the overlay, using a NEW report-scoped additive class (e.g. `.report-fullscreen-datebar`) — From/To + Apply, default last-7-days, cascade `_rangeFrom/_rangeTo` to all widgets on Apply (keep current logic). Additive CSS only (light+dark `.fullscreen-dashboard.dark-mode .report-fullscreen-datebar`), RTL logical props, ?v bump.
5. **Canvas**: `.fullscreen-canvas` > `.fullscreen-scale-wrap` > `.fullscreen-design-layer @ref=_designLayerRef` (compute _designWidth/_designHeight = bounding box of widget positions, mirror ScreenFullscreenPage). Each widget = `<div class="dashboard-widget" data-widget-id=.. style="position:absolute;left/top/width/height">` with a `.widget-header` (title) + `.widget-content` > `<RenderReportWidget WidgetType=.. ConfigJson=.. From=_rangeFrom To=_rangeTo DarkMode=_darkMode />`. Reuse `.dashboard-widget` (existing) — do NOT invent `.report-widget-container`. Empty-state mirrors ScreenFullscreenPage (`bi-grid-3x3-gap` + message).
6. **Viewer scale**: implement OnAfterRenderAsync + Dispose exactly like ScreenFullscreenPage — `widgetResize.applyAllWidgetPositions` then `viewerScale.init(_designLayerRef,_designWidth,_designHeight)`; `viewerScale.dispose` on Dispose. `@implements IDisposable`, `@inject IJSRuntime JS`.
7. **FIX defect — bare catches**: the load path has `catch { _report = null; }` (bare). Per role-shell §B (2026-06-23): NEVER bare catch in a data-load path. Add `@inject ILogger<ReportViewPage> Logger`; in the generic catch `Logger.LogError(ex, "Report view load failed for {Id}", Id)`. Keep the Forbidden->denied / NotFound->null branches.

## OUT OF SCOPE: ReportEditorPage = Ф5b-2 (separate prompt — will mirror ScreenEditorPage `.editor-fullscreen` overlay). Export/Schedule impl = Ф6/Ф7.

## VERIFY / DoD (role-shell §A — MANDATORY)
- Object-store: ReportViewPage has NO `@layout MainLayout`; wrapper is `.fullscreen-dashboard`; uses `.fullscreen-header/.fullscreen-canvas/.fullscreen-scale-wrap/.fullscreen-design-layer/.dashboard-widget`; calls `viewerScale.init`+`viewerScale.dispose`+`widgetResize.applyAllWidgetPositions`; no bare catch (Logger.LogError present); routes /view+/fullscreen+bare; ScreenFullscreenPage/ScreenEditorPage/existing app.css selectors/widget-resize.js UNCHANGED (diff-proven).
- **Soma (host-Chrome): /ops/build exit 0 + serilog [ERR]/[FTL] scan clean + /ops/health.** (suite=unit: run if devops F-QA-4 fixed, else state 'deferred'.)
- **VISUAL CHROME GATE (light+dark):** open `/reports/{id}` -> the report now COVERS the shell (NO sidebar/header visible), identical chrome to `/screens/{id}` fullscreen; date-bar works; close-X returns to list. Screenshot light+dark as RESULT evidence. + live-dashboard regression: `/screens/{id}/fullscreen` still byte-identical.

## §0.6b CAPTURE -> role-shell §B (git add -f), append:
`2026-06-25 · Reports View shipped in-shell (.report-view-page under @layout MainLayout) instead of mirroring ScreenFullscreenPage's fixed-overlay -> sidebar/header showed; dashboards' View/Edit are fixed-position overlays (.fullscreen-dashboard/.editor-fullscreen) that COVER the shell, NOT a different layout. RULE: "identical to dashboards" = reuse the same fixed-overlay classes + viewerScale, drop the in-shell wrapper; never assume a separate layout is what makes a dashboard page fullscreen. · SOURCE: this fix commit; ScreenFullscreenPage.razor:19 .fullscreen-dashboard · status: active`

## Commit `fix:`, NO push, under commit.lock. Binding RESULT -> cc/shell.md (Soma lines + visual evidence light+dark + parity-regression). Report: commit, files, build/serilog/health, screenshots, confirm overlay covers shell + ScreenFullscreenPage untouched.
