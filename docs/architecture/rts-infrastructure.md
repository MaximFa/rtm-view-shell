# RTS Infrastructure — RTM View Shell

**Document type:** Technical Reference  
**Version:** 1.0  
**Date:** 2026-05-26  
**Status:** Current  
**Scope:** Existing widget components and RTS table infrastructure as of commit `e0a308b`

---

## Part 1 — Blazor Widget Components

### 1.1 AgentGridWidget

**File:** `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

**SignalR connection**

| Parameter | Value |
|---|---|
| Hub URL | `{TenantSettings.SignalRConnectionUrl}/hubs/agent-grid?gridId={GridId}` |
| Default URL | `http://localhost:5045/hubs/agent-grid?gridId={GridId}` |
| Subscribe method | Automatic via query string `?gridId=` |
| Push event | `AgentGridUpdate` |

**Incoming message format**

```csharp
record GridUpdate(int GridId, DateTime Timestamp, List<GridRowData> Rows);
record GridRowData(string RowId, Dictionary<string, string> Metrics);
```

**Data mapping**
- `RowId` — agent row identifier
- `Metrics[MetricId]` — metric value for a cell
- Columns are defined via `Config.AgentGridColumnDefs[].MetricId`

**Component parameters**

| Parameter | Type | Description |
|---|---|---|
| `GridId` | `int` | `RTSUserGrid_Grid.GridId` — passed in URL on connect |
| `Config` | `WidgetConfig` | Widget configuration from ConfigJson |
| `DarkMode` | `bool` | Dark theme flag |

**Lifecycle**
- `OnInitializedAsync`: `ApplyConfig()` → `ConnectAsync()`
- `OnParametersSetAsync`: Reconnects if `GridId` changed from 0 to non-zero
- `DisposeAsync`: `_hub.DisposeAsync()`, cancels `CancellationToken`
- Reconnect: `WithAutomaticReconnect` (0s, 2s, 5s, 10s, 30s)
- States: `Connecting` → `Connected` | `Reconnecting` | `Failed`

---

### 1.2 QueueGridWidget

**File:** `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`

**SignalR connection**

| Parameter | Value |
|---|---|
| Hub URL | `{TenantSettings.SignalRConnectionUrl}/hubs/queue-grid?gridId={GridId}` |
| Default URL | `http://localhost:5045/hubs/queue-grid?gridId={GridId}` |
| Subscribe method | Query string `?gridId=` + `UpdateRowConfig()` |
| Push event | `QueueGridUpdate` |

**Incoming message format**

```csharp
record GridUpdate(int GridId, DateTime Timestamp, List<GridRowData> Rows);
record GridRowData(string RowId, Dictionary<string, string> Metrics);
```

**Data mapping**
- `RowId` matches `QueueGridRowDef.Id` (local GUID)
- Data updates `Metrics` of existing rows by `RowId`
- Columns defined via `Config.QueueGridColumnDefs[].MetricId`
- First column is always `QueueName` (not from Metrics)

**Additional hub method**
```csharp
await _hub.SendAsync("UpdateRowConfig", GridId, rowConfigs);
// rowConfigs = List<(RowId, RowIndex, DisplayName)>
```

**Component parameters**

| Parameter | Type | Description |
|---|---|---|
| `GridId` | `int` | `RTSGrid_Grid.GridId` |
| `Config` | `WidgetConfig` | Widget configuration |
| `DarkMode` | `bool` | Dark theme flag |

**Lifecycle**  
Same as AgentGridWidget + calls `SendRowConfig()` after connect and on reconnect.

---

### 1.3 DataSlotWidget

**File:** `src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor`

**SignalR connection**

| Parameter | Value |
|---|---|
| Hub URL | `{TenantSettings.SignalRConnectionUrl}/hubs/queue-grid?gridId={GridId}` |
| Subscribe method | `SubscribeToGrid(GridId)` |
| Push event | `QueueGridUpdate` (same as QueueGrid) |

**Incoming message format:** Identical to QueueGridWidget.

