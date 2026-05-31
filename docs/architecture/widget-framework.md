# Widget Framework Architecture — RTM View Shell v1.6

**Document type:** Technical Architecture  
**Version:** 1.6.0
**Date:** 2026-05-31 (RTM Relay architecture added)
**Status:** Current (v1.6 scope defined; rendering deferred to widget-library sprint)

---

## 1. Overview

The RTM View Shell provides the *container* for real-time dashboards. Its widget framework
responsibility is scoped to:

1. **Widget Catalogue** — a platform-wide registry of available widget types.
2. **Dashboard Widget lifecycle** — recording which widgets are placed on which dashboard
   (stub only; layout/rendering out of scope for v1).
3. **RTS Grid lifecycle** — managing per-user grid view configurations written by the
   CC backend.
4. **Backend notification seam** — notifying the CC platform when shell permission data
   changes (dual-write pattern).
5. **SignalR feed seam** — exposing the per-tenant SignalR endpoint URL for future
   widget-library connection.

Widget *rendering* and *drag-and-drop layout configuration* are explicitly **out of scope**
for v1. See [WGT-04] and ADR-001.

---

## 2. Widget Catalogue

### 2.1 Entity: `WidgetCatalogItem`

```
Table: widget_catalog (no GQF — cross-tenant entity)

Id              uuid (UUIDv7)    PK
Category        varchar(100)     e.g. "Queues", "Agents", "General metrics"
Name            varchar(200)     Widget type name
Description     text
IconUrl         varchar(500)
IsActive        boolean          false = hidden from non-Superadmin
```

`WidgetCatalogItem` is a **cross-tenant** entity — it does not carry a `TenantId` and is
not subject to the Global Query Filter. All tenants share the same catalogue.

### 2.2 Access rules

| Role | Browse | Manage (add/edit/deactivate) |
|---|---|---|
| Superadmin | Yes (all items) | Yes |
| Administrator | Yes (IsActive only) | No |
| Editor | Yes (IsActive only) | No |
| Viewer | No | No |

Rule [WGT-02]: `WidgetCatalogService.BrowseAsync()` applies `Where(w => w.IsActive)`
for non-Superadmin callers (checked via `ICurrentUserAccessor.Role`).

### 2.3 Seed data

Three items seeded on first run ([DATA-07]) after widget catalogue cleanup (commit `9cc4d9b`):
- Category "Queues": **Queue Grid** (real-time queue metrics table)
- Category "Agents": **Agent Grid** (real-time agent table with states)
- Category "General metrics": **Data Slot** (single metric display with target comparison)

`DatabaseInitializer.SeedWidgetCatalogAsync()` also removes 11 obsolete stub entries
(Queue Summary, Queue Trend, SLA Bar, Abandoned Calls, Agent Status, Agent List,
Occupancy Gauge, KPI Scorecard, Calls Per Hour, AHT Chart, Real-time Ticker) on startup.

Admin CRUD screen for catalogue items is deferred (ADR-001). In v1.3, items are
managed via migration seed or direct DB insert.

---

## 3. Dashboard Widget (stub)

### 3.1 Entity: `DashboardWidget`

```
Table: dashboard_widgets

Id                   uuid (UUIDv7)    PK
DashboardId          uuid             FK -> dashboards
WidgetCatalogItemId  uuid             FK -> widget_catalog
PositionJson         jsonb            Reserved for layout (next version)
ConfigJson           jsonb            Reserved for widget config (next version)
```

`DashboardWidget` is a **stub entity** for v1. It records the intent to place a widget
type on a dashboard. Layout (`PositionJson`) and configuration (`ConfigJson`) are stored
as opaque jsonb for the widget-library sprint to populate.

### 3.2 Lifecycle command

`SaveDashboardWidgetCommand`:
- Input: `DashboardId`, `WidgetCatalogItemId`
- Validates: dashboard exists and caller has Edit permission ([PG-01], AccessLevel bit 2)
- Writes: `DashboardWidget` record
- Dual-write: calls `IConfigurationApiHook.NotifyAsync("DashboardWidget.Saved", payload)`
- Audit: `Dashboard.Updated` event

### 3.3 What is NOT implemented in v1

- Widget rendering (real-time data display)
- Drag-and-drop layout
- Widget configuration forms
- Widget-to-data-feed binding
- Remove / reorder widget operations

These are marked `// TODO: widget-library` in Dashboard viewer components.

---

## 4. RTS Grid Lifecycle

### 4.1 Background

