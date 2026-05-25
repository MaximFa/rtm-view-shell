# Widget Framework Architecture — RTM View Shell v1.3

**Document type:** Technical Architecture  
**Version:** 1.3  
**Date:** 2026-05-25  
**Status:** Current (v1.3 scope defined; rendering deferred to widget-library sprint)

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

At least one item per category seeded on first run ([DATA-07]):
- Category "Queues": Queue Summary, Queue Trend, Abandoned Calls, SLA Bar
- Category "Agents": Agent Status, Agent List, Occupancy Gauge
- Category "General metrics": KPI Scorecard, Calls Per Hour, AHT Chart, Real-time Ticker

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

### 4.3 Lifecycle command

`SaveAgentGridRtsCommand`:
- Input: `UserId`, `GridId`, optional `ConfigJson`
- Validates: user exists in current tenant; grid is active for tenant
- Writes: `RTSUserGrid` record (upsert via `ON CONFLICT DO UPDATE`)
- Dual-write: `IConfigurationApiHook.NotifyAsync("AgentGrid.Saved", payload)`
- Note: writes to backend-owned table; no shell EF migration involved

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

### 6.2 External: per-tenant widget feed URL

The CC backend's widget data feed is a separate SignalR hub (external service).
The shell exposes its URL via REST API endpoint:

```
GET /api/v1/tenants/current/signalr-endpoint
Authorization: Bearer <access_token>

Response 200:
{
  "url": "https://backend.example.com/hubs/rtm",  // null if not configured
  "tenantId": "..."
}
```

URL stored in `tenant_settings.BackendSignalRUrl` (NULL = not configured).
Widget library calls this endpoint on startup to obtain the feed hub connection string.
See ADR-004 for rationale.

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

## 8. Test coverage (T5 sprint)

| Test class | Tests | Scope |
|---|---|---|
| `WidgetCatalogTests` | 6 | Browse, IsActive filter, Superadmin sees all |
| `DashboardWidgetTests` | 5 | Create stub, permission check, audit event, dual-write hook called |
| `RtsGridLifecycleTests` | 13 | SaveAgentGridRtsCommand, GQF isolation, upsert idempotency |
| `SignalRTenantGuardTests` | 4 | GridNotificationHub TenantId claim check (SF-007 regression) |
| **Total** | **28** | All passing (commit fbf89fd) |

---

## 9. Open questions

| ID | Question | Status |
|---|---|---|
| OQ-W-01 | Widget library integration API contract (endpoint format, auth) | Open |
| OQ-W-02 | `PositionJson` schema for layout engine | Open (widget-library sprint) |
| OQ-W-03 | `ConfigJson` schema per widget type | Open (widget-library sprint) |
| OQ-W-04 | How does widget library authenticate to backend SignalR hub? | Open (ADR-004 OQ-1) |

---

## 10. Related documents

- ADR-001: Widget Catalogue scope
- ADR-004: SignalR feed seam
- ADR-007: Database boundary (BackendEmulationDbContext)
- ADR-008: Dual-write pattern
- `docs/sprints/T5-widget-framework.md` — sprint brief and DoD
- `docs/diagrams/architecture.md` — C4 diagrams including component view
- CLAUDE.md §18 (Widget catalogue requirements)
