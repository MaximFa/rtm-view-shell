# CC task — Ф5b-1 FRONTEND: ReportsListPage + ReportViewPage (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Reports-Frontend-v1-Spec §3.1/§3.2. Slice 1 of the §4-APPROVED Ф5b split (Ф5b-1 List+View → Ф5b-2 Edit). Owner: role-shell. Executor: native CC. Branch: **v3** (tip 463ea56). Commit `feat:`. **NO push** (§37).
> Mounts the Ф4 report-widgets on the List + read-only View. **VISUAL CHROME GATE fires HERE** (operator-deferred from Ф3). Parity-guard: ZERO edits to ScreenEditorPage.razor / existing shared app.css selectors (F1).
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T00:35Z). Binds the published Ф5a contract (GetReportScreens/GetReportScreen/GetReportCategories); mounts RenderReportWidget (Ф4, server-scoped via RunReportWidgetQuery) read-only with single date-bar cascade; ROUTE-COLLISION resolved (legacy ReportsPage→/reports-legacy, one line, full retire Ф8); parity-guard (zero ScreenEditorPage/shared-selector edits); VISUAL Chrome gate correctly placed (operator-deferred from Ф3); all process blocks. ⚠ v3 tip ADVANCED to **eeacd76** (devops /db/dashboards fix landed — unrelated to your files); checkout v3 + use eeacd76, NOT 463ea56. CLEARED TO RUN.

