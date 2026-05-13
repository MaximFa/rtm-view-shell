# Task: Write RTS tables on widget Save

## Context

When a user saves an AgentGrid widget in the editor, the system must write configuration
to three PostgreSQL tables (already created): `RTSUserGrid_Grid`, `RTSUserGrid_ColumnsSet`,
`RTSUserGrid_Column`. These tables are read by the external SignalR server to serve real-time
data to the widget.

The external server identifies the grid by `RTSUserGrid_Grid.GridId`, which must match
`DashboardWidget.GridId`. Both use PostgreSQL IDENTITY — the save order must guarantee
they are in sync (see Step 1).

Key source files:
- `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` — editor, `SaveWidgetConfig()`
- `src/CcDashboard.Application/Commands/Dashboards/SaveDashboardWidgetCommand.cs`
- `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs`
- `src/CcDashboard.Domain/Domain/RtsEntities.cs` — `RtsUserGridGrid`, `RtsUserGridColumnsSet`, `RtsUserGridColumn`

---

## Step 1 — Fix GridId ownership

Currently `DashboardWidget.GridId` is `UseIdentityAlwaysColumn()` (no explicit insert allowed).
The RTS flow requires that `RTSUserGrid_Grid` generates the GridId first, and
`DashboardWidget.GridId` receives that value.

In `AppDbContext.OnModelCreating`:
- Change `DashboardWidget.GridId` from `UseIdentityAlwaysColumn()` to `UseIdentityByDefaultColumn()`.
  This allows explicit value insert when needed.
- Keep `RtsUserGridGrid.GridId` as `UseIdentityAlwaysColumn()` — it is always auto-generated.

Create a new EF migration for this change:
```
dotnet ef migrations add ChangeGridIdToIdentityByDefault \
  --context AppDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

---

## Step 2 — Extend model classes

In `ScreenEditorPage.razor`, in the `WidgetConfig` class, add:
- `int? ColumnsSetId` — ID of the RTSUserGrid_ColumnsSet record, persisted after first save.

In the `AgentGridColumnDef` class, add:
- `int? DbColumnId` — ID of the RTSUserGrid_Column record, persisted after first save.
  Null means the column has not yet been inserted into the DB.

---

## Step 3 — New Application command: `SaveAgentGridRtsCommand`

Create `src/CcDashboard.Application/Commands/Dashboards/SaveAgentGridRtsCommand.cs`.

The command record takes:
- `int GridId` — 0 for new widget, existing GridId for update
- `int? ColumnsSetId` — null for new widget
- `string WidgetName` — display name (used as Title and Description)
- `int? BusinessUnitId` — stored as UnionId in RTSUserGrid_Grid
- `string? RowsFilter` — pre-built filter string (see Step 5)
- `List<RtsColumnInput> Columns` — each has: `int? DbColumnId`, `string Title`, `string MetricId`, `int ColumnsOrder`

Define a nested record `RtsColumnInput(int? DbColumnId, string Title, string MetricId, int ColumnsOrder)`.

The command returns a `SaveAgentGridRtsResult` record with:
- `int GridId` — the GridId of the RTSUserGrid_Grid record (new or existing)
- `int ColumnsSetId` — the ColumnsSetId after upsert
- `List<(string Title, int DbColumnId)> SavedColumns` — Title mapped to new DbColumnId for each column

Handler logic (inject `AppDbContext` directly via interface or repository, and `IConfigurationApiHook`):

**For RTSUserGrid_ColumnsSet:**
- If `ColumnsSetId` is null → INSERT new record: Title = WidgetName, Description = WidgetName,
  Direction = null. Use EF to add and SaveChanges, read back generated ColumnsSetId.
- If `ColumnsSetId` has value → DO NOTHING. ColumnsSetId is assigned once on first Save
  and never changes, same as GridId. Do not update the record.

**For RTSUserGrid_Column:**
- Columns coming in with `DbColumnId == null` → INSERT new records with ColumnsSetId, Title, MetricId, ColumnsOrder, StyleId = null.
- Columns coming in with `DbColumnId != null` → UPDATE Title, MetricId, ColumnsOrder for that ColumnId.
- Columns that existed before (have a DbColumnId) but are NOT in the incoming list → DELETE those records from RTSUserGrid_Column WHERE ColumnId = that DbColumnId.
  To detect deletions: query all existing ColumnIds for this ColumnsSetId, compare with incoming DbColumnIds, delete the difference.
- After insert, read back the generated ColumnId for each new column.

**For RTSUserGrid_Grid:**
- If `GridId == 0` → INSERT new record: UnionId = BusinessUnitId, StyleId = 1, Title = WidgetName,
  RowsFilter = RowsFilter, PageSize = 40, ColumnsSetId = (newly created ColumnsSetId from above),
  ThresholdScript = null, RowsFilterNew = RowsFilter (same value), NoRecordsText = null,
  AllowPaging = null, AllowScroll = null, TextDirection = null.
  Use EF to add, SaveChanges, read back generated GridId.
  GridId is assigned once on first Save and never regenerated.
- If `GridId > 0` → UPDATE the existing record: UnionId, Title, RowsFilter, RowsFilterNew.
  Do NOT change GridId, ColumnsSetId, StyleId, PageSize, ThresholdScript.

**API hook (placeholder):**
After all DB operations complete successfully, call:
```
await apiHook.NotifyAsync("AgentGridRts.Saved", new { GridId, ColumnsSetId }, ct);
```
`IConfigurationApiHook` is the existing interface (NoOp implementation logs only).
Leave a comment: `// TODO: replace NoOp with real REST or SignalR call — TBD`.