The CC backend platform writes per-user grid view configurations into `RTSGrid_*` tables
in the shared `RTMViewDB`. The shell must:
1. Not touch these tables via its own EF migrations.
2. Provide read-only `DbSet<>` access to grid data for display purposes.
3. Handle lifecycle events (create/delete user grid configurations) triggered by shell actions.

### 4.2 Entities (backend-owned, PascalCase naming)

```
Table: RTSGrid           (owned by CC backend)
Id           int          PK (backend-assigned)
TenantId     uuid         For GQF on AppDbContext DbSet
Name         varchar(200)
IsActive     boolean

Table: RTSUserGrid        (owned by CC backend)
Id           int          PK
UserId       uuid         FK -> identity.users
GridId       int          FK -> RTSGrid
TenantId     uuid         For GQF
ConfigJson   jsonb

Table: RTSGridQueue       (owned by CC backend)
Id           int          PK
GridId       int          FK -> RTSGrid
QueueId      uuid         FK -> NGC_Queue
TenantId     uuid         For GQF
```

These tables are configured in `AppDbContext` as read-only `DbSet<>`s with explicit
`ToTable("RTSGrid")` mappings and no EF migration output. GQF applied at lines 298, 310,
322 of `AppDbContext.cs`.

Dev/CI emulation: `BackendEmulationDbContext` creates these tables via its own migration
history (`__BackendEmulationMigrationsHistory`). Never runs in production.

### 4.3 Two RTS table families

**Type A — `RTSUserGrid_*` (Agent Grid)**

| Table | Purpose |
|---|---|
| `RTSUserGrid_Grid` | Grid header per widget instance |
| `RTSUserGrid_ColumnsSet` | Saved column set for the grid |
| `RTSUserGrid_Column` | Individual column definition |

ConfigJson stores: `RtsUserGridId` (`RTSUserGrid_Grid.GridId`), `ColumnsSetId`, `AgentGridColumnDef[].DbColumnId`.

**Critical:** `RtsUserGridId` is the RTS primary key — **not** the same as `DashboardWidget.GridId`
(which is the DB auto-increment from `dashboard_widgets` table). All RTS operations (save, delete,
update) must use `Config.RtsUserGridId`, never `PlacedWidget.GridId`. Bug fixed in #18 (2026-05-26).

**Type B — `RTSGrid_*` (Queue Grid + Data Slot)**

| Table | Purpose |
|---|---|
| `RTSGrid_Grid` | Grid header per widget instance |
| `RTSGrid_Column` | Column definition (`ColumnNumber`, `MetricId`) |
| `RTSGrid_Row` | Data row (`RowNumber`, `BusinessUnitId`) |
| `RTSGrid_Cell` | Cell at Row × Column intersection (`CellType`, `Value`) |

Queue Grid: multiple columns and rows (one per Business Unit).  
Data Slot: 1×1×1 subtype — exactly 1 Column, 1 Row, 1 Cell (`CellType="Data"`, `Value=MetricId`).

ConfigJson stores for Queue Grid: `GridId`, `HeaderRowId`, `HeaderCellIds`, per-row `RowId`/`CellIds`.  
ConfigJson stores for Data Slot: `DataSlotGridId`, `DataSlotColumnId`, `DataSlotRowId`, `DataSlotCellId`.

### 4.4 Lifecycle commands

`SaveAgentGridRtsCommand` (Type A):
- Input: `existingRtsUserGridId` = `Config.RtsUserGridId ?? 0` (0 = INSERT new Grid)
- Writes `RTSUserGrid_Grid` and child `RTSUserGrid_Column` records
- Returns `GridId` (RTS) + `ColumnsSetId` + per-column `ColumnId`s
- Caller stores `GridId` → `Config.RtsUserGridId` (not into `DashboardWidget.GridId`)
- Dual-write: `IConfigurationApiHook.NotifyAsync("AgentGrid.Saved", payload)`

`SaveQueueGridRtsCommand` (Type B):
- Writes `RTSGrid_Grid`, header Row (RowNumber=1, CellType=Text), data columns, data rows and cells
- Returns IDs for all created/updated records; caller persists them in ConfigJson
- Dual-write: `IConfigurationApiHook.NotifyAsync("QueueGridRts.Saved", payload)`

`SaveDataSlotRtsCommand` (Type B, 1×1×1):
- Writes exactly 1 Grid → 1 Column (ColumnNumber=1) → 1 Row (RowNumber=1) → 1 Cell (CellType="Data", Value=MetricId)
- Uses existence-check pattern: queries DB for existing child IDs before deciding INSERT vs UPDATE
  (guards against stale ConfigJson IDs after dashboard clone or restore)
