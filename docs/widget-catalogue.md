# Widget Catalogue — RTM View Shell v1.3

**Document type:** Reference  
**Status:** Current  
**Last updated:** 2026-05-26 (post-cleanup)  
**Scope:** All widget types present in the codebase as of commit after T6 / #15

---

## Overview

The shell manages two parallel widget registries:

| Registry | Location | Purpose |
|---|---|---|
| **Widget Catalogue** (DB) | `widget_catalog` table, `WidgetCatalogItem` entity | Platform-wide list of available widget types. Cross-tenant, no GQF. Seeded at first run. |
| **Blazor components** (code) | `src/CcDashboard.Web/Components/Widgets/` | Visual implementations. Matched by name pattern in `RenderWidget.razor`. |

The mapping between catalogue entries and Blazor components is performed by `RenderWidget.razor`
via pattern-matching on `PlacedWidget.OriginalWidgetName` (case-insensitive `Contains` checks).
**There is no ID-based binding** — catalogue entry names must match the patterns in the switch.

> **Post-cleanup (commit `9cc4d9b`):** Mock widgets (KpiWidget, AgentStatusWidget, QueueSummaryWidget)
> and 11 stub catalogue entries removed. Only 3 SignalR-backed components remain.
> Stub `.razor` files reduced to a single comment line — compile to empty classes, no dead code.

---

## Catalogue entries (seed data)

Seeded idempotently by `DatabaseInitializer.SeedWidgetCatalogAsync()` on first run.

### Category: Queues (1 entry)

| Name | Description | Blazor component | Notes |
|---|---|---|---|
| **Queue Grid** | Real-time queue metrics table with customizable rows and columns | `QueueGridWidget.razor` | SignalR-connected, 1 320 lines |

> Removed in `9cc4d9b`: Queue Summary (mock), Queue Trend, SLA Bar, Abandoned Calls (no component).

### Category: Agents (1 entry)

| Name | Description | Blazor component | Notes |
|---|---|---|---|
| **Agent Grid** | Real-time agent table with states, durations, metrics and alerts | `AgentGridWidget.razor` | SignalR-connected, 1 340 lines; most feature-rich widget |

> Removed in `9cc4d9b`: Agent Status (mock), Agent List, Occupancy Gauge (no component).

### Category: General metrics (1 entry)

| Name | Description | Blazor component | Notes |
|---|---|---|---|
| **Data Slot** | Single metric display with target comparison | `DataSlotWidget.razor` | SignalR-connected, 489 lines; delta arrows, thresholds |

> Removed in `9cc4d9b`: KPI Scorecard (mock), Calls Per Hour, AHT Chart, Real-time Ticker (no component).

---

## Implemented Blazor components (3 total)

> All three components connect to an external SignalR simulator.
> Mock widgets were removed in commit `9cc4d9b`.

---

---


### 1. `AgentGridWidget.razor` (1 340 lines)

**Catalogue entry:** `Agent Grid` (Agents)  
**Match pattern:** `Contains("agent") && Contains("grid")`  
**Data source:** External SignalR simulator at `{SignalRConnectionUrl}/hubs/agent-grid?gridId={GridId}`  
**Parameters:** `WidgetConfig? Config`, `int GridId`, `bool DarkMode`  
**Implements:** `IAsyncDisposable`

**Capabilities:**
- Full SignalR lifecycle: connect → subscribe → receive `AgentGridUpdate` → reconnect on drop
- Connection states: `Connecting` / `Connected` / `Reconnecting` / `Failed` (with Retry button)
- `GridId = 0` → unconfigured placeholder (prompt to save config first)
- Sortable columns (click header): ascending / descending toggle
- Per-column filter popups: text / number / time / enum (status) filter types
- Active filters toolbar with row count and "Clear all" button
- Server-side pagination (configurable page size from `Config.ShowPagination`)
- Optional avatar circles (`Config.ShowAvatar`) with configurable BG/font colour
- Optional score column (`Config.ShowScore`) with star display and configurable `ScoreFormula` rules
- Column definitions via `Config.AgentGridColumnDefs` (list of `AgentGridColumnDef`)
- Per-column thresholds via `Config.ColumnThresholds` (dict keyed by column name)
- Saved row filters from `Config.TableFilters` applied before display
- Team and state filters via `Config.AgentGridTeams` / `Config.AgentGridStates`
- Keyboard navigation: `ArrowUp` / `ArrowDown` row selection, `Escape` to clear selection
- Dark mode: table, header, rows adapt to `DarkMode` flag and dark colour config
- Hidden header mode: `Config.HideHeader = true` suppresses widget chrome in viewer
- Accessibility: `tabindex`, `aria-label`, `aria-live`, `role` attributes