---

## Step 4 — Modify `SaveDashboardWidgetCommand` for new widgets

For NEW widgets (existing == null branch), the GridId must come from the RTS save, not
from the DashboardWidget identity sequence.

Change the handler to accept an optional `int PreassignedGridId = 0` parameter on the command.
When `PreassignedGridId > 0`, set `newWidget.GridId = PreassignedGridId` before calling
SaveChanges. EF will use `OVERRIDING USER VALUE` on the `BY DEFAULT` identity column,
inserting the provided value.

For EXISTING widgets, nothing changes — GridId is already set.

---

## Step 5 — Build RowsFilter string

Add a private static method `BuildRowsFilter(List<TableFilterRule> rules)` in
`ScreenEditorPage.razor`.

Format: `[MetricId] {operator} "Value"` per rule, joined by `||` (OR) or `&&` (AND)
based on each rule's Connector (applied before the rule, skip for the first rule).

Operator mapping (MatchType → filter string):
- `equal` → `==`
- `notequal` → `!=`
- `contains` → `LIKE`
- `notcontains` → `NOT LIKE`
- `greater` → `>`
- `greaterequal` → `>=`
- `less` → `<`
- `lessequal` → `<=`
- `empty` → `== ""`
- `notempty` → `!= ""`

For numeric operators (greater, greaterequal, less, lessequal), do NOT wrap the value
in quotes. For all others, wrap in double quotes.
Value for `empty`/`notempty` operators is hardcoded (no user value needed).

Example output: `[MonAgentStateDesc] == "PAPERWORK"||[MonAgentStateDesc] == "BREAK_DIALER"`

Return null if rules list is empty or all rules have empty MetricId.

---

## Step 6 — Wire up in `SaveWidgetConfig()`

In `ScreenEditorPage.razor`, `SaveWidgetConfig()` method, after building `newConfig`,
perform RTS save BEFORE saving the DashboardWidget (so we have GridId ready):

1. Parse BusinessUnitId: `int.TryParse(ConfigBusinessUnit, out var buId)`.
2. Build `RowsFilter` string by calling `BuildRowsFilter(ConfigTableFilters)`.
3. Build the `Columns` list from `ConfigAgentColumnDefs`:
   each column → `RtsColumnInput(col.DbColumnId, col.Name, col.MetricId, index + 1)`.
4. Send `SaveAgentGridRtsCommand` with current `ConfiguringWidget.GridId` (0 if new),
   `ConfiguringWidget.Config.ColumnsSetId`, WidgetName, buId, RowsFilter, Columns.
5. From the result: store `result.GridId`, `result.ColumnsSetId` into `newConfig`.
   Update `DbColumnId` on each `AgentGridColumnDef` in `ConfigAgentColumnDefs` using
   `result.SavedColumns` matched by Title.
6. Send `SaveDashboardWidgetCommand` with `PreassignedGridId = result.GridId` for new
   widgets (GridId == 0 before RTS save), or the existing GridId for updates.
7. Set `ConfiguringWidget.GridId = result.GridId`.

Re-serialize `newConfig` (now includes ColumnsSetId and updated DbColumnIds) into the
widget's ConfigJson before sending to `SaveDashboardWidgetCommand`.

---

## Step 7 — Load ColumnsSetId and DbColumnId on open

In `OpenWidgetConfig()`, when loading config into editor state:
- `ConfiguringWidget.Config.ColumnsSetId` is already in the config JSON.
- When populating `ConfigAgentColumnDefs` from `widget.Config.AgentGridColumnDefs`,
  include the `DbColumnId` field (it should already be there if the class was extended
  in Step 2).

---

## Step 8 — Verify

Run `dotnet build CcDashboard.sln` — no errors.

Manual check sequence:
1. Create a new AgentGrid widget → add columns → add a filter → Save.
   Verify rows appear in all three RTS tables. Verify `DashboardWidget.GridId` ==
   `RTSUserGrid_Grid.GridId`.
2. Open the same widget → change a column name → remove one column → add a new column → Save.
   Verify: RTSUserGrid_Column has the renamed column updated, deleted column removed,
   new column inserted with new ColumnId.
3. Check that `ConfigJson` in `dashboard_widgets` contains `columnsSetId` and
   `dbColumnId` values on each column def.