- Dual-write: `IConfigurationApiHook.NotifyAsync("DataSlotRts.Saved", payload)`

`DeleteAgentGridRtsCommand` / `DeleteQueueGridRtsCommand` (shared for Queue Grid + Data Slot):
- Deletes the root Grid record; child records removed by `ON DELETE CASCADE`

### 4.5 Deferred deletion pattern

RTS records are **not** deleted immediately when user removes a widget from the editor.
They are queued in `WidgetsPendingRtsDeletion` and the actual delete runs on `SaveLayout`.
This prevents data loss if the user undoes the widget removal before saving.

---

## 5. Backend Notification Seam (Dual-Write)

### 5.1 Interface

```csharp
public interface IConfigurationApiHook
{
    Task NotifyAsync(string eventType, object payload, CancellationToken ct = default);
}
```

Events that trigger notification (OQ-2, resolved ADR-008):
- `PermissionGroup.Created` / `.Updated` / `.Deleted`
- `PermissionGroup.PermissionChanged` (queues, SGs, BUs, dashboards)
- `Dashboard.Created` / `.Updated`
- `DashboardWidget.Saved`
- `AgentGrid.Saved`
- `QueueGridRts.Saved`
- `DataSlotRts.Saved`

### 5.2 v1.3 implementation: `NoOpConfigurationApiHook`

Current state: logs the event + payload at `Information` level; makes no HTTP call.

```csharp
public class NoOpConfigurationApiHook(ILogger<NoOpConfigurationApiHook> logger) 
    : IConfigurationApiHook
{
    public Task NotifyAsync(string eventType, object payload, CancellationToken ct)
    {
        logger.LogInformation("[API Hook] {EventType}: {@Payload}", eventType, payload);
        return Task.CompletedTask;
    }
}
```

### 5.3 v1.3 target: `HttpConfigurationApiHook` (fire-and-forget + Polly retry)

Replace NoOp with real HTTP client:
- `POST {BackendApiBaseUrl}/api/rts/shell-events`
- Body: `{ eventType, payload, tenantId, timestamp }`
- Auth: service account JWT (OQ-1 pending backend API docs)
- Retry: Polly `WaitAndRetryAsync(3, exponential)` with jitter
- Failure: log at Warning; do not throw (fire-and-forget)

Registration in DI:
```csharp
services.AddHttpClient<IConfigurationApiHook, HttpConfigurationApiHook>(client =>
{
    client.BaseAddress = new Uri(config["BackendApi:BaseUrl"]!);
    client.Timeout = TimeSpan.FromSeconds(10);
})
.AddPolicyHandler(GetRetryPolicy());
```

### 5.4 v1.4 target: Outbox pattern

DB write + outbox record in the same transaction. Background `IHostedService` delivers
with guaranteed at-least-once delivery. See ADR-008 for full rationale.

---

## 6. SignalR Feed Seam

### 6.1 Shell-internal: `GridNotificationHub`

The shell hosts `GridNotificationHub` for notifying connected Blazor clients when
permission-group data changes (e.g., queue list refresh after PG edit [PG-07]).

Group naming: `"t:{tenantId}:{groupName}"` per [ARCH-09].  
Hub methods verify `TenantId` from `ClaimsPrincipal` before adding a connection.

```csharp
[Authorize]
public class GridNotificationHub : Hub
{
    public async Task JoinTenantGroup(string groupName)
    {
        var tenantId = Context.User?.FindFirst("tenant_id")?.Value
            ?? throw new HubException("Tenant not resolved");
        await Groups.AddToGroupAsync(Context.ConnectionId, $"t:{tenantId}:{groupName}");
    }
}
```

### 6.2 RTM Relay — single-port data feed (CC-003, 2026-05-31)

**Previous design (two-port model, superseded):** the widget library opened a second
WebSocket directly to RTM Service on a separate port. This required RTM Service to
be publicly reachable from every client browser — impractical in corporate CC networks.

**Current design — Shell as relay (CLAUDE.md §34):**

```
Browser
  └── WSS (port 443) ──▶ Kestrel/Shell
                              │ in-process
                        RtmRelayService  (Singleton)
                              │ server-to-server, internal network
                        HubConnection ──▶ RTM Service SignalR Hub
```

The shell registers `RtmRelayService` as a **Singleton**. It maintains one `HubConnection`
per `(TenantId, UnionId)` and `(TenantId, GridId)` — shared across all Blazor circuits.
When RTM Service pushes a message, `RtmRelayService` fans it out to all registered
subscriber handlers in-process.

