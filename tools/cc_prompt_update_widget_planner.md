# Task: Add RTM QueueGrid lessons to widget-planner skill

## File to update

`.claude/skills/widget-planner/widget-planner.md`

## What to add

Append a new section at the end of the file titled:
**`## Lesson 11 — RTM QueueGrid data flow & production bugs (2026-06-03)`**

Content to append (write verbatim):

---

## Lesson 11 — RTM QueueGrid data flow & production bugs (2026-06-03)

### Complete component chain

```
RTM Service startup
  RTSGrid_GetDataCells()              reads RTSGrid_Cell (no TemplateCell — removed)
  GetAllUnionQueueClassifications()   reads NGC_BusinessUnitQueueClassification
    ClassificationId == "ALL"  →  union.addWorkgroup(QueueId)
                                →  Union.Queues.Add(QueueId)
                                →  WorkgroupManager registered
  DataCells loop: Cell registered to Grid + Union in memory

RTM Service runtime
  CC event (call enters queue "Everyone")
  getOrAddWGManager("Everyone")  →  finds WorkgroupManager
  metrics recalculated for Union 56
  Grid 31 GridEvent  →  updateGridData to SignalR group "31"
  payload: [{CellId, Value}, ...]

Shell RtmRelayService
  Connected to RTM hub (TenantSettings.SignalRConnectionUrl)
  On connect: init("31") + refreshCells("31")
  Receives updateGridData  →  snapshot + fan-out to widget handlers

QueueGridWidget (Blazor)
  SubscribeGridAsync(tenantId, gridId=31, handler)
  handler: CellId  →  _cellMap  →  RowDefId  →  update row value  →  StateHasChanged()
```

### Bug 1 — RTSGrid_TemplateCell INNER JOIN (always empty)

**Root cause:** `RTSGrid_GetDataCells` had INNER JOIN with `RTSGrid_TemplateCell`.
This table is legacy MSSQL data loaded via pgloader. It was **always 0 rows** in
all deployments. INNER JOIN with empty table = function returns 0 rows = RTM Engine
registers no cells = `updateGridData` never fires.

**Fix:** Remove TemplateCell from query. Cells already have `CellType = 'Data'`
explicitly. Return `NULL::text AS "ColumnMetric"` to preserve column index 9.

**Invariant:** `RTSGrid_TemplateCell` is permanently removed from the solution.
Never reference it in SQL functions or Shell entity model.

### Bug 2 — ClassificationId not set to "ALL"

**Root cause:** Shell saved `NgcBusinessUnitQueueClassification` records with
`ClassificationId = null/""`. RTM Engine only calls `union.addWorkgroup()` when
`ClassificationId == "ALL"`. Without it:
- `Union.Queues` stays empty
- Incoming call with Workgroup="Everyone" hits `getOrAddWGManager`
- A **new duplicate BusinessUnit** is created at runtime
- Cells registered for Union 56 / Grid 31 never receive data

**Fix:** Always set `ClassificationId = "ALL"` in:
- `ConfigurationCommands.cs` QueueAssignment loop
- `DatabaseInitializer.cs` seed loop
- EF migration to fix existing NULL/empty records

**Invariant:** `ClassificationId = "ALL"` = "all calls from this queue, any
classification". Always use this for standard BU-Queue mappings. The Shell UI
does not expose ClassificationId — never leave it null.

### Debugging checklist — QueueGrid shows no data

1. `SELECT count(*) FROM "RTSGrid_GetDataCells"()` must be > 0
2. `SELECT * FROM "RTSGrid_GetAllUnionQueueClassifications"(tenant_id)` must return rows;
   check `ClassificationId = 'ALL'` and `NGC_Site` has matching SiteId
3. RTM Service log: `LoadData: DataCells` — count of registered cells
4. RTM Service log: `Add Workgroup id=...` at runtime = BU not registered at startup
5. `SELECT count(*) FROM "RTSData_Interaction"` — confirms calls written by RTM
6. Shell log: `RtmRelayService: init+refreshCells complete for grid N` — SignalR OK

### Key data model facts

- **UnionId = BusinessUnitId**: same integer used in both RTSGrid and NGC tables
- **SignalR group for QueueGrid**: gridId as string (`"31"`), init param: `"31"`
- **SignalR group for AgentGrid**: `"u" + unionId` (`"u56"`), init param: `"u56"`
- **Cell fallback UnionId**: checked as Cell.UnionId → Row.UnionId → Grid.UnionId

---

Read this section before debugging any QueueGrid widget that shows no data.