**Data mapping**
- DataSlot has 1 Row, 1 Column, 1 Cell
- Takes `Rows[0].Metrics[_metricId]` or first metric
- Parsed as number or time (`MM:SS`, `HH:MM:SS`)

**Component parameters**

| Parameter | Type | Description |
|---|---|---|
| `GridId` | `int` | `RTSGrid_Grid.GridId` (`DataSlotGridId` from Config) |
| `Config` | `WidgetConfig` | Widget configuration |
| `DarkMode` | `bool` | Dark theme flag |

**Lifecycle**  
Simplified lifecycle without pagination and row config.

---

## Part 2 — RTS Tables

### 2.1 Family RTSUserGrid_* (Agent Grid)

**Owner:** CC backend (shell emulates in dev/test)  
**DbContext:** `BackendEmulationDbContext`  
**Access mode:** Read-Write via `IRtsRepository`  
**Used by:** AgentGridWidget

**RTSUserGrid_ColumnsSet**

| Column | Type | Description |
|---|---|---|
| `ColumnsSetId` | int (IDENTITY) | PK |
| `Title` | varchar(100) | Column set name |
| `Description` | text | Description |
| `Direction` | varchar(10) | Text direction (RTL/LTR) |

**RTSUserGrid_Column**

| Column | Type | Description |
|---|---|---|
| `ColumnId` | int (IDENTITY) | PK |
| `ColumnsSetId` | int | FK → RTSUserGrid_ColumnsSet |
| `Title` | varchar(100) | Column header |
| `MetricId` | varchar(100) | Reference to RTSGrid_Metric |
| `StyleId` | int | Style ID |
| `ColumnsOrder` | int | Display order |

**RTSUserGrid_Grid**

| Column | Type | Description |
|---|---|---|
| `GridId` | int (IDENTITY) | PK |
| `UnionId` | int | BusinessUnitId for filtering |
| `StyleId` | int | Style ID |
| `Title` | varchar(100) | Grid name |
| `RowsFilter` | varchar(300) | Row filter |
| `PageSize` | int | Page size |
| `ColumnsSetId` | int | FK → RTSUserGrid_ColumnsSet |
| `ThresholdScript` | text | Threshold script |
| `RowsFilterNew` | varchar(300) | New filter (updated field) |
| `NoRecordsText` | text | Empty data text |
| `AllowPaging` | bool | Enable pagination |
| `AllowScroll` | bool | Enable scroll |
| `TextDirection` | varchar(5) | Text direction |

**Relations**
```
RTSUserGrid_ColumnsSet (1) ←→ (N) RTSUserGrid_Column
RTSUserGrid_Grid       (N) →→  (1) RTSUserGrid_ColumnsSet
```

---

### 2.2 Family RTSGrid_* (Queue Grid, Data Slot)

**Owner:** CC backend (shell emulates in dev/test)  
**DbContext:** `BackendEmulationDbContext`  
**Access mode:** Read-Write via `IRtsRepository`  
**Used by:** QueueGridWidget, DataSlotWidget

**RTSGrid_Grid**

| Column | Type | Description |
|---|---|---|
| `GridId` | int (IDENTITY) | PK |
| `UnionId` | int | BusinessUnitId (-1 for general) |
| `StyleId` | int | Style ID |
| `Title` | varchar(100) | Grid name |
| `ThresholdScript` | text | Threshold script |

**RTSGrid_Column**

| Column | Type | Description |
|---|---|---|
| `ColumnId` | int (IDENTITY) | PK |
| `GridId` | int | FK → RTSGrid_Grid |
| `ColumnNumber` | int | Order (1-based) |
| `CellTemplateId` | int | = ColumnId (self-ref) |

**RTSGrid_Row**

| Column | Type | Description |
|---|---|---|
| `RowId` | int (IDENTITY) | PK |
| `GridId` | int | FK → RTSGrid_Grid |
| `RowNumber` | int | Order (1=header, 2+=data) |
| `UnionId` | int | BusinessUnitId (-1 for header) |
| `StyleId` | int | Style ID |
| `ThresholdScript` | text | Threshold script |
| `OldRowId` | int | Legacy |

