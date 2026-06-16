---
role: shell
project: RTM View Shell
version: 0.1
last_verified: 2026-06-16T07:00:00Z
owner: shell
reviewer: curator
---
# role-shell — RTM Shell / UI-UX role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log src/CcDashboard.Web/ + .coord/journal.md shell/web lines + .claude/memory), NOT
> session narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: Blazor Server UI — widgets (Components/Widgets/), dashboard editor (ScreenEditorPage), configurator modals,
drag-and-drop layout (widget-resize.js), dark-mode, i18n, CSS.
Claim: src/CcDashboard.Web/ (Components, Pages, wwwroot/js, wwwroot/app.css, Resources/*.resx).

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **Widget rendering lives in `Components/Widgets/*.razor`.**
   ScreenEditorPage dispatches to AgentGridWidget, QueueGridWidget, DataSlotWidget, DayTrendWidget, etc.
   · SOURCE: git log, 39 widget dispatches in ScreenEditorPage.razor

2. **Drag-and-drop layout via `wwwroot/js/widget-resize.js`.**
   8-way resize handles + draggable modals by header.
   · SOURCE: b5ef8c3 (resize from all 8 sides), widget-resize.js

3. **Dark mode via `.dark-mode` class in `wwwroot/app.css`.**
   97+ rules scoped to `.dark-mode`; toggle applies class to body.
   · SOURCE: 5acf274 (9 dark-mode gaps), 60c01df (generic selector), app.css

4. **RTM relay via `IRtmRelayService` injection.** Widgets subscribe for live data.
   `InvokeAsync(() => StateHasChanged())` pattern for UI updates.
   · SOURCE: CLAUDE.md §34, 4 IRtmRelayService injections, 12 InvokeAsync uses in widgets

5. **localStorage keys MUST include UserId and use `cc:` prefix (§41).**
   Clear on logout via `ccApp.clearLocalStorage()`.
   · SOURCE: CLAUDE.md §41, 15387fc (localStorage security), app.js

6. **i18n via `.resx` files (en-US, ru-RU, he-IL).** `@L["Key"]` pattern.
   · SOURCE: CLAUDE.md §22, 3 .resx files in Resources/

7. **Searchable dropdown with pre-selected value: clear search on focus.**
   Otherwise dropdown shows only matching item.
   · SOURCE: .claude/memory/daytend-implementation-insights.md (BU dropdown bug)

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-05-27 · DayTrend BU dropdown showed only 1 item — search field pre-filled → clear on @onfocus · SOURCE:daytend-implementation-insights.md · status: active
- 2026-06-06 · preassignedGridId not set on DataSlot save → GridId=NULL in RTS Row → widget showed no data · SOURCE:aae6b8f · status: active
- 2026-06-06 · DataSlot BU not saved to RTS Row (UnionId=NULL) — SelectBusinessUnit must update ConfigDataSlotBusinessUnitId · SOURCE:a20b591 · status: active
- 2026-06-07 · dark-mode gaps in configurator modal (9 fields) — use generic .dark-mode input selector · SOURCE:5acf274, 60c01df · status: active
- 2026-06-09 · F-1 metrics read-only — remove client create/edit/delete; vendor-deploy only · SOURCE:b7b20e4 · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Test-Path src\CcDashboard.Web\wwwroot\js\widget-resize.js` — must be True
2. `(Select-String -Path src\CcDashboard.Web\wwwroot\app.css -Pattern '\.dark-mode').Count` — must be >50
3. `(Select-String -Path 'src\CcDashboard.Web\Components\Widgets\*.razor' -Pattern '@inject.*IRtmRelayService').Count` — must be >=3
4. `Test-Path src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor` — must be True
5. `(Get-ChildItem src\CcDashboard.Web\Resources\*.resx).Count` — must be >=3

## §D REFERENCE  (optional · NOT loaded each init)
Widget implementation patterns: `.claude/skills/widget-creator/widget-creator.md`.
DayTrend polish: `.claude/memory/daytend-implementation-insights.md`.
RTM relay contract: `.claude/memory/rtm-relay-implementation.md`.
