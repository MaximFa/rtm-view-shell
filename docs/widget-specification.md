# Widget Specification — RTM View Shell

> **Document purpose:** Technical specification for data widgets in the RTM View Shell.
> Each section defines one widget type: its data source, metrics, configuration options,
> rendering requirements, and implementation notes.
>
> **Scope:** Widget definition only. Widget rendering is implemented in the widget library
> (separate project). This document drives `WidgetCatalogItem` entries, `ConfigJson` schema,
> and backend query design.
>
> **Language:** English (document); Russian (discussion).
>
> **Version:** 0.1 — 2026-05-26
> **Status:** Draft

---

## Table of Contents

1. [Data Model Reference](#1-data-model-reference)
2. [Metric Catalogue](#2-metric-catalogue)
3. [DayTrend — Intraday Call Volume Chart](#3-daytrend--intraday-call-volume-chart)

---

## 1. Data Model Reference

### 1.1 Business Unit → Queue resolution

Every widget that shows queue data is scoped to one **Business Unit (BU)**.
The shell resolves the BU to a list of queues at query time:

```
NgcBusinessUnit (BusinessUnitId)
  └── NgcBusinessUnitQueueClassification
            └── QueueId (string)  ←→  RTSData_Interaction.Workgroup
```

All `RTSData_*` queries filter: `WHERE Workgroup IN (queues resolved from BU)`.

### 1.2 RTSData_Interaction — key fields

| Field | Type | Notes |
|---|---|---|
| `OnDate` | varchar | Format `DD/MM/YYYY`. Partition key — always filter on this first. |
| `Workgroup` | varchar | Queue name. Maps to `NgcBusinessUnitQueueClassification.QueueId`. |
| `InteractionType` | varchar | `Call` \| `Callback` |
| `Direction` | varchar | `Incoming` \| `Outgoing` |
| `IsAnswered` | bit | `1` = answered by agent |
| `IsAbandoned` | bit | `1` = caller disconnected before answer |
| `IsCallbackRequest` | bit | `1` = interaction is a callback request |
| `InQueueDateTime` | timestamptz | Entered queue. Use for interval grouping. |
| `AnsweredDateTime` | timestamptz | Answered by agent. Null marker = `1753-01-01 00:00:00.000`. |
| `TimeInQueue` | int | Seconds waiting in queue. |
| `TalkTime` | int | Seconds of talk time. |
| `TenantId` | uuid | Always filter. Global Query Filter applied in `BackendEmulationDbContext`. |

### 1.3 Metric catalogue — RTSGrid_Metric

Available metrics are defined in the `RTSGrid_Metric` table (cross-tenant, read-only from shell).
Each widget type uses metrics filtered by `MetricType`.

**DayTrend metrics** use `MetricType = 'Interaction'`.
The widget settings panel loads available metrics via `GetRtsGridMetricsQuery` filtered by this type.

`MetricFunction` and `MetricParameter` encode the aggregation contract:

| MetricFunction | MetricParameter | SQL produced |
|---|---|---|
| `COUNT_FILTER` | predicate key (see §1.4) | `COUNT(*) FILTER (WHERE <predicate>)` |
| `AVG_FIELD` | field name + predicate key | `AVG(<field>) FILTER (WHERE <predicate>)` |

The application layer maps `MetricParameter` to the actual SQL fragment.
No executable SQL is stored in the table — the table is a **metric registry**, not an engine.

> **Note on `IsCallbackRequest`:** field exists in schema but all sampled production rows
> have `IsCallbackRequest = 0`. Callback interactions are identified via
> `InteractionType = 'Callback'` instead.

---

### 1.4 RTSGrid_Metric seed entries for DayTrend

Seed idempotently on first run (by `MetricId`).

| MetricId | Description | MetricFunction | MetricParameter | ValueType | MetricFormat | MetricType |
|---|---|---|---|---|---|---|
| `interaction.incoming_calls` | Incoming Calls | `COUNT_FILTER` | `call_incoming` | `Number` | `0` | `Interaction` |
| `interaction.answered_calls` | Answered Calls | `COUNT_FILTER` | `answered` | `Number` | `0` | `Interaction` |
| `interaction.abandoned_calls` | Abandoned Calls | `COUNT_FILTER` | `abandoned` | `Number` | `0` | `Interaction` |
| `interaction.callback_requests` | Callback Requests | `COUNT_FILTER` | `callback_incoming` | `Number` | `0` | `Interaction` |
| `interaction.completed_callbacks` | Completed Callbacks | `COUNT_FILTER` | `callback_completed` | `Number` | `0` | `Interaction` |
| `interaction.avg_wait_time` | Avg Wait Time | `AVG_FIELD` | `TimeInQueue:answered` | `Time` | `mm:ss` | `Interaction` |
| `interaction.max_wait_time` | Max Wait Time | `MAX_FIELD` | `TimeInQueue:answered` | `Time` | `mm:ss` | `Interaction` |
| `interaction.avg_talk_time` | Avg Talk Time | `AVG_FIELD` | `TalkTime:answered` | `Time` | `mm:ss` | `Interaction` |

**MetricParameter predicate keys** (resolved in application code):

| Predicate key | SQL filter |
|---|---|
| `call_incoming` | `InteractionType = 'Call' AND Direction = 'Incoming'` |
| `answered` | `IsAnswered = true` |
| `abandoned` | `IsAbandoned = true` |
| `callback_incoming` | `InteractionType = 'Callback' AND Direction = 'Incoming'` |
| `callback_completed` | `InteractionType = 'Callback' AND Direction = 'Outgoing' AND IsAnswered = true` |
| `TimeInQueue:answered` | `AVG(TimeInQueue) WHERE IsAnswered = true` |
| `TalkTime:answered` | `AVG(TalkTime) WHERE IsAnswered = true` |

**C# seed snippet:**

```csharp
var interactionMetrics = new[]
{
    new RtsGridMetric { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",       MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",        ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new RtsGridMetric { MetricId = "interaction.answered_calls",      Description = "Answered Calls",       MetricFunction = "COUNT_FILTER", MetricParameter = "answered",             ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new RtsGridMetric { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",      MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",            ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new RtsGridMetric { MetricId = "interaction.callback_requests",   Description = "Callback Requests",    MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",    ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new RtsGridMetric { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",  MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",   ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new RtsGridMetric { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",        MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered", ValueType = "Time",   MetricFormat = "mm:ss", MetricType = "Interaction", DataType = "decimal" },
    new RtsGridMetric { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",        MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",    ValueType = "Time",   MetricFormat = "mm:ss", MetricType = "Interaction", DataType = "decimal" },
};

foreach (var m in interactionMetrics)
{
    if (!await db.RtsGridMetrics.AnyAsync(x => x.MetricId == m.MetricId))
        await db.RtsGridMetrics.AddAsync(m);
}
await db.SaveChangesAsync();
```

---

## 2. Metric Catalogue

All metrics available for use in widgets are registered in `RTSGrid_Metric` (cross-tenant table).
This section is the **authoritative reference** for metric definitions, their source fields,
filter logic, and aggregation method.

Metrics are grouped by source table and `MetricType` value used to filter them in queries.

---

### 2.1 Interaction metrics (`MetricType = 'Interaction'`)

**Source table:** `RTSData_Interaction`
**Filter scope:** always filtered by `TenantId` + `Workgroup IN (queues from BU)` + `OnDate`

Derived from boolean flags and enum fields. Production values confirmed from data sample
(`RTSData_Interaction_DataExample.csv`, 239 rows, 14 queues).

#### Source fields used

| Field | Values (production) | Role |
|---|---|---|
| `InteractionType` | `Call`, `Callback` | Distinguishes voice calls from callback interactions |
| `Direction` | `Incoming`, `Outgoing` | Inbound vs outbound |
| `IsAnswered` | `0`, `1` | Whether an agent answered |
| `IsAbandoned` | `0`, `1` | Whether caller disconnected before answer |
| `IsTransferred` | `0`, `1` | Whether interaction was transferred |
| `IsMessaging` | `0` only (in sample) | Messaging channel flag (reserved) |
| `IsCallbackRequest` | `0` only (in sample) | Legacy flag; use `InteractionType='Callback'` instead |
| `TimeInQueue` | 0 – 35 960 s | Seconds in queue before answer or abandonment |
| `TalkTime` | 0 – 2 495 s | Seconds of active talk time |

#### Metric definitions

| MetricId | Description | MetricFunction | MetricParameter (predicate key) | ValueType | Format |
|---|---|---|---|---|---|
| `interaction.incoming_calls` | Incoming Calls | `COUNT_FILTER` | `call_incoming` | `Number` | `0` |
| `interaction.answered_calls` | Answered Calls | `COUNT_FILTER` | `answered` | `Number` | `0` |
| `interaction.abandoned_calls` | Abandoned Calls | `COUNT_FILTER` | `abandoned` | `Number` | `0` |
| `interaction.callback_requests` | Callback Requests | `COUNT_FILTER` | `callback_incoming` | `Number` | `0` |
| `interaction.completed_callbacks` | Completed Callbacks | `COUNT_FILTER` | `callback_completed` | `Number` | `0` |
| `interaction.outbound_calls` | Outbound Calls | `COUNT_FILTER` | `call_outgoing` | `Number` | `0` |
| `interaction.transferred_calls` | Transferred Calls | `COUNT_FILTER` | `transferred` | `Number` | `0` |
| `interaction.avg_wait_time` | Avg Wait Time | `AVG_FIELD` | `TimeInQueue:answered` | `Time` | `mm:ss` |
| `interaction.max_wait_time` | Max Wait Time | `MAX_FIELD` | `TimeInQueue:answered` | `Time` | `mm:ss` |
| `interaction.avg_talk_time` | Avg Talk Time | `AVG_FIELD` | `TalkTime:answered` | `Time` | `mm:ss` |
| `interaction.avg_abandon_wait` | Avg Wait Before Abandon | `AVG_FIELD` | `TimeInQueue:abandoned` | `Time` | `mm:ss` |

#### Predicate key → SQL filter mapping

| Predicate key | SQL filter applied to `RTSData_Interaction` |
|---|---|
| `call_incoming` | `InteractionType = 'Call' AND Direction = 'Incoming'` |
| `call_outgoing` | `InteractionType = 'Call' AND Direction = 'Outgoing'` |
| `answered` | `IsAnswered = true` |
| `abandoned` | `IsAbandoned = true` |
| `callback_incoming` | `InteractionType = 'Callback' AND Direction = 'Incoming'` |
| `callback_completed` | `InteractionType = 'Callback' AND Direction = 'Outgoing' AND IsAnswered = true` |
| `transferred` | `IsTransferred = true` |
| `TimeInQueue:answered` | `AVG(TimeInQueue) FILTER (WHERE IsAnswered = true)` |
| `TalkTime:answered` | `AVG(TalkTime) FILTER (WHERE IsAnswered = true)` |
| `TimeInQueue:abandoned` | `AVG(TimeInQueue) FILTER (WHERE IsAbandoned = true)` |

> **`IsCallbackRequest` note:** field exists in schema but all production rows have value `0`.
> Callback interactions are reliably identified via `InteractionType = 'Callback'` instead.
> `IsCallbackRequest` is reserved for future use.

---

### 2.2 Agent status metrics (`MetricType = 'AgentStatus'`)

**Source table:** `RTSData_UserStatus`
**Filter scope:** `TenantId` + `OnDate` + agent group filter (via BU → Supergroup → AgentGroup chain)

`RTSData_UserStatus` records **cumulative daily totals per agent per status**.
Each row = one agent + one status, for one day. Fields:

| Field | Values (production) | Role |
|---|---|---|
| `StatusName` | 15 distinct values (see below) | Named status as defined in CC platform |
| `StatusGroup` | `AVAILABLE`, `ONPHONE`, `BREAK`, `PAPERWORK`, `TRAINING` | Canonical group written by CC backend — see [CC-001] |
| `TotalDuration` | 3 – 25 155 s | Cumulative seconds in this status today |
| `TotalCount` | 1 – 61 | Number of times agent entered this status today |
| `MaxDuraction` | integer (s) | Longest single session in this status |

#### StatusGroup → business meaning

| StatusGroup | Business meaning | Agent state |
|---|---|---|
| `AVAILABLE` | Agent ready to take calls | Ready / Waiting |
| `ONPHONE` | Agent handling an interaction | Talking, Hold, Ringing, Callbacks |
| `BREAK` | Agent on scheduled break | Break |
| `PAPERWORK` | After-call work / admin wrap-up. Also surfaces as UNAVAILABLE in some platform UIs. | ACW, Wrap Up, Callback wrap |
| `TRAINING` | Training, meeting, coaching, back-office tasks | Non-call unavailable |

#### StatusName values (confirmed in production data)

| StatusName | StatusGroup | Notes |
|---|---|---|
| `Available` | `AVAILABLE` | Ready state |
| `Waiting for Transfer` | `AVAILABLE` | Available but waiting for transfer to complete |
| `Incoming Ext Call` | `ONPHONE` | Handling inbound call |
| `Calling Out` | `ONPHONE` | Making outbound call |
| `Out Ext Call` | `ONPHONE` | Connected outbound call |
| `Hold` | `ONPHONE` | Customer on hold |
| `Ringing` | `ONPHONE` | Phone ringing, not yet answered |
| `Callback Incoming` | `ONPHONE` | Receiving a callback call |
| `Callback Outgoing` | `ONPHONE` | Making a callback call |
| `Wrap Up` | `PAPERWORK` | After-call wrap / ACW |
| `Callback` | `PAPERWORK` | Callback-related wrap-up |
| `Unavailable` | `PAPERWORK` | Generic unavailable (displays as UNAVAILABLE in some UIs) |
| `Break` | `BREAK` | Scheduled break |
| `Back Office` | `TRAINING` | Back-office, admin, non-call unavailable task |
| _(logged out / unknown)_ | `NULL` | Logged-out agents may not appear in RTSData_UserStatus; unclassified StatusIds → NULL |

#### Metric definitions

| MetricId | Description | MetricFunction | MetricParameter | ValueType | Format |
|---|---|---|---|---|---|
| `agentstatus.available_time` | Available Time | `SUM_DURATION` | `group:AVAILABLE` | `Time` | `hh:mm:ss` |
| `agentstatus.onphone_time` | On Phone Time | `SUM_DURATION` | `group:ONPHONE` | `Time` | `hh:mm:ss` |
| `agentstatus.break_time` | Break Time | `SUM_DURATION` | `group:BREAK` | `Time` | `hh:mm:ss` |
| `agentstatus.paperwork_time` | Paperwork / ACW Time | `SUM_DURATION` | `group:PAPERWORK` | `Time` | `hh:mm:ss` |
| `agentstatus.training_time` | Training / Back-Office Time | `SUM_DURATION` | `group:TRAINING` | `Time` | `hh:mm:ss` |
| `agentstatus.login_time` | Total Login Time | `SUM_DURATION` | `group:ALL_LOGGED_IN` | `Time` | `hh:mm:ss` |
| `agentstatus.wrap_time` | Wrap Up (ACW) Time | `SUM_DURATION` | `status:Wrap Up` | `Time` | `hh:mm:ss` |
| `agentstatus.call_count` | Calls Handled | `SUM_COUNT` | `status:Incoming Ext Call` | `Number` | `0` |
| `agentstatus.occupancy_pct` | Occupancy % | `RATIO` | `group:ONPHONE/group:ONPHONE+AVAILABLE` | `Number` | `0.0%` |

#### Predicate key → SQL filter mapping (`RTSData_UserStatus`)

| Predicate key | SQL filter |
|---|---|
| `group:AVAILABLE` | `StatusGroup = 'AVAILABLE'` |
| `group:ONPHONE` | `StatusGroup = 'ONPHONE'` |
| `group:BREAK` | `StatusGroup = 'BREAK'` |
| `group:PAPERWORK` | `StatusGroup = 'PAPERWORK'` |
| `group:TRAINING` | `StatusGroup = 'TRAINING'` |
| `group:ALL_LOGGED_IN` | `StatusGroup IS NOT NULL` |
| `status:Wrap Up` | `StatusName = 'Wrap Up'` |
| `status:Incoming Ext Call` | `StatusName = 'Incoming Ext Call'` |
| `group:ONPHONE/group:ONPHONE+AVAILABLE` | Ratio: `SUM(ONPHONE) / SUM(ONPHONE + AVAILABLE)` |

---

### 2.3 Agent status log metrics (`MetricType = 'AgentStatusLog'`)

**Source table:** `RTSData_UserStatusLog`  
**Purpose:** Time-series of individual status transitions. Used for interval-based
agent count metrics — e.g. "how many agents were on BREAK from 10:00 to 10:30".

**Key fields:**

| Field | Notes |
|---|---|
| `UserId` | Agent identifier (email or short username, depends on server config) |
| `StartTime` | Status session start timestamp |
| `EndTime` | Status session end timestamp. `NULL` = session still ongoing |
| `StatusGroup` | Canonical group — `AVAILABLE`, `ONPHONE`, `BREAK`, `PAPERWORK`, `TRAINING` or `NULL` |
| `Duration` | Session duration in **milliseconds** |
| `OnDate` | Date partition key in `DD/MM/YYYY` format |

> **Note:** Use `StatusGroup` for all filtering (canonical, deployment-independent).
> `StatusId` (raw localised name) is available for display purposes only.

#### Agent pool resolution — replacing UserId → AgentGroup mapping

`RTSData_UserStatusLog` has no direct link to `NgcSupergroup` or `NgcAgentGroup`.
An agent may belong to multiple groups, so a join table cannot exist without ambiguity.

**Solution:** For a given BU + interval, define the agent pool as:

> **DISTINCT `UserId` values from `RTSData_Interaction` WHERE `Workgroup` IN
> (BU's queue list) AND `IsAnswered = true` AND `Direction = 'Incoming'`
> AND `InQueueDateTime` falls within that interval.**

This ties agent selection to actual call activity on this BU's queues — agents who
answered at least one inbound call in this interval are counted. An agent working
multiple groups is counted once (DISTINCT).

> **Counting rule:** if one agent enters BREAK ten times within an interval, the result
> is **1 agent** (not 10). All status counts use `COUNT(DISTINCT "UserId")`.

#### SQL query — agent counts per interval

```sql
-- @tenantId      uuid
-- @onDate        varchar  -- DD/MM/YYYY
-- @queueList     text[]   -- BU queue names from NgcBusinessUnitQueueClassification
-- @intervalMinutes int    -- 15 | 30 | 60

WITH interval_agents AS (
    -- Active agents per interval: those who answered incoming calls on BU queues
    SELECT
        DATE_TRUNC('hour', "InQueueDateTime") +
            (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / @intervalMinutes)
             * (@intervalMinutes || ' minutes')::interval) AS interval_start,
        "UserId"
    FROM "RTSData_Interaction"
    WHERE "TenantId"  = @tenantId
      AND "OnDate"    = @onDate
      AND "Workgroup" = ANY(@queueList)
      AND "IsAnswered" = true
      AND "Direction"  = 'Incoming'
      AND "InQueueDateTime" IS NOT NULL
),
agent_pool AS (
    SELECT DISTINCT interval_start, "UserId" FROM interval_agents
),
agent_status AS (
    -- Match each pooled agent to their status sessions overlapping the interval
    SELECT
        ap.interval_start,
        usl."UserId",
        usl."StatusGroup"
    FROM agent_pool ap
    JOIN "RTSData_UserStatusLog" usl ON usl."UserId" = ap."UserId"
    WHERE usl."TenantId"    = @tenantId
      AND usl."OnDate"      = @onDate
      AND usl."StatusGroup" IS NOT NULL
      AND usl."StartTime"   < ap.interval_start
                               + (@intervalMinutes || ' minutes')::interval
      AND (usl."EndTime" IS NULL
           OR usl."EndTime" > ap.interval_start)
)
SELECT
    interval_start,
    COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'AVAILABLE')  AS available_agents,
    COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'ONPHONE')    AS onphone_agents,
    COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'BREAK')      AS break_agents,
    COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'PAPERWORK')  AS paperwork_agents,
    COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'TRAINING')   AS training_agents,
    COUNT(DISTINCT "UserId")                                              AS total_agents
FROM agent_status
GROUP BY interval_start
ORDER BY interval_start;
```

#### Metric definitions

| MetricId | Description | Function | Parameter | ValueType | Format |
|---|---|---|---|---|---|
| `statuslog.available_agents` | Available Agents | `COUNT_DISTINCT` | `group:AVAILABLE` | `Number` | `0` |
| `statuslog.onphone_agents` | On Phone Agents | `COUNT_DISTINCT` | `group:ONPHONE` | `Number` | `0` |
| `statuslog.break_agents` | Agents on Break | `COUNT_DISTINCT` | `group:BREAK` | `Number` | `0` |
| `statuslog.paperwork_agents` | Paperwork / ACW Agents | `COUNT_DISTINCT` | `group:PAPERWORK` | `Number` | `0` |
| `statuslog.training_agents` | Training / Back-Office Agents | `COUNT_DISTINCT` | `group:TRAINING` | `Number` | `0` |
| `statuslog.total_agents`        | Total Active Agents (with StatusGroup)   | `COUNT_DISTINCT` | `group:ALL`  | `Number` | `0` |
| `statuslog.logged_in_agents`    | Logged-In Agents (answered calls)        | `COUNT_POOL`     | `pool:all`   | `Number` | `0` |
| `statuslog.available_time_ms`   | Available Time           | `SUM_OVERLAP_MS` | `group:AVAILABLE`  | `Time` | `mm:ss` |
| `statuslog.onphone_time_ms`     | On Phone Time            | `SUM_OVERLAP_MS` | `group:ONPHONE`    | `Time` | `mm:ss` |
| `statuslog.break_time_ms`       | Break Time               | `SUM_OVERLAP_MS` | `group:BREAK`      | `Time` | `mm:ss` |
| `statuslog.paperwork_time_ms`   | Paperwork / ACW Time     | `SUM_OVERLAP_MS` | `group:PAPERWORK`  | `Time` | `mm:ss` |
| `statuslog.training_time_ms`    | Training / Back-Office Time | `SUM_OVERLAP_MS` | `group:TRAINING` | `Time` | `mm:ss` |
| `statuslog.total_active_time_ms`| Total Active Time        | `SUM_OVERLAP_MS` | `group:ALL`        | `Time` | `mm:ss` |

> **`SUM_OVERLAP_MS`**: sum of milliseconds each agent spent in the given StatusGroup
> during the interval, clipped to interval boundaries via
> `GREATEST(StartTime, interval_start)` / `LEAST(EndTime, interval_end)`.
> Divide by 1000 for seconds, by 60 000 for minutes. Display as `mm:ss`.

**Predicate key → SQL filter:**

| Predicate key | SQL (in agent_status CTE) |
|---|---|
| `group:AVAILABLE` | `StatusGroup = 'AVAILABLE'` |
| `group:ONPHONE` | `StatusGroup = 'ONPHONE'` |
| `group:BREAK` | `StatusGroup = 'BREAK'` |
| `group:PAPERWORK` | `StatusGroup = 'PAPERWORK'` |
| `group:TRAINING` | `StatusGroup = 'TRAINING'` |
| `group:ALL`  | _(no filter — COUNT all in agent_status CTE)_ |
| `pool:all`   | COUNT(DISTINCT UserId) from agent_pool CTE — agents who answered calls, regardless of StatusGroup records |

---

### 2.4 RTSGrid_Metric — complete seed catalogue

All entries below must be seeded idempotently (upsert by `MetricId`) on application startup.

```csharp
// Interaction metrics
new RtsGridMetric { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.answered_calls",      Description = "Answered Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "answered",                               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",                              MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.callback_requests",   Description = "Callback Requests",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",                      MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",      DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",                     MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.outbound_calls",      Description = "Outbound Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_outgoing",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.transferred_calls",   Description = "Transferred Calls",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "transferred",                            MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.max_wait_time",       Description = "Max Wait Time",            DataType = "decimal", MetricFunction = "MAX_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon",  DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

// Agent status metrics
new RtsGridMetric { MetricId = "agentstatus.available_time",      Description = "Available Time",           DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:AVAILABLE",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.onphone_time",        Description = "On Phone Time",            DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ONPHONE",                          MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.break_time",          Description = "Break Time",               DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:BREAK",                            MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.training_time",       Description = "Training / Back-Office",   DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:TRAINING",                         MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.paperwork_time",      Description = "Paperwork / ACW Time",     DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:PAPERWORK",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
// agentstatus.signoff_time removed — SIGNOFF is not a canonical StatusGroup value (CC-001)
new RtsGridMetric { MetricId = "agentstatus.login_time",          Description = "Total Login Time",         DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ALL_LOGGED_IN",               MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.wrap_time",           Description = "Wrap Up (ACW) Time",       DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "status:Wrap Up",                         MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.call_count",          Description = "Calls Handled",            DataType = "int",     MetricFunction = "SUM_COUNT",    MetricParameter = "status:Incoming Ext Call",               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.occupancy_pct",       Description = "Occupancy %",              DataType = "decimal", MetricFunction = "RATIO",        MetricParameter = "group:ONPHONE/group:ONPHONE+AVAILABLE",  MetricFormat = "0.0%",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },

// Agent status log interval metrics (source: RTSData_UserStatusLog, agent pool via Interaction)
new RtsGridMetric { MetricId = "statuslog.available_agents",  Description = "Available Agents",             DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:AVAILABLE",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.onphone_agents",    Description = "On Phone Agents",              DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ONPHONE",    MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.break_agents",      Description = "Agents on Break",              DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:BREAK",      MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.paperwork_agents",  Description = "Paperwork / ACW Agents",       DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:PAPERWORK",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.training_agents",   Description = "Training / Back-Office Agents",DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:TRAINING",   MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.total_agents",        Description = "Total Active Agents (with status)", DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ALL",  MetricFormat = "0",  DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.logged_in_agents",    Description = "Logged-In Agents (answered calls)", DataType = "int", MetricFunction = "COUNT_POOL",     MetricParameter = "pool:all",   MetricFormat = "0",  DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
// Agent status log — accumulated time per interval (SUM_OVERLAP_MS)
new RtsGridMetric { MetricId = "statuslog.available_time_ms",   Description = "Available Time",           DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:AVAILABLE",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.onphone_time_ms",     Description = "On Phone Time",            DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ONPHONE",    MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.break_time_ms",       Description = "Break Time",               DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:BREAK",      MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.paperwork_time_ms",   Description = "Paperwork / ACW Time",     DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:PAPERWORK",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.training_time_ms",    Description = "Training / Back-Office Time", DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:TRAINING",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new RtsGridMetric { MetricId = "statuslog.total_active_time_ms",Description = "Total Active Time",        DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ALL",        MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
```

---

## 3. DayTrend — Intraday Call Volume Chart

### 3.1 Overview

**Widget type ID:** `DayTrend`
**Category:** General Metrics
**Purpose:** Displays call volume metrics broken down by configurable time intervals
from the start of the business day to the current moment. Allows supervisors and
managers to spot hourly patterns, peak periods, and deviations from normal traffic.

**Primary users:**
- Shift Manager — monitors current hour vs earlier peaks; supports break rotation decisions
- Department Manager — identifies recurring patterns (e.g. Monday 14:00 spike)
- Director — validates that today matches the weekly profile

**Data sources:**
- `RTSData_Interaction` — interaction (call) volume metrics
- `RTSData_UserStatusLog` — agent count by status group per interval (agent pool resolved via Interaction)

Both queries are direct read-only. No SignalR subscription.  
**RTS tables required:** None (`RTSGrid_*` / `RTSUserGrid_*` not used).

---

### 3.2 Visual layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  [Widget Title]                           [Chart type ▼] [Refresh ↺] │
│  BU: Sales CC  ·  Today 26/05/2026  ·  Interval: 30 min              │
│                                                                        │
│  20 ┤                    ▲                                             │
│  16 ┤         ●──────────●   ●                                         │
│  12 ┤    ●────               ●──────●                                  │
│   8 ┤●───                           ●────                              │
│   4 ┤                                    ●──●                          │
│   0 └──────────────────────────────────────────────────────           │
│      08:30  09:00  09:30  10:00  10:30  11:00  11:30  12:00  12:30    │
│                                                                        │
│  ● Incoming Calls  ● Answered Calls  ● Abandoned Calls                 │
│    [12]              [10]              [2]    ← numeric values         │
│  ○ Available [4]   ○ On Phone [6]   ○ On Break [2]  ← agent counts    │
│                                                                        │
│  Last updated: 14:47:03                                               │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 3.3 Configuration options (widget settings panel)

#### 3.3.1 General

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string | Yes | Widget title displayed in the header |
| `businessUnitId` | int | Yes | BU whose queues are included in the query |
| `intervalMinutes` | int | Yes | Time interval in minutes. Options: `15`, `30`, `60`. Default: `30` |
| `refreshIntervalSeconds` | int | Yes | Auto-refresh period. Options: `60`, `300`, `600`, `0` (manual only). Default: `300` |

#### 3.3.2 Chart appearance

| Field | Type | Required | Description |
|---|---|---|---|
| `chartType` | enum | Yes | `line` \| `bar` \| `area` \| `step`. Default: `line` |
| `showDataLabels` | bool | No | Show numeric value at each data point. Default: `true` |
| `showLegend` | bool | No | Show colour legend below chart. Default: `true` |

#### 3.3.3 Interaction metrics (`metrics` array)

Available metrics loaded from `RTSGrid_Metric WHERE MetricType = 'Interaction'`.
Each entry in the `metrics` array of ConfigJson:

| Field | Type | Required | Description |
|---|---|---|---|
| `metricId` | string | Yes | e.g. `interaction.incoming_calls` |
| `enabled` | bool | Yes | Whether this metric is shown. Default: `true` |
| `color` | string | Yes | Hex colour code |
| `label` | string | No | Override display name; falls back to `RTSGrid_Metric.Description` |

**Default `metrics` set:**

| # | metricId | Default label | Colour | Enabled |
|---|---|---|---|---|
| 1 | `interaction.incoming_calls` | Incoming Calls | `#3b82f6` | `true` |
| 2 | `interaction.answered_calls` | Answered Calls | `#22c55e` | `true` |
| 3 | `interaction.abandoned_calls` | Abandoned Calls | `#ef4444` | `true` |
| 4 | `interaction.callback_requests` | Callback Requests | `#f59e0b` | `false` |
| 5 | `interaction.completed_callbacks` | Completed Callbacks | `#8b5cf6` | `false` |
| 6 | `interaction.avg_wait_time` | Avg Wait Time | `#06b6d4` | `false` |
| 7 | `interaction.max_wait_time` | Max Wait Time | `#0891b2` | `false` |
| 8 | `interaction.avg_talk_time` | Avg Talk Time | `#64748b` | `false` |

> `avg_wait_time` / `max_wait_time` / `avg_talk_time` are time-based (seconds → `mm:ss`). When enabled
> together with count metrics, render on **dual Y-axes** (counts left, seconds right).

#### 3.3.4 Agent status metrics (`agentMetrics` array)

Available metrics loaded from `RTSGrid_Metric WHERE MetricType = 'AgentStatusLog'`.
Same entry structure as `metrics`. Agent counts are integers (same Y-axis as call counts).
Time metrics (`*_time_ms`) hold milliseconds — render as `mm:ss` on the right Y-axis.

**Default `agentMetrics` set:**

| # | metricId | Default label | Colour | Enabled |
|---|---|---|---|---|
| 1 | `statuslog.available_agents` | Available | `#4ade80` | `false` |
| 2 | `statuslog.onphone_agents` | On Phone | `#60a5fa` | `false` |
| 3 | `statuslog.break_agents` | On Break | `#fb923c` | `false` |
| 4 | `statuslog.paperwork_agents` | Paperwork | `#a78bfa` | `false` |
| 5 | `statuslog.training_agents` | Training | `#94a3b8` | `false` |
| 6  | `statuslog.total_agents`          | Total Active     | `#f1f5f9` | `false` |
| 7  | `statuslog.logged_in_agents`       | Logged In        | `#fef08a` | `false` |
| 8  | `statuslog.available_time_ms`     | Avail. Time      | `#4ade80` | `false` |
| 9  | `statuslog.onphone_time_ms`       | OnPhone Time     | `#60a5fa` | `false` |
| 10 | `statuslog.break_time_ms`         | Break Time       | `#fb923c` | `false` |
| 11 | `statuslog.paperwork_time_ms`     | Paperwork Time   | `#a78bfa` | `false` |
| 12 | `statuslog.training_time_ms`      | Training Time    | `#94a3b8` | `false` |
| 13 | `statuslog.total_active_time_ms`  | Total Act. Time  | `#e2e8f0` | `false` |

> All agent metrics use **dashed lines** (or hatched bars) to distinguish them visually
> from call volume metrics. Both series share the left Y-axis (counts).

---

### 3.4 Data query

All DB access uses **PostgreSQL functions** (Stored Procedures pattern).
Functions are owned by the shell solution, created via `BackendEmulationDbContext` migration,
and called from the application layer via `Database.SqlQuery<T>`. No inline SQL in C# code.

**Naming convention:** `fn_<widgettype><purpose>` — all lowercase, underscore-separated.

#### 3.4.1 `fn_daytrendinteractions` — interaction metrics per interval

```sql
CREATE OR REPLACE FUNCTION fn_daytrendinteractions(
    p_tenantid    uuid,
    p_ondate      varchar(50),   -- DD/MM/YYYY
    p_queuelist   text[],
    p_intervalmin integer        -- 15 | 30 | 60
)
RETURNS TABLE (
    interval_start      timestamptz,
    incoming_calls      bigint,
    answered_calls      bigint,
    abandoned_calls     bigint,
    callback_requests   bigint,
    completed_callbacks bigint,
    avg_wait_time       double precision,
    max_wait_time       double precision,
    avg_talk_time       double precision
)
LANGUAGE sql STABLE
AS $$
    SELECT
        DATE_TRUNC('hour', "InQueueDateTime") +
            (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
             * (p_intervalmin || ' minutes')::interval)       AS interval_start,
        COUNT(*) FILTER (WHERE "InteractionType" = 'Call' AND "Direction" = 'Incoming'),
        COUNT(*) FILTER (WHERE "IsAnswered" = true),
        COUNT(*) FILTER (WHERE "IsAbandoned" = true),
        COUNT(*) FILTER (WHERE "InteractionType" = 'Callback' AND "Direction" = 'Incoming'),
        COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                           AND "Direction" = 'Outgoing' AND "IsAnswered" = true),
        AVG("TimeInQueue") FILTER (WHERE "IsAnswered" = true),
        MAX("TimeInQueue") FILTER (WHERE "IsAnswered" = true),
        AVG("TalkTime")    FILTER (WHERE "IsAnswered" = true)
    FROM "RTSData_Interaction"
    WHERE "TenantId"  = p_tenantid
      AND "OnDate"    = p_ondate
      AND "Workgroup" = ANY(p_queuelist)
      AND "InQueueDateTime" IS NOT NULL
    GROUP BY interval_start
    ORDER BY interval_start;
$$;

#### 3.4.2 `fn_daytrendagentstatus` — agent counts and accumulated time per interval

Run in parallel with `fn_daytrendinteractions` when at least one `agentMetrics` entry
has `enabled = true`.

Each `*_time_ms` column contains the **sum of milliseconds** all agents in the pool spent
in that StatusGroup during the interval, clipped to the interval boundaries (overlap
calculation). This gives direct correlation with queue metrics: e.g. total break time
rising as avg wait time rises.

```sql
CREATE OR REPLACE FUNCTION fn_daytrendagentstatus(
    p_tenantid    uuid,
    p_ondate      varchar(50),   -- DD/MM/YYYY
    p_queuelist   text[],
    p_intervalmin integer        -- 15 | 30 | 60
)
RETURNS TABLE (
    interval_start        timestamptz,
    available_agents      bigint,
    onphone_agents        bigint,
    break_agents          bigint,
    paperwork_agents      bigint,
    training_agents       bigint,
    total_agents          bigint,
    logged_in_agents      bigint,   -- all agents who answered calls (agent pool size)
    available_time_ms     bigint,
    onphone_time_ms       bigint,
    break_time_ms         bigint,
    paperwork_time_ms     bigint,
    training_time_ms      bigint,
    total_active_time_ms  bigint
)
LANGUAGE sql STABLE
AS $$
    WITH interval_agents AS (
        SELECT
            DATE_TRUNC('hour', "InQueueDateTime") +
                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                 * (p_intervalmin || ' minutes')::interval) AS interval_start,
            "UserId"
        FROM "RTSData_Interaction"
        WHERE "TenantId"  = p_tenantid
          AND "OnDate"    = p_ondate
          AND "Workgroup" = ANY(p_queuelist)
          AND "IsAnswered" = true
          AND "Direction"  = 'Incoming'
          AND "InQueueDateTime" IS NOT NULL
    ),
    agent_pool AS (
        SELECT DISTINCT interval_start, "UserId" FROM interval_agents
    ),
    -- pool_summary: all agents who answered calls per interval
    -- (counted regardless of having UserStatusLog records)
    pool_summary AS (
        SELECT interval_start,
               COUNT(DISTINCT "UserId") AS logged_in_agents
        FROM agent_pool
        GROUP BY interval_start
    ),
    agent_status AS (
        SELECT
            ap.interval_start,
            ap.interval_start + (p_intervalmin || ' minutes')::interval AS interval_end,
            usl."UserId",
            usl."StatusGroup",
            -- overlap: ms the agent spent in this status WITHIN the interval
            GREATEST(0,
                EXTRACT(EPOCH FROM (
                    LEAST(
                        COALESCE(usl."EndTime",
                                 ap.interval_start + (p_intervalmin || ' minutes')::interval),
                        ap.interval_start + (p_intervalmin || ' minutes')::interval
                    )
                    - GREATEST(usl."StartTime", ap.interval_start)
                ))::bigint * 1000
            )                                                AS overlap_ms
        FROM agent_pool ap
        JOIN "RTSData_UserStatusLog" usl ON usl."UserId" = ap."UserId"
        WHERE usl."TenantId"    = p_tenantid
          AND usl."OnDate"      = p_ondate
          AND usl."StatusGroup" IS NOT NULL
          AND usl."StartTime"   < ap.interval_start
                                   + (p_intervalmin || ' minutes')::interval
          AND (usl."EndTime" IS NULL OR usl."EndTime" > ap.interval_start)
    ),
    status_summary AS (
        SELECT
            interval_start,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'AVAILABLE') AS available_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'ONPHONE')   AS onphone_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'BREAK')     AS break_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'PAPERWORK') AS paperwork_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'TRAINING')  AS training_agents,
            COUNT(DISTINCT "UserId")                                             AS total_agents,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'AVAILABLE'),  0) AS available_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'ONPHONE'),    0) AS onphone_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'BREAK'),      0) AS break_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'PAPERWORK'),  0) AS paperwork_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'TRAINING'),   0) AS training_time_ms,
            COALESCE(SUM(overlap_ms),                                              0) AS total_active_time_ms
        FROM agent_status
        GROUP BY interval_start
    )
    -- LEFT JOIN ensures intervals without StatusGroup records still appear
    SELECT
        ps.interval_start,
        COALESCE(ss.available_agents,     0),
        COALESCE(ss.onphone_agents,       0),
        COALESCE(ss.break_agents,         0),
        COALESCE(ss.paperwork_agents,     0),
        COALESCE(ss.training_agents,      0),
        COALESCE(ss.total_agents,         0),
        ps.logged_in_agents,
        COALESCE(ss.available_time_ms,    0),
        COALESCE(ss.onphone_time_ms,      0),
        COALESCE(ss.break_time_ms,        0),
        COALESCE(ss.paperwork_time_ms,    0),
        COALESCE(ss.training_time_ms,     0),
        COALESCE(ss.total_active_time_ms, 0)
    FROM pool_summary ps
    LEFT JOIN status_summary ss USING (interval_start)
    ORDER BY ps.interval_start;