**Backend persistence (RTS tables):**  
On save in `ScreenEditorPage.SaveWidgetConfig()`:
- Calls `SaveAgentGridRtsCommand` to create/update `RTSUserGrid_*` records
- `Config.ColumnsSetId` stores `RTSUserGrid_ColumnsSet.ColumnsSetId` after first save
- `Config.AgentGridColumnDefs[].DbColumnId` stores per-column `RTSUserGrid_Column.ColumnId`

**Known limitations:**
- Requires external SignalR simulator running on `SignalRConnectionUrl` (configured in `TenantSettings`)
- No fallback / demo data when simulator is unavailable (shows "Connection failed")
- Score formula supports rules but no aggregation functions (sum, avg) yet

---

### 2. `QueueGridWidget.razor` (1 320 lines)

**Catalogue entry:** `Queue Grid` (Queues)  
**Match pattern:** `Contains("queue") && Contains("grid")`  
**Data source:** External SignalR simulator at `{SignalRConnectionUrl}/hubs/queue-grid?gridId={GridId}`  
**Parameters:** `WidgetConfig? Config`, `int GridId`, `bool DarkMode`  
**Implements:** `IAsyncDisposable`

**Capabilities:**
- Full SignalR lifecycle (same as AgentGridWidget)
- Connection states with reconnect banner and retry button
- `GridId = 0` placeholder
- Fixed first column: Queue Name (from `_queueName` pseudo-metric)
- User-defined columns via `Config.QueueGridColumnDefs` (list of `QueueGridColumnDef`)
- User-defined rows via `Config.QueueGridRowDef` (list of `QueueGridRowDef`, each maps to a BU)
- Per-row background/font colour overrides
- Sortable columns, per-column filter popups
- Active filters toolbar with Clear all
- Pagination (`Config.ShowPagination`)
- Column header hide (`Config.HideHeader`)
- Per-column thresholds via `Config.ColumnThresholds`
- Dark mode (table, header, rows)
- JS interop for clipboard copy (`widget-resize.js`)
- Keyboard navigation (ArrowUp / ArrowDown / Escape)

**Backend persistence (RTS tables):**  
On save:
- Calls `SaveQueueGridRtsCommand` to create/update `RTSGrid_*` records
- `Config.GridId` stores `RTSGrid_Grid.GridId`
- `Config.HeaderRowId` stores header row ID (`RowNumber=1, CellType=Text`)
- `Config.HeaderCellIds` stores per-column header cell IDs
- `Config.QueueGridRows[].RowId` stores per-data-row IDs
- `Config.QueueGridRows[].CellIds` stores per-cell IDs keyed by column def ID

**Known limitations:**
- Same simulator dependency as AgentGridWidget
- Queue Name column always shown, cannot be hidden or repositioned

---

### 3. `DataSlotWidget.razor` (489 lines)

**Catalogue entry:** `Data Slot` (General metrics)  
**Match pattern:** `Contains("data") && Contains("slot")`  
**Data source:** External SignalR at `{SignalRConnectionUrl}/hubs/queue-grid?gridId={GridId}` (reuses queue-grid hub)  
**Parameters:** `WidgetConfig? Config`, `int GridId`, `bool DarkMode`  
**Implements:** `IAsyncDisposable`

**Capabilities:**
- Single metric display: shows the first value from the first row of a grid update
- Configurable metric selection via `Config.DataSlotMetricId`
- Time format auto-detection: `MM:SS` and `HH:MM:SS` recognised and stored as seconds for delta calculation
- Target comparison: `Config.DataSlotTarget` + `Config.DataSlotTargetMode` (`less` or `more`)
- Delta indicator: arrow up/down + text "+N / -N to target" or "On target"
- Arrow colour: green (on/better than target) / red (worse than target)
- Optional target label (`Config.DataSlotTargetLabel`)
- Configurable display: title, bold, alignment (left/center/right), font size
- Threshold rules (range-based colour override on value)
- Dark mode aware (separate dark bg/font colours)
- Connection states: Connecting / Connected / Reconnecting / Failed with Retry

