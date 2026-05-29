# Backend Tasks — CC Instructions

> **Document type:** Task backlog for Claude Code (CC)
> **Maintained by:** Cowork (documentation agent)
> **Language:** English (tasks) — conversations in Russian
> **Rule:** Cowork writes this document; CC executes tasks; both keep it updated.

Each task has a status badge, clear acceptance criteria, and references to affected files.
CC must mark a task `[done]` and record the commit hash when complete.

---

## Task index

| ID | Status | Title |
|---|---|---|
| [CC-001](#cc-001) | ✅ Done | Add `StatusGroup` to `RTSData_UserStatusLog` + EF entities for all RTSData_* tables |
| [CC-002](#cc-002) | ✅ Done  | Implement DayTrend widget — PostgreSQL functions, query handler, Blazor component, seed |
| [CC-003](#cc-003) | ❌ Cancelled | ~~Implement AgentStatusCount + AgentStatusDuration widgets~~ |
| [CC-004](#cc-004) | ✅ Done | Cleanup AgentStatus artefacts + create History_Metric table |
| [CC-005](#cc-005) | ✅ Done | Fix RTSGrid_Metric data (dot-notation, MetricType, ValueType) + apply History_Metric migration |
| [CC-006](#cc-006) | ✅ Done | DayTrend: migrate from RTSGrid_Metric to HistoryMetric (DB-driven metric list, ValueType rendering) |
| [CC-007](#cc-007) | ✅ Done | Agent State Distribution: Queue Grid chart widget (Pie/Donut/Bar) |
| [CC-008](#cc-008) | ✅ Done | Agent State Definitions registry (3 tables) + Edit Tenant tab + widget refactor |

---

## Backlog (documentation)

| ID | Description | Priority |
|---|---|---|
| DOC-001 | Update `docs/widget-specification.md` §2 intro: replace "All metrics registered in RTSGrid_Metric" with two-catalogue description (RTSGrid_Metric = real-time CC platform; HistoryMetric = historical shell-owned). §2.1/2.2/2.3 are already HistoryMetric content — just the framing is wrong. | 🟡 Medium |

---

## CC-001

### Add `StatusGroup` to `RTSData_UserStatusLog` + EF entities for all RTSData_* tables

**Status:** ✅ Done  
**Priority:** 🔴 High — blocks DayTrend and AgentStatus interval widgets  
**Depends on:** —  
**Commit:** `cd99e46`

---

### 1. Background

`RTSData_UserStatusLog` records individual agent status transitions. The existing
`StatusId` column contains **localised** status names (Hebrew, English, mixed) that
vary between deployments. This makes interval-based filtering unreliable.

The backend will start populating a new `StatusGroup` column on every new row,
using a canonical, deployment-independent value set. The shell needs to:

1. Accept this new column in the EF model.
2. Add the three `RTSData_*` tables to `BackendEmulationDbContext` as
   **read-only** `DbSet`s (the shell never writes to these tables).
3. Create a BackendEmulation migration so the dev/test database gets the column.

> **Note on Duration units (correction to rts-infrastructure.md §5.3):**
> `RTSData_UserStatusLog.Duration` is stored in **milliseconds**, not seconds.
> The existing documentation is incorrect. Update rts-infrastructure.md §5.3 when
> implementing this task.

---

### 2. Canonical StatusGroup values

| StatusGroup | Meaning | Example StatusId values |
|---|---|---|
| `AVAILABLE` | Agent ready for calls | `Available`, Hebrew equivalent |
| `ONPHONE` | Agent handling a call | `On Phone`, Hebrew equivalent |
| `BREAK` | Scheduled break | `Break`, Hebrew equivalent |
| `PAPERWORK` | After-call work / wrap-up | `After Call Work`, `ACW`, sometimes displays as UNAVAILABLE |
| `TRAINING` | Training, meeting, coaching | `Training`, Hebrew equivalent |

The set is closed — no other values will be introduced without updating this document.
Unknown `StatusId` values that the backend cannot classify are left as `NULL`.

---

### 3. Database change

```sql
-- Add column to existing table (idempotent)
ALTER TABLE "RTSData_UserStatusLog"
    ADD COLUMN IF NOT EXISTS "StatusGroup" character varying(50) NULL;

-- Index for interval queries
CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
    ON "RTSData_UserStatusLog" ("TenantId", "StatusGroup", "StartTime", "EndTime");
```

---

### 4. New file: `src/CcDashboard.Domain/Domain/RtsDataEntities.cs`

Create this file. All three classes are **read-only** (no navigation properties needed).

```csharp
namespace CcDashboard.Domain.Domain;

/// <summary>
/// RTSData_Interaction — call/chat interaction records written by the CC backend.
/// Shell access: read-only. PK: (InteractionId, Segment, OnDate, ServerId, Workgroup).
/// OnDate format: DD/MM/YYYY (varchar). AnsweredDateTime null marker: 1753-01-01 00:00:00.
/// </summary>
public class RtsDataInteraction
{
    public Guid? TenantId { get; set; }
    public string InteractionId { get; set; } = string.Empty;
    public int Segment { get; set; }
    public string OnDate { get; set; } = string.Empty;   // DD/MM/YYYY
    public string ServerId { get; set; } = string.Empty;
    public string Workgroup { get; set; } = string.Empty; // = QueueId in NGC_Queue
    public string UserId { get; set; } = string.Empty;
    public string? ClassificationCode { get; set; }
    public string? InteractionType { get; set; }  // Call, Chat, Email, Callback
    public string? CallType { get; set; }
    public string? Direction { get; set; }         // Incoming, Outgoing
    public string? CustomCallData { get; set; }
    public bool? IsTransferred { get; set; }
    public bool? IsAnswered { get; set; }
    public bool? IsInQueue { get; set; }
    public bool? IsTalk { get; set; }
    public bool? IsAbandoned { get; set; }
    public int? TimeInQueue { get; set; }          // seconds
    public int? TalkTime { get; set; }             // seconds
    public DateTime? InQueueDateTime { get; set; } // timestamptz — primary for interval grouping
    public DateTime? AnsweredDateTime { get; set; } // null marker: 1753-01-01 00:00:00.000
    public DateTime? UpdateTime { get; set; }
    public string? LastUserId { get; set; }
    public string? LastWorkgroup { get; set; }
    public bool? IsMessaging { get; set; }
    public string? RemoteAddress { get; set; }
    public bool? IsCallbackRequest { get; set; }
    public string? TimeZone { get; set; }
    // CustomCallData1..CustomCallData20 omitted — add on demand
}

/// <summary>
/// RTSData_UserStatus — aggregated per-agent status statistics for the current day.
/// Shell access: read-only. PK: (UserId, StatusId, ServerId, OnDate).
/// TotalDuration and MaxDuration are in seconds.
/// </summary>
public class RtsDataUserStatus
{
    public Guid? TenantId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string StatusId { get; set; } = string.Empty;
    public string ServerId { get; set; } = string.Empty;
    public string OnDate { get; set; } = string.Empty;   // DD/MM/YYYY
    public string? StatusName { get; set; }
    public string? StatusGroup { get; set; }  // AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING
    public int? TotalDuration { get; set; }   // seconds
    public int? MaxDuration { get; set; }     // seconds
    public int? TotalCount { get; set; }
    public DateTime? UpdateTime { get; set; }
    public string? DisplayName { get; set; }
    public string? TimeZone { get; set; }
}

/// <summary>
/// RTSData_UserStatusLog — time-series log of individual agent status transitions.
/// Shell access: read-only. PK: Id (serial).
/// IMPORTANT: Duration is in MILLISECONDS (not seconds).
/// StatusGroup canonical values: AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING, NULL.
/// </summary>
public class RtsDataUserStatusLog
{
    public int Id { get; set; }
    public Guid? TenantId { get; set; }
    public string? UserId { get; set; }
    public string? StatusId { get; set; }
    public string? StatusGroup { get; set; }  // NEW — canonical group, NULL if unclassified
    public string? ServerId { get; set; }
    public string? OnDate { get; set; }       // DD/MM/YYYY
    public DateTime? StartTime { get; set; }
    public DateTime? EndTime { get; set; }    // NULL = still in this status
    public long? Duration { get; set; }       // MILLISECONDS
    public DateTime? UpdateTime { get; set; }
    public string? TimeZone { get; set; }
}
```

---

### 5. Changes to `BackendEmulationDbContext`

Add three read-only `DbSet`s and their EF configurations.

**5.1 Add DbSets** (after the existing RTS sets):

```csharp
// RTSData tables — read-only; written by CC backend / external system
public DbSet<RtsDataInteraction> RtsDataInteractions => Set<RtsDataInteraction>();
public DbSet<RtsDataUserStatus> RtsDataUserStatuses => Set<RtsDataUserStatus>();
public DbSet<RtsDataUserStatusLog> RtsDataUserStatusLogs => Set<RtsDataUserStatusLog>();
```

**5.2 Add EF configurations inside `OnModelCreating`:**

```csharp
// --- RTSData tables (read-only, no Global Query Filter) ---

mb.Entity<RtsDataInteraction>(e =>
{
    e.ToTable("RTSData_Interaction");
    e.HasKey(x => new { x.InteractionId, x.Segment, x.OnDate, x.ServerId, x.Workgroup });
    e.Property(x => x.InteractionId).HasMaxLength(50);
    e.Property(x => x.OnDate).HasMaxLength(50);
    e.Property(x => x.ServerId).HasMaxLength(50);
    e.Property(x => x.Workgroup).HasMaxLength(100);
    e.Property(x => x.UserId).HasMaxLength(50);
    e.Property(x => x.InteractionType).HasMaxLength(50);
    e.Property(x => x.CallType).HasMaxLength(50);
    e.Property(x => x.Direction).HasMaxLength(50);
    e.Property(x => x.RemoteAddress).HasMaxLength(50);
    e.Property(x => x.LastUserId).HasMaxLength(50);
    e.Property(x => x.LastWorkgroup).HasMaxLength(100);
    e.Property(x => x.TimeZone).HasMaxLength(10);
    // No Global Query Filter: RTSData tables are backend-owned cross-tenant tables.
    // Shell filters by TenantId explicitly in every query.
});

mb.Entity<RtsDataUserStatus>(e =>
{
    e.ToTable("RTSData_UserStatus");
    e.HasKey(x => new { x.UserId, x.StatusId, x.ServerId, x.OnDate });
    e.Property(x => x.UserId).HasMaxLength(100);
    e.Property(x => x.StatusId).HasMaxLength(100);
    e.Property(x => x.ServerId).HasMaxLength(50);
    e.Property(x => x.OnDate).HasMaxLength(50);
    e.Property(x => x.StatusName).HasMaxLength(100);
    e.Property(x => x.StatusGroup).HasMaxLength(100);
    e.Property(x => x.DisplayName).HasMaxLength(100);
    e.Property(x => x.TimeZone).HasMaxLength(10);
});

mb.Entity<RtsDataUserStatusLog>(e =>
{
    e.ToTable("RTSData_UserStatusLog");
    e.HasKey(x => x.Id);
    e.Property(x => x.Id).UseIdentityAlwaysColumn();
    e.Property(x => x.UserId).HasMaxLength(100);
    e.Property(x => x.StatusId).HasMaxLength(100);
    e.Property(x => x.StatusGroup).HasMaxLength(50);   // NEW column
    e.Property(x => x.ServerId).HasMaxLength(50);
    e.Property(x => x.OnDate).HasMaxLength(50);
    e.Property(x => x.TimeZone).HasMaxLength(10);
    e.Property(x => x.Duration).HasColumnType("bigint"); // milliseconds
});
```

---

### 6. BackendEmulation migration

Run:

```powershell
dotnet ef migrations add AddRtsDataEntitiesAndStatusGroup `
  --context BackendEmulationDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web
```

The migration **Up** must use `CREATE TABLE IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`
so it is safe to run against a production database that already has the `RTSData_*` tables:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.Sql("""
        -- RTSData_Interaction (dev/test only; production table owned by CC backend)
        CREATE TABLE IF NOT EXISTS "RTSData_Interaction" (
            "TenantId"           uuid,
            "InteractionId"      varchar(50)  NOT NULL,
            "Segment"            integer      NOT NULL,
            "OnDate"             varchar(50)  NOT NULL,
            "ServerId"           varchar(50)  NOT NULL,
            "Workgroup"          varchar(100) NOT NULL,
            "UserId"             varchar(50)  NOT NULL DEFAULT '',
            "ClassificationCode" text,
            "InteractionType"    varchar(50),
            "CallType"           varchar(50),
            "Direction"          varchar(50),
            "CustomCallData"     text,
            "IsTransferred"      boolean,
            "IsAnswered"         boolean,
            "IsInQueue"          boolean,
            "IsTalk"             boolean,
            "IsAbandoned"        boolean,
            "TimeInQueue"        integer,
            "TalkTime"           integer,
            "InQueueDateTime"    timestamptz,
            "AnsweredDateTime"   timestamptz,
            "UpdateTime"         timestamptz,
            "LastUserId"         varchar(50),
            "LastWorkgroup"      varchar(100),
            "IsMessaging"        boolean,
            "RemoteAddress"      varchar(50),
            "IsCallbackRequest"  boolean,
            "TimeZone"           varchar(10),
            CONSTRAINT "PK_RTSData_Interaction"
                PRIMARY KEY ("InteractionId","Segment","OnDate","ServerId","Workgroup")
        );

        -- RTSData_UserStatus
        CREATE TABLE IF NOT EXISTS "RTSData_UserStatus" (
            "TenantId"      uuid,
            "UserId"        varchar(100) NOT NULL,
            "StatusId"      varchar(100) NOT NULL,
            "ServerId"      varchar(50)  NOT NULL,
            "OnDate"        varchar(50)  NOT NULL,
            "StatusName"    varchar(100),
            "StatusGroup"   varchar(100),
            "TotalDuration" integer,
            "MaxDuration"   integer,
            "TotalCount"    integer,
            "UpdateTime"    timestamptz,
            "DisplayName"   varchar(100),
            "TimeZone"      varchar(10),
            CONSTRAINT "PK_RTSData_UserStatus"
                PRIMARY KEY ("UserId","StatusId","ServerId","OnDate")
        );

        -- RTSData_UserStatusLog
        CREATE TABLE IF NOT EXISTS "RTSData_UserStatusLog" (
            "Id"          integer GENERATED ALWAYS AS IDENTITY,
            "TenantId"    uuid,
            "UserId"      varchar(100),
            "StatusId"    varchar(100),
            "ServerId"    varchar(50),
            "OnDate"      varchar(50),
            "StartTime"   timestamptz,
            "EndTime"     timestamptz,
            "Duration"    bigint,
            "UpdateTime"  timestamptz,
            "TimeZone"    varchar(10),
            CONSTRAINT "PK_RTSData_UserStatusLog" PRIMARY KEY ("Id")
        );

        -- Add StatusGroup to UserStatusLog (idempotent — safe on production)
        ALTER TABLE "RTSData_UserStatusLog"
            ADD COLUMN IF NOT EXISTS "StatusGroup" varchar(50) NULL;

        -- Index for interval StatusGroup queries
        CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
            ON "RTSData_UserStatusLog" ("TenantId","StatusGroup","StartTime","EndTime");
        """);
}

protected override void Down(MigrationBuilder migrationBuilder)
{
    // Do NOT drop RTSData_* tables — backend-owned.
    // Only remove what this migration added.
    migrationBuilder.Sql("""
        ALTER TABLE "RTSData_UserStatusLog"
            DROP COLUMN IF EXISTS "StatusGroup";
        DROP INDEX IF EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time";
        """);
}
```

---

### 7. Update `docs/architecture/rts-infrastructure.md`

In §5.3 RTSData_UserStatusLog:

1. Change `Duration` description from "Duration in seconds" to "Duration in **milliseconds**".
2. Add `StatusGroup` row to the column table:

| Column | Type | Nullable | Description |
|---|---|---|---|
| `StatusGroup` | varchar(50) | YES | Canonical group: AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING — see [CC-001] |

---

### 8. Acceptance criteria

- [ ] `RtsDataEntities.cs` created in `src/CcDashboard.Domain/Domain/`
- [ ] `BackendEmulationDbContext` has three new `DbSet`s and EF configurations
- [ ] Migration `AddRtsDataEntitiesAndStatusGroup` created and applied (`dotnet ef database update`)
- [ ] `dotnet build CcDashboard.sln` — zero errors, zero warnings introduced
- [ ] Dev/test DB: `RTSData_UserStatusLog` has `StatusGroup varchar(50) NULL` column
- [ ] `docs/architecture/rts-infrastructure.md` §5.3 corrected (Duration = milliseconds, StatusGroup added)

---

---

## CC-002

### Implement DayTrend widget — PostgreSQL functions, query handler, Blazor component, seed

**Status:** ✅ Done  
**Priority:** 🔴 High — first production widget for RTM shell  
**Depends on:** CC-001 ✅  
**Spec reference:** `docs/widget-specification.md` §3 (DayTrend) — read in full before starting  
**Skill:** `.claude/skills/widget-creator/widget-creator.md` — read **§20** (Chart/Analytics architecture), **§21** (config modal tabs), **§22** (Template pattern), **§23** (methodology) before implementing  
**Commit:** —

---

### 1. Background

DayTrend displays intraday call volume and agent status metrics as a chart broken into
configurable intervals (15 / 30 / 60 min). Data comes from two PostgreSQL functions
returning **narrow format** `(interval_start, metric_id, value)` rows.

Use the exact SQL from the spec — do not simplify. `metric_id` strings in function
output must match `RTSGrid_Metric.MetricId` exactly (consistency rule, spec §3.4.3).

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | Migration `AddDayTrendFunctions` | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| 2.2 | `DayTrendQuery` + `DayTrendQueryHandler` | `src/CcDashboard.Application/` |
| 2.3 | `DayTrendWidget.razor` | `src/CcDashboard.Web/Components/Dashboard/Widgets/` |
| 2.4 | `RtsGridMetric` seed | `src/CcDashboard.Infrastructure/Persistence/Seed/RtsMetricSeed.cs` |
| 2.5 | `WidgetCatalogItem` seed | same seed file or `WidgetCatalogSeed.cs` |
| 2.6 | Config modal tabs for DayTrend | `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` |
| 2.7 | JS interop file | `src/CcDashboard.Web/wwwroot/js/daytrendChart.js` |

---

### 3. Migration `AddDayTrendFunctions`

Run:

```powershell
dotnet ef migrations add AddDayTrendFunctions `
  --context BackendEmulationDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web
```

Populate `Up()` and `Down()` (pattern from spec §3.10 note 9).
Copy the complete SQL bodies verbatim from spec §3.4.1 and §3.4.2:

```csharp
protected override void Up(MigrationBuilder mb) =>
    mb.Sql("""
        <paste full fn_daytrendinteractions body from spec §3.4.1>
        <paste full fn_daytrendagentstatus body from spec §3.4.2>
    """);

protected override void Down(MigrationBuilder mb) =>
    mb.Sql("""
        DROP FUNCTION IF EXISTS fn_daytrendinteractions(uuid, varchar(50), text[], integer);
        DROP FUNCTION IF EXISTS fn_daytrendagentstatus(uuid, varchar(50), text[], integer);
    """);
```

`CREATE OR REPLACE FUNCTION` is idempotent — safe to re-run.

---

### 4. Application layer records

Place in `CcDashboard.Application/DTOs/` (or `Queries/DayTrend/`):

```csharp
// Narrow format row — returned by both PostgreSQL functions
public record DayTrendMetricRow(DateTime IntervalStart, string MetricId, double? Value);

// Per-interval grouped result; keys = RTSGrid_Metric.MetricId strings
public record DayTrendIntervalData(
    DateTime IntervalStart,
    IReadOnlyDictionary<string, double?> Metrics);

// Query result
public record DayTrendResult(
    IReadOnlyList<DayTrendIntervalData> Intervals,
    bool IsNoQueues = false)
{
    public static DayTrendResult NoQueues() => new(Array.Empty<DayTrendIntervalData>(), true);
    public static DayTrendResult Empty()    => new(Array.Empty<DayTrendIntervalData>());
}

// CQRS query
public record DayTrendQuery(
    Guid BusinessUnitId,
    int IntervalMinutes,          // 15 | 30 | 60
    bool IncludeAgentMetrics,     // false = skip fn_daytrendagentstatus
    DateOnly? OnDate = null       // null = today (UTC)
) : IRequest<DayTrendResult>;
```

---

### 5. Query handler

```csharp
public sealed class DayTrendQueryHandler(
    BackendEmulationDbContext beDb,
    INgcRepository ngcRepo,
    ITenantContext tenantContext)
    : IRequestHandler<DayTrendQuery, DayTrendResult>
{
    public async Task<DayTrendResult> Handle(DayTrendQuery query, CancellationToken ct)
    {
        // 1. Resolve queues for the BU (Workgroup = NgcQueue.ExternalId)
        var queues = await ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
        if (!queues.Any())
            return DayTrendResult.NoQueues();

        var tenantId   = tenantContext.TenantId;
        var onDate     = (query.OnDate ?? DateOnly.FromDateTime(DateTime.UtcNow))
                             .ToString("dd/MM/yyyy");        // RTSData format: DD/MM/YYYY
        var queueArray = queues.Select(q => q.ExternalId).ToArray();
        var interval   = query.IntervalMinutes;

        // 2. Run both functions in parallel
        var interactionTask = beDb.Database
            .SqlQuery<DayTrendMetricRow>(
                $"SELECT * FROM fn_daytrendinteractions({tenantId}, {onDate}, {queueArray}, {interval})")
            .ToListAsync(ct);

        var agentTask = query.IncludeAgentMetrics
            ? beDb.Database
                .SqlQuery<DayTrendMetricRow>(
                    $"SELECT * FROM fn_daytrendagentstatus({tenantId}, {onDate}, {queueArray}, {interval})")
                .ToListAsync(ct)
            : Task.FromResult(new List<DayTrendMetricRow>());

        await Task.WhenAll(interactionTask, agentTask);

        // 3. Merge and pivot to per-interval dictionaries
        var intervals = interactionTask.Result
            .Concat(agentTask.Result)
            .GroupBy(r => r.IntervalStart)
            .Select(g => new DayTrendIntervalData(
                g.Key,
                (IReadOnlyDictionary<string, double?>)
                    g.ToDictionary(r => r.MetricId, r => r.Value)))
            .OrderBy(x => x.IntervalStart)
            .ToList();

        return new DayTrendResult(intervals);
    }
}
```

**Queue resolution — BU → Queue → Workgroup chain:**
```
NgcBusinessUnit.BusinessUnitId
  → NgcBusinessUnitQueueClassification.BusinessUnitId  (FK)
  → NgcBusinessUnitQueueClassification.QueueId          (string)
  = NgcQueue.ExternalId                                  (string)
  = RTSData_Interaction.Workgroup                        (string, SQL filter)
```
So `QueueAssignment.QueueId` values ARE the workgroup strings — no extra lookup needed.
If `GetQueuesByBusinessUnitAsync` does not exist on `INgcRepository`, implement it:
load `NgcBusinessUnit` with `.Include(b => b.QueueAssignments)`, then
return `bu.QueueAssignments.Select(q => q.QueueId).ToArray()`.

---

### 6. Blazor component

**File:** `src/CcDashboard.Web/Components/Dashboard/Widgets/DayTrendWidget.razor`

Config records (deserialise from `DashboardWidget.ConfigJson`):

```csharp
public record DayTrendConfig(
    string Title,
    Guid BusinessUnitId,
    int IntervalMinutes,
    int RefreshIntervalSeconds,
    string ChartType,             // "line" | "bar" | "area" | "step"
    bool ShowDataLabels,
    bool ShowLegend,
    List<DayTrendMetricConfig> Metrics,
    List<DayTrendMetricConfig> AgentMetrics);

public record DayTrendMetricConfig(
    string MetricId, bool Enabled, string Color, string Label);
```

Component responsibilities:

1. Deserialise `ConfigJson` → `DayTrendConfig` on `OnInitializedAsync`.
2. Send `DayTrendQuery` via `IMediator`; set `IncludeAgentMetrics = AgentMetrics.Any(m => m.Enabled)`.
3. Render chart via Chart.js JS interop (`IJSRuntime`). Add `wwwroot/js/daytrendChart.js`:

```javascript
window.dayTrendChart = {
    _charts: {},
    render(id, labels, datasets, options) {
        if (this._charts[id]) this._charts[id].destroy();
        const ctx = document.getElementById(id)?.getContext('2d');
        if (!ctx) return;
        this._charts[id] = new Chart(ctx, { type: 'line', data: { labels, datasets }, options });
    },
    destroy(id) {
        this._charts[id]?.destroy();
        delete this._charts[id];
    }
};
```

4. **Dual Y-axis:** metrics whose `MetricId` ends with `_time`, `_wait`, `_talk`, or `_ms`
   go on the right Y-axis; format values as `mm:ss` (`TimeSpan.FromSeconds(v).ToString(@"mm\:ss")`
   for `avg/max_wait_time`, `avg_talk_time`; `TimeSpan.FromMilliseconds(v).ToString(@"mm\:ss")`
   for `*_ms` metrics). All count metrics go on the left Y-axis.
5. **Auto-refresh:** `PeriodicTimer` at `RefreshIntervalSeconds`; dispose in `IAsyncDisposable.DisposeAsync`.
6. **Config modal** (§21.2 in widget-creator skill)  
   Add a new case in `ScreenEditorPage.razor` modal switch for `"Day Trend"`.  
   Four tabs: **General** (title, BU, interval, refresh), **Appearance** (chart type, labels, legend, colors),  
   **Call Metrics** (toggle / color / label per metric row), **Agent Metrics** (same structure).  
   On Save: serialize all config fields → `DashboardWidget.ConfigJson`.  
   Add **"Save as Template"** button per skill §22.4 — dispatches `CreateWidgetTemplateCommand`.

7. **States:** loading skeleton, no-queues warning (`IsNoQueues = true`),
   empty-day message (intervals empty), query error with retry button.

Use Chart.js from CDN already in `_Host.cshtml` / `App.razor`, or add:
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
```

---

### 7. Seed data

> **State as of HEAD** — verify before implementing:
> - `SeedWidgetCatalogAsync`: has Queue Grid / Agent Grid / Data Slot — **"Day Trend Chart" missing**
> - `SeedRtsGridMetricsAsync`: called on line 48 — **method body missing (startup crash)**
> - `SeedSampleCcEntitiesAsync`: exists, seeds NgcQueue (ExternalId Q001–Q005), NgcBusinessUnit,
>   NgcSite, NgcSupergroup — **`NgcBusinessUnitQueueClassification` missing → DayTrend always returns NoQueues()**

---

#### 7.1 Add "Day Trend Chart" to `SeedWidgetCatalogAsync`

In `DatabaseInitializer.cs`, add to the `items` list inside `SeedWidgetCatalogAsync`:

```csharp
new() {
    Id          = Uuid.NewSequential(),
    Category    = "General metrics",
    Name        = "Day Trend Chart",
    Description = "Intraday call volume chart showing configured metrics broken down by time interval (15/30/60 min). Supports line, bar, area, and step chart types.",
    IsActive    = true
},
```

---

#### 7.2 Implement `SeedRtsGridMetricsAsync` — **method is missing, startup crashes**

Add the full method body to `DatabaseInitializer.cs`. Copy all entries verbatim from
`docs/widget-specification.md §2.4`. Upsert pattern (skip existing by MetricId):

```csharp
private async Task SeedRtsGridMetricsAsync(CancellationToken ct)
{
    var metrics = new List<RtsGridMetric>
    {
        // -- interaction.* (11 entries) — copy from spec §2.4 --
        // -- statuslog.* (13 entries) — copy from spec §2.4 --
    };

    var existing = (await beDb.RtsGridMetrics.Select(m => m.MetricId).ToListAsync(ct)).ToHashSet();
    var toAdd = metrics.Where(m => !existing.Contains(m.MetricId)).ToList();
    if (toAdd.Count > 0)
    {
        beDb.RtsGridMetrics.AddRange(toAdd);
        await beDb.SaveChangesAsync(ct);
        logger.LogInformation("Seeded {Count} RtsGridMetric entries", toAdd.Count);
    }
}
```

> `RtsGridMetric` lives in `BackendEmulationDbContext` (`beDb`).

---

#### 7.3 Add `NgcBusinessUnitQueueClassification` to `SeedSampleCcEntitiesAsync`

The existing seed has NgcBusinessUnit (BusinessUnitId auto-assigned: Sales=1, Support=2, Billing=3)
and NgcQueue (ExternalId Q001–Q005). The BU→Queue link is missing.

Add after the NgcBusinessUnit seed block:

```csharp
// BU → Queue classification (required for DayTrend queue resolution)
try
{
    if (!await beDb.NgcBusinessUnitQueueClassifications
            .IgnoreQueryFilters()
            .AnyAsync(c => c.TenantId == tenant.Id, ct))
    {
        // Resolve BU IDs seeded above
        var buSales   = await beDb.NgcBusinessUnits.IgnoreQueryFilters()
            .FirstAsync(b => b.TenantId == tenant.Id && b.BusinessUnitName == "Sales Department", ct);
        var buSupport = await beDb.NgcBusinessUnits.IgnoreQueryFilters()
            .FirstAsync(b => b.TenantId == tenant.Id && b.BusinessUnitName == "Support Department", ct);
        var buBilling = await beDb.NgcBusinessUnits.IgnoreQueryFilters()
            .FirstAsync(b => b.TenantId == tenant.Id && b.BusinessUnitName == "Billing Department", ct);

        beDb.NgcBusinessUnitQueueClassifications.AddRange(
            new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = buSales.BusinessUnitId,   QueueId = "Q001", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
            new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = buSupport.BusinessUnitId, QueueId = "Q002", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
            new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = buSupport.BusinessUnitId, QueueId = "Q003", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
            new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = buBilling.BusinessUnitId, QueueId = "Q004", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
            new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = buBilling.BusinessUnitId, QueueId = "Q005", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" }
        );
        await beDb.SaveChangesAsync(ct);
        logger.LogInformation("Seeded NGC BU→Queue classifications for tenant {TenantId}", tenant.Id);
    }
}
catch (Exception ex) { logger.LogWarning(ex, "BU→Queue classification seed skipped"); }
```

> `NgcBusinessUnitQueueClassification` lives in `BackendEmulationDbContext` (`beDb`).
> `NgcQueue` (in AppDbContext) already has ExternalId "Q001"–"Q005" — these match.

---

#### 7.4 Dev seed — `RTSData_Interaction` test rows

**Key field mapping (from `RtsDataEntities.cs`):**
- `OnDate` — varchar `DD/MM/YYYY` — date partition filter
- `InQueueDateTime` — `timestamptz` — **primary field for interval grouping in SQL functions**
- `Workgroup` — string, equals `NgcQueue.ExternalId` equals `NgcBusinessUnitQueueClassification.QueueId`
- `AnsweredDateTime` — null marker value is `1753-01-01` (not C# null)

Both `OnDate` AND `InQueueDateTime` must be set to today — the SQL function filters by `OnDate`
and groups intervals by `DATE_TRUNC` on `InQueueDateTime`.

```csharp
private async Task SeedDevRtsInteractionsAsync(Guid tenantId, CancellationToken ct)
{
    if (!env.IsDevelopment()) return;
    var today = DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy");
    if (await beDb.RtsDataInteractions.AnyAsync(
            r => r.TenantId == tenantId && r.OnDate == today, ct))
        return;

    var rng    = new Random(42);
    var now    = DateTime.UtcNow;
    var queues  = new[] { "Q001", "Q002", "Q003", "Q004", "Q005" };  // ALL queues across all BUs
    // Same agent IDs as in SeedDevRtsUserStatusLogAsync — UserId is the JOIN key
    // fn_daytrendagentstatus: agent pool = DISTINCT UserId FROM RTSData_Interaction WHERE IsAnswered=true
    var agents  = new[] { "agent01", "agent02", "agent03", "agent04", "agent05" };
    var rows    = new List<RtsDataInteraction>();
    var seg     = 0;

    for (int h = 8; h <= 17; h++)
    {
        foreach (var q in queues)
        {
            int count = rng.Next(3, 12);
            for (int i = 0; i < count; i++)
            {
                var inQueue  = new DateTime(now.Year, now.Month, now.Day, h, rng.Next(0, 59), 0, DateTimeKind.Utc);
                var answered = rng.NextDouble() > 0.15;
                rows.Add(new RtsDataInteraction
                {
                    TenantId          = tenantId,
                    InteractionId     = Guid.NewGuid().ToString(),
                    Segment           = ++seg,
                    ServerId          = "SRV01",
                    OnDate            = today,              // DD/MM/YYYY — partition filter
                    InQueueDateTime   = inQueue,            // timestamptz — interval grouping
                    AnsweredDateTime  = answered ? inQueue.AddSeconds(rng.Next(5, 60)) : new DateTime(1753, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                    Workgroup         = q,                  // = NgcQueue.ExternalId
                    InteractionType   = "Call",
                    Direction         = "Incoming",
                    IsAnswered        = answered,
                    UserId            = answered ? agents[rng.Next(agents.Length)] : string.Empty,  // JOIN key for fn_daytrendagentstatus
                    IsAbandoned       = !answered && rng.NextDouble() > 0.3,
                    IsTransferred     = answered && rng.NextDouble() < 0.1,
                    IsInQueue         = true,
                    TimeInQueue       = answered ? rng.Next(5, 120) : rng.Next(10, 180),
                    TalkTime          = answered ? rng.Next(30, 600) : 0,
                    UpdateTime        = DateTime.UtcNow,
                });
            }
        }
    }

    beDb.RtsDataInteractions.AddRange(rows);
    await beDb.SaveChangesAsync(ct);
    logger.LogInformation("Seeded {Count} dev RTSData_Interaction rows for {Date}", rows.Count, today);
}
```

---

#### 7.5 Dev seed — `RTSData_UserStatusLog` test rows

Agent metrics require status log data. `Duration` is **milliseconds**:

```csharp
private async Task SeedDevRtsUserStatusLogAsync(Guid tenantId, CancellationToken ct)
{
    if (!env.IsDevelopment()) return;
    var today = DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy");
    if (await beDb.RtsDataUserStatusLogs.AnyAsync(
            r => r.TenantId == tenantId && r.OnDate == today, ct))
        return;

    var rng    = new Random(42);
    var now    = DateTime.UtcNow;
    var agents = new[] { "agent01", "agent02", "agent03", "agent04", "agent05" };
    var groups = new[] { "AVAILABLE", "ONPHONE", "BREAK", "PAPERWORK", "TRAINING" };
    var rows   = new List<RtsDataUserStatusLog>();

    foreach (var agent in agents)
    {
        var cursor    = new DateTime(now.Year, now.Month, now.Day, 8,  0, 0, DateTimeKind.Utc);
        var endOfDay  = new DateTime(now.Year, now.Month, now.Day, 18, 0, 0, DateTimeKind.Utc);
        while (cursor < endOfDay)  // full working day 08:00-18:00 UTC (not relative to now)
        {
            var group    = groups[rng.Next(groups.Length)];
            var durationMs = rng.Next(2, 30) * 60 * 1000L;  // milliseconds
            var end      = cursor.AddMilliseconds(durationMs);
            rows.Add(new RtsDataUserStatusLog
            {
                TenantId    = tenantId,
                UserId      = agent,
                OnDate      = today,
                StatusGroup = group,
                StatusId    = group.ToLower() + "_status",
                StartTime   = cursor,
                EndTime     = end,
                Duration    = durationMs,   // MILLISECONDS — not seconds
                UpdateTime  = DateTime.UtcNow
            });
            cursor = end;
        }
    }

    beDb.RtsDataUserStatusLogs.AddRange(rows);
    await beDb.SaveChangesAsync(ct);
    logger.LogInformation("Seeded {Count} dev RTSData_UserStatusLog rows", rows.Count);
}
```

Call both from `SeedSampleCcEntitiesAsync` at the end (after NGC entities):

```csharp
// Dev-only: RTSData test data
await SeedDevRtsInteractionsAsync(tenant.Id, ct);
await SeedDevRtsUserStatusLogAsync(tenant.Id, ct);
```

### 8. Acceptance criteria

- [ ] Migration applied; `fn_daytrendinteractions` and `fn_daytrendagentstatus` exist in DB
- [ ] `SELECT * FROM fn_daytrendinteractions(...)` returns rows for a test `OnDate` with data
- [ ] `SELECT * FROM fn_daytrendagentstatus(...)` returns rows for a test `OnDate` with data
- [ ] Handler returns non-empty `Intervals` for a valid BU with interactions today
- [ ] Handler returns `NoQueues()` when BU has no queue assignments
- [ ] `DayTrendWidget.razor` renders chart without JS errors on a test dashboard
- [ ] Auto-refresh timer fires; disposed correctly on component destroy (no memory leak)
- [ ] All `RtsGridMetric` entries from spec §2.4 seeded
- [ ] `WidgetCatalogItem` for DayTrend visible in widget catalogue UI
- [ ] `dotnet build CcDashboard.sln` — zero errors, zero new warnings
- [ ] Unit test: handler returns `NoQueues` when repository returns empty queue list
- [ ] Unit test: handler correctly pivots narrow rows into `DayTrendIntervalData` dictionaries
- [ ] Config modal opens for DayTrend widget; General / Appearance / Call Metrics / Agent Metrics tabs render
- [ ] Saving modal updates `ConfigJson`; widget reloads with new config
- [ ] "Save as Template" button visible in modal footer; dispatches `CreateWidgetTemplateCommand`
- [ ] `SeedSampleCcEntitiesAsync` method implemented — startup no longer throws (method was missing)
- [ ] Dev DB: `RTSData_Interaction` rows seeded for today's date (dev environment only)
- [ ] Dev DB: `RTSData_UserStatusLog` rows seeded for today with all `StatusGroup` values (dev only)
- [ ] DayTrend widget shows actual chart data on dev dashboard (NGC tables pre-populated from CC platform)

---

*CC-002 written: 2026-05-27*

---

*Document created: 2026-05-26 | Last updated: 2026-05-27 | Current task: CC-003*


---

## CC-003

### Implement AgentStatusCount and AgentStatusDuration widgets

**Status:** ❌ Cancelled — superseded by CC-004  
**Priority:** 🟡 Medium  
**Depends on:** CC-001 ✅, CC-002 ✅  
**Spec reference:** `docs/widget-specification.md` §4 (AgentStatusCount) and §5 (AgentStatusDuration) — read both in full before starting  
**Skill:** `.claude/skills/widget-creator/widget-creator.md` — read **§20** (Chart/Analytics architecture), **§21** (config modal tabs), **§22** (Template pattern), **§23** (methodology) before implementing  
**Commit:** —

---

### 1. Background

Two companion widgets, both using Chart.js Donut/Pie/Bar visualisation:

- **AgentStatusCount** — current count of agents per StatusGroup right now.
  Source: `RTSData_UserStatusLog WHERE EndTime IS NULL`. Agent pool = agents who answered an
  incoming call today on the BU's queues (DISTINCT UserId from `RTSData_Interaction`).

- **AgentStatusDuration** — today's cumulative time per StatusGroup (in seconds).
  Source: `RTSData_UserStatus.TotalDuration`. Same agent pool derivation.

Both widgets use the Chart/Analytics architecture (no RTSGrid_* tables, no SignalR).
Data flows: BU → queue list → PostgreSQL function → C# handler → Blazor component → Chart.js.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 3.1 | Migration `AddAgentStatusFunctions` | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| 3.2 | `AgentStatusCountQuery` + `AgentStatusCountQueryHandler` | `src/CcDashboard.Application/Queries/Widgets/` |
| 3.3 | `AgentStatusDurationQuery` + `AgentStatusDurationQueryHandler` | same |
| 3.4 | `AgentStatusCountWidget.razor` | `src/CcDashboard.Web/Components/Dashboard/Widgets/` |
| 3.5 | `AgentStatusDurationWidget.razor` | same |
| 3.6 | `agentStatusChart.js` (shared JS interop for both widgets) | `src/CcDashboard.Web/wwwroot/js/` |
| 3.7 | `snapshot.*` seed entries in `RtsMetricSeed.cs` | `src/CcDashboard.Infrastructure/Persistence/Seed/` |
| 3.8 | `WidgetCatalogItem` seed entries (×2) | same or `WidgetCatalogSeed.cs` |
| 3.9 | Config modal tabs for both widgets | `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` |

---

### 3. Migration `AddAgentStatusFunctions`

Run:

```powershell
dotnet ef migrations add AddAgentStatusFunctions `
  --context BackendEmulationDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web
```

Populate `Up()` with both SQL bodies from spec §4.4.2 and §5.4.1 verbatim
(two `CREATE OR REPLACE FUNCTION` statements in one `mb.Sql("""...""")` call).

`Down()`:

```csharp
protected override void Down(MigrationBuilder mb) =>
    mb.Sql("""
        DROP FUNCTION IF EXISTS fn_agentstatuscount(uuid, varchar, text[]);
        DROP FUNCTION IF EXISTS fn_agentstatusduration(uuid, varchar, text[]);
    """);
```

---

### 4. C# records and query definitions

#### AgentStatusCount

```csharp
public record AgentStatusCountQuery(int BusinessUnitId) : IRequest<AgentStatusCountResult>;

public record AgentStatusCountRow(string MetricId, double? Value);

public record AgentStatusCountResult(
    IReadOnlyDictionary<string, double> Segments,
    DateTime LastUpdated,
    bool NoQueues = false)
{
    public static AgentStatusCountResult Empty(bool noQueues = false) =>
        new(new Dictionary<string, double>(), DateTime.UtcNow, noQueues);
}
```

Handler body — copy from spec §4.4.3.
Queue resolution: `_ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct)` → `queues.Select(q => q.ExternalId).ToArray()`.
OnDate: `DateTime.UtcNow.ToString("dd/MM/yyyy")`.

#### AgentStatusDuration

```csharp
public record AgentStatusDurationQuery(int BusinessUnitId) : IRequest<AgentStatusDurationResult>;

public record AgentStatusDurationRow(string MetricId, double? Value);

public record AgentStatusDurationResult(
    IReadOnlyDictionary<string, double> Segments,   // value = seconds
    DateTime LastUpdated,
    bool NoQueues = false)
{
    public static AgentStatusDurationResult Empty(bool noQueues = false) =>
        new(new Dictionary<string, double>(), DateTime.UtcNow, noQueues);
}
```

Duration formatter (static helper in the Blazor component):

```csharp
static string FormatDuration(double seconds, string format) => format switch
{
    "hh:mm:ss" => TimeSpan.FromSeconds(seconds).ToString(@"hh\:mm\:ss"),
    "minutes"  => $"{(int)(seconds / 60)} min",
    _          => TimeSpan.FromSeconds(seconds).ToString(@"h\:mm")
};
```

---

### 5. JS interop — `agentStatusChart.js`

Single JS file serving **both** widgets.

```javascript
window.agentStatusChart = {
    instances: {},

    render: function (widgetId, config, data) {
        // data = [{ metricId, value, displayValue, label, color }]
        // value = numeric (count or seconds) — used for segment sizing
        // displayValue = pre-formatted string — used in datalabels
        const ctx = document.getElementById('agentStatusCanvas_' + widgetId);
        if (!ctx) return;
        if (this.instances[widgetId]) { this.instances[widgetId].destroy(); }

        const chartType = config.chartType === 'donut' ? 'doughnut' : config.chartType;

        this.instances[widgetId] = new Chart(ctx, {
            type: chartType,
            data: {
                labels:   data.map(d => d.label),
                datasets: [{ data: data.map(d => d.value),
                             backgroundColor: data.map(d => d.color),
                             borderWidth: 2 }]
            },
            options: {
                responsive: true,
                cutout: chartType === 'doughnut' ? '62%' : undefined,
                plugins: {
                    legend: { display: config.showLegend },
                    tooltip: {
                        callbacks: {
                            label: function(ctx) {
                                const d = data[ctx.dataIndex];
                                const pct = ((d.value / data.reduce((a,b)=>a+b.value,0))*100).toFixed(1);
                                return d.label + ' — ' + d.displayValue + ' (' + pct + '%)';
                            }
                        }
                    }
                }
            }
        });
    },

    destroy: function (widgetId) {
        if (this.instances[widgetId]) {
            this.instances[widgetId].destroy();
            delete this.instances[widgetId];
        }
    }
};
```

> Chart.js must be loaded via `<script>` in `App.razor` before `agentStatusChart.js`.
> Use the same CDN reference already present for DayTrend.

---

### 6. Blazor components

**AgentStatusCountWidget.razor** — key structure:

- Canvas element: `<canvas id="agentStatusCanvas_@WidgetId"></canvas>`
- On `AfterRenderAsync(firstRender)`: call `RefreshAsync()`, start timer if `RefreshIntervalSeconds > 0`
- `RefreshAsync()`: dispatch `AgentStatusCountQuery` → get result → build `chartData` array
  (each enabled segment: `{ metricId, value = _counts[seg.MetricId], displayValue = value.ToString("0"), label, color }`)
  → call `JS.InvokeVoidAsync("agentStatusChart.render", WidgetId, config, chartData)`
- `DisposeAsync()`: cancel timer + call `agentStatusChart.destroy`
- Empty states:
  - `NoQueues = true` → message `"No queues assigned to this Business Unit"`
  - All values 0 → message `"No active agents found for this Business Unit today"`
  - Error → badge with retry button

**AgentStatusDurationWidget.razor** — identical structure; differences:
- Dispatches `AgentStatusDurationQuery`
- `displayValue` for each segment = `FormatDuration(seconds, Config.DurationFormat)`
- Segment size still uses raw seconds for correct proportionality

---

### 7. Seed entries

#### 7.1 `snapshot.*` metrics — add to `RtsMetricSeed.cs`

```csharp
// AgentStatusSnapshot metrics (RTSData_UserStatusLog WHERE EndTime IS NULL, BU agent pool)
new RtsGridMetric { MetricId = "snapshot.available_count",  Description = "Available Agents (Now)",        DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:AVAILABLE",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.onphone_count",    Description = "On Phone Agents (Now)",         DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:ONPHONE",    MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.break_count",      Description = "On Break Agents (Now)",         DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:BREAK",      MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.paperwork_count",  Description = "Paperwork / ACW Agents (Now)",  DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:PAPERWORK",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.training_count",   Description = "Training / Back-Office (Now)",  DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:TRAINING",   MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.total_active",     Description = "Total Active Agents (Now)",     DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:ALL",        MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
```

#### 7.2 `WidgetCatalogItem` entries — add to `WidgetCatalogSeed.cs`

Copy verbatim from spec §4.9 and §5.9.

---

### 8. Config modal tabs (ScreenEditorPage.razor)

Add two new `case` blocks in the widget type switch.

**Case "AgentStatusCount" — tabs: General | Appearance | Status Groups**

Tab General:
- `Title` text input → `Config.Title`
- `BusinessUnitId` dropdown (load `GetNgcBusinessUnitsQuery`) → `Config.BusinessUnitId`
- `RefreshIntervalSeconds` dropdown: 15 s / 30 s / 1 min / 5 min → `Config.RefreshIntervalSeconds`

Tab Appearance:
- `ChartType` icon toggle: Donut / Pie / Bar → `Config.ChartType`
- `ShowLegend` toggle → `Config.ShowLegend`
- `ShowLabels` toggle → `Config.ShowLabels`
- `ShowCenterTotal` toggle (visible only when `ChartType == "donut"`) → `Config.ShowCenterTotal`

Tab Status Groups:
- Foreach `Config.Segments`: toggle (Enabled), colour picker (Color), label text input

**Case "AgentStatusDuration" — tabs: General | Appearance | Status Groups**

Tab General:
- `Title`, `BusinessUnitId`, `RefreshIntervalSeconds` (options: 1 min / 5 min / 10 min)

Tab Appearance:
- `ChartType`, `ShowLegend`, `ShowLabels`, `ShowCenterTotal`
- `DurationFormat` radio: `hh:mm` / `hh:mm:ss` / `minutes`

Tab Status Groups:
- Same structure as AgentStatusCount

**"Save as Template" button** in both config modal footers per `widget-creator.md §22.4`.
Dispatches `CreateWidgetTemplateCommand` with current `ConfigJson`.

---

### 9. Acceptance criteria

| # | Criterion |
|---|---|
| 9.1 | Migration `AddAgentStatusFunctions` applies cleanly; `fn_agentstatuscount` and `fn_agentstatusduration` exist in DB |
| 9.2 | `AgentStatusCountQuery` returns correct segment counts for seeded test data |
| 9.3 | `AgentStatusCountQuery` returns `NoQueues = true` when BU has no queue assignments |
| 9.4 | `AgentStatusDurationQuery` returns correct seconds per StatusGroup for seeded test data |
| 9.5 | `AgentStatusDurationQuery` returns `NoQueues = true` when BU has no queue assignments |
| 9.6 | `AgentStatusCountWidget.razor` renders Donut chart without JS errors in browser |
| 9.7 | `AgentStatusDurationWidget.razor` renders Donut chart with formatted durations |
| 9.8 | Both widgets auto-refresh at configured interval; `DisposeAsync` cancels timer and destroys Chart.js instance (no memory leak) |
| 9.9 | Chart type toggle (Donut / Pie / Bar) updates chart without page reload |
| 9.10 | All 6 `snapshot.*` seed entries visible in DB after startup |
| 9.11 | Both `WidgetCatalogItem` entries appear under category "Agents" in the widget picker |
| 9.12 | Config modal opens, all 3 tabs render, save writes correct ConfigJson to `DashboardWidget.ConfigJson` |
| 9.13 | "Save as Template" button dispatches `CreateWidgetTemplateCommand` for both widget types |
| 9.14 | `dotnet build CcDashboard.sln` — zero errors, zero warnings |
| 9.15 | Unit tests: handler returns `NoQueues` branch; segment dictionary contains all 5 StatusGroup keys |

---

## CC-004

### Cleanup AgentStatus artefacts + create History_Metric table

**Status:** ✅ Done  
**Priority:** 🔴 High  
**Depends on:** CC-002 ✅  
**Spec reference:** `docs/widget-specification.md` §2 — read before starting  
**Skill:** none  
**Commit:** (pending)

---

### 1. Background

During CC-003 development, two architectural errors were introduced:

1. **Wrong metric store**: dot-notation metrics (`interaction.*`, `statuslog.*`, `agentstatus.*`,
   `snapshot.*`) were seeded into `RtsGridMetric` — a CC-platform-owned read-only table.
   These metrics belong in a new shell-owned table **`History_Metric`**.

2. **Premature widget development**: `AgentStatusCount` and `AgentStatusDuration` widgets were
   implemented before the metric catalogue architecture was settled. All their artefacts must be
   removed.

This task fixes both errors. DayTrend migration to `History_Metric` is a **separate task (CC-005)**.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | Remove CC-003 BackendEmulation migration | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| 2.2 | Delete AgentStatus application files | `src/CcDashboard.Application/Queries/Widgets/` |
| 2.3 | Delete AgentStatus infrastructure files | `src/CcDashboard.Infrastructure/Handlers/` |
| 2.4 | Delete AgentStatus Blazor components | `src/CcDashboard.Web/Components/Widgets/` |
| 2.5 | Delete AgentStatus JS interop | `src/CcDashboard.Web/wwwroot/js/` |
| 2.6 | Clean `DatabaseInitializer.cs` seed method | `src/CcDashboard.Infrastructure/Seeding/` |
| 2.7 | `HistoryMetric` domain entity | `src/CcDashboard.Domain/Domain/` |
| 2.8 | `HistoryMetricConfiguration` | `src/CcDashboard.Infrastructure/Persistence/Configurations/` |
| 2.9 | EF migration `AddHistoryMetricTable` (App context) | `src/CcDashboard.Infrastructure/Migrations/App/` |
| 2.10 | `SeedHistoryMetricsAsync()` in `DatabaseInitializer.cs` | `src/CcDashboard.Infrastructure/Seeding/` |
| 2.11 | Update `docs/widget-specification.md` | `docs/` |
| 2.12 | Update `docs/backend-tasks.md` — CC-003 already marked ❌ in this commit | `docs/` |

---

### 3. Step-by-step instructions

#### 3.1 Remove BackendEmulation migration `AddAgentStatusFunctions`

```bash
dotnet ef migrations remove   --context BackendEmulationDbContext   --project src/CcDashboard.Infrastructure   --startup-project src/CcDashboard.Web
```

This removes `20260527132732_AddAgentStatusFunctions.cs` and `...Designer.cs` and reverts
the snapshot. Verify with `git status` — only those two files should be deleted.

If the DB has already applied the migration, first run:
```bash
dotnet ef database update 20260526214442_AddDayTrendFunctions   --context BackendEmulationDbContext   --project src/CcDashboard.Infrastructure   --startup-project src/CcDashboard.Web
```

#### 3.2 Delete AgentStatus application artefacts

Delete these files:
- `src/CcDashboard.Application/Queries/Widgets/AgentStatusCountQuery.cs`
- `src/CcDashboard.Application/Queries/Widgets/AgentStatusDurationQuery.cs`
- `src/CcDashboard.Infrastructure/Handlers/AgentStatusCountQueryHandler.cs`
- `src/CcDashboard.Infrastructure/Handlers/AgentStatusDurationQueryHandler.cs`
- `src/CcDashboard.Web/Components/Widgets/AgentStatusCountWidget.razor`
- `src/CcDashboard.Web/Components/Widgets/AgentStatusDurationWidget.razor`
- `src/CcDashboard.Web/wwwroot/js/agentStatusChart.js` (if exists)

Do **not** delete `AgentStatusWidget.razor` — verify it predates CC-003 via `git log` first.
If it was created by CC-003, delete it too.

#### 3.3 Clean `DatabaseInitializer.cs` — `SeedRtsGridMetricsAsync()`

Remove from the `metrics` list inside `SeedRtsGridMetricsAsync()`:
- All `snapshot.*` entries (MetricType = "AgentStatusSnapshot") — **delete entirely, do not move**
- All `agentstatus.*` entries (MetricType = "AgentStatus") — **move to `SeedHistoryMetricsAsync()`**
- All `interaction.*` entries (MetricType = "Interaction") — **move to `SeedHistoryMetricsAsync()`**
- All `statuslog.*` entries (MetricType = "AgentStatusLog") — **move to `SeedHistoryMetricsAsync()`**

After removal, `SeedRtsGridMetricsAsync()` should contain **zero** entries with a "." in MetricId.

#### 3.4 Create `HistoryMetric` entity

```csharp
// src/CcDashboard.Domain/Domain/HistoryMetric.cs
namespace CcDashboard.Domain.Domain;

/// <summary>
/// Shell-owned catalogue of historical (RTSData_*) metric definitions.
/// Used by Chart/Analytics widgets. Not related to RTSGrid_Metric (CC platform, read-only).
/// MetricId convention: {domain}.{metric_name} — e.g. "interaction.incoming_calls"
/// </summary>
public class HistoryMetric
{
    public string MetricId       { get; set; } = string.Empty; // PK — e.g. "interaction.incoming_calls"
    public string Description    { get; set; } = string.Empty;
    public string DataType       { get; set; } = string.Empty; // "int" | "decimal" | "bigint"
    public string MetricFunction { get; set; } = string.Empty; // "COUNT_FILTER" | "AVG_FIELD" | etc.
    public string MetricParameter{ get; set; } = string.Empty;
    public string MetricFormat   { get; set; } = string.Empty; // "0" | "mm:ss" | "hh:mm:ss"
    public string DefaultValue   { get; set; } = "0";
    public string ValueType      { get; set; } = string.Empty; // "Number" | "Time" | "TimeMs"
    public string MetricType     { get; set; } = string.Empty; // "Interaction" | "AgentStatus" | "AgentStatusLog"
}
```

#### 3.5 Create `HistoryMetricConfiguration`

```csharp
// src/CcDashboard.Infrastructure/Persistence/Configurations/HistoryMetricConfiguration.cs
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class HistoryMetricConfiguration : IEntityTypeConfiguration<HistoryMetric>
{
    public void Configure(EntityTypeBuilder<HistoryMetric> builder)
    {
        builder.ToTable("history_metrics");
        builder.HasKey(m => m.MetricId);
        builder.Property(m => m.MetricId)       .HasMaxLength(100).IsRequired();
        builder.Property(m => m.Description)    .HasMaxLength(200).IsRequired();
        builder.Property(m => m.DataType)       .HasMaxLength(20) .IsRequired();
        builder.Property(m => m.MetricFunction) .HasMaxLength(50) .IsRequired();
        builder.Property(m => m.MetricParameter).HasMaxLength(200).IsRequired();
        builder.Property(m => m.MetricFormat)   .HasMaxLength(20) .IsRequired();
        builder.Property(m => m.DefaultValue)   .HasMaxLength(20) .IsRequired();
        builder.Property(m => m.ValueType)      .HasMaxLength(20) .IsRequired();
        builder.Property(m => m.MetricType)     .HasMaxLength(50) .IsRequired();
        // No TenantId — cross-tenant shell catalogue (same pattern as RtsGridMetric)
    }
}
```

Register in `AppDbContext`: `public DbSet<HistoryMetric> HistoryMetrics => Set<HistoryMetric>();`

**No Global Query Filter** — `HistoryMetric` is a cross-tenant catalogue (same as `RtsGridMetric`).

#### 3.6 Run EF migration for App context

```bash
dotnet ef migrations add AddHistoryMetricTable   --context AppDbContext   --project src/CcDashboard.Infrastructure   --startup-project src/CcDashboard.Web
```

#### 3.7 Add `SeedHistoryMetricsAsync()` to `DatabaseInitializer.cs`

Add the method and call it from `InitialiseAsync`. Move the dot-notation entries here:

```csharp
private async Task SeedHistoryMetricsAsync(CancellationToken ct)
{
    var metrics = new List<HistoryMetric>
    {
        // --- Interaction metrics (source: RTSData_Interaction) ---
        new() { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.answered_calls",      Description = "Answered Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "answered",                               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",         DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",                              MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.callback_requests",   Description = "Callback Requests",       DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",                      MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",     DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",                     MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.outbound_calls",      Description = "Outbound Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_outgoing",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.transferred_calls",   Description = "Transferred Calls",       DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "transferred",                            MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
        new() { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",           DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
        new() { MetricId = "interaction.max_wait_time",       Description = "Max Wait Time",           DataType = "decimal", MetricFunction = "MAX_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
        new() { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",           DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
        new() { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon", DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

        // --- Agent status log metrics (source: RTSData_UserStatusLog — interval aggregates) ---
        new() { MetricId = "statuslog.available_agents",      Description = "Available Agents",             DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:AVAILABLE",  MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.onphone_agents",        Description = "On Phone Agents",              DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ONPHONE",    MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.break_agents",          Description = "Agents on Break",              DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:BREAK",      MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.paperwork_agents",      Description = "Paperwork / ACW Agents",       DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:PAPERWORK",  MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.training_agents",       Description = "Training / Back-Office Agents",DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:TRAINING",   MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.total_agents",          Description = "Total Active Agents",          DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ALL",        MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.logged_in_agents",      Description = "Logged-In Agents",             DataType = "int",    MetricFunction = "COUNT_POOL",     MetricParameter = "pool:all",         MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.available_time_ms",     Description = "Available Time",               DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:AVAILABLE",  MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.onphone_time_ms",       Description = "On Phone Time",                DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ONPHONE",    MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.break_time_ms",         Description = "Break Time",                   DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:BREAK",      MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.paperwork_time_ms",     Description = "Paperwork / ACW Time",         DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:PAPERWORK",  MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.training_time_ms",      Description = "Training / Back-Office Time",  DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:TRAINING",   MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
        new() { MetricId = "statuslog.total_active_time_ms",  Description = "Total Active Time",            DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ALL",        MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },

        // --- Agent status daily totals (source: RTSData_UserStatus.TotalDuration — seconds) ---
        new() { MetricId = "agentstatus.available_time",  Description = "Available Time Today",             DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:AVAILABLE",  MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
        new() { MetricId = "agentstatus.onphone_time",    Description = "On Phone Time Today",              DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:ONPHONE",    MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
        new() { MetricId = "agentstatus.break_time",      Description = "On Break Time Today",              DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:BREAK",      MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
        new() { MetricId = "agentstatus.paperwork_time",  Description = "Paperwork / ACW Time Today",       DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:PAPERWORK",  MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
        new() { MetricId = "agentstatus.training_time",   Description = "Training / Back-Office Time Today",DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:TRAINING",   MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
    };

    try
    {
        var existingIds = (await _db.HistoryMetrics.Select(m => m.MetricId).ToListAsync(ct)).ToHashSet();
        var toAdd = metrics.Where(m => !existingIds.Contains(m.MetricId)).ToList();
        if (toAdd.Count > 0)
        {
            _db.HistoryMetrics.AddRange(toAdd);
            await _db.SaveChangesAsync(ct);
            logger.LogInformation("Seeded {Count} HistoryMetric entries", toAdd.Count);
        }
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "HistoryMetric seed skipped");
    }
}
```

Call from `InitialiseAsync()` alongside other seed calls:
```csharp
await SeedHistoryMetricsAsync(ct);
```

#### 3.8 Update `docs/widget-specification.md`

- **Remove §4** (AgentStatusCount — Current Agent Status Distribution) entirely
- **Remove §5** (AgentStatusDuration — Agent Status Time Distribution) entirely
- **Remove TOC entries** for §4 and §5
- **In §2.4** (seed code blocks): replace `new RtsGridMetric { MetricId = "interaction.*` / `statuslog.*` / `agentstatus.*` entries with `new HistoryMetric { ...` — same data, different class name
- **Remove `snapshot.*` block** from §2.4 entirely (no longer needed)
- **Add note** at the top of §2: "Metrics with `MetricId` containing `.` belong to the Shell-owned `History_Metric` table — not to `RTSGrid_Metric`."
- Update version footer to `v1.0`

---

### 4. Acceptance criteria

| # | Criterion |
|---|---|
| 4.1 | `dotnet ef migrations remove --context BackendEmulationDbContext` completes without error; `20260527132732_*` files no longer exist |
| 4.2 | `AgentStatusCountQuery.cs`, `AgentStatusDurationQuery.cs`, both handlers, both Blazor components deleted |
| 4.3 | `agentStatusChart.js` deleted (if existed) |
| 4.4 | `DatabaseInitializer.SeedRtsGridMetricsAsync()` contains zero entries with `.` in MetricId |
| 4.5 | `snapshot.*` entries are gone from codebase entirely (no file references remain) |
| 4.6 | `HistoryMetric` entity exists in `CcDashboard.Domain`; no TenantId field |
| 4.7 | `AppDbContext.HistoryMetrics` DbSet exists; no Global Query Filter |
| 4.8 | EF migration `AddHistoryMetricTable` applies cleanly; `history_metrics` table created |
| 4.9 | `SeedHistoryMetricsAsync()` seeds 29 entries (11 interaction + 13 statuslog + 5 agentstatus) on first run; idempotent on re-run |
| 4.10 | `docs/widget-specification.md`: §4 and §5 removed; TOC updated; §2.4 uses `HistoryMetric` class name; `snapshot.*` block removed; version footer = v1.0 |
| 4.11 | `dotnet build CcDashboard.sln` — zero errors, zero warnings |
| 4.12 | `git grep -r "snapshot\."` returns no matches in `src/` |
| 4.13 | `git grep -r "RtsGridMetric" src/CcDashboard.Infrastructure/Seeding/` — no dot-notation MetricId values remain |

--

---

## CC-005

### Fix RTSGrid_Metric data + apply History_Metric migration

**Status:** ✅ Done  
**Priority:** 🔴 High  
**Depends on:** CC-004 ✅  
**Spec reference:** `docs/rtsgrid-metric-reference.md` — read §3 (MetricFunction catalogue) and §4 (ValueType rules) before starting  
**Skill:** none  
**Commit:** `f0cb60c`

---

### 1. Background

The BackendEmulation `RTSGrid_Metrics` table currently has three data quality problems:

1. **Dot-notation MetricIds** (`interaction.*`, `statuslog.*`, `agentstatus.*`, `snapshot.*`) were
   seeded by CC-003. These belong to `history_metrics`. Must be deleted from `RTSGrid_Metrics`.

2. **MetricType is wrong** — all rows have `MetricType = "Agent"`. Correct values:
   - `"Data"` for Queue metrics (Description starts with `"QM - "`)
   - `"Data"` for AgentGroup metrics (Description starts with `"Agent Group - "`)
   - `"Agent"` for Agent metrics (Description starts with `"Agent - "`)

3. **ValueType is wrong** — all rows have `ValueType = "String"`. Correct values:
   - `"time"` for duration/time functions
   - `"text"` for string/identifier functions
   - `"number"` for everything else (counts, percentages, rates)

Additionally, the **`history_metrics` table does not yet exist** in the App DB — the EF migration
`AddHistoryMetricTable` has been created (committed in CC-004) but not yet applied.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | BackendEmulation migration `FixRtsGridMetricData` | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| 2.2 | Apply App migration `AddHistoryMetricTable` to DB | run `dotnet ef database update` |
| 2.3 | Update `SeedRtsGridMetricsAsync()` with all 190 metrics (correct ValueType + MetricType) | `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` |
| 2.4 | Update task index | `docs/backend-tasks.md` |

---

### 3. Step-by-step instructions

#### 3.1 Create BackendEmulation migration `FixRtsGridMetricData`

```bash
dotnet ef migrations add FixRtsGridMetricData \
  --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

Edit the generated migration file — replace `Up()` body with:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    // 1. Delete dot-notation metrics (belong to history_metrics, not RTSGrid_Metrics)
    migrationBuilder.Sql("""
        DELETE FROM "RTSGrid_Metrics"
        WHERE "MetricId" LIKE '%.%';
        """);

    // 2. Fix MetricType based on Description prefix
    migrationBuilder.Sql("""
        UPDATE "RTSGrid_Metrics"
        SET "MetricType" = 'Data'
        WHERE "Description" LIKE 'QM - %'
           OR "Description" LIKE 'Agent Group - %';

        UPDATE "RTSGrid_Metrics"
        SET "MetricType" = 'Agent'
        WHERE "Description" LIKE 'Agent - %'
           OR ("MetricType" != 'Data');
        """);

    // 3. Fix ValueType — default to 'number', then override time and text
    migrationBuilder.Sql("""
        UPDATE "RTSGrid_Metrics" SET "ValueType" = 'number';

        UPDATE "RTSGrid_Metrics" SET "ValueType" = 'time'
        WHERE "MetricFunction" IN (
            'CurLoginDuration', 'CurStatusDuration', 'CurStatusGroupDuration',
            'LongestInteractionStateDuration',
            'MessagesAvgFirstResponseTime', 'MessagesAvgResponseTime', 'MessagesMaxFirstResponseTime',
            'TalkDurationAvg', 'TalkDurationCurMax', 'TalkDurationMax',
            'TotalLoginDuration', 'TotalStatusDuration', 'TotalStatusDurationAvg',
            'TotalStatusGroupDuration', 'TotalStatusGroupDurationAvg',
            'WaitDurationAvg', 'WaitDurationCurMax'
        );

        UPDATE "RTSGrid_Metrics" SET "ValueType" = 'text'
        WHERE "MetricFunction" IN (
            'CurLoginTimeStamp', 'CurStatusGroup', 'CurStatusTitle', 'DisplayName',
            'FirstLoginTimestamp', 'IsTodayLogin',
            'LongestInteractionId', 'LongestInteractionRemoteAddress',
            'LongestInteractionState', 'LongestInteractionType', 'LongestInteractionWorkgroup',
            'Station', 'UserExtension', 'UserID'
        );
        """);
}

protected override void Down(MigrationBuilder migrationBuilder)
{
    // Restore ValueType and MetricType to legacy incorrect values
    migrationBuilder.Sql("""
        UPDATE "RTSGrid_Metrics" SET "ValueType" = 'String', "MetricType" = 'Agent';
        """);
}
```

Apply migration:

```bash
dotnet ef database update \
  --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

Verify:

```sql
-- Should return 0
SELECT COUNT(*) FROM "RTSGrid_Metrics" WHERE "MetricId" LIKE '%.\%';

-- Should return ~90 rows with MetricType = 'Data'
SELECT "MetricType", COUNT(*) FROM "RTSGrid_Metrics" GROUP BY "MetricType";

-- Should show distribution across number/time/text
SELECT "ValueType", COUNT(*) FROM "RTSGrid_Metrics" GROUP BY "ValueType";
```

#### 3.2 Apply App migration `AddHistoryMetricTable`

The migration file already exists (committed in CC-004). Just apply it:

```bash
dotnet ef database update \
  --context AppDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

Then restart the app — `SeedHistoryMetricsAsync()` will populate `history_metrics` with all
30 dot-notation metrics on first run.

Verify:

```sql
-- Should return 29 rows
SELECT COUNT(*) FROM history_metrics;

-- Check distribution
SELECT "MetricType", COUNT(*) FROM history_metrics GROUP BY "MetricType";
```

#### 3.3 Update `SeedRtsGridMetricsAsync()` in `DatabaseInitializer.cs`

Replace the empty `metrics` list with all 190 CC-platform metrics (correct ValueType and MetricType).
This ensures a fresh BackendEmulation DB also gets correct data without running the fix migration.

```csharp
private async Task SeedRtsGridMetricsAsync(CancellationToken ct)
{
    var metrics = new List<RtsGridMetric>
    {
            new() { MetricId = "MonAgentTalkDuration", Description = "Agent - Cumulative Talk Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentTalkDurationPct", Description = "Agent - Cumlative Talk Duration Percent", DataType = "User", MetricFunction = "TotalStatusGroupPercent", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentActiveInteractionId", Description = "Agent - Active Interction ID", DataType = "User", MetricFunction = "LongestInteractionId", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueNumCompletedCallbacks", Description = "QM - Number of Completed Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Outgoing\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAcceptedCallbacks", Description = "QM - Number of Accepted Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCalls", Description = "QM - Number of Incoming Calls including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCallbacks", Description = "QM - Number of Incoming Callbacks including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCallsAndCallbacks", Description = "QM - Number of Incoming Calls and Callbacks including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineChats", Description = "QM - Number of Incoming Chats including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIcomingOnlineInteractions", Description = "QM - Number of Incoming Interactions including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonefCalls", Description = "QM - Number of Abandoned Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonefCallbacks", Description = "QM - Number of Abandoned Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedCallsAndCallbacks", Description = "QM - Number of Abandoned Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedChats", Description = "QM - Number of Abandoned Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedInteractions", Description = "QM - Number of Abandoned Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumCallbackRequests", Description = "QM - Number of Callback Requests", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls", Description = "QM - Number of Answered Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls60sec", Description = "QM - Number of Answered Calls in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsBreakDurationMax", Description = "Agent Group - Max duration of  Break State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupDurationCurMax", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentNumChatsCompleted", Description = "Agent - Number of Answered Chats", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\" && Direction==\"Incoming\" && !IsTalk && !IsInQueue && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueBaseAnsweredPct", Description = "QM - Base Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueExclCallbackReqAnsweredPct", Description = "QM - Excluding Callback Requests Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])==0 ? 0 : ((double)[QueueNumAnsweredCalls]/([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueInclCallbackReqAnsweredPct", Description = "QM - Including Callback Requests Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCallbackRequests])/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueInclCompCallbacksAnsweredPct", Description = "QM - Including Completed Callbacks Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCompletedCallbacks])/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls60secIncLast30min", Description = "QM - Percent of Answered Calls in 60 sec Last 30 min from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumIncomingCompletedCalls])&&InQueueDateTime>=DateTime.Now.AddHours(-0.5)", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumOnlineChats", Description = "QM - Number of Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UserNumMissedCalls", Description = "Agent - Number of Missed Calls", DataType = "User", MetricFunction = "TotalStatusCount", MetricParameter = "Missed Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueNumIncomingHandledInteractions", Description = "QM - Number of Completed Incoming Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue && !IsAbandoned && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueSLAIn30secFrom80PctInc", Description = "QM - Percent of Answered Calls in 30 sec from 80% Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec ]/([QueueNumIncomingCompletedCalls]*0.8))", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWrapUpAgents", Description = "QM - Number of Wpap Up Agents in Queue Skill", DataType = "Interactions Summary", MetricFunction = "UsersInStatusCount", MetricParameter = "Wrap Up", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueCPH", Description = "QM - Calls per Hour", DataType = "Interactions Summary", MetricFunction = "CPH", MetricParameter = "InteractionType==\"Call\" && Direction == \"Incoming\"", MetricFormat = "F2", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UserCPH", Description = "Agent - Calls per Hour", DataType = "User", MetricFunction = "CPH", MetricParameter = "InteractionType==\"Call\" && Direction == \"Incoming\"", MetricFormat = "F2", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MessagesMaxFirstResponseTime", Description = "QM - Messages Max First Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesMaxFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MessagesAvgFirstResponseTime", Description = "QM - Messages Avg First Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesAvgFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonAgentNumChatsActive", Description = "Agent - Number of Active Chats", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MessagesAvgResponseTime", Description = "QM - Messages Avg Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesAvgResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "AgentMessagesAvgResponseTime", Description = "Agent - Messages Avg Response Time", DataType = "User", MetricFunction = "MessagesAvgResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "AgentMessagesAvgFirstResponseTime", Description = "Agent - Messages Avg First Response Time", DataType = "User", MetricFunction = "MessagesAvgFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "QueueNumAnsweredCallbacks", Description = "QM - Number of Answered Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks", Description = "QM - Number of Answered Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats", Description = "QM - Number of Answered Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions", Description = "QM - Number of Answered Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCalls", Description = "QM - Number of Incoming Calls exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCallbacks", Description = "QM - Number of Incoming Callbacks exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCallsAndCallbacks", Description = "QM - Number of Incoming Calls and Callbacks exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedChats", Description = "QM - Number of Incoming Chats exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue  && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedInteractions", Description = "QM - Number of Incoming Interactions exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue  && !IsCallbackRequest && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCalls", Description = "QM - Number of Waiting Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCallbacks", Description = "QM - Number of Waiting Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCallsAndCallbacks", Description = "QM - Number of Waiting Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingChats", Description = "QM - Number of Waiting Chats", DataType = "Interactions Summary", MetricFunction = "NumWaitings", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingInteractions", Description = "QM - Number of Waiting Interactions", DataType = "Interactions Summary", MetricFunction = "NumWaitings", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCalls", Description = "QM - Current Max Wait Time of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCallbacks", Description = "QM - Current Max Wait Time of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCallsAndCallbacks", Description = "QM - Current Max Wait Time of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeChats", Description = "QM - Current Max Wait Time of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeInteractions", Description = "QM - Current Max Wait Time of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsTotal", Description = "QM - Percent of Answered Calls", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacksTotal", Description = "QM - Percent of Answered Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacksTotal", Description = "QM - Percent of Answered Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChatsTotal", Description = "QM - Percent of Answered Chats", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractionsTotal", Description = "QM - Percent of Answered Interactions", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallsTotal", Description = "QM - Percent of Abandoned Calls", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAbandonedCalls]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallbacksTotal", Description = "QM - Percent of Abandoned Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallbacks]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallsAndCallbacksTotal", Description = "QM - Percent of Abandoned Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedInteractionsTotal", Description = "QM - Percent of Abandoned Interactions", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAbandonedInteractions]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedChatsTotal", Description = "QM - Percent of Abandoned Chats", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAbandonedChats]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls30sec", Description = "QM - Number of Answered Calls in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks30sec", Description = "QM - Number of Answered Callbacks in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks30sec", Description = "QM - Number of Answered Calls and Callbacks in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats30sec", Description = "QM - Number of Answered Chats in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions30sec", Description = "QM - Number of Answered Interactions in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks60sec", Description = "QM - Number of Answered Calls in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks60sec", Description = "QM - Number of Answered Calls and Callbacks in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats60sec", Description = "QM - Number of Answered Chats in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions60sec", Description = "QM - Number of Answered Interactions in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls120sec", Description = "QM - Number of Answered Calls in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks120sec", Description = "QM - Number of Answered Callbacks in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks120sec", Description = "QM - Number of Answered Calls and Callbacks in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats120sec", Description = "QM - Number of Answered Chats in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions120sec", Description = "QM - Number of Answered Interactions in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCalls", Description = "QM - Average Wait Time of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCallbacks", Description = "QM - Average Wait Time of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCallsAndCallbacks", Description = "QM - Average Wait Time of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeChats", Description = "QM - Average Wait Time of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeInteractions", Description = "QM - Average Wait Time of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCalls", Description = "QM - Average Time to Aband of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCallbacks", Description = "QM - Average Time to Aband of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCallsAndCallbacks", Description = "QM - Average Time to Aband of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandChats", Description = "QM - Average Time to Aband of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandInteractions", Description = "QM - Average Time to Aband of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveCalls", Description = "QM - Number of Active Calls in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveCallbacks", Description = "QM - Number of Active Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentTelState", Description = "Agent - Active Interaction State", DataType = "User", MetricFunction = "LongestInteractionState", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueNumActiveCallsAndCallbacks", Description = "QM - Number of Active Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\"&& (InteractionType==\"Call\" || InteractionType==\"Callback\")&& IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveChats", Description = "QM - Number of Active Chats in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveInteractions", Description = "QM - Number of Active Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsTalk && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumOnCallAgents", Description = "QM - Number of On Call Agents in Queue Skill", DataType = "Interactions Summary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCalls", Description = "QM - Average Talking Duration of Calls", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCallbacks", Description = "QM - Average Talking Duration of Callbacks", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCallsAndCallbacks", Description = "QM - Average Talking Duration of Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationChats", Description = "QM - Average Talking Duration of Chats", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationInteractions", Description = "QM - Average Talking Duration of Interactions", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls30secInc", Description = "QM - Percent of Answered Calls in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks30secInc", Description = "QM - Percent of Answered Callbacks in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks30secInc", Description = "QM - Percent of Answered Calls and Callbacks in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats30secInc", Description = "QM - Percent of Answered Chats in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions30secInc", Description = "QM - Percent of Answered Interactions in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls30secAns", Description = "QM - Percent of Answered Calls in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks30secAns", Description = "QM - Percent of Answered Callbacks in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks30secAns", Description = "QM - Percent of Answered Calls and Callbacks in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats30secAns", Description = "QM - Percent of Answered Chats in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions30secAns", Description = "QM - Percent of Answered Interactions in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls60secInc", Description = "QM - Percent of Answered Calls in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks60secInc", Description = "QM - Percent of Answered Callbacks in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks60secInc", Description = "QM - Percent of Answered Calls and Callbacks in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats60secInc", Description = "QM - Percent of Answered Chats in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions60secInc", Description = "QM - Percent of Answered Interactions in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls60secAns", Description = "QM - Percent of Answered Calls in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks60secAns", Description = "QM - Percent of Answered Callbacks in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks60secAns", Description = "QM - Percent of Answered Calls and Callbacks in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats60secAns", Description = "QM - Percent of Answered Chats in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions60secAns", Description = "QM - Percent of Answered Interactions in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls120secInc", Description = "QM - Percent of Answered Calls in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsInMissedCall", Description = "Agent Group - Number of Agents on Missed Call", DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Missed Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks120secInc", Description = "QM - Percent of Answered Callbacks in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks120secInc", Description = "QM - Percent of Answered Calls and Callbacks in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats120secInc", Description = "QM - Percent of Answered Chats in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions120secInc", Description = "QM - Percent of Answered Interactions in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls120secAns", Description = "QM - Percent of Answered Calls in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks120secAns", Description = "QM - Percent of Answered Callbacks in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks120secAns", Description = "QM - Percent of Answered Calls and Callbacks in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats120secAns", Description = "QM - Percent of Answered Chats in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions120secAns", Description = "QM - Percent of Answered Interactions in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumberOfLoggedAgents", Description = "QM - Number of Logged In Agents", DataType = "Interactions Summary", MetricFunction = "LogedInUsersCount", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentCurrentLoginDuration", Description = "Agent - Current Login Duration", DataType = "User", MetricFunction = "CurLoginDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonSumAgentsAverageCallDuration", Description = "Agent Group - Average Talk Duration in Incoming Calls and Callbacks", DataType = "UsersInteraction", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && (InteractionType == \"Call\" || InteractionType == \"Callback\") && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "UserNumAllIntercom", Description = "Agent - Number of Internal Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"Intercom\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCalls15sec", Description = "Agent - Number of Incoming Calls with Talk Time less than 15 seconds", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" &&  TalkTime<15 && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCalls10Min", Description = "Agent - Number of Incoming Calls with Talk Time more than 10 minutes", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && TalkTime>600 && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsDialer", Description = "Agent Group - Number of Dialer Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Dialer\" && (CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "RemotePhoneNumber", Description = "Agent - Active Interaction Customer Phone Number", DataType = "User", MetricFunction = "LongestInteractionRemoteAddress", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueLoginDataNumAvailableUsers", Description = "Agent Group - Number of Available Agents", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "AVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentAvailableDuration", Description = "Agent - Available State Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "AVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsWithIntercom", Description = "Agent - Number of Incoming External and Internal Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"  && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentTodayLogin", Description = "Change -ID of a representative who was connected that day", DataType = "User", MetricFunction = "IsTodayLogin", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueLoginDataNumLoggedUsers", Description = "Agent Group - Number of Curently Logged in Users", DataType = "UsersSummary", MetricFunction = "LogedInUsersCount", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueLoginDataNumBreakUsers", Description = "Agent Group - Number of Agents in Break State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueLoginDataNumPaperworkUsers", Description = "Agent Group - Number of Agents in Paperwork State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "PAPERWORK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UsersSumOnCall", Description = "Agent Group - Number of On Call Agents", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentStation", Description = "Agent - Station ID", DataType = "User", MetricFunction = "Station", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentDurationOfCurrentCall", Description = "Agent - Current Incoming Ext Call Duration", DataType = "User", MetricFunction = "CurStatusDuration", MetricParameter = "Incoming Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsOnly", Description = "Agent - Number of Incoming External Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" ||  InteractionType==\"Callback\") && (CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentUserId", Description = "Agent - User ID", DataType = "User", MetricFunction = "UserID", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageMakeCallDuration", Description = "Agent - Average Oubound Call Duration", DataType = "User", MetricFunction = "TotalStatusDurationAvg", MetricParameter = "Out Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageAgentDialerDuration", Description = "Agent - Average Dialer Calls Duration", DataType = "User", MetricFunction = "TotalStatusDurationAvg", MetricParameter = "Campaign Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "AgentLoginName", Description = "Agent - Login Name", DataType = "User", MetricFunction = "DisplayName", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonActiveCampaign", Description = "Agent - Active Interaction Queue Name", DataType = "User", MetricFunction = "LongestInteractionWorkgroup", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonInteractionType", Description = "Agent - Active Interaction Type", DataType = "User", MetricFunction = "LongestInteractionType", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentState", Description = "Agent - Current Satatus", DataType = "User", MetricFunction = "CurStatusTitle", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentDurationOfCalls", Description = "Agent - Cumulative  Incoming Ext Call Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Incoming Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageCallDuration", Description = "Agent - Average Handling Duration", DataType = "User", MetricFunction = "TotalStatusGroupDurationAvg", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentExtension", Description = "Agent - Extension ID", DataType = "User", MetricFunction = "UserExtension", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDuration", Description = "Agent - Current Status Duration", DataType = "User", MetricFunction = "CurStatusDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentTelStateDuration", Description = "Agent - Active Interaction State Duration", DataType = "User", MetricFunction = "LongestInteractionStateDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfConsultCalls", Description = "Agent - Number of Consultation Calls", DataType = "User", MetricFunction = "TotalStatusCount", MetricParameter = "Consulting Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfMakeCalls", Description = "Agent - Number of Outbound Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Call\" && CallType==\"External\" && Direction==\"Outgoing\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentBreakDuration", Description = "Agent - Cumulative Break Group Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentWrapUpDuration", Description = "Agent - Cumulative Wrap Up Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Wrap Up", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentUnavailableStateDuration", Description = "Agent - Cumulative Unavailable State Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Unavailable", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDesc", Description = "Agent - Current Status Group", DataType = "User", MetricFunction = "CurStatusGroup", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumMakeCallsInCompleted", Description = "Agent - Number of Answered Incoming Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" ||  InteractionType==\"Callback\") && Direction==\"Incoming\" && IsAnswered && !IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageInboundCallDuration", Description = "Agent - Average Call Duration", DataType = "User", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && (InteractionType==\"Call\" || InteractionType==\"Callback\")  && Direction==\"Incoming\" && !IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentPaperworkDuration", Description = "Agent - Cumulative Paperwork Group Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "PAPERWORK", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonSumAgentsAnsweredCalls", Description = "Agent Group - Number of Answered Incoming Calls and Callbacks", DataType = "UsersInteraction", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && !IsTalk && !IsInQueue && (InteractionType == \"Call\" || InteractionType == \"Callback\") && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsMakeCalls", Description = "Agent Group - Number of Otbound Calls", DataType = "UsersInteraction", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Outgoing\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsAverageChatDuration", Description = "Agent Group - Average Talk Duration in Incoming Chats", DataType = "UsersInteraction", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && (InteractionType == \"Chat\") && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsBreakDurationPercent", Description = "Agent Group - Percent of Agents in Break State Group", DataType = "UsersInteraction", MetricFunction = "UsersInStatusGroupDurationPercent", MetricParameter = "BREAK", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsPaperworkDurationPercent", Description = "Agent Group - Percent of Agents in Paperwork State Group", DataType = "UsersInteraction", MetricFunction = "UsersInStatusGroupDurationPercent", MetricParameter = "PAPERWORK", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsLongestCurrentCall", Description = "Agent Group - Current Max Talk Duration", DataType = "UsersInteraction", MetricFunction = "TalkDurationCurMax", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonAgentOutgoingCallbacksNum", Description = "Agent - Number of Outgoing Callbacks", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Callback\" && Direction==\"Outgoing\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueNumAnsweredCalls360sec", Description = "QM - Number of Answered Calls in 360 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<360", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls360secInc", Description = "QM - Percent of Answered Calls in 360 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls360sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentMaxCallDuration", Description = "Agent - Max Call Duration", DataType = "User", MetricFunction = "TalkDurationMax", MetricParameter = "CallType==\"External\" && (InteractionType==\"Call\" || InteractionType==\"Callback\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentLoginTime", Description = "Agent - Cumulative Login Duration", DataType = "User", MetricFunction = "TotalLoginDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDescDuration", Description = "Agent - Current Status Group Duration", DataType = "User", MetricFunction = "CurStatusGroupDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentFirstLoginTimeStamp", Description = "Agent - First Login Time Stamp", DataType = "User", MetricFunction = "FirstLoginTimestamp", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentCurrentLoginTimeStamp", Description = "Agent - Current Login Time Stamp", DataType = "User", MetricFunction = "CurLoginTimeStamp", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentProxyCallsNum", Description = "Agent - Number of Incoming Callbacks", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Callback\" && Direction==\"Incoming\"  && IsAnswered && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentHeldDuration", Description = "Agent - Cumulative Hold Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Hold", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
    };

    try
    {
        var existingIds = (await beDb.RtsGridMetrics.Select(m => m.MetricId).ToListAsync(ct)).ToHashSet();
        var toAdd = metrics.Where(m => !existingIds.Contains(m.MetricId)).ToList();
        if (toAdd.Count > 0)
        {
            beDb.RtsGridMetrics.AddRange(toAdd);
            await beDb.SaveChangesAsync(ct);
            logger.LogInformation("Seeded {Count} RtsGridMetric entries", toAdd.Count);
        }
        // Fix MetricType and ValueType for existing rows that have wrong values
        var toFix = await beDb.RtsGridMetrics
            .Where(m => m.ValueType == "String" || !m.MetricId.Contains('.') == false)
            .ToListAsync(ct);
        foreach (var existing in toFix)
        {
            var correct = metrics.FirstOrDefault(m => m.MetricId == existing.MetricId);
            if (correct != null)
            {
                existing.ValueType = correct.ValueType;
                existing.MetricType = correct.MetricType;
            }
        }
        if (toFix.Count > 0)
            await beDb.SaveChangesAsync(ct);
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "RtsGridMetric seed skipped (may already exist)");
    }
}
```

> **Note:** The fix loop (`toFix`) is a belt-and-suspenders approach — the migration in 3.1
> handles the DB directly. On a fresh DB, the seed inserts correct values from the start.

---

### 4. Verification checklist

```bash
# After applying both migrations and restarting the app:
# 1. No dot-notation rows in RTSGrid_Metrics
# 2. MetricType distribution: Data ~90 rows, Agent ~100 rows
# 3. ValueType distribution: number ~130, time ~45, text ~15
# 4. history_metrics has 29 rows (11 interaction + 13 statuslog + 5 agentstatus)
# 5. App builds: dotnet build CcDashboard.sln
``

---

## CC-006

### DayTrend: migrate from RTSGrid_Metric to HistoryMetric

**Status:** ✅ Done
**Priority:** 🔴 High
**Depends on:** CC-005 ✅
**Spec reference:** `docs/widget-specification.md` §1.3, §1.4, §3 — read before starting
**Skill:** `.claude/skills/widget-creator/widget-creator.md` §23
**Commit:** `18613d5`

---

### 1. Background

DayTrend was implemented before the RTSGrid_Metric / HistoryMetric architectural split.
Currently the widget:
- Has hardcoded static metric lists (`GetDefaultMetrics()`, `GetDefaultAgentMetrics()`)
- Detects time metrics via fragile string matching on MetricId (e.g. `Contains("_time")`)
- Has stale comments referencing `RTSGrid_Metric` in `DayTrendQuery.cs`

After this task:
- Widget loads all available metrics from `history_metrics` (AppDbContext) on init
- Uses `HistoryMetric.ValueType == "time"` for time-metric rendering decisions
- Default-enables the same three interaction metrics as before
- Config modal shows all available metrics grouped by MetricType

**No changes to PostgreSQL functions or query handler** — they already return correct
`metric_id` values matching `HistoryMetric.MetricId`.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | `DayTrendMetricConfig` — add `ValueType` property | `DayTrendWidget.razor` |
| 2.2 | Load metrics from `AppDbContext.HistoryMetrics` on widget init | `DayTrendWidget.razor` |
| 2.3 | Replace `isTimeMetric` string-matching with `ValueType == "time"` | `DayTrendWidget.razor` |
| 2.4 | Fix comment in `DayTrendQuery.cs` | `DayTrendQuery.cs` |
| 2.5 | Update `docs/widget-specification.md` §1.3 and §1.4 | `docs/widget-specification.md` |
| 2.6 | Mark CC-006 Done in task index | `docs/backend-tasks.md` |

---

### 3. Step-by-step instructions

#### 3.1 Add `ValueType` to `DayTrendMetricConfig`

Find the `DayTrendMetricConfig` record in `DayTrendWidget.razor` and add `ValueType`:

```csharp
public record DayTrendMetricConfig(
    string MetricId,
    bool Enabled,
    string Color,
    string Label,
    string ValueType = "number");   // add this
```

#### 3.2 Load metrics from HistoryMetric on init

Inject `IDbContextFactory<AppDbContext>` (or scoped AppDbContext — whichever other widgets
in this project use; check existing widget injections first). Replace `GetDefaultMetrics()`
calls with a DB load on `OnInitializedAsync`:

```csharp
[Inject] private IDbContextFactory<AppDbContext> AppDbFactory { get; set; } = default!;

private static readonly HashSet<string> DefaultEnabledInteraction = new()
{
    "interaction.incoming_calls",
    "interaction.answered_calls",
    "interaction.abandoned_calls",
};

private static readonly Dictionary<string, string> DefaultColors = new()
{
    ["interaction.incoming_calls"]      = "#3b82f6",
    ["interaction.answered_calls"]      = "#22c55e",
    ["interaction.abandoned_calls"]     = "#ef4444",
    ["interaction.callback_requests"]   = "#f59e0b",
    ["interaction.completed_callbacks"] = "#8b5cf6",
    ["interaction.avg_wait_time"]       = "#06b6d4",
    ["interaction.max_wait_time"]       = "#0891b2",
    ["interaction.avg_talk_time"]       = "#64748b",
    ["statuslog.available_agents"]      = "#4ade80",
    ["statuslog.onphone_agents"]        = "#60a5fa",
    ["statuslog.break_agents"]          = "#fb923c",
    ["statuslog.paperwork_agents"]      = "#a78bfa",
    ["statuslog.training_agents"]       = "#94a3b8",
    ["statuslog.total_agents"]          = "#f1f5f9",
    ["statuslog.logged_in_agents"]      = "#fef08a",
    ["statuslog.available_time_ms"]     = "#86efac",
    ["statuslog.onphone_time_ms"]       = "#93c5fd",
    ["statuslog.break_time_ms"]         = "#fdba74",
    ["statuslog.paperwork_time_ms"]     = "#c4b5fd",
    ["statuslog.training_time_ms"]      = "#cbd5e1",
    ["statuslog.total_active_time_ms"]  = "#e2e8f0",
};

private async Task LoadMetricsFromDbAsync()
{
    await using var db = await AppDbFactory.CreateDbContextAsync();
    var allMetrics = await db.HistoryMetrics
        .AsNoTracking()
        .OrderBy(m => m.MetricId)
        .ToListAsync();

    var savedInteraction = Config.DayTrendMetrics?.ToDictionary(m => m.MetricId)
                           ?? new Dictionary<string, DayTrendMetricConfig>();
    var savedAgent = Config.DayTrendAgentMetrics?.ToDictionary(m => m.MetricId)
                     ?? new Dictionary<string, DayTrendMetricConfig>();

    _metrics = allMetrics
        .Where(m => m.MetricType == "Interaction")
        .Select(m => savedInteraction.TryGetValue(m.MetricId, out var saved)
            ? saved with { ValueType = m.ValueType }
            : new DayTrendMetricConfig(
                m.MetricId,
                Enabled: DefaultEnabledInteraction.Contains(m.MetricId),
                Color: DefaultColors.GetValueOrDefault(m.MetricId, "#64748b"),
                Label: m.Description,
                ValueType: m.ValueType))
        .ToList();

    _agentMetrics = allMetrics
        .Where(m => m.MetricType == "AgentStatusLog" || m.MetricType == "AgentStatus")
        .Select(m => savedAgent.TryGetValue(m.MetricId, out var saved)
            ? saved with { ValueType = m.ValueType }
            : new DayTrendMetricConfig(
                m.MetricId,
                Enabled: false,
                Color: DefaultColors.GetValueOrDefault(m.MetricId, "#64748b"),
                Label: m.Description,
                ValueType: m.ValueType))
        .ToList();

    Logger.LogInformation("DayTrendWidget: loaded {I} interaction + {A} agent metrics from history_metrics",
        _metrics.Count, _agentMetrics.Count);
}
```

Call `await LoadMetricsFromDbAsync()` inside `OnInitializedAsync()` before the existing
chart/data load. Remove the static `GetDefaultMetrics()` and `GetDefaultAgentMetrics()`
methods after confirming nothing else calls them.

> **Config property check:** If `Config.DayTrendAgentMetrics` does not exist on the config
> model, add it alongside `DayTrendMetrics`. Search the config class definition first.

#### 3.3 Replace `isTimeMetric` string matching (2 occurrences in `RenderChart`)

```csharp
// BEFORE — interaction metrics block
var isTimeMetric = metric.MetricId.Contains("_time") ||
                   metric.MetricId.Contains("_wait") ||
                   metric.MetricId.Contains("_talk");
// AFTER
var isTimeMetric = metric.ValueType == "time";

// BEFORE — agent metrics block
var isTimeMetric = metric.MetricId.Contains("_time_ms");
// AFTER
var isTimeMetric = metric.ValueType == "time";
```

#### 3.4 Fix comment in `DayTrendQuery.cs`

```csharp
// BEFORE
/// Per-interval grouped result. Keys are RTSGrid_Metric.MetricId strings.

// AFTER
/// Per-interval grouped result. Keys are HistoryMetric.MetricId strings
/// (dot-notation, e.g. "interaction.incoming_calls").
```

#### 3.5 Update `docs/widget-specification.md` §1.3 and §1.4

**§1.3** — rename heading and replace opening paragraph:
- `Metric catalogue — RTSGrid_Metric` → `Metric catalogue — HistoryMetric`
- Replace "Available metrics are defined in the `RTSGrid_Metric` table... via `GetRtsGridMetricsQuery`" with:
  > Available metrics for DayTrend are defined in the `history_metrics` table (`HistoryMetric`
  > entity, App context — cross-tenant, shell-owned).
  > The widget loads them via `AppDbContext.HistoryMetrics` filtered by `MetricType`:
  > interaction metrics (`MetricType = 'Interaction'`) and agent metrics
  > (`MetricType IN ('AgentStatusLog', 'AgentStatus')`).

**§1.4** — rename heading and fix C# snippet:
- `RTSGrid_Metric seed entries for DayTrend` → `HistoryMetric seed entries for DayTrend`
- `db.RtsGridMetrics` → `db.HistoryMetrics` (both occurrences in the code snippet)

---

### 4. Verification

```bash
# 1. Build clean
dotnet build CcDashboard.sln

# 2. Runtime checks (browser):
#    - DayTrend chart renders with incoming/answered/abandoned lines
#    - Time metrics (avg_wait_time, avg_talk_time) display as mm:ss, NOT raw float
#    - Config modal shows metrics loaded from DB (all 11 interaction + agent metrics)
#    - Toggling metrics re-renders chart
#    - No JS console errors

# 3. Log check: "DayTrendWidget: loaded 11 interaction + 18 agent metrics"
#    (18 = 13 AgentStatusLog + 5 AgentStatus)
```

*CC-006 written: 2026-05-27*

---

*Document created: 2026-05-26 | Last updated: 2026-05-27 | Current task: CC-007*

---

## CC-007

### Agent State Distribution — Real-Time BU Status Chart (Queue Grid)

**Status:** ✅ Done
**Priority:** 🟡 Medium
**Depends on:** CC-005 ✅ (RTSGrid_Metric seeding patterns), CC-006 ✅
**Spec reference:** `docs/widget-specification.md` §4 — read before starting
**Skill:** `.claude/skills/widget-creator/widget-creator.md` §15 (Queue Grid), §16 (Dark Mode), §17 (Header Colors), §18 (UI Guidelines), §19 (RTS Infrastructure), §21 (Config Modal), §22 (CC task template)

---

### 1. Background

Implement the **Agent State Distribution** widget — a real-time chart showing the
distribution of agents across status groups (AVAILABLE, ONPHONE, BREAK, PAPERWORK,
TRAINING) for a selected Business Unit. Rendered with Chart.js as a configurable
Pie / Donut / Bar / HorizontalBar chart.

Architecture: **Queue Grid** pattern (`SaveQueueGridRtsCommand`). The widget registers
6 fixed metrics as Grid columns and subscribes to the existing SignalR hub
(`ReceiveQueueGridData`). A 6th **OTHER** segment appears automatically when
`QueueLoginDataNumLoggedUsers > SUM(5 status groups)`.

Key properties:
- Single BU filter (one `BusinessUnitId` per widget instance)
- No columns tab — metric list is fixed (hardcoded in component)
- Chart type is user-configurable (Pie/Donut/Bar/HorizontalBar)
- Segment colours are user-configurable per status group
- Dark mode supported via `DarkMode` parameter (§16.4 widget-creator)

New database work required:
- One-time migration to add **TRAINING** metric to `RTSGrid_Metric` (does NOT touch `DatabaseInitializer.cs`)
- WidgetCatalogItem seed entry (in `DatabaseInitializer.cs`)

Full spec: `docs/widget-specification.md §4`.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | EF migration: add TRAINING metric to `RTSGrid_Metric` | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| 2.2 | `AgentStateDistributionConfig` record (ConfigJson shape) | `AgentStateDistributionWidget.razor` |
| 2.3 | `AgentStateDistributionWidget.razor` — full Blazor component | `src/CcDashboard.Web/Components/Widgets/` |
| 2.4 | `agentStateDistribution.js` — Chart.js JS interop | `src/CcDashboard.Web/wwwroot/js/widgets/` |
| 2.5 | WidgetCatalogItem seed entry | `src/CcDashboard.Infrastructure/Persistence/DatabaseInitializer.cs` |
| 2.6 | `SaveQueueGridRtsCommand` call on config save | inside `AgentStateDistributionWidget.razor` |
| 2.7 | `DeleteQueueGridRtsCommand` call on dispose | inside `AgentStateDistributionWidget.razor` |
| 2.8 | Widget registration in `WidgetFactory` / widget registry | `src/CcDashboard.Web/Components/Widgets/WidgetFactory.razor` (or equivalent) |
| 2.9 | Update task index row for CC-007 to ✅ Done | `docs/backend-tasks.md` |

---

### 3. Step-by-step instructions

> **Before writing any code:** read `.claude/skills/widget-creator/widget-creator.md`
> focusing on: §15 (Queue Grid patterns), §16 (Dark Mode), §17 (Header Colors),
> §18 (UI Guidelines), §19 (RTS Infrastructure), §21 (Config Modal Tabs).
> Then read `docs/widget-specification.md §4` in full.
>
> Check existing Queue Grid widgets (e.g. `QueueGridWidget.razor`) to confirm exact
> field names, injection pattern, and SignalR subscription call — copy their pattern exactly.

#### 3.1 Add TRAINING metric — one-time EF migration (BackendEmulation context)

Create migration named `AddTrainingRtsGridMetric`. **Do NOT add to `DatabaseInitializer.cs`** —
this follows the L-15 pattern (one-time migration for static reference data).

In `Up()`:

```csharp
migrationBuilder.Sql(
    @"INSERT INTO ""RTSGrid_Metric""
          (""MetricId"", ""Description"", ""MetricParameter"", ""CategoryName"",
           ""AggregationType"", ""FilterExpression"",
           ""MetricFormat"", ""DefaultValue"", ""DataType"", ""MetricType"")
      VALUES
          ('QueueLoginDataNumTrainingUsers',
           'Agent Group - Number of Agents in Training State Group',
           'TRAINING',
           'UsersSummary',
           'UsersInStatusGroupCount',
           '', '', 'String', 'Agent')
      ON CONFLICT (""MetricId"") DO NOTHING;");
```

Apply with:

```bash
dotnet ef database update --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

#### 3.2 Define `AgentStateDistributionConfig` record

Place at the top of `@code` in `AgentStateDistributionWidget.razor`:

```csharp
public record AgentStateDistributionConfig
{
    public string DisplayName    { get; init; } = "Agent State Distribution";
    public int    BusinessUnitId { get; init; } = 0;
    public string ChartType      { get; init; } = "doughnut"; // doughnut|pie|bar|horizontalBar
    public bool   ShowLegend      { get; init; } = true;
    public bool   ShowValueLabels { get; init; } = true;
    public string ValueDisplay    { get; init; } = "percentages"; // percentages | numbers
    public string BackgroundColor { get; init; } = "";
    public string FontColor       { get; init; } = "";
    public string FontSize        { get; init; } = "14";
    // Segment colours
    public string ColorAvailable { get; init; } = "#22c55e";
    public string ColorOnPhone   { get; init; } = "#3b82f6";
    public string ColorBreak     { get; init; } = "#f59e0b";
    public string ColorPaperwork { get; init; } = "#8b5cf6";
    public string ColorTraining  { get; init; } = "#94a3b8";
    public string ColorOther     { get; init; } = "#64748b";
}
```

#### 3.3 Component lifecycle — Queue Grid pattern (§15 widget-creator)

**Key fields:**

```csharp
private AgentStateDistributionConfig Config = new();
private AgentStateDistributionConfig _editConfig = new();
private int    _gridId = 0;
private Dictionary<string, string> _cellValues = new();
private bool   _configOpen  = false;
private bool   _saving      = false;
private string? _saveError  = null;
private string _elementId   = $"asd-{Guid.NewGuid():N}";
private List<NgcBusinessUnitDto> _availableBusinessUnits = [];
```

**`OnInitializedAsync`:**
1. Deserialize `WidgetInstance.ConfigJson` → `Config` (null-safe, fall back to `new()`)
2. If `Config.BusinessUnitId > 0`: call `await SaveQueueGridRts()`, then subscribe SignalR
3. If `Config.BusinessUnitId == 0`: show "Configure widget first" placeholder

**`SaveQueueGridRts` — register fixed metric columns:**

```csharp
private static readonly IReadOnlyList<string> FixedMetricIds = new[]
{
    "QueueLoginDataNumAvailableUsers",
    "QueueLoginDataNumOnPhoneUsers",
    "QueueLoginDataNumBreakUsers",
    "QueueLoginDataNumPaperworkUsers",
    "QueueLoginDataNumTrainingUsers",
    "QueueLoginDataNumLoggedUsers",
};

private async Task SaveQueueGridRts()
{
    var result = await Mediator.Send(new SaveQueueGridRtsCommand(
        TenantId:       TenantContext.TenantId,
        WidgetId:       WidgetInstance.Id,
        BusinessUnitId: Config.BusinessUnitId,
        MetricIds:      FixedMetricIds.ToList()));
    _gridId = result.GridId;
}
```

**SignalR — subscribe after `SaveQueueGridRts()`:**

```csharp
await HubConnection.SendAsync("SubscribeToGrid", _gridId);
HubConnection.On<QueueGridData>("ReceiveQueueGridData", OnGridData);
```

**OnGridData handler:**

```csharp
private Task OnGridData(QueueGridData data)
{
    if (data.GridId != _gridId) return Task.CompletedTask;
    var row = data.Rows.FirstOrDefault(r => r.UnionId == Config.BusinessUnitId);
    if (row is not null)
        _cellValues = row.Cells.ToDictionary(c => c.MetricId, c => c.Value ?? "0");
    InvokeAsync(async () => { StateHasChanged(); await RenderChartAsync(); });
    return Task.CompletedTask;
}
```

**IAsyncDisposable:**

```csharp
public async ValueTask DisposeAsync()
{
    if (_gridId > 0)
        await HubConnection.SendAsync("UnsubscribeFromGrid", _gridId);
    if (_gridId > 0 && Config.BusinessUnitId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(WidgetInstance.Id));
    await JSRuntime.InvokeVoidAsync("agentStateDistributionChart.destroy", _elementId);
}
```

#### 3.4 Chart.js JS interop — `agentStateDistribution.js`

Create `src/CcDashboard.Web/wwwroot/js/widgets/agentStateDistribution.js`:

```javascript
window.agentStateDistributionChart = {
    _charts: {},

    render: function (elementId, cfg) {
        const ctx = document.getElementById(elementId);
        if (!ctx) return;
        if (this._charts[elementId]) { this._charts[elementId].destroy(); }

        const isPolar  = cfg.chartType === 'pie' || cfg.chartType === 'doughnut';
        const type     = cfg.chartType === 'horizontalBar' ? 'bar' : cfg.chartType;
        const indexAxis = cfg.chartType === 'horizontalBar' ? 'y' : 'x';
        const textColor = cfg.darkMode ? '#d1d5db' : '#374151';
        const gridColor = cfg.darkMode ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)';

        this._charts[elementId] = new Chart(ctx, {
            type: type,
            data: {
                labels: cfg.labels,
                datasets: [{
                    data:            cfg.data,
                    backgroundColor: cfg.colors,
                    borderWidth:     1,
                    borderColor:     cfg.darkMode ? '#1f2937' : '#ffffff',
                }]
            },
            options: {
                indexAxis: indexAxis,
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display:  cfg.showLegend,
                        position: 'bottom',
                        labels:   { color: textColor, font: { size: parseInt(cfg.fontSize) || 13 } }
                    },
                },
                scales: isPolar ? {} : {
                    x: { grid: { color: gridColor }, ticks: { color: textColor } },
                    y: { grid: { color: gridColor }, ticks: { color: textColor } }
                }
            }
        });
    },

    destroy: function (elementId) {
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
    }
};
```

Add script reference in `App.razor` (or `_Layout.cshtml`) after existing widget JS:

```html
<script src="js/widgets/agentStateDistribution.js"></script>
```

Chart.js is already loaded for DayTrend — **do not add a second Chart.js script tag**.

#### 3.5 Data extraction + OTHER segment logic

```csharp
private int GetVal(string metricId)
    => int.TryParse(_cellValues.GetValueOrDefault(metricId, "0"), out var v) ? v : 0;

private (string[] Labels, int[] Values, string[] Colors) GetChartData()
{
    int available = GetVal("QueueLoginDataNumAvailableUsers");
    int onPhone   = GetVal("QueueLoginDataNumOnPhoneUsers");
    int onBreak   = GetVal("QueueLoginDataNumBreakUsers");
    int paperwork = GetVal("QueueLoginDataNumPaperworkUsers");
    int training  = GetVal("QueueLoginDataNumTrainingUsers");
    int loggedIn  = GetVal("QueueLoginDataNumLoggedUsers");
    int other     = Math.Max(0, loggedIn - (available + onPhone + onBreak + paperwork + training));

    var labels = new List<string> { "Available", "On Phone", "Break", "Paperwork", "Training" };
    var values = new List<int>    { available, onPhone, onBreak, paperwork, training };
    var colors = new List<string> {
        Config.ColorAvailable, Config.ColorOnPhone, Config.ColorBreak,
        Config.ColorPaperwork, Config.ColorTraining
    };
    if (other > 0) { labels.Add("Other"); values.Add(other); colors.Add(Config.ColorOther); }

    return (labels.ToArray(), values.ToArray(), colors.ToArray());
}

private async Task RenderChartAsync()
{
    var (labels, values, colors) = GetChartData();
    await JSRuntime.InvokeVoidAsync("agentStateDistributionChart.render", _elementId, new {
        chartType  = Config.ChartType,
        labels     = labels,
        data       = values,
        colors     = colors,
        showLegend      = Config.ShowLegend,
        showValueLabels = Config.ShowValueLabels,
        valueDisplay    = Config.ValueDisplay,   // "percentages" | "numbers"
        darkMode        = DarkMode,
        fontSize        = Config.FontSize,
    });
}
```

**Render states (in markup):**

```razor
@if (Config.BusinessUnitId == 0)
{
    <!-- @L["Widget.ConfigureFirst"] or existing equivalent — §13 widget-creator pattern -->
}
else if (_cellValues.Count == 0)
{
    <!-- Loading spinner (no text label needed) -->
}
else if (GetVal("QueueLoginDataNumLoggedUsers") == 0)
{
    <!-- @L["Widget.NoAgentsLoggedIn"] or existing equivalent -->
}
else
{
    <div style="position:relative; height:100%;">
        <canvas id="@_elementId"></canvas>
    </div>
}
```

#### 3.6 Dark mode (§16.4 widget-creator)

```csharp
[Parameter] public bool DarkMode { get; set; }

private string EffectiveBg   => string.IsNullOrEmpty(Config.BackgroundColor)
    ? (DarkMode ? "var(--widget-bg-dark)"   : "var(--widget-bg-light)")
    : Config.BackgroundColor;

private string EffectiveFont => string.IsNullOrEmpty(Config.FontColor)
    ? (DarkMode ? "var(--widget-text-dark)" : "var(--widget-text-light)")
    : Config.FontColor;
```

Apply on widget root: `style="background:@EffectiveBg; color:@EffectiveFont;"`.

Call `await RenderChartAsync()` in `OnParametersSetAsync()` when `DarkMode` changes.

#### 3.7 Config modal — two tabs (§21 widget-creator)

Follow §21 for modal shell. Two tabs: **General** and **Appearance**.

**General tab:**

| Field | Control | Bound to |
|---|---|---|
| Display name | `<input type="text">` | `_editConfig.DisplayName` |
| Business Unit | `<select>` (from `_availableBusinessUnits`) | `_editConfig.BusinessUnitId` |
| Chart type | `<select>`: Donut / Pie / Bar / Horizontal Bar | `_editConfig.ChartType` |
| Value display | radio / segmented control: **Percentages** / **Numbers** | `_editConfig.ValueDisplay` |
| Show legend | `<input type="checkbox">` | `_editConfig.ShowLegend` |
| Show value labels | `<input type="checkbox">` | `_editConfig.ShowValueLabels` |

Load BU list on modal open — use the same `NgcBusinessUnits` query pattern as other Queue Grid widgets.

**Appearance tab:**

| Field | Control | Bound to |
|---|---|---|
| Background colour | `<input type="color">` | `_editConfig.BackgroundColor` |
| Font colour | `<input type="color">` | `_editConfig.FontColor` |
| Font size | `<select>` (tenant font sizes) | `_editConfig.FontSize` |
| Available colour | `<input type="color">` | `_editConfig.ColorAvailable` |
| On Phone colour | `<input type="color">` | `_editConfig.ColorOnPhone` |
| Break colour | `<input type="color">` | `_editConfig.ColorBreak` |
| Paperwork colour | `<input type="color">` | `_editConfig.ColorPaperwork` |
| Training colour | `<input type="color">` | `_editConfig.ColorTraining` |
| Other colour | `<input type="color">` | `_editConfig.ColorOther` |

> **Localization in the modal:** use `@L["Key"]` for all visible labels (tab names,
> field labels, placeholder text, button text). Check existing keys in `SharedResources.resx`
> (and locale variants) **before** adding new ones. Common keys that likely already exist:
> `L["General"]`, `L["Appearance"]`, `L["Save"]`, `L["Cancel"]`, `L["DisplayName"]`.
> For widget-specific labels ("Chart Type", "Value Display", "Business Unit", "Show Legend",
> segment colour names) — check first, add only if no suitable key exists.
>
> Segment labels passed to Chart.js (`"Available"`, `"On Phone"`, etc.) are **not** localized — platform-standard English terms.

**Save handler:**

```csharp
private async Task SaveConfig()
{
    _saving = true; _saveError = null;
    try
    {
        Config = _editConfig with {};
        var json = JsonSerializer.Serialize(Config);
        await Mediator.Send(new UpdateWidgetConfigCommand(WidgetInstance.Id, json));
        if (Config.BusinessUnitId > 0)
            await SaveQueueGridRts();
        _configOpen = false;
        await RenderChartAsync();
    }
    catch (Exception ex) { _saveError = ex.Message; }
    finally { _saving = false; }
}
```

#### 3.8 WidgetCatalogItem seed (DatabaseInitializer.cs)

In the `SeedWidgetCatalogAsync` method, add:

```csharp
new WidgetCatalogItem
{
    Id          = new Guid("a4d1e3f7-2b8c-4e9a-b1d5-6f3c2a7e0d11"),
    Category    = "Agents",
    Name        = "Agent State Distribution",
    Description = "Real-time pie/donut/bar chart showing agent distribution across " +
                  "status groups (Available, On Phone, Break, Paperwork, Training) " +
                  "for a selected Business Unit.",
    IconUrl     = "/icons/widgets/agent-state-distribution.svg",
    IsActive    = true
},
```

#### 3.9 Register in WidgetFactory

Search for `QueueGridWidget` in the project to find where widgets are registered.
Add `AgentStateDistributionWidget` with key `"AgentStateDistribution"` (or the enum/string
value used in `WidgetCatalogItem.Name` — match whatever the factory uses as lookup key).

---

### 4. Verification

```bash
# 1. Build clean
dotnet build CcDashboard.sln

# 2. Apply BackendEmulation migration:
dotnet ef database update --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# 3. Verify TRAINING metric exists:
#    SELECT "MetricId", "MetricParameter" FROM "RTSGrid_Metric"
#    WHERE "MetricId" = 'QueueLoginDataNumTrainingUsers';
#    → 1 row

# 4. Runtime checks (browser):
#    a) Add "Agent State Distribution" widget to a dashboard
#    b) Before config: shows "Configure widget first" state
#    c) Open config → select BU → save → doughnut chart renders
#    d) Switch chart type → Pie / Bar / HorizontalBar renders correctly
#    e) OTHER segment appears when loggedIn > sum(5 groups)
#    f) Colour pickers persist and apply to segments after save
#    g) Toggle dark mode on dashboard → chart background/text updates
#    h) Remove widget from dashboard → no JS console errors (canvas destroyed)
#    i) No SignalR subscription errors in browser console or server log
```

---

*CC-007 written: 2026-05-27*

---

## CC-008

### Agent State Definitions — Dynamic State Group Registry + Widget Refactor

**Status:** ✅ Done
**Priority:** 🟡 Medium
**Depends on:** CC-007 ✅
**Commit:** `5de22a6` (entities, migration, seed), `9b4b3f7` (queries, commands, handlers, UI)
**Spec reference:** `docs/widget-specification.md` §5 — read before starting
**Related:** `docs/widget-specification.md` §4.10 §5.6 — widget refactor details

---

### 1. Background

Currently `AgentStateDistributionWidget` uses a hardcoded list of 5 MetricIds and 5 fixed colour fields in its config. This task introduces a proper normalized registry that allows Superadmin to add new CC-platform states and groups through the UI — no code change needed afterward.

Three new shell tables:
- `tenant_agent_states` — raw CC-platform state names per tenant
- `tenant_agent_state_groups` — display group names per tenant
- `tenant_agent_state_definitions` — junction: one State → one Group

New "Agent States" tab in Edit Tenant modal (Superadmin only).

Widget refactor: `FixedMetricIds` replaced by dynamic DB query; segment colours become a `Dictionary<string, string>` keyed by `GroupName`.

Full spec: `docs/widget-specification.md §5`.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | EF entities: `AgentState`, `AgentStateGroup`, `AgentStateDefinition` + configurations | `CcDashboard.Infrastructure/Persistence/Configurations/` |
| 2.2 | App migration: create 3 tables | `CcDashboard.Infrastructure/Migrations/App/` |
| 2.3 | Seed 5 standard definitions for all existing tenants | `DatabaseInitializer.cs` |
| 2.4 | `GetAgentStateDefinitionsQuery` + handler (returns MetricId via RTSGrid_Metric join) | `CcDashboard.Application/Queries/` |
| 2.5 | `CreateAgentStateGroupCommand`, `DeactivateAgentStateGroupCommand` (with Reassign/DeactivateAll option) | `CcDashboard.Application/Commands/` |
| 2.6 | `CreateAgentStateCommand`, `DeactivateAgentStateCommand` | `CcDashboard.Application/Commands/` |
| 2.7 | "Agent States" tab in Edit Tenant modal | `CcDashboard.Web/Components/Admin/` |
| 2.8 | `AgentStateDistributionWidget.razor` refactor — dynamic MetricIds + colour dict | `CcDashboard.Web/Components/Widgets/` |
| 2.9 | ConfigJson backward compat (legacy colour fields → dict) | inside widget |
| 2.10 | Update CLAUDE.md §6 — add 3 new entities to data model | `CLAUDE.md` |
| 2.11 | Update task index (CC-008 → ✅ Done) | `docs/backend-tasks.md` |

---

### 3. Step-by-step instructions

#### 3.1 EF Entities

**`AgentState`** (`tenant_agent_states`):
```csharp
public class AgentState : IAuditableEntity
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string AgentStateName { get; set; } = "";   // column: AgentState
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Tenant Tenant { get; set; } = null!;
    public AgentStateDefinition? Definition { get; set; }
}
```

**`AgentStateGroup`** (`tenant_agent_state_groups`):
```csharp
public class AgentStateGroup : IAuditableEntity
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string GroupName { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Tenant Tenant { get; set; } = null!;
    public ICollection<AgentStateDefinition> Definitions { get; set; } = [];
}
```

**`AgentStateDefinition`** (`tenant_agent_state_definitions`):
```csharp
public class AgentStateDefinition : IAuditableEntity
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid AgentStateId { get; set; }
    public Guid AgentStateGroupId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public AgentState State { get; set; } = null!;
    public AgentStateGroup Group { get; set; } = null!;
}
```

**`IEntityTypeConfiguration`** for each — apply GQF (`TenantId`), unique indexes, CASCADE delete on FK. See `docs/widget-specification.md §5.2` for full index list.

#### 3.2 Migration

```bash
dotnet ef migrations add AddAgentStateRegistry \
  --context AppDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

#### 3.3 Seed data (DatabaseInitializer)

In `SeedAgentStateDefinitionsAsync` — called from `InitializeAsync`. Idempotent:

```csharp
private static readonly (string State, string Group)[] StandardDefinitions =
[
    ("AVAILABLE", "Available"),
    ("ONPHONE",   "On Phone"),
    ("BREAK",     "Break"),
    ("PAPERWORK", "Paperwork"),
    ("TRAINING",  "Training"),
];

// For each active tenant: upsert State, Group, Definition
// Use ON CONFLICT DO NOTHING pattern (check existing before insert)
```

#### 3.4 `GetAgentStateDefinitionsQuery`

Returns active definitions with MetricId resolved from `RTSGrid_Metric`:

```csharp
public record AgentStateDefinitionDto(
    Guid StateId,
    string AgentState,
    Guid GroupId,
    string GroupName,
    string MetricId);       // from RTSGrid_Metric.MetricId where MetricParameter = AgentState

public record GetAgentStateDefinitionsQuery : IRequest<IReadOnlyList<AgentStateDefinitionDto>>;
```

Handler joins `tenant_agent_state_definitions` → `tenant_agent_states` → `tenant_agent_state_groups` → `RTSGrid_Metric` (cross-tenant, no GQF on RTSGrid_Metric). Filter: `d.IsActive && s.IsActive && g.IsActive`. Order: `GroupName, AgentState`.

#### 3.5 Commands

**`CreateAgentStateGroupCommand(string GroupName)`**
- Validate: GroupName unique in tenant (case-insensitive)
- Insert `tenant_agent_state_groups`

**`DeactivateAgentStateGroupCommand(Guid GroupId, DeactivateGroupAction action, Guid? ReassignToGroupId)`**
```csharp
public enum DeactivateGroupAction { ReassignStates, DeactivateAllStates }
```
- If `ReassignStates`: update all active `AgentStateDefinition.AgentStateGroupId` = `ReassignToGroupId`
- If `DeactivateAllStates`: set `IsActive = false` on all definitions + their AgentStates for this group
- Then set `AgentStateGroup.IsActive = false`
- Wrap in transaction

**`CreateAgentStateCommand(string AgentStateName, Guid GroupId)`**
- Validate: AgentStateName unique in tenant
- Insert `tenant_agent_states` + `tenant_agent_state_definitions`

**`DeactivateAgentStateCommand(Guid StateId)`**
- Set `AgentState.IsActive = false`
- Set matching `AgentStateDefinition.IsActive = false`

#### 3.6 "Agent States" tab in Edit Tenant modal

Add tab button "Agent States" alongside General / Settings / Appearance.
Tab is hidden unless `CurrentUser.Role == Superadmin`.

**Section 1 — State Groups:**

Table: GroupName | Status badge | Edit button | Deactivate button

- **Edit**: inline rename input + Save
- **Deactivate** (Danger Zone, red button):
  - Confirmation modal: "Deactivating group '{name}'. Choose what to do with its states:"
  - Radio: **Reassign to group** [dropdown of other active groups] / **Deactivate all states**
  - "Confirm deactivation →" button (disabled until choice made)

Button: `+ Add State Group` → input for GroupName → Save

**Section 2 — Agent States:**

Table: AgentState | Mapped Group | Status badge | Edit button | Deactivate button

- **Edit**: change mapped group via dropdown of active groups
- **Deactivate** (Danger Zone):
  - Confirmation: "Deactivating state '{name}'. It will no longer appear in widgets."
  - "Confirm →" button

Button: `+ Add State` → AgentState text input + Group dropdown (active groups) → Save

**Validation messages** (use `@L["Key"]`):
- AgentState already exists in this tenant
- GroupName already exists in this tenant
- Must select a target group when reassigning

All labels, headings, buttons: `@L["Key"]` — check existing keys first.

#### 3.7 `AgentStateDistributionWidget` refactor

**Remove:**
- `FixedMetricIds` static list
- `ColorAvailable`, `ColorOnPhone`, `ColorBreak`, `ColorPaperwork`, `ColorTraining`, `ColorOther` properties from `AgentStateDistributionConfig`

**Add to `AgentStateDistributionConfig`:**
```csharp
public Dictionary<string, string> SegmentColors     { get; init; } = new();
public Dictionary<string, string> DarkSegmentColors { get; init; } = new();
```

Default colours (applied when key missing from dict):
```csharp
private static readonly Dictionary<string, string> FallbackColors = new()
{
    ["Available"] = "#22c55e", ["On Phone"] = "#3b82f6",
    ["Break"]     = "#f59e0b", ["Paperwork"] = "#8b5cf6",
    ["Training"]  = "#06b6d4", ["Other"]     = "#6b7280",
};
```

**`OnInitializedAsync`:**
```csharp
_definitions = await Mediator.Send(new GetAgentStateDefinitionsQuery());
var metricIds = _definitions.Select(d => d.MetricId).ToList();
if (Config.BusinessUnitId > 0)
    await SaveQueueGridRts(metricIds);
```

**`GetChartData()`:**
```csharp
var groups = _definitions
    .GroupBy(d => d.GroupName)
    .OrderBy(g => g.Key);

foreach (var group in groups)
{
    var value = group.Sum(d => GetVal(d.MetricId));
    labels.Add(group.Key);
    values.Add(value);
    colors.Add(Config.SegmentColors.GetValueOrDefault(group.Key,
               FallbackColors.GetValueOrDefault(group.Key, "#64748b")));
}
// OTHER segment unchanged
```

**Config modal Appearance — colour pickers:**

Generate dynamically from loaded groups:
```razor
@foreach (var group in _definitions.Select(d => d.GroupName).Distinct().OrderBy(x => x))
{
    <div class="mb-2">
        <label>@group</label>
        <input type="color" @bind="_editConfig.SegmentColors[group]" />
    </div>
}
```

**Backward compat on config load:**

```csharp
private AgentStateDistributionConfig MigrateConfig(AgentStateDistributionConfig cfg)
{
    // If SegmentColors is empty but legacy fields exist in raw JSON, convert them
    if (cfg.SegmentColors.Count == 0)
    {
        var legacy = new Dictionary<string, string>
        {
            ["Available"] = cfg.ColorAvailable ?? "#22c55e",
            ["On Phone"]  = cfg.ColorOnPhone   ?? "#3b82f6",
            ["Break"]     = cfg.ColorBreak      ?? "#f59e0b",
            ["Paperwork"] = cfg.ColorPaperwork  ?? "#8b5cf6",
            ["Training"]  = cfg.ColorTraining   ?? "#06b6d4",
            ["Other"]     = cfg.ColorOther      ?? "#6b7280",
        };
        return cfg with { SegmentColors = legacy };
    }
    return cfg;
}
```

> **Note:** `ColorAvailable` etc. are no longer in `AgentStateDistributionConfig` after this refactor. Deserialize raw JSON to `JsonDocument` first to extract legacy fields, then build the new config. Or keep the old properties as `[JsonIgnore(Condition = WhenWritingNull)]` `[Obsolete]` for one version.

---

### 4. Verification

```bash
# 1. Build clean
dotnet build CcDashboard.sln

# 2. Apply migration
dotnet ef database update --context AppDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# 3. Verify seed:
#    SELECT s."AgentState", g."GroupName"
#    FROM tenant_agent_state_definitions d
#    JOIN tenant_agent_states s ON s."Id" = d."AgentStateId"
#    JOIN tenant_agent_state_groups g ON g."Id" = d."AgentStateGroupId"
#    WHERE d."TenantId" = '<any tenant id>';
#    → 5 rows: AVAILABLE/Available, ONPHONE/On Phone, BREAK/Break,
#              PAPERWORK/Paperwork, TRAINING/Training

# 4. UI checks (browser, logged in as Superadmin):
#    a) Tenants → Edit → "Agent States" tab visible
#    b) 5 seeded states and groups shown
#    c) "+ Add State Group" → create "Lunch" group → appears in list
#    d) "+ Add State" → "LUNCH" mapped to "Lunch" → appears in states list
#    e) Deactivate state → confirmation shown → state marked inactive
#    f) Deactivate group with states → dialog shows Reassign / Deactivate All
#    g) Reassign: states move to selected group
#    h) "Agent States" tab NOT visible when logged in as Administrator

# 5. Widget checks (AgentStateDistributionWidget after CC-007):
#    a) Widget loads segments from DB (not hardcoded)
#    b) Adding LUNCH state → widget shows "Lunch" segment after config re-save
#    c) Old saved ConfigJson with colorAvailable field → migrated to SegmentColors dict
#    d) No JS errors; chart re-renders after definition change
```

---

*CC-008 written: 2026-05-28*

---

## CC-009

### ASD Widget — Dual Distribution Mode (By Group / By State)

**Status:** 🔲 Ready
**Priority:** 🟡 Medium
**Depends on:** CC-008 ✅
**Spec reference:** `docs/widget-specification.md` §4 v1.6 — read **in full** before starting (§4.1, §4.3–§4.7, §4.10)
**Skill:** `.claude/skills/widget-creator/widget-creator.md` — read §15 (Queue Grid), §16 (Dark Mode), §19 (RTS Infrastructure), §21 (Config Modal) before implementing

---

### Context

CC-008 implemented the ASD widget with **By Group mode only** (fixed 5 groups: AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING). CC-009 extends it with **By State mode**, where each individual Agent State (e.g. Available, Short Break, Lunch, Coffee Break) is its own segment.

Key architectural decisions (from spec §4.10):
- **Two independent RTSGrids**: `GroupGridId` (existing, now renamed) + `StateGridId` (new)
- **Both grids saved on every config save**, deleted together on widget delete
- **No junction table** (`tenant_agent_state_definitions` not touched)
- **Color dicts are independent**: `segmentColors` (By Group, keyed by GroupName CC code) and `stateSegmentColors` (By State, keyed by AgentStateName)
- **MetricId resolution at save time**: stored in `GroupColumnMetricIds` / `StateColumnMetricIds` — zero DB calls at render time

---

### 1. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 1.1 | `AgentStateDistributionConfig` — new fields | `src/CcDashboard.Application/Queries/Widgets/AgentStateDistributionConfig.cs` (or wherever config is defined) |
| 1.2 | `SaveAsdWidgetConfigCommandHandler` — dual-grid save | `src/CcDashboard.Infrastructure/Handlers/` |
| 1.3 | `AgentStateDistributionWidget.razor` — mode switching, dynamic segments | `src/CcDashboard.Web/Components/Dashboard/Widgets/` |
| 1.4 | `ScreenEditorPage.razor` — config modal: Distribution Mode + dynamic Segment Colors | `src/CcDashboard.Web/Components/Dashboard/` |
| 1.5 | Simulator: verify both grids produce data | `tools/SignalRSimulator/` |

---

### 2. Changes in Detail

#### 2.1 `AgentStateDistributionConfig` record changes

Add these fields to the existing config record. **Keep all existing fields for backward compatibility** (old ConfigJson must still deserialize).

```csharp
// NEW fields — add alongside existing ones
public string DistributionMode { get; set; } = "group"; // "group" | "state"

// Rename existing GridId/RtsGridId fields → GroupGridId (or add GroupGridId as alias)
public int GroupGridId { get; set; }
public int GroupRtsHeaderRowId { get; set; }
public int GroupRtsDataRowId { get; set; }
public Dictionary<string, int> GroupRtsColumnIds { get; set; } = new();
public Dictionary<string, int> GroupRtsHeaderCellIds { get; set; } = new();
public Dictionary<string, int> GroupRtsDataCellIds { get; set; } = new();
// MetricId map for render time (GroupName → MetricId)
public Dictionary<string, string> GroupColumnMetricIds { get; set; } = new();

// NEW: By State grid
public int StateGridId { get; set; }
public int StateRtsHeaderRowId { get; set; }
public int StateRtsDataRowId { get; set; }
public Dictionary<string, int> StateRtsColumnIds { get; set; } = new();
public Dictionary<string, int> StateRtsHeaderCellIds { get; set; } = new();
public Dictionary<string, int> StateRtsDataCellIds { get; set; } = new();
// MetricId map for render time (AgentStateName → MetricId)
public Dictionary<string, string> StateColumnMetricIds { get; set; } = new();

// NEW: Segment colors keyed by GroupName CC code (e.g. "AVAILABLE", "BREAK")
// Replaces the existing lowercased keys ("available", "break") — migrate on load (§4.10 note 9)
// segmentColors and darkSegmentColors already exist — only key format changes

// NEW: By State segment colors keyed by AgentStateName (e.g. "Available", "Short Break")
public Dictionary<string, string> StateSegmentColors { get; set; } = new();
public Dictionary<string, string> DarkStateSegmentColors { get; set; } = new();
```

**Legacy migration** (apply in the config constructor or a static `Migrate()` helper — call it in `SaveWidgetConfigCommandHandler` before using the config):

```csharp
public static AgentStateDistributionConfig Migrate(AgentStateDistributionConfig cfg)
{
    // Remap lowercased group color keys → uppercase CC codes
    var keyMap = new Dictionary<string, string>
    {
        ["available"] = "AVAILABLE", ["onphone"] = "ONPHONE", ["break"] = "BREAK",
        ["paperwork"] = "PAPERWORK", ["training"] = "TRAINING", ["other"] = "OTHER"
    };
    if (cfg.SegmentColors.Keys.Any(k => k == k.ToLower()))
    {
        cfg = cfg with
        {
            SegmentColors = cfg.SegmentColors
                .ToDictionary(kv => keyMap.GetValueOrDefault(kv.Key, kv.Key), kv => kv.Value),
            DarkSegmentColors = cfg.DarkSegmentColors
                .ToDictionary(kv => keyMap.GetValueOrDefault(kv.Key, kv.Key), kv => kv.Value)
        };
    }
    // Migrate old single-GridId field → GroupGridId if GroupGridId == 0
    if (cfg.GroupGridId == 0 && cfg.GridId > 0)
        cfg = cfg with { GroupGridId = cfg.GridId };
    return cfg;
}
```

Keep `GridId` as an `[Obsolete]` property (read-only, maps to GroupGridId) so old ConfigJson still deserializes.

---

#### 2.2 Save handler — dual-grid logic

In `SaveAsdWidgetConfigCommandHandler` (or wherever the ASD config save is wired):

```csharp
// 1. Migrate legacy config
config = AgentStateDistributionConfig.Migrate(config);

// 2. Fetch By Group data
var groups = await mediator.Send(new GetAgentStateGroupsQuery(tenantId), ct);
// Resolve MetricIds for By Group
var groupMetricIds = await ResolveMetricIdsAsync(
    beDb, "UsersInStatusGroupCount",
    groups.Select(g => g.GroupName).ToList(), ct);

// 3. Fetch By State data
var states = await mediator.Send(new GetAgentStatesQuery(tenantId), ct);
// Resolve MetricIds for By State
var stateMetricIds = await ResolveMetricIdsAsync(
    beDb, "UsersInStatusCount",
    states.Where(s => s.IsActive).Select(s => s.AgentStateName).ToList(), ct);

// 4. Build columns for By Group Grid
var groupColumns = groups
    .Where(g => g.IsActive && groupMetricIds.ContainsKey(g.GroupName))
    .Select((g, i) => new RtsColumn(i + 1, groupMetricIds[g.GroupName], g.GroupName))
    .Append(new RtsColumn(groups.Count + 1, "QueueLoginDataNumLoggedUsers", "Total"))
    .ToList();

// 5. Build columns for By State Grid
var stateColumns = states
    .Where(s => s.IsActive && stateMetricIds.ContainsKey(s.AgentStateName))
    .Select((s, i) => new RtsColumn(i + 1, stateMetricIds[s.AgentStateName], s.AgentStateName))
    .Append(new RtsColumn(states.Count + 1, "QueueLoginDataNumLoggedUsers", "Total"))
    .ToList();

// 6. Save By Group RTSGrid (SaveQueueGridRtsCommand)
var groupGridResult = await mediator.Send(new SaveQueueGridRtsCommand(
    config.GroupGridId, config.BusinessUnitId, groupColumns,
    config.GroupRtsHeaderRowId, config.GroupRtsDataRowId,
    config.GroupRtsColumnIds, config.GroupRtsHeaderCellIds, config.GroupRtsDataCellIds), ct);

// 7. Save By State RTSGrid
var stateGridResult = await mediator.Send(new SaveQueueGridRtsCommand(
    config.StateGridId, config.BusinessUnitId, stateColumns,
    config.StateRtsHeaderRowId, config.StateRtsDataRowId,
    config.StateRtsColumnIds, config.StateRtsHeaderCellIds, config.StateRtsDataCellIds), ct);

// 8. Store MetricId maps and updated RTS IDs in config
config = config with
{
    GroupColumnMetricIds = groupMetricIds,
    StateColumnMetricIds = stateMetricIds,
    // ... update GroupGridId, StateGridId, RowIds, ColumnIds, CellIds from results
};
```

**`ResolveMetricIdsAsync` helper:**

```csharp
private static async Task<Dictionary<string, string>> ResolveMetricIdsAsync(
    BackendEmulationDbContext beDb, string metricFunction,
    IReadOnlyList<string> parameters, CancellationToken ct)
{
    var rows = await beDb.RtsGridMetrics
        .Where(m => m.MetricFunction == metricFunction && parameters.Contains(m.MetricParameter!))
        .Select(m => new { m.MetricParameter, m.MetricId })
        .ToListAsync(ct);

    return rows
        .GroupBy(r => r.MetricParameter!)
        .ToDictionary(g => g.Key, g => g.First().MetricId);
}
```

---

#### 2.3 `AgentStateDistributionWidget.razor` changes

**Property for hub URL (mode-switched):**

```csharp
private int RtsGridId => Config?.DistributionMode == "state"
    ? (Config?.StateGridId ?? GridId)
    : (Config?.GroupGridId ?? GridId);

private string HubUrl => $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";
```

**When `DistributionMode` parameter changes** (via `SetParametersAsync` or `OnParametersSetAsync`): if the mode changed, disconnect current hub and reconnect with new `RtsGridId`.

**Segment list (built once from config, no DB calls):**

```csharp
private List<SegmentDef> _segmentDefs = new();

private record SegmentDef(string DisplayName, string MetricId, string LightColor, string DarkColor);

private void LoadSegmentDefs()
{
    _segmentDefs = Config?.DistributionMode == "state"
        ? BuildSegmentDefs(
            Config.StateColumnMetricIds,
            Config.StateSegmentColors,
            Config.DarkStateSegmentColors)
        : BuildSegmentDefs(
            Config?.GroupColumnMetricIds ?? new(),
            Config?.SegmentColors ?? new(),
            Config?.DarkSegmentColors ?? new());
}

private static List<SegmentDef> BuildSegmentDefs(
    Dictionary<string, string> metricIds,
    Dictionary<string, string> lightColors,
    Dictionary<string, string> darkColors)
{
    return metricIds
        .Where(kv => kv.Key != "Total")   // exclude Total column
        .Select(kv => new SegmentDef(
            kv.Key,
            kv.Value,
            lightColors.GetValueOrDefault(kv.Key, DefaultPaletteColor(kv.Key, false)),
            darkColors.GetValueOrDefault(kv.Key, DefaultPaletteColor(kv.Key, true))
        ))
        .ToList();
}
```

Call `LoadSegmentDefs()` in `OnParametersSetAsync` whenever config or mode changes.

**UpdateChartData** — use `_segmentDefs` (see spec §4.5 for full code).

**Delete / Dispose (widget component):**

```csharp
public async ValueTask DisposeAsync()
{
    _cts.Cancel();
    if (_hub != null)
    {
        try { await _hub.DisposeAsync(); } catch { /* ignore */ }
    }
    _cts.Dispose();
    await jsRuntime.InvokeVoidAsync("agentStateDistributionChart.destroy", elementId);
    // NOTE: RTSGrid cleanup is NOT done here — it is deferred to ScreenEditorPage.razor
    // save flow (WidgetsPendingRtsDeletion pattern). See L-26 in widget-planner.md.
}
```

**Delete / ScreenEditorPage.razor (3 mandatory places — see L-26 in widget-planner.md):**

Update all three places to use `GroupGridId` + `StateGridId` (replacing the CC-008 single `GridId`):

```csharp
// Place 1 & 2 — dialog warning + ConfirmDeleteWidget condition:
(IsAgentStateDistributionWidget(widget) &&
    (widget.Config?.GroupGridId > 0 || widget.Config?.StateGridId > 0))

// Place 3 — save loop:
else if (IsAgentStateDistributionWidget(widget))
{
    if (widget.Config?.GroupGridId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(widget.Config.GroupGridId.Value), _cts.Token);
    if (widget.Config?.StateGridId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(widget.Config.StateGridId.Value), _cts.Token);
    // Legacy fallback: single GridId (CC-008 config, before GroupGridId migration)
    if (widget.Config?.GroupGridId == 0 && widget.Config?.GridId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(widget.Config.GridId.Value), _cts.Token);
}
```

---

#### 2.4 Config modal in `ScreenEditorPage.razor`

**Loading (when ASD config modal opens):**

```csharp
// Load both lists regardless of current mode
_asdGroups = await mediator.Send(new GetAgentStateGroupsQuery(), ct);   // Status Groups
_asdStates = await mediator.Send(new GetAgentStatesQuery(), ct);         // Agent States

// Pre-fill missing group colors with defaults
foreach (var g in _asdGroups.Where(g => g.IsActive))
{
    if (!ConfigAsd.SegmentColors.ContainsKey(g.GroupName))
        ConfigAsd.SegmentColors[g.GroupName] = DefaultGroupColor(g.GroupName, dark: false);
    if (!ConfigAsd.DarkSegmentColors.ContainsKey(g.GroupName))
        ConfigAsd.DarkSegmentColors[g.GroupName] = DefaultGroupColor(g.GroupName, dark: true);
}
// Pre-fill missing state colors with palette defaults
foreach (var (s, i) in _asdStates.Where(s => s.IsActive).Select((s, i) => (s, i)))
{
    if (!ConfigAsd.StateSegmentColors.ContainsKey(s.AgentStateName))
        ConfigAsd.StateSegmentColors[s.AgentStateName] = PaletteColor(i, dark: false);
    if (!ConfigAsd.DarkStateSegmentColors.ContainsKey(s.AgentStateName))
        ConfigAsd.DarkStateSegmentColors[s.AgentStateName] = PaletteColor(i, dark: true);
}
```

**General tab — add Distribution Mode field** (after Business Unit, before Chart Type):

```razor
<div class="mb-3">
    <label class="form-label">@L["Widget.DistributionMode"]</label>
    <div class="btn-group w-100" role="group">
        <input type="radio" class="btn-check" id="mode-group" name="distMode"
               checked="@(ConfigAsd.DistributionMode == "group")"
               @onchange="@(() => { ConfigAsd.DistributionMode = "group"; StateHasChanged(); })" />
        <label class="btn btn-outline-primary" for="mode-group">@L["Widget.ByGroup"]</label>
        <input type="radio" class="btn-check" id="mode-state" name="distMode"
               checked="@(ConfigAsd.DistributionMode == "state")"
               @onchange="@(() => { ConfigAsd.DistributionMode = "state"; StateHasChanged(); })" />
        <label class="btn btn-outline-primary" for="mode-state">@L["Widget.ByState"]</label>
    </div>
    <div class="form-text">@L["Widget.DistributionModeHelp"]</div>
</div>
```

**Appearance tab — Segment Colors section** (dynamic based on mode):

```razor
@{
    var segRows = ConfigAsd.DistributionMode == "state"
        ? _asdStates.Where(s => s.IsActive)
            .Select(s => (Key: s.AgentStateName, Label: s.AgentStateName,
                          Light: ConfigAsd.StateSegmentColors,
                          Dark: ConfigAsd.DarkStateSegmentColors))
        : _asdGroups.Where(g => g.IsActive)
            .Select(g => (Key: g.GroupName, Label: g.GroupName,
                          Light: ConfigAsd.SegmentColors,
                          Dark: ConfigAsd.DarkSegmentColors));
}
<h6 class="mt-3">@L["Widget.SegmentColors"]</h6>
<table class="table table-sm">
    <thead><tr>
        <th>@L["Widget.Segment"]</th>
        <th>@L["Appearance.LightMode"]</th>
        <th>@L["Appearance.DarkMode"]</th>
    </tr></thead>
    <tbody>
        @foreach (var row in segRows)
        {
            <tr>
                <td>@row.Label</td>
                <td><input type="color" class="form-control form-control-color"
                           value="@row.Light.GetValueOrDefault(row.Key, "#6b7280")"
                           @onchange="e => row.Light[row.Key] = e.Value!.ToString()!" /></td>
                <td><input type="color" class="form-control form-control-color"
                           value="@row.Dark.GetValueOrDefault(row.Key, "#9ca3af")"
                           @onchange="e => row.Dark[row.Key] = e.Value!.ToString()!" /></td>
            </tr>
        }
        <tr class="text-muted">
            <td>Other (auto)</td>
            <td><span class="color-swatch" style="background:#6b7280"></span> #6b7280</td>
            <td><span class="color-swatch" style="background:#9ca3af"></span> #9ca3af</td>
        </tr>
    </tbody>
</table>
```

**New `.resx` keys needed** (add to `SharedResources.resx` and `SharedResources.ru-RU.resx`):

| Key | EN | RU |
|---|---|---|
| `Widget.DistributionMode` | Distribution Mode | Режим распределения |
| `Widget.ByGroup` | By Group | По группам |
| `Widget.ByState` | By State | По статусам |
| `Widget.DistributionModeHelp` | By Group shows aggregated status groups; By State shows individual agent states | По группам — агрегированные группы статусов; По статусам — индивидуальные статусы агентов |
| `Widget.Segment` | Segment | Сегмент |
| `Widget.SegmentColors` | Segment Colors | Цвета сегментов |

---

### 3. Simulator Verification (mandatory — see L-19 in widget-planner.md)

After implementing the widget:

1. Confirm `tools/SignalRSimulator/Models/GridModels.cs` — `GridRowData` has `int? UnionId`. If absent, add it.
2. In `DbMetricService.cs`: `GetMetricsForGridAsync(int gridId)` must cover `UsersInStatusCount` MetricIds (By State grid). If the description-prefix filter excludes them, extend to also include metrics with `MetricFunction = 'UsersInStatusCount'`.
3. In `QueueDataGenerator.cs`: generator must populate `UnionId` from `RTSGrid_Row.UnionId` for both Group and State grids.
4. Build simulator, restart, load ASD widget in both modes, confirm non-zero data within 5 s.

---

### 4. MANDATORY Pre-Commit Check

```bash
# MANDATORY before every commit — no exceptions
bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add
```

---

### 5. Acceptance Criteria

- [ ] Config modal — **Distribution Mode** selector present in General tab (By Group / By State)
- [ ] Config modal — **Segment Colors** section shows Status Groups when mode = "group", Agent States when mode = "state"
- [ ] Switching mode in config tab reloads segment colors list without losing colors already set for the other mode
- [ ] Config save: `SaveQueueGridRtsCommand` called **twice** — once for GroupGridId, once for StateGridId
- [ ] `GroupColumnMetricIds` and `StateColumnMetricIds` correctly populated in saved ConfigJson (verify via DevTools / DB)
- [ ] Widget renders correctly in **By Group** mode: 5 group segments + OTHER (if > 0)
- [ ] Widget renders correctly in **By State** mode: N state segments + OTHER (if > 0)
- [ ] `RtsGridId` switches to `StateGridId` when `DistributionMode = "state"` (verified via SignalR connection URL in browser)
- [ ] Changing mode on a live widget: SignalR disconnects from old grid, reconnects to new grid within 2 s
- [ ] Legacy ConfigJson with lowercased keys (`"available"`, `"break"`) correctly migrated on load (no visible errors)
- [ ] **Dispose**: both `DeleteQueueGridRtsCommand` calls fire (GroupGridId + StateGridId); no memory leak
- [ ] Simulator: both grids produce non-zero data within 5 s (By Group and By State)
- [ ] **Deletion — ScreenEditorPage.razor updated in all 3 places** (dialog warning, `ConfirmDeleteWidget`, save loop) to use `GroupGridId` + `StateGridId` with legacy `GridId` fallback
- [ ] Deleting an ASD widget and saving: both `GroupGridId` and `StateGridId` records removed from `RTSGrid_Grid` (verify via DB query)
- [ ] Build clean: `dotnet build CcDashboard.sln` — zero errors, zero warnings

---

*CC-009 written: 2026-05-28. Updated 2026-05-28: corrected deletion pattern (3-place ScreenEditorPage rule, L-26)*


---

## CC-010

### Implement Info Slot Widget — Message Display System

**Status:** 🔲 Ready
**Priority:** 🔴 High
**Depends on:** CC-009 ✅
**Spec reference:** `docs/widget-specification.md` §6 — read in full before starting
**Skill:** `.claude/skills/widget-creator/widget-creator.md` — read §22 (task template) for structure reference

---

### 1. Overview

This task implements a complete new feature: the **Info Slot** message display system.
It is **not** a Queue Grid or Agent Grid widget. It uses its own DB tables, SignalR hub,
and background service — all managed by the shell, not the CC platform.

Deliverables span four areas: infrastructure (DB + hub + service), application layer
(CQRS commands/queries), UI pages (admin + viewer), and the dashboard widget component.

---

### 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 2.1 | EF migration `AddInfoSlotTables` | `src/CcDashboard.Infrastructure/Migrations/` |
| 2.2 | Domain entities: `InfoSlot`, `InfoSlotPermission`, `InfoSlotMessage` | `src/CcDashboard.Domain/Domain/` |
| 2.3 | EF configurations for all 3 entities | `src/CcDashboard.Infrastructure/Persistence/Configurations/` |
| 2.4 | Application layer: commands, queries, handlers, validators | `src/CcDashboard.Application/` |
| 2.5 | `InfoSlotHub` (SignalR hub) | `src/CcDashboard.Web/Hubs/InfoSlotHub.cs` |
| 2.6 | `InfoSlotExpiryService` (BackgroundService) | `src/CcDashboard.Infrastructure/BackgroundServices/` |
| 2.7 | Admin page `/admin/info-slots` | `src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor` |
| 2.8 | Viewer page `/info-slots` | `src/CcDashboard.Web/Components/Dashboard/InfoSlots/InfoSlotMessages.razor` |
| 2.9 | PG editor — new "Info Slots" tab | `src/CcDashboard.Web/Components/Admin/GroupAdmin.razor` (extend) |
| 2.10 | NavMenu — new menu item `menu.infoSlots` | `src/CcDashboard.Web/Components/Layout/NavMenu.razor` (extend) |
| 2.11 | `InfoSlotWidget.razor` (dashboard widget) | `src/CcDashboard.Web/Components/Dashboard/Widgets/InfoSlotWidget.razor` |
| 2.12 | CSS animations for scroll directions | `src/CcDashboard.Web/wwwroot/css/widgets/info-slot.css` |
| 2.13 | `WidgetCatalogItem` seed + `MenuKey` seed | `src/CcDashboard.Infrastructure/Persistence/Seed/` |

---

### 3. Implementation Instructions

#### 3.1 Domain Entities

```csharp
// InfoSlot.cs
public class InfoSlot : IAuditableEntity
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public string DisplayMode { get; set; } = "Ticker"; // "Ticker" | "Sequential"
    public int SecondsPerMessage { get; set; } = 10;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public ICollection<InfoSlotPermission> Permissions { get; set; } = [];
    public ICollection<InfoSlotMessage> Messages { get; set; } = [];
}

// InfoSlotPermission.cs
public class InfoSlotPermission
{
    public Guid InfoSlotId { get; set; }
    public Guid PermissionGroupId { get; set; }
    public Guid TenantId { get; set; }

    public InfoSlot InfoSlot { get; set; } = default!;
    public PermissionGroup PermissionGroup { get; set; } = default!;
}

// InfoSlotMessage.cs
public class InfoSlotMessage
{
    public Guid Id { get; set; }
    public Guid InfoSlotId { get; set; }
    public Guid TenantId { get; set; }
    public string Content { get; set; } = default!;
    public string Priority { get; set; } = "Normal"; // "Normal" | "High"
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime? DeactivatedAt { get; set; }
    public Guid? DeactivatedByUserId { get; set; }

    public InfoSlot InfoSlot { get; set; } = default!;
}
```

#### 3.2 EF Configuration

```csharp
// InfoSlotConfiguration.cs
builder.ToTable("info_slots");
builder.HasKey(x => x.Id);
builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
builder.Property(x => x.DisplayMode).HasMaxLength(20).IsRequired();
builder.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);

// InfoSlotPermissionConfiguration.cs
builder.ToTable("info_slot_permissions");
builder.HasKey(x => new { x.InfoSlotId, x.PermissionGroupId });
builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);

// InfoSlotMessageConfiguration.cs
builder.ToTable("info_slot_messages");
builder.HasKey(x => x.Id);
builder.HasIndex(x => new { x.InfoSlotId, x.IsActive, x.ExpiresAt });
builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);
```

#### 3.3 Application Layer — Commands and Queries

**Commands:**

```csharp
// CreateInfoSlotCommand
public record CreateInfoSlotCommand(
    string Name,
    string? Description,
    string DisplayMode,
    int SecondsPerMessage,
    List<Guid> PermissionGroupIds
) : IRequest<Guid>;

// UpdateInfoSlotCommand
public record UpdateInfoSlotCommand(
    Guid Id,
    string Name,
    string? Description,
    string DisplayMode,
    int SecondsPerMessage,
    bool IsActive,
    List<Guid> PermissionGroupIds
) : IRequest;

// DeleteInfoSlotCommand — fails if any DashboardWidget references this IS
public record DeleteInfoSlotCommand(Guid Id) : IRequest;

// DeactivateInfoSlotCommand — same guard as delete
public record DeactivateInfoSlotCommand(Guid Id) : IRequest;

// CreateInfoSlotMessageCommand
public record CreateInfoSlotMessageCommand(
    Guid InfoSlotId,
    string Content,
    string Priority,
    DateTime? ExpiresAt
) : IRequest<InfoSlotMessageDto>;

// DeactivateInfoSlotMessageCommand
public record DeactivateInfoSlotMessageCommand(Guid MessageId) : IRequest;
```

**Queries:**

```csharp
// GetInfoSlotsQuery — admin list; optional TenantId for Superadmin cross-tenant
public record GetInfoSlotsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<InfoSlotListDto>>;

// GetInfoSlotsForViewerQuery — PG-gated; includes dashboard placements
public record GetInfoSlotsForViewerQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<InfoSlotViewerDto>>;

// GetActiveMessagesQuery — called by widget on mount
public record GetActiveMessagesQuery(Guid InfoSlotId) : IRequest<IReadOnlyList<InfoSlotMessageDto>>;

// GetInfoSlotsForWidgetConfigQuery — dropdown in widget config modal
public record GetInfoSlotsForWidgetConfigQuery : IRequest<IReadOnlyList<InfoSlotSummaryDto>>;
```

**DTOs:**

```csharp
public record InfoSlotListDto(
    Guid Id, string Name, string? Description,
    string DisplayMode, int SecondsPerMessage,
    bool IsActive, int ActiveMessageCount, int AssignedPgCount);

public record InfoSlotViewerDto(
    Guid Id, string Name, string DisplayMode,
    int ActiveMessageCount, List<string> DashboardNames,
    List<InfoSlotMessageDto> ActiveMessages);

public record InfoSlotMessageDto(
    Guid Id, Guid InfoSlotId, string Content,
    string Priority, DateTime? ExpiresAt,
    string AuthorName, DateTime CreatedAt);

public record InfoSlotSummaryDto(Guid Id, string Name, string DisplayMode);
```

**Guard (shared, call in Delete + Deactivate handlers):**

```csharp
private async Task EnsureNotPlacedOnDashboardsAsync(Guid infoSlotId, CancellationToken ct)
{
    var idString = infoSlotId.ToString();
    var dashboardNames = await db.DashboardWidgets
        .Where(w => EF.Functions.Like(w.ConfigJson, $"%{idString}%"))
        .Select(w => w.Dashboard.Name)
        .Distinct()
        .ToListAsync(ct);

    if (dashboardNames.Count > 0)
        throw new DomainException(
            $"Info Slot is placed on {dashboardNames.Count} dashboard(s): {string.Join(", ", dashboardNames)}. " +
            "Remove all widget placements before deactivating or deleting.");
}
```

**Authorization in handlers:**
- `CreateInfoSlotMessageCommand` handler: verify user's PG is in `info_slot_permissions` for the given IS (or user is Admin/Superadmin).
- `DeactivateInfoSlotMessageCommand` handler: Viewer can only deactivate own messages (`CreatedByUserId == currentUser.UserId`); Admin/Superadmin can deactivate any.

#### 3.4 InfoSlotHub

```csharp
[Authorize]
public class InfoSlotHub : Hub
{
    private readonly ITenantContext _tenantContext;

    public InfoSlotHub(ITenantContext tenantContext) =>
        _tenantContext = tenantContext;

    public async Task JoinSlot(Guid infoSlotId)
    {
        var tenantId = Context.User!.FindFirst("tenant_id")?.Value
            ?? throw new HubException("Missing tenant_id claim");

        // Verify TenantId matches resolved tenant (ARCH-04 pattern)
        if (tenantId != _tenantContext.TenantId.ToString())
            throw new HubException("Tenant mismatch");

        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
    }

    public async Task LeaveSlot(Guid infoSlotId)
    {
        var tenantId = Context.User!.FindFirst("tenant_id")?.Value!;
        var groupName = $"t:{tenantId}:is:{infoSlotId}";
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
    }
}
```

Register in `Program.cs`:
```csharp
app.MapHub<InfoSlotHub>("/hubs/info-slot");
```

Push from handlers via `IHubContext<InfoSlotHub>`:
```csharp
// After DB insert in CreateInfoSlotMessageCommand handler:
var group = $"t:{tenantId}:is:{command.InfoSlotId}";
await hubContext.Clients.Group(group).SendAsync("MessageAdded", messageDto, ct);
```

#### 3.5 InfoSlotExpiryService

```csharp
public class InfoSlotExpiryService(
    IServiceScopeFactory scopeFactory,
    IHubContext<InfoSlotHub> hubContext,
    ILogger<InfoSlotExpiryService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await ExpireMessagesAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromSeconds(60), stoppingToken);
        }
    }

    private async Task ExpireMessagesAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Cross-tenant: IgnoreQueryFilters + explicit where
        var expired = await db.InfoSlotMessages
            .IgnoreQueryFilters()
            .Where(m => m.IsActive &&
                        m.ExpiresAt.HasValue &&
                        m.ExpiresAt.Value <= DateTime.UtcNow)
            .Select(m => new { m.Id, m.TenantId, m.InfoSlotId })
            .ToListAsync(ct);

        if (!expired.Any()) return;

        await db.InfoSlotMessages
            .IgnoreQueryFilters()
            .Where(m => expired.Select(e => e.Id).Contains(m.Id))
            .ExecuteUpdateAsync(s => s
                .SetProperty(m => m.IsActive, false)
                .SetProperty(m => m.DeactivatedAt, DateTime.UtcNow), ct);

        foreach (var msg in expired)
        {
            var group = $"t:{msg.TenantId}:is:{msg.InfoSlotId}";
            await hubContext.Clients.Group(group)
                .SendAsync("MessageExpired", new { MessageId = msg.Id }, ct);
        }

        logger.LogInformation("InfoSlotExpiryService: expired {Count} messages", expired.Count);
    }
}
```

Register in `Program.cs`:
```csharp
builder.Services.AddHostedService<InfoSlotExpiryService>();
```

#### 3.6 Admin Page `/admin/info-slots`

Route: `@page "/admin/info-slots"`
Auth: `@attribute [Authorize(Roles = "Superadmin,Administrator")]`
RenderMode: `@rendermode InteractiveServer`

**Superadmin tenant selector:** At the top of the page, if `currentUser.Role == "Superadmin"`:
- Dropdown: "All Tenants" + list of all tenants (loaded via `GetTenantsQuery`)
- Selection changes `SelectedTenantId` → reloads IS list via `GetInfoSlotsQuery(SelectedTenantId)`
- "All Tenants" option → `GetInfoSlotsQuery(null)` with `IgnoreQueryFilters` in handler

**List:** Table with columns: Name | DisplayMode | Active messages | PG count | Status pill | Edit (pencil) | Delete (trash)

**Create/Edit modal — 2 tabs:**
- Tab "General": Name, Description, DisplayMode (select), SecondsPerMessage (shown if Sequential), IsActive toggle
- Tab "Access": dual-pane PG assignment (standard `DualPaneSelector` component)

**Delete flow:**
1. Click trash → call `CheckInfoSlotPlacementsQuery(id)` → if placements exist: show blocking modal with dashboard list (cannot delete); else show confirmation dialog
2. Confirm → `DeleteInfoSlotCommand` → reload list
3. Audit event: `InfoSlot.Deleted`

**Deactivate guard (IsActive toggle off):**
Same placement check as delete. If placements exist: revert toggle + show warning modal.

#### 3.7 Viewer Page `/info-slots`

Route: `@page "/info-slots"`
Auth: `@attribute [Authorize]` (all authenticated users)
RenderMode: `@rendermode InteractiveServer`

**Superadmin tenant selector:** Same pattern as admin page — dropdown "All Tenants" / specific tenant at top. Changes `SelectedTenantId` → reloads IS list.

**IS list:** Cards or table rows per IS accessible to current user:
- IS name + DisplayMode badge
- Active message count badge
- Dashboard list: small pills showing dashboard names where IS is placed (from `InfoSlotViewerDto.DashboardNames`)
- "Manage Messages →" button → opens messages modal

**Messages modal (per IS):**

*Active messages section:*
- List: `[HIGH ★]` or `[NORMAL]` badge | Content (full text) | ExpiresAt | Author | CreatedAt | Deactivate button
- Deactivate → `DeactivateInfoSlotMessageCommand` → push `MessageDeactivated` → update list reactively
- Admin/Superadmin see Deactivate on all messages; Viewer/Editor only on own

*Add message form (bottom of modal):*
```
Content:    [textarea, required]
Priority:   ○ Normal  ● High
Expires at: [datetime picker]  □ Never expires
            [Add Message →]
```
Submit → `CreateInfoSlotMessageCommand` → on success: hub pushes `MessageAdded` → modal list updates

#### 3.8 PG Editor — New Info Slots Tab

Extend `GroupAdmin.razor`: add tab **"Info Slots"** after the "BU / SG" tab.

Tab content:
- Heading: `@L["PermGroup_InfoSlots"]`
- Sub-heading note: `@L["PermGroup_InfoSlots_Note"]` ("Members of this group can write messages to assigned Info Slots")
- List: assigned IS names with remove (×) button
- "+ Add Info Slot" button → search/select dialog (loads `GetInfoSlotsForSelectQuery`, search by name)
- On save: `UpdatePermissionGroupInfoSlotsCommand(pgId, List<Guid> infoSlotIds)`

#### 3.9 NavMenu — New Menu Item

Add to `NavMenu.razor` under the "Content" section:

```razor
@if (_menuPermissions.Contains("menu.infoSlots"))
{
    <NavLink href="/info-slots">@L["Menu_InfoSlots"]</NavLink>
}
```

Add `menu.infoSlots` to `menu_permissions` seed: accessible to all roles (Superadmin, Administrator, Editor, Viewer).

#### 3.10 InfoSlotWidget.razor

Location: `src/CcDashboard.Web/Components/Dashboard/Widgets/InfoSlotWidget.razor`

**Parameters:** `[Parameter] public InfoSlotWidgetConfig Config { get; set; }` + standard widget parameters (`GridId`, `TenantId`, etc.)

**WidgetConfig record:**
```csharp
public record InfoSlotWidgetConfig
{
    public Guid? InfoSlotId { get; init; }
    public string DisplayName { get; init; } = "";
    public string ScrollDirection { get; init; } = "LeftToRight";
    public string ScrollSpeed { get; init; } = "Medium";
    public int FontSize { get; init; } = 14;
    public string BackgroundColor { get; init; } = "auto";
    public string TextColor { get; init; } = "auto";
    public string PriorityHighBackgroundColor { get; init; } = "auto";
    public string PriorityHighTextColor { get; init; } = "auto";
    public bool ShowAuthor { get; init; } = true;
    public bool ShowTimestamp { get; init; } = true;
    public string EmptyStateMessage { get; init; } = "";
    public int MaxMessagesVisible { get; init; } = 0;
}
```

**Lifecycle:**
1. `OnInitializedAsync`: call `GetActiveMessagesQuery` → populate `_messages` list
2. `OnAfterRenderAsync(firstRender)`: connect `HubConnection` to `/hubs/info-slot`, call `JoinSlot(Config.InfoSlotId)`
3. Register handlers: `"MessageAdded"` → add to list + `StateHasChanged()`; `"MessageDeactivated"` / `"MessageExpired"` → remove from list + `StateHasChanged()`
4. `DisposeAsync`: `await _hubConnection.DisposeAsync()`

**Message ordering:**
```csharp
private IEnumerable<InfoSlotMessageDto> OrderedMessages =>
    _messages.OrderByDescending(m => m.Priority == "High")
             .ThenByDescending(m => m.CreatedAt);
```

Apply `MaxMessagesVisible` filter if > 0.

**Rendering:**

Ticker mode — CSS class `is-ticker is-dir-{scrollDirection.ToLower()}`:
```razor
<div class="is-ticker-wrapper">
    <div class="is-ticker-track" style="animation-duration: @AnimDuration">
        @foreach (var msg in OrderedMessages)
        {
            <span class="is-msg @(msg.Priority == "High" ? "is-high" : "")" style="@MsgStyle(msg)">
                @if (msg.Priority == "High") { <span class="is-star">★</span> }
                @msg.Content
                @if (Config.ShowAuthor) { <small>@msg.AuthorName</small> }
                @if (Config.ShowTimestamp) { <small>@msg.CreatedAt.ToString("HH:mm")</small> }
            </span>
            <span class="is-sep">·····</span>
        }
    </div>
</div>
```

Sequential mode — show `_currentIndex` message, advance via `System.Threading.Timer` every `SecondsPerMessage × 1000` ms.

Empty state:
```razor
@if (!_messages.Any())
{
    <div class="is-empty">@(string.IsNullOrEmpty(Config.EmptyStateMessage) ? L["InfoSlot_NoMessages"] : Config.EmptyStateMessage)</div>
}
```

#### 3.11 CSS Animations (`info-slot.css`)

```css
/* Ticker — horizontal (LeftToRight / RightToLeft) */
.is-ticker { overflow: hidden; white-space: nowrap; }
.is-ticker-track { display: inline-block; }

.is-dir-lefttoright .is-ticker-track {
    animation: ticker-ltr var(--is-anim-duration, 20s) linear infinite;
}
@keyframes ticker-ltr {
    from { transform: translateX(-100%); }
    to   { transform: translateX(100%); }
}

.is-dir-righttoleft .is-ticker-track {
    animation: ticker-rtl var(--is-anim-duration, 20s) linear infinite;
}
@keyframes ticker-rtl {
    from { transform: translateX(100%); }
    to   { transform: translateX(-100%); }
}

/* Ticker — vertical (TopToBottom / BottomToTop) */
.is-ticker.is-vertical { white-space: normal; overflow: hidden; height: 100%; }

.is-dir-toptobottom .is-ticker-track {
    animation: ticker-ttb var(--is-anim-duration, 20s) linear infinite;
}
@keyframes ticker-ttb {
    from { transform: translateY(-100%); }
    to   { transform: translateY(100%); }
}

.is-dir-bottomtotop .is-ticker-track {
    animation: ticker-btt var(--is-anim-duration, 20s) linear infinite;
}
@keyframes ticker-btt {
    from { transform: translateY(100%); }
    to   { transform: translateY(-100%); }
}

/* Speed → CSS variable (set inline on wrapper) */
/* Slow=40s, Medium=20s, Fast=10s — set via style="--is-anim-duration: 20s" */

/* Priority High */
.is-high {
    background-color: var(--is-priority-high-bg, var(--bs-warning-bg-subtle));
    color: var(--is-priority-high-text, var(--bs-warning-text-emphasis));
    border-radius: 3px;
    padding: 0 4px;
}

/* auto colour mode */
.is-widget[data-bg="auto"] { background: var(--widget-bg); }
.is-widget[data-text="auto"] { color: var(--widget-text); }

/* Empty state */
.is-empty {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: var(--bs-secondary-color);
    font-style: italic;
}
```

#### 3.12 Seed Data

```csharp
// In WidgetCatalogSeeder or DatabaseInitializer:
if (!await db.WidgetCatalogItems.AnyAsync(w => w.Name == "Info Slot"))
{
    db.WidgetCatalogItems.Add(new WidgetCatalogItem
    {
        Id = Uuid.NewSequential(),
        Category = "General",
        Name = "Info Slot",
        Description = "Displays scrolling messages written by management staff. " +
                      "Supports Ticker (continuous band) and Sequential (one-at-a-time) modes.",
        IconUrl = "/icons/widgets/info-slot.svg",
        IsActive = true
    });
}

// menu_permissions seed — add menu.infoSlots for all roles:
// Seeded for every PG created (default grant = true for menu.infoSlots)
```

#### 3.13 Localization Keys to Add

Add to `SharedResources.resx` and `SharedResources.ru-RU.resx`:

| Key | EN | RU |
|---|---|---|
| `InfoSlot_SelectSlot` | Select Info Slot | Выберите Info Slot |
| `InfoSlot_ScrollDirection` | Scroll Direction | Направление прокрутки |
| `InfoSlot_ScrollSpeed` | Scroll Speed | Скорость прокрутки |
| `InfoSlot_EmptyStateMessage` | Empty State Message | Сообщение при отсутствии данных |
| `InfoSlot_NoMessages` | No active messages | Нет активных сообщений |
| `InfoSlot_MaxMessages` | Max Messages Visible | Макс. сообщений |
| `InfoSlot_ShowAuthor` | Show Author | Показывать автора |
| `InfoSlot_ShowTimestamp` | Show Timestamp | Показывать время |
| `InfoSlot_PriorityHighBackground` | High Priority Background | Фон высокого приоритета |
| `InfoSlot_PriorityHighText` | High Priority Text Color | Цвет текста высокого приоритета |
| `InfoSlot_WriteMessage` | Write Message | Написать сообщение |
| `InfoSlot_Priority` | Priority | Приоритет |
| `InfoSlot_ExpiresAt` | Expires At | Действует до |
| `InfoSlot_Delete_Confirm` | Delete Info Slot? | Удалить Info Slot? |
| `InfoSlot_Delete_Warning` | This Info Slot is placed on dashboards | Info Slot размещён на дашбордах |
| `InfoSlot_Deactivate_Warning` | Cannot deactivate — remove from dashboards first | Нельзя деактивировать — сначала уберите с дашбордов |
| `InfoSlot_AssignedGroups` | Assigned Permission Groups | Назначенные группы |
| `InfoSlot_AddMessage` | Add Message | Добавить сообщение |
| `PermGroup_InfoSlots` | Info Slots | Info Slots |
| `PermGroup_InfoSlots_Note` | Members of this group can write messages to assigned Info Slots | Участники группы могут писать сообщения в назначенные Info Slots |
| `Menu_InfoSlots` | Info Slots | Info Slots |

---

### 4. Audit Events

Add to `AuditService` and `AuditEventType` enum:

```csharp
InfoSlot_Created,
InfoSlot_Updated,
InfoSlot_Deactivated,
InfoSlot_Deleted,
InfoSlot_MessageAdded,
InfoSlot_MessageDeactivated,
InfoSlot_MessageExpired
```

Write audit in every command handler. `InfoSlot.MessageExpired` is written by `InfoSlotExpiryService` (batch — one event per expired message).

---

### 5. Security Checklist

#### 5.1 Authentication & Page Authorization

- [ ] `/admin/info-slots` — `[Authorize(Roles = "Superadmin,Administrator")]` attribute on page/component
- [ ] `/info-slots` — `[Authorize]` on page (all authenticated users; PG gate enforced in Application layer)
- [ ] `InfoSlotWidget.razor` — rendered only inside authenticated Blazor circuit (standard `[Authorize]` on parent page)
- [ ] `InfoSlotHub` — `[Authorize]` attribute on hub class; unauthenticated connections rejected before reaching any method

#### 5.2 SignalR Hub Security

- [ ] `JoinSlot`: extract `tenant_id` from `Context.User` claims — **not** from method parameter
- [ ] `JoinSlot`: compare extracted `tenant_id` against `ITenantContext.TenantId`; mismatch → `throw new HubException("Tenant mismatch")` (generic message, no detail)
- [ ] `JoinSlot`: verify the requested `InfoSlotId` belongs to the resolved tenant before adding to group — query `info_slots` with active GQF; slot not found → `throw new HubException("Not found")`
- [ ] `JoinSlot`: verify user has VIEW access to the IS (is admin, or their PG is in `info_slot_permissions`, or IS is placed on a dashboard they can access); block subscription otherwise
- [ ] Hub methods never return sensitive data in exception messages — use generic strings only
- [ ] SignalR hub URL (`/hubs/info-slot`) not exposed in client-side JS before authentication

#### 5.3 Application Layer Authorization — [PG-04] Enforcement

- [ ] `CreateInfoSlotMessageCommand` handler: verify `InfoSlot.TenantId == currentUser.TenantId` (GQF covers this, but assert explicitly for defence-in-depth)
- [ ] `CreateInfoSlotMessageCommand` handler: verify user's `PermissionGroupId` is present in `info_slot_permissions` for this IS — **or** user role is Admin/Superadmin; reject with `ForbiddenException` otherwise
- [ ] `DeactivateInfoSlotMessageCommand` handler: verify message `TenantId == currentUser.TenantId`
- [ ] `DeactivateInfoSlotMessageCommand` handler: Viewer/Editor role → `message.CreatedByUserId == currentUser.UserId` required; Admin/Superadmin → unrestricted
- [ ] `DeleteInfoSlotCommand` / `DeactivateInfoSlotCommand` handlers: `EnsureNotPlacedOnDashboardsAsync` called **before** any DB mutation — never skip
- [ ] `GetInfoSlotsForViewerQuery` handler: non-admin users receive only IS where their PG is in `info_slot_permissions` — filter applied in query, not post-processing
- [ ] UI hiding (disabled buttons, hidden menu items) is cosmetic only — all checks above are **also** enforced in Application layer

#### 5.4 Input Validation (FluentValidation)

- [ ] `CreateInfoSlotCommand`: `Name` required, max 200 chars; `DisplayMode` must be `"Ticker"` or `"Sequential"`; `SecondsPerMessage` 3–3600; `PermissionGroupIds` must all belong to current tenant
- [ ] `CreateInfoSlotMessageCommand`: `Content` required, max 2000 chars; `Priority` must be `"Normal"` or `"High"`; `ExpiresAt` if provided must be **in the future** (`> UtcNow`)
- [ ] `UpdateInfoSlotCommand`: same field rules as Create; `Id` must resolve to existing IS in current tenant
- [ ] All validators registered in MediatR `ValidationBehavior` pipeline — not called manually

#### 5.5 XSS Protection — [CODE-02]

- [ ] `InfoSlotWidget.razor`: message `Content` rendered via standard Blazor `@msg.Content` — Blazor auto-encodes; **never** use `@((MarkupString)msg.Content)` without sanitisation
- [ ] Author name in widget: same rule — `@msg.AuthorName` only, no MarkupString
- [ ] IS `Name` displayed in admin/viewer pages: standard `@slot.Name` — no MarkupString
- [ ] If rich-text content is ever added in future: use `Ganss.Xss.HtmlSanitizer` before rendering

#### 5.6 Multi-Tenancy Isolation

- [ ] All 3 new entities have `TenantId` column with Global Query Filter in `AppDbContext` — verify GQF is active in `OnModelCreating`
- [ ] `info_slot_permissions` GQF: `x.TenantId == _tenantContext.TenantId`
- [ ] `InfoSlotExpiryService`: uses `IgnoreQueryFilters()` legitimately (cross-tenant system operation) — **must** write `Tenant.CrossTenantAccess` audit event per ARCH-01 (one event per service run, not per message)
- [ ] Superadmin cross-tenant handlers: `IgnoreQueryFilters()` + explicit `.Where(x => x.TenantId == targetTenantId)` + `Tenant.CrossTenantAccess` audit event
- [ ] No `IgnoreQueryFilters()` in any regular (non-system) repository path without explicit audit
- [ ] SignalR group name includes `tenantId`: `t:{tenantId}:is:{slotId}` — prevents cross-tenant message leakage if slot IDs coincide across tenants

#### 5.7 Rate Limiting — Message Spam Prevention

- [ ] `CreateInfoSlotMessageCommand` handler: Redis rate limit per `(UserId, InfoSlotId)` — max 20 messages per IS per hour; on exceed → return `TooManyRequestsException` (HTTP 429 equivalent in Application layer)
- [ ] Redis key: `"{tenantId}:is_msg_rate:{userId}:{infoSlotId}"` with TTL 1 hour; increment on each create
- [ ] Rate limit values configurable in `appsettings` — not hardcoded

#### 5.8 Background Service Safety

- [ ] `InfoSlotExpiryService.ExecuteAsync`: create a **fresh DI scope per run** (`scopeFactory.CreateScope()`) — no tenant context leakage between iterations
- [ ] Serilog log output: log only `Count` of expired messages — **never** log `Content`, `AuthorName`, or any message body
- [ ] Exception in one run must not crash the service — wrap `ExpireMessagesAsync` in `try/catch`; log error and continue loop
- [ ] Service respects `CancellationToken stoppingToken` — check before each iteration and pass to all async calls

#### 5.9 Audit Trail Completeness

- [ ] `InfoSlot.Created` — written in `CreateInfoSlotCommand` handler
- [ ] `InfoSlot.Updated` — written in `UpdateInfoSlotCommand` handler; `Details` includes changed fields (old/new values for Name, DisplayMode, IsActive, PG list diff)
- [ ] `InfoSlot.Deactivated` — written in `DeactivateInfoSlotCommand` handler
- [ ] `InfoSlot.Deleted` — written in `DeleteInfoSlotCommand` handler; `Details` includes IS name
- [ ] `InfoSlot.MessageAdded` — written in `CreateInfoSlotMessageCommand` handler; `Details` includes `InfoSlotId`, `Priority`, `ExpiresAt` — **not** `Content` (PII risk)
- [ ] `InfoSlot.MessageDeactivated` — written in `DeactivateInfoSlotMessageCommand` handler; `Details` includes `MessageId`, `InfoSlotId`, `DeactivatedBy`
- [ ] `InfoSlot.MessageExpired` — written by `InfoSlotExpiryService` per expired message; `Details` includes `MessageId`, `InfoSlotId`
- [ ] `Tenant.CrossTenantAccess` — written on every `IgnoreQueryFilters()` call path per ARCH-01

#### 5.10 Cascade Delete & Data Integrity

- [ ] EF `ON DELETE CASCADE` configured on `info_slot_permissions.InfoSlotId` → `info_slots.Id`
- [ ] EF `ON DELETE CASCADE` configured on `info_slot_messages.InfoSlotId` → `info_slots.Id`
- [ ] Before IS deletion: push `MessageDeactivated` for all currently active messages via hub — prevents widget showing stale data after IS is gone
- [ ] Before IS deletion: `EnsureNotPlacedOnDashboardsAsync` — never skip even if called from admin context

---

### 6. Acceptance Criteria

- [ ] Migration `AddInfoSlotTables` applies cleanly: tables `info_slots`, `info_slot_permissions`, `info_slot_messages` created with all indexes
- [ ] Admin can create IS with DisplayMode Ticker and Sequential; Sequential shows `SecondsPerMessage` field only
- [ ] Dual-pane PG assignment saves correctly to `info_slot_permissions`
- [ ] Deactivating IS with dashboard placements → blocking modal shows dashboard names, IsActive not changed
- [ ] Deleting IS with placements → blocked; deleting IS without placements → cascade removes permissions + messages
- [ ] Viewer page shows only IS where user's PG has access; Admin/Superadmin sees all
- [ ] Superadmin sees tenant dropdown ("All Tenants" / specific tenant) on **both** `/admin/info-slots` and `/info-slots`; switching tenant reloads the list
- [ ] Viewer can add message (Normal + High priority, with and without ExpiresAt)
- [ ] Message appears on open widget within 2 s via SignalR push (no page reload)
- [ ] `InfoSlotExpiryService`: expired messages (ExpiresAt past) set `IsActive = false`; `MessageExpired` pushed to hub group; widget removes message without reload
- [ ] Widget Ticker mode: all 4 scroll directions animate correctly
- [ ] Widget Sequential mode: messages advance every `SecondsPerMessage` s; cycles back to first
- [ ] High-priority messages: shown first + distinct background/text colour in both Ticker and Sequential
- [ ] `backgroundColor = "auto"` → uses `var(--widget-bg)`; High-priority `auto` → Bootstrap warning vars
- [ ] Empty state message shown when no active messages (uses config text or `@L["InfoSlot_NoMessages"]`)
- [ ] PG editor "Info Slots" tab saves assignments; assignments visible in Viewer page IS list
- [ ] `menu.infoSlots` appears in NavMenu for all roles with PG grant
- [ ] All new UI strings use `@L["Key"]`; `SharedResources.resx` and `.ru-RU.resx` updated
- [ ] All 7 audit event types written to `audit.audit_logs` on corresponding actions
- [ ] `DisposeAsync` in `InfoSlotWidget.razor` disconnects SignalR; no memory leak
- [ ] Build clean: `dotnet build CcDashboard.sln` — zero errors

```bash
# MANDATORY before every commit — no exceptions
bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add
```

---

*CC-010 written: 2026-05-29.*

---

## CC-011

### Implement Info Slot Message Edit

**Status:** 🔲 Ready
**Priority:** 🟡 Medium
**Depends on:** CC-010 ✅
**Spec reference:** `docs/widget-specification.md` §6.8 — "Edit mode" section

---

### 1. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 1.1 | `UpdateInfoSlotMessageCommand` + validator + handler | `src/CcDashboard.Application/Commands/InfoSlots/` + `src/CcDashboard.Infrastructure/Handlers/` |
| 1.2 | `MessageUpdated` hub event in `InfoSlotHub` push | `src/CcDashboard.Web/Hubs/InfoSlotHub.cs` (push only — no new hub method) |
| 1.3 | Inline edit UI in `InfoSlotMessages.razor` | `src/CcDashboard.Web/Components/Dashboard/InfoSlots/InfoSlotMessages.razor` |
| 1.4 | `MessageUpdated` handler in `InfoSlotWidget.razor` | `src/CcDashboard.Web/Components/Widgets/InfoSlotWidget.razor` |
| 1.5 | Audit event `InfoSlot.MessageUpdated` | in handler (1.1) |
| 1.6 | Localization keys | `SharedResources.resx` + `SharedResources.ru-RU.resx` |

---

### 2. Command

```csharp
public record UpdateInfoSlotMessageCommand(
    Guid MessageId,
    string Content,
    string Priority,
    DateTime? ExpiresAt
) : IRequest<InfoSlotMessageDto>;
```

**Validator:**
- `Content` required, max 2000 chars
- `Priority` must be `"Normal"` or `"High"`
- `ExpiresAt` if provided must be in the future (`> UtcNow`)

**Handler:**
1. Load message by `MessageId` (GQF ensures tenant isolation)
2. Verify `message.IsActive == true` — cannot edit deactivated message; throw `DomainException` if false
3. **Authorization check:**
   - Role is Viewer or Editor → `message.CreatedByUserId == currentUser.UserId` required; else `ForbiddenException`
   - Role is Admin or Superadmin → allowed unconditionally
4. Apply changes: `Content`, `Priority`, `ExpiresAt`
5. `await db.SaveChangesAsync(ct)`
6. Push `MessageUpdated` via `IHubContext<InfoSlotHub>`:
   ```csharp
   var group = $"t:{message.TenantId}:is:{message.InfoSlotId}";
   await hubContext.Clients.Group(group).SendAsync("MessageUpdated", updatedDto, ct);
   ```
7. Write audit event `InfoSlot.MessageUpdated`:
   - `Details`: `{ MessageId, InfoSlotId, ChangedFields: { Priority: {old, new}, ExpiresAt: {old, new} } }`
   - **Do NOT include Content in audit** (PII)
8. Return `InfoSlotMessageDto`

---

### 3. Inline Edit UI (`InfoSlotMessages.razor`)

**State per component:**
```csharp
private Guid? _editingMessageId;       // null = no row in edit mode
private string _editContent = "";
private string _editPriority = "Normal";
private DateTime? _editExpiresAt;
private bool _editNeverExpires = true;
private bool _editSaving;
private string? _editError;
```

**Row rendering logic:**
```razor
@foreach (var msg in ActiveMessages)
{
    @if (_editingMessageId == msg.Id)
    {
        <!-- EDIT MODE -->
        <div class="is-msg-edit">
            <textarea @bind="_editContent" rows="2" class="form-control" />
            <div class="is-msg-edit-footer">
                <div>
                    <label><input type="radio" @onchange='_ => _editPriority = "Normal"'
                        checked='@(_editPriority == "Normal")' /> @L["Normal"]</label>
                    <label><input type="radio" @onchange='_ => _editPriority = "High"'
                        checked='@(_editPriority == "High")' /> @L["High"]</label>
                </div>
                <div>
                    <input type="datetime-local" @bind="_editExpiresAt"
                        disabled="@_editNeverExpires" class="form-control form-control-sm" />
                    <label><input type="checkbox" @bind="_editNeverExpires" /> @L["InfoSlot_NeverExpires"]</label>
                </div>
                @if (_editError != null) { <div class="text-danger small">@_editError</div> }
                <button class="btn btn-sm btn-secondary" @onclick="CancelEdit">@L["Cancel"]</button>
                <button class="btn btn-sm btn-primary" @onclick="() => SaveEdit(msg.Id)"
                    disabled="@_editSaving">@L["InfoSlot_SaveMessage"] →</button>
            </div>
        </div>
    }
    else
    {
        <!-- DISPLAY MODE -->
        <div class="is-msg-row">
            <!-- priority badge + author + timestamp + content + expiry -->
            @if (CanEditMessage(msg))
            {
                <button class="btn btn-sm btn-outline-secondary" @onclick="() => StartEdit(msg)"
                    title="@L["Edit"]"><i class="bi bi-pencil"></i></button>
            }
            @if (CanDeactivateMessage(msg))
            {
                <button class="btn btn-sm btn-outline-danger" @onclick="() => Deactivate(msg.Id)">
                    <i class="bi bi-x-circle"></i></button>
            }
        </div>
    }
}
```

**Helper methods:**
```csharp
private void StartEdit(InfoSlotMessageDto msg)
{
    _editingMessageId = msg.Id;
    _editContent = msg.Content;
    _editPriority = msg.Priority;
    _editNeverExpires = msg.ExpiresAt == null;
    _editExpiresAt = msg.ExpiresAt?.ToLocalTime();
    _editError = null;
}

private void CancelEdit()
{
    _editingMessageId = null;
    _editError = null;
}

private async Task SaveEdit(Guid messageId)
{
    _editSaving = true;
    _editError = null;
    try
    {
        await Mediator.Send(new UpdateInfoSlotMessageCommand(
            messageId,
            _editContent,
            _editPriority,
            _editNeverExpires ? null : _editExpiresAt?.ToUniversalTime()));
        _editingMessageId = null;
        // list updated via MessageUpdated hub push
    }
    catch (Exception ex) { _editError = ex.Message; }
    finally { _editSaving = false; StateHasChanged(); }
}

private bool CanEditMessage(InfoSlotMessageDto msg) =>
    CurrentUser.IsAdminOrSuperadmin() || msg.AuthorUserId == CurrentUser.UserId;
```

**One-edit-at-a-time rule:** `StartEdit` always sets `_editingMessageId` — previous open row closes automatically because `@if (_editingMessageId == msg.Id)` becomes false.

---

### 4. Widget Update (`InfoSlotWidget.razor`)

Register `MessageUpdated` handler alongside existing `MessageAdded` / `MessageExpired`:

```csharp
_hubConnection.On<InfoSlotMessageDto>("MessageUpdated", msg =>
{
    var idx = _messages.FindIndex(m => m.Id == msg.Id);
    if (idx >= 0) _messages[idx] = msg;
    InvokeAsync(StateHasChanged);
});
```

---

### 5. New Localization Keys

| Key | EN | RU |
|---|---|---|
| `InfoSlot_SaveMessage` | Save message | Сохранить сообщение |
| `InfoSlot_NeverExpires` | Never expires | Без срока действия |
| `InfoSlot_EditMessage` | Edit message | Редактировать сообщение |
| `InfoSlot_CannotEditInactive` | Cannot edit a deactivated message | Нельзя редактировать деактивированное сообщение |

---

### 6. Security

- [ ] `UpdateInfoSlotMessageCommand` handler: Viewer/Editor → own message only (`CreatedByUserId == currentUser.UserId`); else `ForbiddenException`
- [ ] Cannot edit `IsActive = false` message — `DomainException` in handler
- [ ] `Content` rendered via `@_editContent` / `@msg.Content` — Blazor auto-encode, no MarkupString
- [ ] `ExpiresAt` validated as future date in FluentValidation
- [ ] Edit button hidden in UI for unauthorized users (cosmetic) — authorization enforced in handler [PG-04]
- [ ] Audit Details excludes Content (PII)

---

### 7. Acceptance Criteria

- [ ] Edit (✎) button visible only on own messages for Viewer/Editor; visible on all messages for Admin/Superadmin
- [ ] Clicking ✎ opens inline edit form pre-filled with current Content, Priority, ExpiresAt
- [ ] Only one row can be in edit mode at a time — opening second row closes first
- [ ] Save → `UpdateInfoSlotMessageCommand` → row updates instantly via `MessageUpdated` push (no reload)
- [ ] Widget on open dashboard updates the message in place within 2 s of Save
- [ ] Cancel → row returns to display mode, no changes saved
- [ ] Trying to edit a deactivated message (direct API call) → `DomainException`
- [ ] Viewer editing another user's message (direct API call) → `ForbiddenException`
- [ ] `ExpiresAt` in the past → validation error shown inline
- [ ] Audit event `InfoSlot.MessageUpdated` written; Content absent from Details
- [ ] All new strings use `@L["Key"]`; resx files updated
- [ ] Build clean: `dotnet build CcDashboard.sln` — zero errors

```bash
# MANDATORY before every commit — no exceptions
bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add
```

---

*CC-011 written: 2026-05-29.*

---

## CC-012

### Info Slot — Display Mode toggle in messages modal

**Status:** 🔲 Ready
**Priority:** 🟡 Medium
**Depends on:** CC-011 ✅
**Spec reference:** `docs/widget-specification.md` §6.8 — "Modal header area — Display Mode toggle"

---

### 1. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 1.1 | `UpdateInfoSlotDisplayModeCommand` + validator + handler | `src/CcDashboard.Application/Commands/InfoSlots/` + `src/CcDashboard.Infrastructure/Handlers/` |
| 1.2 | `DisplayModeChanged` push in handler | via `IHubContext<InfoSlotHub>` |
| 1.3 | Display Mode toggle UI in `InfoSlotMessages.razor` | `src/CcDashboard.Web/Components/Dashboard/InfoSlots/InfoSlotMessages.razor` |
| 1.4 | `DisplayModeChanged` handler in `InfoSlotWidget.razor` | `src/CcDashboard.Web/Components/Widgets/InfoSlotWidget.razor` |
| 1.5 | Localization keys | `SharedResources.resx` + `SharedResources.ru-RU.resx` |

---

### 2. Command

```csharp
public record UpdateInfoSlotDisplayModeCommand(
    Guid InfoSlotId,
    string DisplayMode,       // "Ticker" | "Sequential"
    int SecondsPerMessage     // min 3, default 10; relevant only for Sequential
) : IRequest;
```

**Validator:**
- `DisplayMode` must be `"Ticker"` or `"Sequential"`
- `SecondsPerMessage` range 3–3600

**Handler:**
1. Load `InfoSlot` by `InfoSlotId` (GQF — tenant isolation automatic)
2. **Authorization:** verify user's `PermissionGroupId` is in `info_slot_permissions` for this IS — **or** role is Admin/Superadmin; else `ForbiddenException`
3. Update `slot.DisplayMode` and `slot.SecondsPerMessage`
4. `await db.SaveChangesAsync(ct)`
5. Push `DisplayModeChanged` via `IHubContext<InfoSlotHub>`:
   ```csharp
   var group = $"t:{slot.TenantId}:is:{slot.Id}";
   await hubContext.Clients.Group(group).SendAsync(
       "DisplayModeChanged",
       new { DisplayMode = slot.DisplayMode, SecondsPerMessage = slot.SecondsPerMessage },
       ct);
   ```
6. Write audit event `InfoSlot.Updated` — `Details`: `{ InfoSlotId, Field: "DisplayMode", Old: oldMode, New: newMode }`

---

### 3. UI — `InfoSlotMessages.razor`

Add to modal header, between modal title and "Active Messages" label:

```razor
<div class="is-mode-toggle">
    <span class="me-2">@L["InfoSlot_DisplayMode"]:</span>
    <div class="btn-group btn-group-sm" role="group">
        <button type="button"
            class="btn @(_currentDisplayMode == "Ticker" ? "btn-primary" : "btn-outline-secondary")"
            @onclick='() => SetDisplayMode("Ticker")'>
            @L["InfoSlot_Ticker"]
        </button>
        <button type="button"
            class="btn @(_currentDisplayMode == "Sequential" ? "btn-primary" : "btn-outline-secondary")"
            @onclick='() => SetDisplayMode("Sequential")'>
            @L["InfoSlot_Sequential"]
        </button>
    </div>
    @if (_currentDisplayMode == "Sequential")
    {
        <span class="ms-3">@L["InfoSlot_SecondsPerMessage"]:</span>
        <input type="number" min="3" max="3600" @bind="_currentSeconds"
               @bind:event="onchange" @onchange="OnSecondsChanged"
               class="form-control form-control-sm ms-1" style="width:70px" />
    }
</div>
```

**State:**
```csharp
private string _currentDisplayMode = "Ticker";
private int _currentSeconds = 10;

// Initialise on modal open from InfoSlotViewerDto:
_currentDisplayMode = slot.DisplayMode;
_currentSeconds = slot.SecondsPerMessage;
```

**Add `EventCallback` parameter** so the parent list (IS cards/table) stays in sync:

```csharp
// Parameter on InfoSlotMessages.razor
[Parameter] public EventCallback<InfoSlotDisplayModeUpdatedArgs> OnDisplayModeChanged { get; set; }

public record InfoSlotDisplayModeUpdatedArgs(Guid InfoSlotId, string DisplayMode, int SecondsPerMessage);
```

**Handlers:**
```csharp
private async Task SetDisplayMode(string mode)
{
    if (mode == _currentDisplayMode) return;
    _currentDisplayMode = mode;
    await Mediator.Send(new UpdateInfoSlotDisplayModeCommand(
        _currentSlot.Id, _currentDisplayMode, _currentSeconds));
    // Notify parent list so badge reflects new mode immediately
    await OnDisplayModeChanged.InvokeAsync(
        new(_currentSlot.Id, _currentDisplayMode, _currentSeconds));
    StateHasChanged();
}

private async Task OnSecondsChanged(ChangeEventArgs e)
{
    if (int.TryParse(e.Value?.ToString(), out var s) && s >= 3)
    {
        _currentSeconds = s;
        await Mediator.Send(new UpdateInfoSlotDisplayModeCommand(
            _currentSlot.Id, _currentDisplayMode, _currentSeconds));
        await OnDisplayModeChanged.InvokeAsync(
            new(_currentSlot.Id, _currentDisplayMode, _currentSeconds));
    }
}
```

`SecondsPerMessage` change: debounce 800 ms before sending command (avoid rapid-fire on spinner clicks). Use `System.Threading.Timer` or `Task.Delay` cancellation pattern.

**Parent page (`InfoSlots.razor`) — wire the callback:**

```csharp
// In _slots list (InfoSlotViewerDto must include DisplayMode + SecondsPerMessage):
private void HandleDisplayModeChanged(InfoSlotDisplayModeUpdatedArgs args)
{
    var slot = _slots.FirstOrDefault(s => s.Id == args.InfoSlotId);
    if (slot is null) return;
    // Replace the DTO in the list with updated values
    var idx = _slots.IndexOf(slot);
    _slots[idx] = slot with
    {
        DisplayMode = args.DisplayMode,
        SecondsPerMessage = args.SecondsPerMessage
    };
    StateHasChanged(); // badge in list updates immediately
}
```

```razor
<InfoSlotMessages Slot="_openSlot"
                  OnDisplayModeChanged="HandleDisplayModeChanged" />
```

**Why this works:** the IS list stays in memory while the modal is open. The callback mutates the list item in place → when modal closes, the parent re-renders with the already-updated `DisplayMode` badge. No round-trip to DB needed.

**`InfoSlotViewerDto` — ensure it includes these fields** (add if missing in CC-010 DTO):
```csharp
public record InfoSlotViewerDto(
    Guid Id, string Name, string DisplayMode, int SecondsPerMessage,
    int ActiveMessageCount, List<string> DashboardNames,
    List<InfoSlotMessageDto> ActiveMessages);
```

---

### 4. Widget — `InfoSlotWidget.razor`

Register `DisplayModeChanged` handler alongside existing events:

```csharp
_hubConnection.On<DisplayModeChangedPayload>("DisplayModeChanged", payload =>
{
    _displayMode = payload.DisplayMode;
    _secondsPerMessage = payload.SecondsPerMessage;
    // restart Sequential timer if running
    if (_displayMode == "Sequential") RestartSequentialTimer();
    else _sequentialTimer?.Dispose();
    InvokeAsync(StateHasChanged);
});

private record DisplayModeChangedPayload(string DisplayMode, int SecondsPerMessage);
```

`_displayMode` drives the render branch (`@if (_displayMode == "Ticker")` vs Sequential). On `DisplayModeChanged` the widget switches rendering mode in real time without page reload.

---

### 5. Localization Keys

| Key | EN | RU |
|---|---|---|
| `InfoSlot_DisplayMode` | Display Mode | Режим отображения |
| `InfoSlot_Ticker` | Ticker | Бегущая строка |
| `InfoSlot_Sequential` | Sequential | Последовательный |
| `InfoSlot_SecondsPerMessage` | Seconds per message | Секунд на сообщение |

---

### 6. Acceptance Criteria

- [ ] Messages modal header shows Ticker / Sequential toggle pre-filled from current IS `DisplayMode`
- [ ] Switching Ticker → Sequential: `SecondsPerMessage` input appears; command sent; DB updated
- [ ] Switching Sequential → Ticker: `SecondsPerMessage` input hidden; command sent; DB updated
- [ ] Changing `SecondsPerMessage` (with 800 ms debounce): command sent; DB updated
- [ ] After changing DisplayMode or SecondsPerMessage: closing the modal shows the **updated** badge in the IS list immediately (no page reload, no stale value)
- [ ] Widget on open dashboard switches rendering mode in real time via `DisplayModeChanged` push (no reload)
- [ ] Sequential timer restarts with new `SecondsPerMessage` after `DisplayModeChanged`
- [ ] Viewer without PG access trying to change mode (direct API) → `ForbiddenException`
- [ ] Audit event `InfoSlot.Updated` with DisplayMode old/new written
- [ ] `SecondsPerMessage < 3` → validation error (not sent)
- [ ] Build clean: `dotnet build CcDashboard.sln` — zero errors

```bash
# MANDATORY before every commit — no exceptions
bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add
```

---

*CC-012 written: 2026-05-29.*