## INIT — branch v3 + role-shell §A/§C + §40
- BRANCH: `git checkout v3`; verify rev-parse = v3 + `git rev-parse v3` (object-store; tip 463ea56 — re-verify; mount L-SC-04 → no escalate). role-shell §A (DoD block) + §C-green; §40.
- POST-VERIFY reliable floor (cat + git show v3 + hash-object). §0.3 Python+fsync. Binding PRE+POST -> .coord/cc/shell.md. commit.lock 5×60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportsListPage.razor (NEW, @page "/reports")
- src/CcDashboard.Web/Components/Reports/ReportViewPage.razor (NEW, @page "/reports/{Id:guid}")
- src/CcDashboard.Web/Components/Layout/NavMenu.razor (add Reports NavLink, [Authorize] v1 — menu.reports still deferred)
- src/CcDashboard.Web/wwwroot/app.css (ADDITIVE report-scoped only) ; src/CcDashboard.Web/Components/App.razor (?v bump) ; 3× Resources/SharedResources.{en-US,ru-RU,he-IL}.resx
- S1 freeze-check (FULL line). **ZERO edits to ScreenEditorPage.razor / existing app.css selectors.** (Old Components/Reports/*.razor tabs = Ф8, leave; /reports route note below.)
- ROUTE NOTE: the legacy 4-tab `Components/Reports/ReportsPage.razor` currently owns `@page "/reports"`. The new ReportsListPage takes `/reports` — to avoid a duplicate-route compile error, CHANGE the legacy page's route to `@page "/reports-legacy"` (minimal one-line; full retirement is Ф8). Confirm only ONE component owns `/reports`.

## Ф5a CRUD CONTRACT (bi, LANDED v3 463ea56 — bind to THESE; read the files for exact fields)
Queries (Application/Reports/Queries): 
- `GetReportScreensQuery(ReportScreenListRequest Request) : IRequest<PagedResult<ReportScreenDto>>` — PG-scoped (View|IsPublic; Superadmin all; paged). `ReportScreenListRequest(Search?, CategoryId?, Status?, IsPublic?, Page=1, PageSize=25)`.
- `GetReportScreenQuery(Guid Id) : IRequest<ReportScreenDetailDto>` (+ Widgets, View-gated).
- `GetReportCategoriesQuery : IRequest<IReadOnlyList<ReportCategoryDto>>`.
DTOs (Application/Reports/DTOs/ReportScreenDtos.cs):
- `ReportScreenDto(Id, TenantId, Name, Description?, CategoryId?, CategoryName?, Status, IsPublic, IsDarkMode, CreatedByUserId, CreatedByName?, CreatedAt, UpdatedByUserId, UpdatedByName?, UpdatedAt, RowVersion, AccessLevel)`.
- `ReportScreenDetailDto(... + LayoutJson?, IReadOnlyList<ReportWidgetDto> Widgets)`.
- `ReportWidgetDto(Id, ReportWidgetType WidgetType, string? PositionJson, string? ConfigJson)`.
- `ReportCategoryDto(Id, Name, IsActive)`. Status enum = ReportScreenStatus (Draft|Published). AccessLevel bitmask View=1/Edit=2/Delete=4/Full=7.
- New screen (List "New report") = `CreateReportScreenCommand(CreateReportScreenRequest(Name, Description?, CategoryId?, IsPublic, IsDarkMode))` → ReportScreenDto.

## THE WORK
### A. ReportsListPage.razor (mirror ScreenListPage)
`@page "/reports"` `@rendermode InteractiveServer` `@layout MainLayout` `@attribute [Authorize]` `@inject IMediator Mediator` `@inject NavigationManager Nav` `@inject IStringLocalizer<SharedResources> L`.
- Load: `Mediator.Send(new GetReportScreensQuery(new ReportScreenListRequest(Search, CategoryId, Status, IsPublic, Page, PageSize)))` → PagedResult<ReportScreenDto>. Categories: GetReportCategoriesQuery. PG-scope is server-enforced (do not re-filter).
- Toolbar: search + category filter + status filter (+ IsPublic) + "New report" (CreateReportScreenCommand → Nav to `/reports/{id}/edit`; NOTE the edit route lands in Ф5b-2 — until then it 404s; acceptable per slice order, OR gate the button text — keep it, Ф5b-2 is next).
- Rows/cards (mirror ScreenListPage card markup/classes): Name, CategoryName, Status badge (Draft/Published), UpdatedAt (CultureInfo), Access (from AccessLevel) + actions: **View** (→ `/reports/{id}`), **Edit** (→ `/reports/{id}/edit`, shown if AccessLevel&Edit), **Settings**. `@bind:after=LoadAsync` filter pattern.

### B. ReportViewPage.razor (mirror ScreenFullscreenPage, read-only)
`@page "/reports/{Id:guid}"` `@rendermode InteractiveServer` `@layout MainLayout` `@attribute [Authorize]` `@inject IMediator` `@inject IStringLocalizer<SharedResources> L`.
- Load: `Mediator.Send(new GetReportScreenQuery(Id))` → ReportScreenDetailDto (View-gated server-side; on forbid → friendly denied state). IsDarkMode from the DTO.
- **Single screen-level date-bar** (From→To + Apply) — the ONE Range source. Default last-7-days (UtcNow.Date-7 .. UtcNow.Date). On Apply, cascade Range to ALL mounted widgets.
- Mount each `ReportWidgetDto` via `<RenderReportWidget WidgetType="w.WidgetType" ConfigJson="w.ConfigJson" Range="@_range" DarkMode="@_dark" />`, absolutely positioned from `w.PositionJson` (mirror ScreenFullscreenPage `.fullscreen-design-layer`/`.fullscreen-canvas`). Read-only — NO palette/drag. (RenderReportWidget Ф4 already calls RunReportWidgetQuery internally; server owns scope+inclusive-To.) Use the DateRange type as defined by Ф4 RenderReportWidget — read its param signature; if it's From/To not a DateRange record, pass those.
- Top bar: Export ▾ + Schedule buttons = DISABLED/stub (Ф6/Ф7).
- empty state (no widgets) + loading.

### C. NavMenu + cross-cutting
- NavMenu: add Reports NavLink href "/reports" (@L label), [Authorize] v1 (menu.reports deferred). app.css additive (report list/view scoped); App.razor ?v bump. All strings @L (en/ru/he real). Dark/Light; RTL logical props; a11y (table caption/th scope; date-bar + nav keyboard).

## OUT OF SCOPE (Ф5b-2/later): ReportEditorPage (/reports/{id}/edit) = Ф5b-2 (Create/Update/SaveReportWidgets/Delete/Restore); export/schedule impl (Ф6/Ф7); old-tab retirement+seed (Ф8).

## VERIFY / DoD (role-shell §A — MANDATORY)
- Object-store: ReportsListPage binds GetReportScreensQuery (+categories); ReportViewPage binds GetReportScreenQuery + mounts RenderReportWidget with the single date-bar Range cascade; only ONE component owns `/reports`; ScreenEditorPage + shared app.css selectors UNCHANGED; @L resolves 3 locales.
- **Soma (host-Chrome): /ops/build exit 0 + /ops/test?suite=unit 0-failed + serilog [ERR]/[FTL] scan clean + /ops/health.**
- **VISUAL CHROME GATE (operator-deferred from Ф3, fires here):** open `/reports` (list renders, filters work) + `/reports/{id}` (view: date-bar + widgets render data) in host-Chrome; verify **light AND dark**; screenshot/read-page as RESULT evidence. + **live-dashboard regression** (open /screens editor — byte-identical, parity-guard).

## §0.6b CAPTURE -> role-shell §B if a real lesson. Commit feat:, NO push. Binding RESULT -> cc/shell.md (Soma lines + visual evidence). Report: commit, files, build/unit/serilog/health, visual screenshots (light+dark), parity-regression, route-collision resolution.
