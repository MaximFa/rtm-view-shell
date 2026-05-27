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
| [CC-003](#cc-003) | 🔲 Ready | Implement AgentStatusCount + AgentStatusDuration widgets |

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

**Status:** 🔲 Ready  
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
