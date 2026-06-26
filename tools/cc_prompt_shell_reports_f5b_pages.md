# CC task — Ф5b FRONTEND: Reports List / View / Edit pages (role-shell) — PRE-AUTHORED for coordinator §4-bless (do NOT execute pre-bless / pre-Ф5a)
> Reports-Frontend-v1-Spec §3. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37).
> Mounts the Ф4 report-widgets on real pages. **VISUAL CHROME GATE fires HERE** (operator-deferred from Ф3). Parity-guard: ZERO edits to ScreenEditorPage.razor / existing shared app.css selectors (F1) — the report editor MIRRORS, never edits, the live editor.

## ⛔ SEQUENCE GATE (HARD — do NOT execute until BOTH)
1. **bi Ф5a CRUD landed on v3** (report_screens/report_widgets CRUD + report_permissions) — directed to bi 22:15, NOT yet landed at pre-author. Load/save depends on it.
2. **bi publishes the Ф5a CRUD contract in .coord/cc/bi.md RESULT** (the MediatR commands/queries: list report-screens PG-scoped, get screen+widgets, create/update/delete screen, upsert widgets Position/Config). Bind pages to THAT — confirm exact names before coding.
Coordinator confirms Ф5a landed + contract published before issuing to operator. RunReportWidgetQuery (e9bbc89) already landed.

## SLICING PROPOSAL (coordinator §4 to ratify)
Ф5b is large (3 pages + a mirror editor). RECOMMEND split into TWO CC tasks, executed in order:
- **Ф5b-1 = ReportsListPage + ReportViewPage** (list mirror + read-only viewer with the single date-bar cascade). Smaller, lower risk; gives a visible /reports + view first.
- **Ф5b-2 = ReportEditorPage** (the dashboard-style mirror editor: palette + canvas + widget-resize.js + ReportWidgetConfigModal + Save). Heaviest; isolates the mirror-editor risk.
Each slice: own §4-bless, own Soma DoD + VISUAL Chrome gate, own commit. (If coordinator prefers one task, this single prompt covers all three — but two is safer per the parity-guard cadence.)

## INIT — branch v3 + role-shell §A/§C + §40
- BRANCH: `git checkout v3`; verify rev-parse (object-store; mount L-SC-04 — no escalate). role-shell §A (DoD block) + §C-green; §40.
- POST-VERIFY reliable floor (cat + git show v3 + hash-object). §0.3 Python+fsync. Binding PRE+POST -> .coord/cc/shell.md. commit.lock 5×60s. cc_post_commit.sh. NO push.

## §42.6 CLAIM (file-mode, web) — NEW pages + additive:
- Ф5b-1: src/CcDashboard.Web/Components/Reports/ReportsListPage.razor (NEW, @page "/reports"), ReportViewPage.razor (NEW, @page "/reports/{id:guid}") + NavMenu.razor (Reports link, [Authorize] v1 — menu.reports still deferred) + app.css (additive) + App.razor (?v) + 3 resx.
- Ф5b-2: src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor (NEW, @page "/reports/{id:guid}/edit") + app.css (additive) + App.razor (?v) + 3 resx.
- **ZERO edits to ScreenEditorPage.razor / existing app.css selectors.** (Migration of old Components/Reports/*.razor tabs = Ф8, NOT here.)

## GROUNDING (object-store v3 — mirror, don't edit)
- **List** mirror `Components/Dashboard/ScreenListPage.razor` (@page "/screens"; @inject IMediator+ICurrentUserAccessor+Nav; filters @bind:after=LoadAsync; @foreach cards). ReportsListPage = same shape over Ф5a list-report-screens (PG-scoped); rows: Name/Category/Access/Status/Updated + View/Edit/Settings.
- **View** mirror `Components/Dashboard/ScreenFullscreenPage.razor` (mounts widgets via `<RenderWidget>` in `.fullscreen-design-layer`; routes /screens/{id}/view). ReportViewPage = read-only grid mounting `<RenderReportWidget WidgetType=.. ConfigJson=.. Range=.. DarkMode=..>` from report_widgets.PositionJson; ONE screen-level date-bar (From→To + Apply) cascades Range to ALL widgets (each calls RunReportWidgetQuery internally). Export/Schedule buttons = Ф6/Ф7 stubs (disabled/placeholder).
- **Edit** mirror `Components/Dashboard/ScreenEditorPage.razor` STRUCTURE (do NOT edit it): `.editor-body` flex [palette|canvas]; palette of the 5 ReportWidgetType; drag onto `.dashboard-canvas-grid`; `window.widgetResize` (shared JS, reuse via the same DOM classes — Ф3 §1.1); per-widget `<ReportWidgetConfigModal>`; Save -> Ф5a upsert (report_widgets Position/Config JSON + report_screens.LayoutJson).
- RenderReportWidget (Ф4) takes (WidgetType, ConfigJson, Range, DarkMode) — already built.

## THE WORK (per slice)
- Pages [Authorize] + InteractiveServer + MainLayout; PG-scope server-enforced via Ф5a (list/permissions); CODE-03 (no UI-only auth).
- View: single date-bar is the ONE Range source; widgets re-query on Apply (UTC range; server owns inclusive-To/scope via RunReportWidgetQuery).
- Edit: mirror editor; widget-resize.js reuse; ReportWidgetConfigModal for per-widget config; Save persists via Ф5a CRUD.
- Dark/Light; RTL logical props; a11y (table caption/th scope from Ф4 widgets; modal focus-trap; nav keyboard); @L (en/ru/he real translations); app.css additive report-scoped only; App.razor ?v bump.

## OUT OF SCOPE: export/schedule impl (Ф6/Ф7 — buttons stubbed); old /reports tab migration + seed defaults (Ф8); menu.reports PG-key (separate).

## VERIFY / DoD (role-shell §A — MANDATORY)
- Object-store: pages exist + routes; View mounts RenderReportWidget + single date-bar cascade; Edit mirrors editor (palette/canvas/widget-resize.js/ReportWidgetConfigModal) with ZERO ScreenEditorPage/shared-selector edits; Save binds to Ф5a CRUD; @L resolves 3 locales.
- **Soma (host-Chrome): /ops/build exit 0 + /ops/test?suite=unit 0-failed + serilog [ERR]/[FTL] scan clean + /ops/health.**
- **VISUAL CHROME GATE (fires here, operator-deferred from Ф3):** open `/reports` (list), `/reports/{id}` (view — widgets render data), `/reports/{id}/edit` (editor — palette+canvas+drag+config modal) in host-Chrome; verify render in **light AND dark**; screenshot/read-page as evidence in the RESULT. + run the **live-dashboard regression** (open /screens editor — byte-identical, parity-guard).

## §0.6b CAPTURE -> role-shell §B if a real lesson. Commit feat:, NO push, per slice. Binding RESULT -> cc/shell.md (Soma lines + visual-gate evidence). Report: commit, files, build/unit/serilog/health, visual screenshots, parity-regression result.