**Backend persistence (RTS tables):**  
On save:
- `Config.DataSlotColumnId`, `Config.DataSlotRowId`, `Config.DataSlotCellIds` store RTS cell references

**Known limitations:**
- Shares the queue-grid SignalR hub — single-value extraction from a grid designed for tables
- No independent data hub for scalar metrics
- `Config.DataSlotBusinessUnitId` is stored but not currently used to filter which BU row to read

---

## RenderWidget.razor — dispatch logic

`src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor`

```
PlacedWidget.OriginalWidgetName (lowercase)
│
├─ Contains("agent") && Contains("grid")  →  AgentGridWidget
├─ Contains("queue") && Contains("grid")  →  QueueGridWidget
├─ Contains("data")  && Contains("slot")  →  DataSlotWidget
└─ default                                →  Placeholder (bi-puzzle icon + name)
```

**Note:** The default branch is now unreachable for any seeded catalogue entry —
all 3 seeded names match one of the three patterns above.

---

## WidgetConfig — full parameter reference

`WidgetConfig` is a flat class defined inside `ScreenEditorPage.razor` (nested class, public).
It is serialised to/from `DashboardWidget.ConfigJson` (jsonb in PostgreSQL).

### Common parameters (all widgets)

| Property | Type | Default | Used by |
|---|---|---|---|
| `DisplayName` | `string?` | null | All — shown in widget header |
| `BusinessUnit` | `string?` | null | QueueSummary, AgentStatus |
| `Metric` | `string?` | null | KPI — selects metric type |
| `FontSize` | `string?` | null | All — `small/large/xlarge/xxlarge` |
| `BackgroundColor` | `string?` | null | All |
| `FontColor` | `string?` | null | All |
| `DarkBackgroundColor` | `string?` | `#333333` | All |
| `DarkFontColor` | `string?` | `#FFFFFF` | All |
| `HeaderBackgroundColor` | `string?` | null | AgentGrid, QueueGrid |
| `HeaderFontColor` | `string?` | null | AgentGrid, QueueGrid |
| `DarkHeaderBackgroundColor` | `string?` | null | AgentGrid, QueueGrid |
| `DarkHeaderFontColor` | `string?` | null | AgentGrid, QueueGrid |
| `TableBackgroundColor` | `string?` | null | AgentGrid, QueueGrid |
| `DarkTableBackgroundColor` | `string?` | null | AgentGrid, QueueGrid |
| `Thresholds` | `List<ThresholdRule>?` | null | KPI, QueueSummary |
| `ColumnThresholds` | `Dictionary<string, List<ColumnThreshold>>?` | null | AgentGrid, QueueGrid |
| `TableFilters` | `List<TableFilterRule>?` | null | AgentGrid, QueueGrid |
| `ShowPagination` | `bool` | `true` | AgentGrid, QueueGrid |
| `HideHeader` | `bool` | `false` | AgentGrid, QueueGrid, DataSlot |

### Agent Grid–specific

| Property | Type | Default | Notes |
|---|---|---|---|
| `AgentGridColumnDefs` | `List<AgentGridColumnDef>?` | null | New column definitions |
| `AgentGridTeams` | `List<string>?` | null | Team name filter |
| `AgentGridStates` | `List<string>?` | null | State name filter |
| `ShowAvatar` | `bool` | `false` | |
| `AvatarBgColor` | `string?` | null | |
| `AvatarFontColor` | `string?` | null | |
| `ShowScore` | `bool` | `false` | |
| `ScoreStarColor` | `string?` | null | |
| `ScoreFormula` | `List<ScoreFormulaRule>?` | null | |
| `AgentGridShowAlerts` | `bool` | `true` | |
| `ColumnsSetId` | `int?` | null | RTS FK — set after first save |

### Queue Grid–specific

| Property | Type | Default | Notes |
|---|---|---|---|
| `QueueGridColumnDefs` | `List<QueueGridColumnDef>?` | null | |
| `QueueGridRows` | `List<QueueGridRowDef>?` | null | |
| `GridId` | `int?` | null | RTS FK — set after first save |
| `HeaderRowId` | `int?` | null | RTS FK |
| `HeaderCellIds` | `Dictionary<string, int?>` | `{}` | RTS FKs per column |

### Data Slot–specific