**RTSGrid_Cell**

| Column | Type | Description |
|---|---|---|
| `CellId` | int (IDENTITY) | PK |
| `RowId` | int | FK → RTSGrid_Row |
| `ColumnId` | int | FK → RTSGrid_Column |
| `ColNumber` | int | Column number |
| `UnionId` | int | BusinessUnitId |
| `StyleId` | int | Style ID |
| `CellType` | varchar(50) | `"Text"` (header) / `"Data"` (value) |
| `Value` | varchar(500) | Header: text; Data: MetricId |
| `Tooltip` | varchar(500) | Tooltip |
| `OnClick` | varchar(500) | Click action |
| `ThresholdSetId` | int | Threshold set ID |
| `NewRowId` | int | Legacy |
| `OldRowId` | int | Legacy |

**Relations**
```
RTSGrid_Grid   (1) ←→ (N) RTSGrid_Column
RTSGrid_Grid   (1) ←→ (N) RTSGrid_Row
RTSGrid_Row    (1) ←→ (N) RTSGrid_Cell
RTSGrid_Column (1) ←→ (N) RTSGrid_Cell
```

---

### 2.3 RTSGrid_Metric (metric reference)

**Owner:** CC backend  
**Access mode:** Read-Only  
**Used by:** Metric selector in widget config UI

| Column | Type | Description |
|---|---|---|
| `MetricId` | varchar(100) | PK (e.g. `"QueuePctAbandonedCallsTotal"`) |
| `Description` | text | Metric description |
| `DataType` | varchar(50) | Data type |
| `MetricFunction` | varchar(200) | Calculation function |
| `MetricParameter` | varchar(200) | Parameters |
| `MetricFormat` | varchar(100) | Display format |
| `DefaultValue` | varchar(100) | Default value |
| `ValueType` | varchar(20) | `"String"` / `"Number"` / `"Time"` |
| `MetricType` | varchar(20) | `"Agent"` / `"Queue"` |

---

## Part 3 — Shell RTS Commands

### 3.1 SaveAgentGridRtsCommand

**File:** `src/CcDashboard.Application/Commands/Dashboards/SaveAgentGridRtsCommand.cs`  
**Tables:** `RTSUserGrid_ColumnsSet`, `RTSUserGrid_Column`, `RTSUserGrid_Grid`

```csharp
record SaveAgentGridRtsCommand(
    int GridId,                    // 0 for new
    int? ColumnsSetId,             // null for new
    string WidgetName,             // Title
    int? BusinessUnitId,           // UnionId
    string? RowsFilter,
    List<RtsColumnInput> Columns
);

record RtsColumnInput(
    int? DbColumnId,               // null for new column
    string Title,
    string MetricId,
    int ColumnsOrder
);
```

**Returns**
```csharp
record SaveAgentGridRtsResult(
    int GridId,
    int ColumnsSetId,
    List<(string Title, int DbColumnId)> SavedColumns
);
```

**NotifyAsync:** `"AgentGridRts.Saved"` → `{ GridId, ColumnsSetId }`

---

### 3.2 DeleteAgentGridRtsCommand

**File:** `src/CcDashboard.Application/Commands/Dashboards/DeleteAgentGridRtsCommand.cs`  
**Tables:** `RTSUserGrid_Grid`, `RTSUserGrid_ColumnsSet`, `RTSUserGrid_Column`

```csharp
record DeleteAgentGridRtsCommand(int GridId);
```

**Logic:** Grid → ColumnsSetId → Delete Grid → Delete ColumnsSet (cascade deletes Columns)  
**NotifyAsync:** `"AgentGridRts.Deleted"` → `{ GridId, ColumnsSetId }`

---

### 3.3 SaveQueueGridRtsCommand

**File:** `src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs`  
**Tables:** `RTSGrid_Grid`, `RTSGrid_Column`, `RTSGrid_Row`, `RTSGrid_Cell`