$$;
```

**Overlap calculation note:** `overlap_ms = GREATEST(0, EXTRACT(EPOCH FROM (LEAST(EndTime, interval_end) - GREATEST(StartTime, interval_start))) * 1000)`.
If `EndTime IS NULL` the agent is still in the status → treated as `interval_end`.

**Result record:**

```csharp
public record DayTrendAgentInterval(
    DateTime IntervalStart,
    long AvailableAgents,
    long OnPhoneAgents,
    long BreakAgents,
    long PaperworkAgents,
    long TrainingAgents,
    long TotalAgents,
    long AvailableTimeMs,
    long OnPhoneTimeMs,
    long BreakTimeMs,
    long PaperworkTimeMs,
    long TrainingTimeMs,
    long TotalActiveTimeMs);
```

#### 3.4.4 Important notes

- `OnDate` is stored as `varchar` in format `DD/MM/YYYY`. Always pass the date in this format.
- `AnsweredDateTime` null is stored as `1753-01-01 00:00:00.000` — treat as absent, not a real date. Do not use `AnsweredDateTime` for interval grouping.
- `InQueueDateTime` is the canonical timestamp for grouping (when the interaction entered the queue).
- If `@queueList` is empty (BU has no queue assignments), return empty dataset and display
  a warning: _"No queues assigned to this Business Unit"_.
- EF Core / raw SQL: use `FromSqlInterpolated` or parameterised `ExecuteSqlRaw`. Never string concatenation. **[CODE-01]**

#### 3.4.5 Application layer — calling the functions

```csharp
// Result records (map 1:1 to RETURNS TABLE columns)
public record DayTrendInterval(
    DateTime IntervalStart,
    long IncomingCalls, long AnsweredCalls, long AbandonedCalls,
    long CallbackRequests, long CompletedCallbacks,
    double? AvgWaitTime, double? MaxWaitTime, double? AvgTalkTime);