**Blazor Server widget components** subscribe directly:

```csharp
@inject IRtmRelayService RtmRelay

// OnInitializedAsync:
_handler = async change => await InvokeAsync(() => { ApplyChange(change); StateHasChanged(); });
await RtmRelay.SubscribeUnionAsync(TenantId, unionId, _handler, ct);

// DisposeAsync:
await RtmRelay.UnsubscribeUnionAsync(TenantId, unionId, _handler);
```

**JS / external widget clients** connect to the shell hub:

```javascript
const conn = new signalR.HubConnectionBuilder().withUrl("/hubs/rtm-relay").build();
conn.on("unionUpdate", handler);
conn.on("gridUpdate",  handler);
await conn.start();
await conn.invoke("subscribeUnion", unionId);
```

Hub URL per tenant is configured in `tenant_settings.SignalRConnectionUrl`.
Redis cache: `{tenantId}:rtm:hub_url` (TTL 5 min).

**RTM Hub protocol (server sends):**

| Method | Parameters | Notes |
|---|---|---|
| `updateUserGrid` | `(JsonElement, JsonElement, JsonElement)` | 3 params; only 3rd (payload) used |
| `removeUser` | `(JsonElement, JsonElement)` | 2nd param = `[{"name":"loginName"}]` |
| `updateGridData` | `JsonElement` | Array `[{CellId, Value}]` |

Always use `JsonElement` — typed parameters cause silent message drops.
DataGrid requires `init` + `refreshCells` on connect; `init` alone gives no initial push.

**Ref-count + grace timer:** connection stays alive for 30 s after the last
subscriber unsubscribes (handles page navigation without reconnecting).

**Tenant lifecycle:** `DisconnectTenantAsync(tenantId)` disconnects all active
connections for a tenant — called when tenant is Suspended or Deleted.

---

## 7. MediatR pipeline position

Widget commands pass through the standard pipeline:

```
LoggingBehavior
  -> ValidationBehavior (FluentValidation)
  -> TransactionBehavior (PostgreSQL transaction)
  -> AuthorizationBehavior (permission check: Edit on dashboard)
  -> AuditBehavior (writes Dashboard.Updated)
  -> SaveDashboardWidgetCommand handler
       -> writes DashboardWidget
       -> calls IConfigurationApiHook.NotifyAsync (outside transaction)
```

Note: `IConfigurationApiHook.NotifyAsync` is called **after** the transaction commits.
This is the fire-and-forget pattern (v1.3). On v1.4 migration to outbox, the outbox
record write moves inside the transaction scope.

---

## 8. Test coverage (T5 sprint + DataSlot RTS session)

| Test class | Tests | Scope |
|---|---|---|
| `WidgetCatalogTests` | 6 | Browse, IsActive filter, Superadmin sees all |
| `DashboardWidgetTests` | 5 | Create stub, permission check, audit event, dual-write hook called |
| `RtsGridLifecycleTests` | 13 | SaveAgentGridRtsCommand + SaveQueueGridRtsCommand, GQF isolation, upsert idempotency |
| `SignalRTenantGuardTests` | 4 | GridNotificationHub TenantId claim check (SF-007 regression) |
| **Total** | **28** | All passing (commit fbf89fd) |

**Not yet covered:**
- `SaveDataSlotRtsCommand` — no test; existence-check-before-UPDATE logic untested
- `WidgetConfig` ConfigJson round-trip for DataSlot RTS fields
- Deferred deletion lifecycle (`WidgetsPendingRtsDeletion` queue)

---

## 9. Open questions

| ID | Question | Status |
|---|---|---|
| OQ-W-01 | Widget library integration API contract (endpoint format, auth) | Open |
| OQ-W-02 | `PositionJson` schema for layout engine | Open (widget-library sprint) |
| OQ-W-03 | `ConfigJson` schema per widget type | Open (widget-library sprint) |
| OQ-W-04 | How does widget library authenticate to backend SignalR hub? | **Resolved (CC-003):** Blazor components inject `IRtmRelayService` directly; JS clients use `/hubs/rtm-relay` with the same Identity cookie. |

---

## 10. Related documents

- ADR-001: Widget Catalogue scope
- ADR-004: SignalR feed seam
- ADR-007: Database boundary (BackendEmulationDbContext)
- ADR-008: Dual-write pattern
- `docs/sprints/T5-widget-framework.md` — sprint brief and DoD
- `docs/diagrams/architecture.md` — C4 diagrams including component view
- CLAUDE.md §18 (Widget catalogue requirements)