```csharp
record SaveQueueGridRtsCommand(
    int? GridId,
    int? HeaderRowId,
    string Title,
    List<QueueGridColumnInput> Columns,
    List<QueueGridRowInput> Rows,
    Dictionary<string, int?> ExistingHeaderCellIds
);

record QueueGridColumnInput(
    string LocalId,        // GUID for tracking
    int? ColumnId,         // null for new
    string Name,
    string MetricId,
    int ColumnNumber       // 1-based
);

record QueueGridRowInput(
    string LocalId,
    int? RowId,
    int? BusinessUnitId,
    int RowNumber,         // 2+ (1=header)
    Dictionary<string, int?> CellIds  // key = column LocalId
);
```

**Returns**
```csharp
record SaveQueueGridRtsResult(
    int GridId,
    int HeaderRowId,
    Dictionary<string, int> SavedColumnIds,
    Dictionary<string, int> HeaderCellIds,
    Dictionary<string, int> SavedRowIds,
    Dictionary<string, Dictionary<string, int>> SavedCellIds
);
```

**NotifyAsync:** `"QueueGridRts.Saved"` → `{ GridId, HeaderRowId, Title, ColumnCount, RowCount, ColumnIds, RowIds }`

---

### 3.4 DeleteQueueGridRtsCommand

**File:** `src/CcDashboard.Application/Commands/Dashboards/DeleteQueueGridRtsCommand.cs`  
**Tables:** `RTSGrid_Grid`, `RTSGrid_Column`, `RTSGrid_Row`, `RTSGrid_Cell`

```csharp
record DeleteQueueGridRtsCommand(int GridId);
```

**Logic:** Cascade delete: Cells → Columns + Rows → Grid  
**NotifyAsync:** `"QueueGridRts.Deleted"` → `{ GridId }`

---

### 3.5 SaveDataSlotRtsCommand

**File:** `src/CcDashboard.Application/Commands/Dashboards/SaveDataSlotRtsCommand.cs`  
**Tables:** `RTSGrid_Grid`, `RTSGrid_Column`, `RTSGrid_Row`, `RTSGrid_Cell` (1 record each)

```csharp
record SaveDataSlotRtsCommand(
    int? GridId,
    int? ColumnId,
    int? RowId,
    int? CellId,
    string Title,
    string MetricId,
    int? BusinessUnitId
);
```

**Returns**
```csharp
record SaveDataSlotRtsResult(int GridId, int ColumnId, int RowId, int CellId);
```

**Note:** Checks record existence in DB before UPDATE (guards against orphan IDs in ConfigJson after clone/restore).  
**NotifyAsync:** `"DataSlotRts.Saved"` → `{ GridId, ColumnId, RowId, CellId, Title, MetricId, BusinessUnitId }`

---

## Part 4 — ConfigJson Fields per Widget

### 4.1 Agent Grid

| Field | Type | Description |
|---|---|---|
| `rtsUserGridId` | `int?` | `RTSUserGrid_Grid.GridId` |
| `columnsSetId` | `int?` | `RTSUserGrid_ColumnsSet.ColumnsSetId` |
| `agentGridColumnDefs` | `List` | Column definitions |
| `agentGridColumnDefs[].dbColumnId` | `int?` | `RTSUserGrid_Column.ColumnId` |

**Save:** `SaveAgentGridRtsCommand` → result written to `rtsUserGridId`, `columnsSetId`, `agentGridColumnDefs[].dbColumnId`  
**Open:** Loaded from Config and used on subsequent Save  
**Delete:** `DeleteAgentGridRtsCommand(rtsUserGridId)`

---

### 4.2 Queue Grid