public record DayTrendAgentInterval(
    DateTime IntervalStart,
    long AvailableAgents, long OnPhoneAgents, long BreakAgents,
    long PaperworkAgents, long TrainingAgents, long TotalAgents,
    long LoggedInAgents,   // COUNT from agent_pool (all who answered calls)
    long AvailableTimeMs, long OnPhoneTimeMs, long BreakTimeMs,
    long PaperworkTimeMs, long TrainingTimeMs, long TotalActiveTimeMs);

// In DayTrendQueryHandler.Handle():
var queues = await _ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
if (!queues.Any())
    return DayTrendResult.NoQueues();

var tenantId   = _tenantContext.TenantId;
var onDate     = DateTime.UtcNow.ToString("dd/MM/yyyy");  // DD/MM/YYYY
var queueArray = queues.ToArray();
var interval   = query.IntervalMinutes;

// Both functions called via parameterised SqlQuery — safe per [CODE-01]
var interactionTask = _beDb.Database
    .SqlQuery<DayTrendInterval>(
        $"SELECT * FROM fn_daytrendinteractions({tenantId}, {onDate}, {queueArray}, {interval})")
    .ToListAsync(ct);

var agentTask = query.IncludeAgentMetrics
    ? _beDb.Database
        .SqlQuery<DayTrendAgentInterval>(
            $"SELECT * FROM fn_daytrendagentstatus({tenantId}, {onDate}, {queueArray}, {interval})")
        .ToListAsync(ct)
    : Task.FromResult(new List<DayTrendAgentInterval>());

