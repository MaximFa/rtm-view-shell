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

*Document created: 2026-05-26 | Next task: CC-002 (TBD)*
                