| Field | Type | Description |
|---|---|---|
| `gridId` | `int?` | `RTSGrid_Grid.GridId` |
| `headerRowId` | `int?` | `RTSGrid_Row.RowId` (RowNumber=1) |
| `headerCellIds` | `Dict<string, int?>` | Header cell IDs (key = column.Id) |
| `queueGridColumnDefs` | `List` | Column definitions |
| `queueGridColumnDefs[].columnId` | `int?` | `RTSGrid_Column.ColumnId` |
| `queueGridRows` | `List` | Row definitions |
| `queueGridRows[].rowId` | `int?` | `RTSGrid_Row.RowId` |
| `queueGridRows[].cellIds` | `Dict<string, int?>` | Cell IDs (key = column.Id) |

**Save:** `SaveQueueGridRtsCommand` → all IDs written to corresponding fields  
**Open:** All IDs loaded and used on Save  
**Delete:** `DeleteQueueGridRtsCommand(gridId)`

---

### 4.3 Data Slot

| Field | Type | Description |
|---|---|---|
| `dataSlotGridId` | `int?` | `RTSGrid_Grid.GridId` |
| `dataSlotColumnId` | `int?` | `RTSGrid_Column.ColumnId` |
| `dataSlotRowId` | `int?` | `RTSGrid_Row.RowId` |
| `dataSlotCellId` | `int?` | `RTSGrid_Cell.CellId` |
| `dataSlotMetricId` | `string` | MetricId for Cell.Value |
| `dataSlotBusinessUnitId` | `int?` | BusinessUnitId for Row.UnionId |

**Save:** `SaveDataSlotRtsCommand` → all IDs written  
**Open:** IDs loaded into local variables `_dataSlotGridId`, `_dataSlotColumnId`, `_dataSlotRowId`, `_dataSlotCellId`  
**Delete:** `DeleteQueueGridRtsCommand(dataSlotGridId)` — reuses Queue Grid delete command

---

## Appendix: Deferred Deletion Pattern

When a widget is removed via UI:

1. `ConfirmDeleteWidget()` — widget is added to `WidgetsPendingRtsDeletion`
2. UI updates immediately (`PlacedWidgets.Remove`)
3. `SaveLayout()` — on dashboard save, actual RTS deletion runs:

```csharp
foreach (var widget in WidgetsPendingRtsDeletion)
{
    if (IsAgentGridWidget && RtsUserGridId > 0)
        → DeleteAgentGridRtsCommand(RtsUserGridId)
    else if (IsQueueGridWidget && GridId > 0)
        → DeleteQueueGridRtsCommand(GridId)
    else if (IsDataSlotWidget && DataSlotGridId > 0)
        → DeleteQueueGridRtsCommand(DataSlotGridId)
}
WidgetsPendingRtsDeletion.Clear();
```

This prevents RTS data loss if the user removes a widget but does not save the layout.

---

## Part 5 — RTSData_* Tables (read-only data)

**Owner:** CC backend / external system  
**DbContext:** `BackendEmulationDbContext`  
**Access mode:** Read-Only — shell reads for widget display; backend writes  
**Purpose:** Real-time call/interaction and agent status data that feeds widget SignalR pushes  
and serves as the source for historical queries.

---

### 5.1 RTSData_Interaction

Real-time interaction (call/chat) data for queue and agent monitoring.