| Property | Type | Default | Notes |
|---|---|---|---|
| `DataSlotTitle` | `string?` | null | Overrides DisplayName for value label |
| `DataSlotMetricId` | `string?` | null | Metric column key from grid update |
| `DataSlotTarget` | `decimal?` | null | Comparison target |
| `DataSlotTargetMode` | `string?` | `"less"` | `"less"` or `"more"` |
| `DataSlotTargetLabel` | `string?` | null | Label next to target |
| `DataSlotTargetText` | `string?` | null | Additional target description |
| `DataSlotBold` | `bool` | `false` | Bold value display |
| `DataSlotAlign` | `string?` | `"center"` | `"left"`, `"center"`, `"right"` |
| `DataSlotShowTargetLabel` | `bool` | `true` | |
| `DataSlotShowArrow` | `bool` | `true` | |
| `DataSlotBusinessUnitId` | `int?` | null | BU filter (stored, not yet applied) |
| `DataSlotColumnId` | `int?` | null | RTS FK |
| `DataSlotRowId` | `int?` | null | RTS FK |
| `DataSlotCellIds` | `Dictionary<string, int?>?` | null | RTS FKs |

---

## Test coverage

| Test file | Widget area covered | Test count |
|---|---|---|
| `Tests.Security/Widgets/WidgetCatalogTests.cs` | WGT-01 cross-tenant visibility, WGT-02/03 access control (Superadmin vs non-Superadmin), deactivated items filtering | 6 |
| `Tests.Security/Widgets/DashboardWidgetTests.cs` | WGT-04 lifecycle (save/retrieve/delete), soft-delete interaction, GridId round-trip | 5 |
| `Tests.Security/Widgets/RtsGridLifecycleTests.cs` | Agent/Queue Grid RTS CRUD + dual-write `IConfigurationApiHook` assertions | 13 |
| `Tests.Unit/Commands/SaveDashboardWidgetCommandHandlerTests.cs` | `SaveDashboardWidgetCommand` handler: permission check, audit event | ? |

**Not covered by tests (as of T6/cleanup):**
- Blazor component rendering (no bUnit or Playwright tests)
- SignalR connection lifecycle in `AgentGridWidget`, `QueueGridWidget`, `DataSlotWidget`
- `WidgetConfig` serialisation round-trip
- Default placeholder branch in `RenderWidget` (unreachable for seeded entries)

---

## Gap analysis

### Catalogue parity

All 3 catalogue entries now have a corresponding Blazor component. No stubs or placeholders remain.
Removed entries (Queue Trend, SLA Bar, Abandoned Calls, Agent List, Occupancy Gauge,
Calls Per Hour, AHT Chart, Real-time Ticker, Queue Summary, KPI Scorecard, Agent Status)
are cleaned up by `DatabaseInitializer.SeedWidgetCatalogAsync()` on next application start.

### Missing catalogue admin UI

Per [WGT-03] and ADR-001, the admin CRUD screen for catalogue items is deferred.
Superadmin can manage items only via DB migration or direct INSERT. `WidgetCataloguePage`
is read-only browse.

### No component-level unit tests

Blazor component tests (bUnit) are absent. All widget tests are at the Application/
Infrastructure level via `WebApplicationFactory` + Testcontainers. Component rendering,
config modal logic, and SignalR state machine are untested.

---

## Related files

| File | Purpose |
|---|---|
| `src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor` | Widget dispatch by name pattern |
| `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` | Editor with drag-and-drop palette + config modal (2 896 lines) |
| `src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor` | Read-only viewer (255 lines) |
| `src/CcDashboard.Domain/Domain/WidgetCatalogItem.cs` | Entity |
| `src/CcDashboard.Domain/Domain/WidgetTemplate.cs` | Per-tenant saved widget config templates |
| `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` | `SeedWidgetCatalogAsync()` |
| `src/CcDashboard.Infrastructure/Persistence/Repositories/WidgetCatalogRepository.cs` | Repository |
| `src/CcDashboard.Application/Queries/Widgets/GetWidgetCatalogQuery.cs` | Browse query with role-based IsActive filter |
| `src/CcDashboard.Application/Commands/Dashboards/UpdateDashboardWidgetsCommand.cs` | Batch save placed widgets + LayoutJson |
| `src/CcDashboard.Web/wwwroot/js/widget-resize.js` | JS interop for widget resize + clipboard |
| `docs/architecture/widget-framework.md` | Architecture overview (T5 input) |
| `decisions/ADR-001*.md` | Widget catalogue scope decision |
| `decisions/ADR-004*.md` | SignalR seam design |
| `decisions/ADR-008*.md` | Dual-write pattern |