await Task.WhenAll(interactionTask, agentTask);
return new DayTrendResult(interactionTask.Result, agentTask.Result);
```

> `Database.SqlQuery<T>()` (EF Core 7+) with interpolated string produces fully parameterised SQL.
> `{param}` → `$1, $2, ...` bound parameters on the wire. Never string concatenation. **[CODE-01]**

---

### 3.5 Rendering requirements

#### 3.5.1 Chart

- X-axis: interval start times formatted as `HH:mm`. Show only intervals up to the current time (do not render future empty intervals).
- Y-axis (left): count metrics (integers). Start at 0. Grid lines at reasonable intervals.
- Y-axis (right, optional): time metrics (`avg_wait_time`, `max_wait_time`, `avg_talk_time`) in seconds. Label as `mm:ss`. Only rendered when a time metric is enabled.
- Chart types: `line` (with smooth curves and data point markers), `bar` (grouped bars per interval), `area` (filled area under line), `step` (stepped line — useful for cumulative reading).
- Each metric rendered in its configured `color`.
- `showDataLabels = true`: numeric value displayed above each data point or bar segment. Time metrics shown as `mm:ss`.

#### 3.5.2 Legend

Rendered below the chart when `showLegend = true`.

| Element | Content |
|---|---|
| Colour swatch | Filled circle (●) in the metric's configured colour |
| Label | Metric's display name (configurable `label` or default) |
| Current total | Total for today (sum of all intervals shown) |

Example:
```
● Incoming Calls  142    ● Answered Calls  130    ● Abandoned Calls  12
```

Time metrics in legend show today's average, not sum:
```
● Avg Wait Time  01:24
```

#### 3.5.3 Refresh indicator

- Footer line: `Last updated: HH:mm:ss`
- Manual refresh button (↺) in widget header.
- Auto-refresh spinner shown during data fetch.
- If refresh fails: show last successful data with warning badge `⚠ Data may be stale`.

#### 3.5.4 Empty / loading states

| State | Display |
|---|---|
| Loading (first load) | Skeleton chart placeholder |
| No data for today | Message: _"No interactions recorded today for this Business Unit"_ |
| No queues in BU | Warning: _"No queues assigned to this Business Unit"_ |
| Query error | Error badge with retry button |

---

### 3.6 ConfigJson schema

Stored in `DashboardWidget.ConfigJson` (jsonb).

```json
{
  "widgetType": "DayTrend",
  "title": "UK Sales — Today",
  "businessUnitId": 3,
  "intervalMinutes": 30,
  "refreshIntervalSeconds": 300,
  "chartType": "line",
  "showDataLabels": true,
  "showLegend": true,
  "metrics": [
    { "metricId": "interaction.incoming_calls",      "enabled": true,  "color": "#3b82f6", "label": "Incoming Calls"      },
    { "metricId": "interaction.answered_calls",      "enabled": true,  "color": "#22c55e", "label": "Answered Calls"      },
    { "metricId": "interaction.abandoned_calls",     "enabled": true,  "color": "#ef4444", "label": "Abandoned Calls"     },
    { "metricId": "interaction.callback_requests",   "enabled": false, "color": "#f59e0b", "label": "Callback Requests"   },
    { "metricId": "interaction.completed_callbacks", "enabled": false, "color": "#8b5cf6", "label": "Completed Callbacks" },
    { "metricId": "interaction.avg_wait_time",       "enabled": false, "color": "#06b6d4", "label": "Avg Wait Time"       },
    { "metricId": "interaction.max_wait_time",       "enabled": false, "color": "#0891b2", "label": "Max Wait Time"       },
    { "metricId": "interaction.avg_talk_time",       "enabled": false, "color": "#64748b", "label": "Avg Talk Time"       }
  ],
  "agentMetrics": [
    { "metricId": "statuslog.available_agents",      "enabled": false, "color": "#4ade80", "label": "Available (agents)"     },
    { "metricId": "statuslog.onphone_agents",        "enabled": false, "color": "#60a5fa", "label": "On Phone (agents)"      },
    { "metricId": "statuslog.break_agents",          "enabled": false, "color": "#fb923c", "label": "On Break (agents)"      },
    { "metricId": "statuslog.paperwork_agents",      "enabled": false, "color": "#a78bfa", "label": "Paperwork (agents)"     },
    { "metricId": "statuslog.training_agents",       "enabled": false, "color": "#94a3b8", "label": "Training (agents)"      },
    { "metricId": "statuslog.total_agents",          "enabled": false, "color": "#f1f5f9", "label": "Total Active (agents)"  },
    { "metricId": "statuslog.logged_in_agents",      "enabled": true,  "color": "#fef08a", "label": "Logged In"              },
    { "metricId": "statuslog.available_time_ms",     "enabled": false, "color": "#86efac", "label": "Available Time"         },
    { "metricId": "statuslog.onphone_time_ms",       "enabled": false, "color": "#93c5fd", "label": "On Phone Time"          },
    { "metricId": "statuslog.break_time_ms",         "enabled": true,  "color": "#fdba74", "label": "Break Time"             },
    { "metricId": "statuslog.paperwork_time_ms",     "enabled": false, "color": "#c4b5fd", "label": "Paperwork Time"         },
    { "metricId": "statuslog.training_time_ms",      "enabled": false, "color": "#cbd5e1", "label": "Training Time"          },
    { "metricId": "statuslog.total_active_time_ms",  "enabled": false, "color": "#e2e8f0", "label": "Total Active Time"      }
  ]
}
```

---

### 3.7 Widget settings panel (UI — configuration form)

When a user opens the widget settings panel, they see:

**Tab: General**
- Title (text input)
- Business Unit (dropdown — from `NgcBusinessUnit` filtered by user's PG)
- Interval (radio: 15 min / 30 min / 60 min)
- Auto-refresh (dropdown: Every 1 min / Every 5 min / Every 10 min / Manual)

**Tab: Appearance**
- Chart type (icon buttons: Line / Bar / Area / Step)
- Show data labels (toggle)
- Show legend (toggle)

**Tab: Call Metrics**

Table with one row per interaction metric (fixed set of 7).

| Column | Control |
|---|---|
| On/Off | Toggle switch |
| Colour swatch | Colour picker (hex input + palette) |
| Label | Text input (placeholder: default name) |
| Preview | Coloured solid line/bar sample |

Drag-to-reorder rows changes display order in chart and legend.

**Tab: Agent Metrics**

Table with one row per agent status metric (fixed set of 6).
Same column structure as Call Metrics.
Preview shows dashed line (to distinguish from call metrics visually).

> If no agent metric is enabled, the agent status query is **not executed** — performance optimisation.

---

### 3.8 Access control

| Role | Access |
|---|---|
| Viewer | Can view widget (if dashboard permission includes View) |
| Editor | Can view + configure widget settings |
| Administrator | Can view + configure + assign to any BU in their tenant |
| Superadmin | Full access across all tenants |

BU dropdown in settings: shows only BUs where the user's Permission Group includes
the BU in `pg_business_units`. If `pg_business_units` is empty → show all BUs in tenant
(as per `[PG-03]` semantics — empty list = no restriction for BU).

---

### 3.9 WidgetCatalogItem seed entry

```csharp
new WidgetCatalogItem
{
    Id        = Uuid.NewSequential(),
    Category  = "General Metrics",
    Name      = "Day Trend Chart",
    Description = "Intraday call volume chart showing configured metrics broken down "
                + "by time interval (15/30/60 min) from start of day to now. "
                + "Supports line, bar, area, and step chart types with configurable "
                + "colours, labels, and auto-refresh.",
    IconUrl   = "/icons/widgets/day-trend.svg",
    IsActive  = true
}
```

---

### 3.10 Implementation notes

1. **No RTSGrid_* tables.** DayTrend uses PostgreSQL functions via `BackendEmulationDbContext`.
   No `SaveDayTrendRtsCommand` is needed.

2. **OnDate timezone.** `OnDate` stores server-local date in `DD/MM/YYYY` format.
   Use `DateTime.UtcNow` converted to the tenant's timezone when constructing the filter,
   or use `TenantSettings.DefaultLocale` / timezone offset from `RTSData_Interaction.TimeZone`.
   For v1: use UTC date — document this as a known limitation.

3. **Dual Y-axis.** Charting library must support secondary Y-axis for time metrics.
   If the chosen library does not support this natively, disable time metrics when count
   metrics are also enabled (show warning in settings panel).

4. **Interval alignment.** Intervals are aligned to clock boundaries:
   `00:00`, `00:30`, `01:00`, etc. for 30-minute interval. Not rolling windows.

5. **`avg_wait_time` for abandoned calls.** `TimeInQueue` is populated even for abandoned
   interactions. The current spec filters `AVG(TimeInQueue) WHERE IsAnswered = 1` to show
   wait time for answered calls only. A future option `avgWaitTimeScope: 'answered' | 'all'`
   can be added to ConfigJson.

6. **Performance.** `RTSData_Interaction` may be large. Always filter `OnDate` first
   (partition key). Ensure index exists on `(TenantId, OnDate, Workgroup)`.
   See `[DATA-08]` in `CLAUDE.md`.

7. **Agent status query is conditional.** Only run when `agentMetrics` contains at least
   one `enabled: true` entry. The CTE join between `Interaction` and `UserStatusLog`
   is a cross-table operation — avoid running it unnecessarily.

8. **UserId format.** `RTSData_Interaction.UserId` and `RTSData_UserStatusLog.UserId`
   may use different formats (email vs short username) depending on server configuration.
   The JOIN inside `fn_daytrendagentstatus` uses `usl."UserId" = ap."UserId"` — verify
   that both fields match in the production DB. If they differ, add a normalisation expression
   (e.g. `SPLIT_PART(ap."UserId", '@', 1)`) inside the function body — no C# changes needed.

9. **SP migration pattern.** Functions are created in migration `AddDayTrendFunctions`
   under `BackendEmulationDbContext`. `Up()` uses `CREATE OR REPLACE FUNCTION` (idempotent).
   `Down()` uses `DROP FUNCTION IF EXISTS` with full signature. Template:

   ```csharp
   protected override void Up(MigrationBuilder mb) =>
       mb.Sql("""
           CREATE OR REPLACE FUNCTION fn_daytrendinteractions(...) ...;
           CREATE OR REPLACE FUNCTION fn_daytrendagentstatus(...) ...;
       """);

   protected override void Down(MigrationBuilder mb) =>
       mb.Sql("""
           DROP FUNCTION IF EXISTS fn_daytrendinteractions(uuid, varchar, text[], integer);
           DROP FUNCTION IF EXISTS fn_daytrendagentstatus(uuid, varchar, text[], integer);
       """);
   ```

---

*Widget Specification v0.6 — Added interaction.max_wait_time (MAX_FIELD) to fn_daytrendinteractions; statuslog.*_time_ms + logged_in_agents. Next: CC-002 implementation task.*