**PK:** `(InteractionId, Segment, OnDate, ServerId, Workgroup)`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `TenantId` | uuid | YES | Tenant identifier |
| `InteractionId` | varchar(50) | NO | Unique interaction ID |
| `Segment` | integer | NO | Segment number within interaction |
| `OnDate` | varchar(50) | NO | Date partition key |
| `ServerId` | varchar(50) | NO | Server identifier |
| `Workgroup` | varchar(100) | NO | Queue/workgroup name |
| `UserId` | varchar(50) | NO | Agent user ID |
| `ClassificationCode` | text | YES | Call classification/wrap-up code |
| `InteractionType` | varchar(50) | YES | Type: Call, Chat, Email, etc. |
| `CallType` | varchar(50) | YES | Inbound, Outbound, Internal |
| `Direction` | varchar(50) | YES | In/Out direction |
| `CustomCallData` | text | YES | Custom data field |
| `IsTransferred` | boolean | YES | Transfer flag |
| `IsAnswered` | boolean | YES | Answered flag |
| `IsInQueue` | boolean | YES | Currently in queue |
| `IsTalk` | boolean | YES | Currently talking |
| `IsAbandoned` | boolean | YES | Abandoned flag |
| `TimeInQueue` | integer | YES | Queue wait time (seconds) |
| `TalkTime` | integer | YES | Talk duration (seconds) |
| `InQueueDateTime` | timestamptz | YES | Entered queue timestamp |
| `AnsweredDateTime` | timestamptz | YES | Answer timestamp |
| `UpdateTime` | timestamptz | YES | Last update timestamp |
| `LastUserId` | varchar(50) | YES | Last handling agent |
| `LastWorkgroup` | varchar(100) | YES | Last workgroup |
| `IsMessaging` | boolean | YES | Messaging interaction flag |
| `RemoteAddress` | varchar(50) | YES | Remote phone/address |
| `CustomCallData1`..`CustomCallData20` | text | YES | Extended custom fields (×20) |
| `IsCallbackRequest` | boolean | YES | Callback request flag |
| `TimeZone` | varchar(10) | YES | Timezone offset |

**Used by:** Queue Grid (calls waiting, SLA, abandon rate), Data Slot

---

### 5.2 RTSData_UserStatus

Aggregated agent status statistics per day.

**PK:** `(UserId, StatusId, ServerId, OnDate)`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `TenantId` | uuid | YES | Tenant identifier |
| `UserId` | varchar(100) | NO | Agent user ID |
| `StatusId` | varchar(100) | NO | Status code |
| `ServerId` | varchar(50) | NO | Server identifier |
| `OnDate` | varchar(50) | NO | Date partition key |
| `StatusName` | varchar(100) | YES | Status display name |
| `StatusGroup` | varchar(100) | YES | Status group (Available, Away, etc.) |
| `TotalDuration` | integer | YES | Total time in status (seconds) |
| `MaxDuration` | integer | YES | Max single duration (seconds) |
| `TotalCount` | integer | YES | Number of times in status |
| `UpdateTime` | timestamptz | YES | Last update timestamp |
| `DisplayName` | varchar(100) | YES | Agent display name |
| `TimeZone` | varchar(10) | YES | Timezone offset |

**Used by:** Agent Grid (agent state, duration, availability)

---

### 5.3 RTSData_UserStatusLog

Agent status change log — time-series of individual status transitions.

**PK:** `Id` (surrogate, serial)

| Column | Type | Nullable | Description |
|---|---|---|---|
| `Id` | serial | NO | Auto-increment PK |
| `TenantId` | uuid | YES | Tenant identifier |
| `UserId` | varchar(100) | YES | Agent user ID |
| `StatusId` | varchar(100) | YES | Status code |
| `StatusGroup` | varchar(50) | YES | Canonical group: AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING — see [CC-001] |
| `ServerId` | varchar(50) | YES | Server identifier |
| `OnDate` | varchar(50) | YES | Date partition key |
| `StartTime` | timestamptz | YES | Status start timestamp |
| `EndTime` | timestamptz | YES | Status end timestamp (null = current) |
| `Duration` | bigint | YES | Duration in **milliseconds** |
| `UpdateTime` | timestamptz | YES | Record update timestamp |
| `TimeZone` | varchar(10) | YES | Timezone offset |

**Used by:** Agent timeline, status history reports, DayTrend interval widgets

---

### 5.4 Data flow summary

```
External CC system
        │
        ▼ writes
RTSData_Interaction   ──► SignalR server ──► QueueGridWidget  (GridUpdate push)
RTSData_UserStatus    ──► SignalR server ──► AgentGridWidget  (GridUpdate push)
RTSData_UserStatusLog                   ──► DataSlotWidget    (GridUpdate push)
        │
        ▼ direct DB read (future historical widgets)
Historical comparison queries (OnDate filter)
```

Shell accesses these tables **read-only**. No shell commands write to `RTSData_*`.
