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

### 1.3 Metric catalogue — HistoryMetric

Available metrics for DayTrend are defined in the `history_metrics` table (`HistoryMetric`
entity, App context — cross-tenant, shell-owned).
The widget loads them via `AppDbContext.HistoryMetrics` filtered by `MetricType`:
interaction metrics (`MetricType = 'Interaction'`) and agent metrics
(`MetricType IN ('AgentStatusLog', 'AgentStatus')`).

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

### 1.4 HistoryMetric seed entries for DayTrend

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
    new HistoryMetric { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",       MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",        ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new HistoryMetric { MetricId = "interaction.answered_calls",      Description = "Answered Calls",       MetricFunction = "COUNT_FILTER", MetricParameter = "answered",             ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new HistoryMetric { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",      MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",            ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new HistoryMetric { MetricId = "interaction.callback_requests",   Description = "Callback Requests",    MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",    ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new HistoryMetric { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",  MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",   ValueType = "Number", MetricFormat = "0",     MetricType = "Interaction", DataType = "int" },
    new HistoryMetric { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",        MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered", ValueType = "Time",   MetricFormat = "mm:ss", MetricType = "Interaction", DataType = "decimal" },
    new HistoryMetric { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",        MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",    ValueType = "Time",   MetricFormat = "mm:ss", MetricType = "Interaction", DataType = "decimal" },
};

foreach (var m in interactionMetrics)
{
    if (!await db.HistoryMetrics.AnyAsync(x => x.MetricId == m.MetricId))
        await db.HistoryMetrics.AddAsync(m);
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

### 2.4 HistoryMetric — shell-owned metric catalogue

> **Architecture note:** Metrics with dot-notation `MetricId` (e.g. `interaction.*`, `statuslog.*`,
> `agentstatus.*`) belong to the shell-owned `history_metrics` table (`HistoryMetric` entity).
> These are **not** related to `RTSGrid_Metric` (CC-platform-owned, read-only from the shell).

All entries below must be seeded idempotently (upsert by `MetricId`) on application startup.

```csharp
// Interaction metrics
new HistoryMetric { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.answered_calls",      Description = "Answered Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "answered",                               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",                              MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.callback_requests",   Description = "Callback Requests",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",                      MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",      DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",                     MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.outbound_calls",      Description = "Outbound Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_outgoing",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.transferred_calls",   Description = "Transferred Calls",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "transferred",                            MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.max_wait_time",       Description = "Max Wait Time",            DataType = "decimal", MetricFunction = "MAX_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new HistoryMetric { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon",  DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

// Agent status metrics
new HistoryMetric { MetricId = "agentstatus.available_time",      Description = "Available Time",           DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:AVAILABLE",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.onphone_time",        Description = "On Phone Time",            DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ONPHONE",                          MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.break_time",          Description = "Break Time",               DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:BREAK",                            MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.training_time",       Description = "Training / Back-Office",   DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:TRAINING",                         MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.paperwork_time",      Description = "Paperwork / ACW Time",     DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:PAPERWORK",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
// agentstatus.signoff_time removed — SIGNOFF is not a canonical StatusGroup value (CC-001)
new HistoryMetric { MetricId = "agentstatus.login_time",          Description = "Total Login Time",         DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ALL_LOGGED_IN",               MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.wrap_time",           Description = "Wrap Up (ACW) Time",       DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "status:Wrap Up",                         MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.call_count",          Description = "Calls Handled",            DataType = "int",     MetricFunction = "SUM_COUNT",    MetricParameter = "status:Incoming Ext Call",               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },
new HistoryMetric { MetricId = "agentstatus.occupancy_pct",       Description = "Occupancy %",              DataType = "decimal", MetricFunction = "RATIO",        MetricParameter = "group:ONPHONE/group:ONPHONE+AVAILABLE",  MetricFormat = "0.0%",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },

// Agent status log interval metrics (source: RTSData_UserStatusLog, agent pool via Interaction)
new HistoryMetric { MetricId = "statuslog.available_agents",  Description = "Available Agents",             DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:AVAILABLE",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.onphone_agents",    Description = "On Phone Agents",              DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ONPHONE",    MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.break_agents",      Description = "Agents on Break",              DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:BREAK",      MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.paperwork_agents",  Description = "Paperwork / ACW Agents",       DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:PAPERWORK",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.training_agents",   Description = "Training / Back-Office Agents",DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:TRAINING",   MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.total_agents",        Description = "Total Active Agents (with status)", DataType = "int", MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ALL",  MetricFormat = "0",  DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.logged_in_agents",    Description = "Logged-In Agents (answered calls)", DataType = "int", MetricFunction = "COUNT_POOL",     MetricParameter = "pool:all",   MetricFormat = "0",  DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
// Agent status log — accumulated time per interval (SUM_OVERLAP_MS)
new HistoryMetric { MetricId = "statuslog.available_time_ms",   Description = "Available Time",           DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:AVAILABLE",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.onphone_time_ms",     Description = "On Phone Time",            DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ONPHONE",    MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.break_time_ms",       Description = "Break Time",               DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:BREAK",      MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.paperwork_time_ms",   Description = "Paperwork / ACW Time",     DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:PAPERWORK",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.training_time_ms",    Description = "Training / Back-Office Time", DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:TRAINING",  MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
new HistoryMetric { MetricId = "statuslog.total_active_time_ms",Description = "Total Active Time",        DataType = "bigint",  MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ALL",        MetricFormat = "mm:ss",  DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
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

**Output format — narrow (tall):** every function returns `(interval_start, metric_id, value)`,
not a wide table. Adding a metric = one `UNION ALL` row in the function body; the C# record
and handler never change. See §3.4.3 for the full methodology.

#### 3.4.1 `fn_daytrendinteractions` — interaction metrics per interval

Returns one row per **(interval\_start, metric\_id)** in narrow format (§3.4.3).
Every `metric_id` string is the canonical `RTSGrid_Metric.MetricId`; the SQL filter
mirrors `MetricParameter` exactly so DayTrend totals match RTSGrid widget totals.

```sql
CREATE OR REPLACE FUNCTION fn_daytrendinteractions(
    p_tenantid    uuid,
    p_ondate      varchar(50),   -- DD/MM/YYYY
    p_queuelist   text[],
    p_intervalmin integer        -- 15 | 30 | 60
)
RETURNS TABLE (
    interval_start  timestamptz,
    metric_id       text,
    value           double precision
)
LANGUAGE sql STABLE
AS $$
    WITH base AS (
        -- Pre-filter rows; compute interval bucket once
        SELECT
            DATE_TRUNC('hour', "InQueueDateTime") +
                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                 * (p_intervalmin || ' minutes')::interval)  AS interval_start,
            "InteractionType", "Direction",
            "IsAnswered", "IsAbandoned",
            "TimeInQueue", "TalkTime"
        FROM "RTSData_Interaction"
        WHERE "TenantId"  = p_tenantid
          AND "OnDate"    = p_ondate
          AND "Workgroup" = ANY(p_queuelist)
          AND "InQueueDateTime" IS NOT NULL
    ),
    agg AS (
        -- Single aggregate pass. Column comments: MetricId | predicate key
        -- SQL filter must match RTSGrid_Metric.MetricParameter exactly (§3.4.3).
        SELECT
            interval_start,
            -- interaction.incoming_calls      | call_incoming
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call' AND "Direction" = 'Incoming')  AS incoming_calls,
            -- interaction.answered_calls      | answered
            COUNT(*) FILTER (WHERE "IsAnswered" = true)                                       AS answered_calls,
            -- interaction.abandoned_calls     | abandoned
            COUNT(*) FILTER (WHERE "IsAbandoned" = true)                                      AS abandoned_calls,
            -- interaction.callback_requests   | callback_incoming
            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback' AND "Direction" = 'Incoming') AS callback_requests,
            -- interaction.completed_callbacks | callback_completed
            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                               AND "Direction" = 'Outgoing' AND "IsAnswered" = true)         AS completed_callbacks,
            -- interaction.outbound_calls      | call_outgoing
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call' AND "Direction" = 'Outgoing') AS outbound_calls,
            -- interaction.transferred_calls   | transferred
            COUNT(*) FILTER (WHERE "IsTransferred" = true)                                AS transferred_calls,
            -- interaction.avg_wait_time       | TimeInQueue:answered
            AVG("TimeInQueue") FILTER (WHERE "IsAnswered" = true)                           AS avg_wait_time,
            -- interaction.max_wait_time       | TimeInQueue:answered (MAX variant)
            MAX("TimeInQueue") FILTER (WHERE "IsAnswered" = true)                           AS max_wait_time,
            -- interaction.avg_talk_time       | TalkTime:answered
            AVG("TalkTime")    FILTER (WHERE "IsAnswered" = true)                           AS avg_talk_time,
            -- interaction.avg_abandon_wait    | TimeInQueue:abandoned
            AVG("TimeInQueue") FILTER (WHERE "IsAbandoned" = true)                          AS avg_abandon_wait
        FROM base
        GROUP BY interval_start
    )
    -- Each row: (interval_start, 'RTSGrid_Metric.MetricId', value)
    -- To add a metric: add column to agg CTE above + one UNION ALL row here.
    SELECT interval_start, 'interaction.incoming_calls',      incoming_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.answered_calls',      answered_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.abandoned_calls',     abandoned_calls::double precision     FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.callback_requests',   callback_requests::double precision   FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.completed_callbacks', completed_callbacks::double precision FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.outbound_calls',      outbound_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.transferred_calls',   transferred_calls::double precision   FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_wait_time',       avg_wait_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.max_wait_time',       max_wait_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_talk_time',       avg_talk_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_abandon_wait',    avg_abandon_wait                      FROM agg
    ORDER BY interval_start, metric_id;
$$;
```


#### 3.4.2 `fn_daytrendagentstatus` — agent status metrics per interval

Same narrow format as §3.4.1. All `metric_id` values match `RTSGrid_Metric.MetricId` for
`MetricType = 'AgentStatusLog'`. Agent pool = DISTINCT UserId from answered incoming calls
(rationale in §2.3). Time values are milliseconds cast to `double precision`.

```sql
CREATE OR REPLACE FUNCTION fn_daytrendagentstatus(
    p_tenantid    uuid,
    p_ondate      varchar(50),   -- DD/MM/YYYY
    p_queuelist   text[],
    p_intervalmin integer        -- 15 | 30 | 60
)
RETURNS TABLE (
    interval_start  timestamptz,
    metric_id       text,
    value           double precision
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
    pool_summary AS (
        -- statuslog.logged_in_agents: COUNT from agent pool (all who answered calls)
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
            -- overlap_ms: time agent spent in this StatusGroup within the interval
            GREATEST(0,
                EXTRACT(EPOCH FROM (
                    LEAST(
                        COALESCE(usl."EndTime",
                                 ap.interval_start + (p_intervalmin || ' minutes')::interval),
                        ap.interval_start + (p_intervalmin || ' minutes')::interval
                    )
                    - GREATEST(usl."StartTime", ap.interval_start)
                ))::bigint * 1000
            ) AS overlap_ms
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
        -- Column comments: MetricId | MetricParameter (filter = StatusGroup value)
        SELECT
            interval_start,
            -- statuslog.available_agents  | group:AVAILABLE
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'AVAILABLE') AS available_agents,
            -- statuslog.onphone_agents    | group:ONPHONE
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'ONPHONE')   AS onphone_agents,
            -- statuslog.break_agents      | group:BREAK
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'BREAK')     AS break_agents,
            -- statuslog.paperwork_agents  | group:PAPERWORK
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'PAPERWORK') AS paperwork_agents,
            -- statuslog.training_agents   | group:TRAINING
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'TRAINING')  AS training_agents,
            -- statuslog.total_agents      | group:ALL
            COUNT(DISTINCT "UserId")                                             AS total_agents,
            -- statuslog.available_time_ms | group:AVAILABLE (SUM_OVERLAP_MS)
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'AVAILABLE'),  0) AS available_time_ms,
            -- statuslog.onphone_time_ms   | group:ONPHONE
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'ONPHONE'),    0) AS onphone_time_ms,
            -- statuslog.break_time_ms     | group:BREAK
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'BREAK'),      0) AS break_time_ms,
            -- statuslog.paperwork_time_ms | group:PAPERWORK
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'PAPERWORK'),  0) AS paperwork_time_ms,
            -- statuslog.training_time_ms  | group:TRAINING
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'TRAINING'),   0) AS training_time_ms,
            -- statuslog.total_active_time_ms | group:ALL
            COALESCE(SUM(overlap_ms),                                              0) AS total_active_time_ms
        FROM agent_status
        GROUP BY interval_start
    )
    -- logged_in_agents from pool_summary (all answering agents, with or without StatusGroup)
    -- All other metrics from status_summary (agents with StatusGroup records)
    SELECT ps.interval_start, 'statuslog.logged_in_agents',    ps.logged_in_agents::double precision    FROM pool_summary ps
    UNION ALL
    SELECT ss.interval_start, 'statuslog.available_agents',    ss.available_agents::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.onphone_agents',      ss.onphone_agents::double precision      FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.break_agents',        ss.break_agents::double precision        FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.paperwork_agents',    ss.paperwork_agents::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.training_agents',     ss.training_agents::double precision     FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.total_agents',        ss.total_agents::double precision        FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.available_time_ms',   ss.available_time_ms::double precision   FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.onphone_time_ms',     ss.onphone_time_ms::double precision     FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.break_time_ms',       ss.break_time_ms::double precision       FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.paperwork_time_ms',   ss.paperwork_time_ms::double precision   FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.training_time_ms',    ss.training_time_ms::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.total_active_time_ms',ss.total_active_time_ms::double precision FROM status_summary ss
    ORDER BY interval_start, metric_id;
$$;
```

> Intervals where no agent has a StatusGroup record still produce a `logged_in_agents` row
> from `pool_summary`. Count and time rows are absent for that interval — client treats
> missing keys as 0 via `.GetValueOrDefault(metricId, 0)`.

#### 3.4.3 Metric extensibility — methodology

Both DayTrend functions use the **narrow (tall) format**: every row is one metric value
for one interval. The C# record and handler never change when a new metric is added.

**Consistency rule:** `metric_id` in every `UNION ALL` row **must exactly match**
`RTSGrid_Metric.MetricId`. The SQL filter in the `agg` / `status_summary` CTE is
derived from `MetricParameter` — this is the **single source of truth**. If the filter
diverges from `MetricParameter`, DayTrend totals will not match RTSGrid widget totals.

**Schema trust rule:** every field referenced in `RTSGrid_Metric.MetricParameter` is
guaranteed to exist in the corresponding source table (`RTSData_Interaction`,
`RTSData_UserStatusLog`, etc.). No field-existence check is needed before using a
`MetricParameter` value in SQL.

**Checklist — adding a new metric:**

| Step | Action |
|---|---|
| 1 | Add `RtsGridMetric` seed entry (§2.4): `MetricId`, `MetricFunction`, `MetricParameter` |
| 2 | Add predicate key to §2.1 if the filter pattern is new |
| 3 | Add computed column in `agg` / `status_summary` CTE — annotate with `MetricId \| predicate_key` |
| 4 | Add `UNION ALL SELECT interval_start, 'new.metric_id', column FROM agg` |
| 5 | Deploy with `CREATE OR REPLACE FUNCTION` — no migration structural change, no C# change |
| 6 | Add entry to ConfigJson `metrics[]` or `agentMetrics[]` (§3.6) |
| 7 | Add row to §3.3.3 / §3.3.4 default table |

**Validation (integration test):** for every `metricId` with `enabled = true` in a
widget's ConfigJson, the function must return at least one row with that `metric_id`
for a non-empty dataset. Test fails if a metric is configured but the function omits it.


#### 3.4.4 Important notes

- `OnDate` is stored as `varchar` in format `DD/MM/YYYY`. Always pass the date in this format.
- `AnsweredDateTime` null is stored as `1753-01-01 00:00:00.000` — treat as absent, not a real date. Do not use `AnsweredDateTime` for interval grouping.
- `InQueueDateTime` is the canonical timestamp for grouping (when the interaction entered the queue).
- If `@queueList` is empty (BU has no queue assignments), return empty dataset and display
  a warning: _"No queues assigned to this Business Unit"_.
- EF Core / raw SQL: use `FromSqlInterpolated` or parameterised `ExecuteSqlRaw`. Never string concatenation. **[CODE-01]**

#### 3.4.5 Application layer — calling the functions

Both functions return the same narrow record type — one handler, one grouping pass.

```csharp
// Single result type for BOTH functions (narrow format)
public record DayTrendMetricRow(DateTime IntervalStart, string MetricId, double? Value);

// Per-interval result — keys are RTSGrid_Metric.MetricId strings
public record DayTrendIntervalData(
    DateTime IntervalStart,
    IReadOnlyDictionary<string, double?> Metrics);

// In DayTrendQueryHandler.Handle():
var queues = await _ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
if (!queues.Any())
    return DayTrendResult.NoQueues();

var tenantId   = _tenantContext.TenantId;
var onDate     = DateTime.UtcNow.ToString("dd/MM/yyyy");  // DD/MM/YYYY
var queueArray = queues.ToArray();
var interval   = query.IntervalMinutes;

var interactionTask = _beDb.Database
    .SqlQuery<DayTrendMetricRow>(
        $"SELECT * FROM fn_daytrendinteractions({tenantId}, {onDate}, {queueArray}, {interval})")
    .ToListAsync(ct);

var agentTask = query.IncludeAgentMetrics
    ? _beDb.Database
        .SqlQuery<DayTrendMetricRow>(
            $"SELECT * FROM fn_daytrendagentstatus({tenantId}, {onDate}, {queueArray}, {interval})")
        .ToListAsync(ct)
    : Task.FromResult(new List<DayTrendMetricRow>());

await Task.WhenAll(interactionTask, agentTask);

// Merge both result sets and pivot to per-interval dictionaries
var intervals = interactionTask.Result
    .Concat(agentTask.Result)
    .GroupBy(r => r.IntervalStart)
    .Select(g => new DayTrendIntervalData(
        g.Key,
        g.ToDictionary(r => r.MetricId, r => r.Value)))
    .OrderBy(x => x.IntervalStart)
    .ToList();

return new DayTrendResult(intervals);
```

> `Database.SqlQuery<T>()` (EF Core 7+) with interpolated string produces fully parameterised SQL.
> `{param}` → `$1, $2, ...` bound parameters on the wire. Never string concatenation. **[CODE-01]**
>
> Client lookup: `interval.Metrics.GetValueOrDefault("interaction.incoming_calls", 0)`
> returns 0 for intervals where no interactions occurred.

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

*Widget Specification v1.0 — CC-004: migrated dot-notation metrics to HistoryMetric (shell-owned); removed snapshot.* metrics; AgentStatusCount/Duration widgets cancelled.*

---

## 4. Agent State Distribution — Real-Time BU Status Chart

> **⚠ MANDATORY for CC implementation:** before writing any code for this widget, read
> `.claude/skills/widget-creator/widget-creator.md` — specifically:
> **§15** (Queue Grid patterns), **§16** (Dark Mode), **§17** (Header Colors),
> **§18** (UI Guidelines), **§19** (RTS Infrastructure), **§21** (Config Modal Tabs),
> **§22** (CC task template).
> Then inspect `QueueGridWidget.razor` to confirm exact field names and SignalR patterns used in this project.

### 4.1 Overview

| Field | Value |
|---|---|
| Widget name | `Agent State Distribution` |
| Component file | `AgentStateDistributionWidget.razor` |
| Architecture | **Specialized Grid Widget** — Queue Grid infrastructure + Chart.js renderer |
| Data source | SignalR hub → `ReceiveQueueGridData` via `GridId` (mode-switched) |
| RTS pattern | `SaveQueueGridRtsCommand` / `DeleteQueueGridRtsCommand` (×2 per widget instance) |
| Rendering | Chart.js — Pie / Donut / Bar / HorizontalBar (configurable) |
| Filter | Single Business Unit (int `BusinessUnitId`) |
| Distribution modes | **By Group** (`UsersInStatusGroupCount`) — aggregated by Status Group (default) |
| | **By State** (`UsersInStatusCount`) — one segment per individual Agent State |
| Audience | All authenticated roles (Viewer, Editor, Administrator, Superadmin) |

**By Group mode (default):** shows agents distributed across Status Groups (AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING). Segment list sourced from `tenant_agent_state_groups`. An extra **OTHER** segment appears when `LoggedUsers > SUM(all groups)`.

**By State mode:** shows agents distributed across individual Agent States (e.g. Available, Short Break, Lunch, Coffee Break, …). Segment list sourced from `tenant_agent_states`. An extra **OTHER** segment appears when `LoggedUsers > SUM(all states)`.

Each mode has its own RTSGrid (`GroupGridId` / `StateGridId`) — both are saved on every config save. At render time, `RtsGridId = distributionMode == "state" ? StateGridId : GroupGridId`.

---

### 4.2 Visual Layout

```
┌─────────────────────────────────────────┐
│  Agent State Distribution               │  ← widget header (gear / drag)
├─────────────────────────────────────────┤
│                                         │
│          ┌───────────────────┐          │
│          │   ●  AVAILABLE    │          │  ← Donut / Pie (configurable)
│          │  ╱╲               │          │
│          │ ╱  ╲  ●  ONPHONE  │          │
│          │╱    ╲             │          │
│          │  ●  BREAK         │          │
│          │  ●  PAPERWORK     │          │
│          │  ●  TRAINING      │          │
│          │  ●  OTHER (if >0) │          │
│          └───────────────────┘          │
│                                         │
│  ■ Available 42%  ■ On Phone 28%  ...  │  ← legend (toggleable)
└─────────────────────────────────────────┘
```

For **Bar / HorizontalBar** chart type: one bar per segment, value shown on bar or axis.

---

### 4.3 Configuration Options

#### Tab: General

| Field | Type | Required | Notes |
|---|---|---|---|
| `displayName` | string | No | Shown in widget header. Default: "Agent State Distribution" |
| `businessUnitId` | int | Yes | Selected BU. Searchable dropdown (§18.1). 0 = unconfigured |
| `distributionMode` | string | No | `"group"` (default) \| `"state"` — switches aggregation level |
| `chartType` | string | No | `"donut"` (default) \| `"pie"` \| `"bar"` \| `"horizontalbar"` |
| `valueDisplay` | string | No | `"percentages"` (default) \| `"numbers"` |
| `showLegend` | bool | No | Show legend below chart. Default: `true` |
| `showValueLabels` | bool | No | Show per-segment labels on chart. Default: `true` |

#### Tab: Appearance

| Field | Type | Default | Notes |
|---|---|---|---|
| `backgroundColor` | string | `""` | Widget background (light mode) |
| `darkBackgroundColor` | string | `"#1e1e1e"` | Widget background (dark mode) |
| `fontColor` | string | `""` | Label / legend text color (light) |
| `darkFontColor` | string | `"#ffffff"` | Label / legend text color (dark) |

**Segment colors — By Group mode** (one row per Status Group, sourced from `GetAgentStateGroupsQuery`):

| Segment key | Default light | Default dark |
|---|---|---|
| `AVAILABLE` | `#22c55e` | `#4ade80` |
| `ONPHONE` | `#3b82f6` | `#60a5fa` |
| `BREAK` | `#f59e0b` | `#fbbf24` |
| `PAPERWORK` | `#8b5cf6` | `#a78bfa` |
| `TRAINING` | `#06b6d4` | `#22d3ee` |
| `OTHER` | `#6b7280` | `#9ca3af` |

**Segment colors — By State mode** (one row per Agent State, sourced from `GetAgentStatesQuery`):
- Segment keys = `AgentState.AgentStateName` (e.g. `"Available"`, `"Short Break"`, `"Lunch"`)
- Defaults: cycle through a predefined palette; OTHER always `#6b7280` / `#9ca3af`
- Stored in `stateSegmentColors` / `darkStateSegmentColors` (separate dicts from group colors)

Both color dicts are keyed by the **CC platform code / display name** exactly as stored in the DB — no normalisation or lowercasing.

---

### 4.4 RTS Table Structure

This widget maintains **two independent RTSGrids** — one per distribution mode. Both are saved on every config save and deleted together on widget delete. At runtime, the widget subscribes to the grid that matches the current `distributionMode`.

#### 4.4.1 By Group Grid (`GroupGridId`)

**Columns** — one per active Status Group + Total (sourced from `GetAgentStateGroupsQuery`):

| ColumnNumber | MetricId | MetricFunction | MetricParameter | Header |
|---|---|---|---|---|
| 1 | `QueueLoginDataNumAvailableUsers` | `UsersInStatusGroupCount` | `AVAILABLE` | `Available` |
| 2 | `QueueNumOnCallAgents` | `UsersInStatusGroupCount` | `ONPHONE` | `On Phone` |
| 3 | `QueueLoginDataNumBreakUsers` | `UsersInStatusGroupCount` | `BREAK` | `Break` |
| 4 | `QueueLoginDataNumPaperworkUsers` | `UsersInStatusGroupCount` | `PAPERWORK` | `Paperwork` |
| 5 | `QueueLoginDataNumTrainingUsers` | `UsersInStatusGroupCount` | `TRAINING` | `Training` |
| N+1 | `QueueLoginDataNumLoggedUsers` | — | — | `Total` |

MetricId per group is resolved at save time: `RTSGrid_Metric WHERE MetricFunction = 'UsersInStatusGroupCount' AND MetricParameter = group.GroupName`. Column count = number of active Status Groups + 1 (Total).

#### 4.4.2 By State Grid (`StateGridId`)

**Columns** — one per active Agent State + Total (sourced from `GetAgentStatesQuery`):

| ColumnNumber | MetricId | MetricFunction | MetricParameter | Header |
|---|---|---|---|---|
| 1 | (resolved) | `UsersInStatusCount` | `Available` | `Available` |
| 2 | (resolved) | `UsersInStatusCount` | `Short Break` | `Short Break` |
| 3 | (resolved) | `UsersInStatusCount` | `Lunch` | `Lunch` |
| … | … | … | … | … |
| N+1 | `QueueLoginDataNumLoggedUsers` | — | — | `Total` |

MetricId per state is resolved at save time: `RTSGrid_Metric WHERE MetricFunction = 'UsersInStatusCount' AND MetricParameter = state.AgentStateName`.

> **Important:** If a MetricId cannot be resolved for a given GroupName or AgentStateName, that segment is skipped during RTSGrid save and a warning is logged. The widget still renders — unresolvable segments show 0.

#### 4.4.3 Row structure (both grids)

**Header row** (RowNumber=1, UnionId=-1): N+1 cells with CellType=`"Text"`, Value=column header name.

**Data row** (RowNumber=2, UnionId=`BusinessUnitId`): N+1 cells with CellType=`"Data"`, Value=MetricId.

When BU changes in config: update the data row's UnionId via `SaveQueueGridRtsCommand` (pass existing RowId). Both grids updated in sequence.

---

### 4.5 Rendering Requirements

#### Mode switching

```csharp
private int RtsGridId => Config?.DistributionMode == "state"
    ? (Config?.StateGridId ?? GridId)
    : (Config?.GridId ?? GridId);

private string HubUrl => $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";
```

When `distributionMode` changes in config: disconnect current hub, reconnect with new `RtsGridId`.

#### SignalR Data Reception

```csharp
_hub.On<List<QueueRowData>>("ReceiveQueueGridData", data =>
{
    var buRow = data.FirstOrDefault(r => r.BusinessUnitId == _businessUnitId);
    if (buRow != null)
    {
        _metrics = buRow.Metrics; // Dictionary<string, string>
        UpdateChartData();
    }
    InvokeAsync(StateHasChanged);
});
```

#### Segment Building (both modes)

The widget stores a resolved list of `(MetricId, DisplayName, LightColor, DarkColor)` tuples in `_segmentDefs`. This list is populated:
- **By Group mode**: from `Config.GroupColumnMetricIds` (Dictionary<GroupName, MetricId>) + `Config.SegmentColors`
- **By State mode**: from `Config.StateColumnMetricIds` (Dictionary<AgentStateName, MetricId>) + `Config.StateSegmentColors`

No DB queries at render time — everything is resolved from saved config.

```csharp
private void UpdateChartData()
{
    var total = ParseInt(_metrics.GetValueOrDefault("QueueLoginDataNumLoggedUsers"));
    var sumAll = 0;
    var segments = new List<ChartSegment>();

    foreach (var def in _segmentDefs)
    {
        var value = ParseInt(_metrics.GetValueOrDefault(def.MetricId));
        sumAll += value;
        var color = DarkMode ? def.DarkColor : def.LightColor;
        segments.Add(new ChartSegment(def.DisplayName, value, color));
    }

    var other = Math.Max(0, total - sumAll);
    if (other > 0)
    {
        var otherColor = DarkMode ? OtherDarkColor : OtherLightColor;
        segments.Add(new ChartSegment("Other", other, otherColor));
    }

    _segments = segments;
}

private static int ParseInt(string? value) =>
    int.TryParse(value, out var n) ? n : 0;
```

#### Chart Types

| `chartType` | Chart.js type | Notes |
|---|---|---|
| `"donut"` | `"doughnut"` | Default. Hole in centre |
| `"pie"` | `"pie"` | No hole |
| `"bar"` | `"bar"` | Vertical bars |
| `"horizontalbar"` | `"bar"` + `indexAxis: 'y'` | Horizontal bars |

#### JS Interop Contract

```javascript
// wwwroot/js/agent-state-distribution-chart.js
window.agentStateDistributionChart = {
    render(elementId, segments, options) { /* Chart.js init/update */ },
    destroy(elementId) { /* Chart.js destroy */ }
};
```

`segments` array (passed from C#):
```json
[
  { "label": "Available", "value": 12, "color": "#22c55e" },
  { "label": "On Phone",  "value": 8,  "color": "#3b82f6" },
  { "label": "Break",     "value": 3,  "color": "#f59e0b" },
  { "label": "Paperwork", "value": 2,  "color": "#8b5cf6" },
  { "label": "Training",  "value": 1,  "color": "#06b6d4" },
  { "label": "Other",     "value": 1,  "color": "#6b7280" }
]
```

`options`:
```json
{
  "chartType": "donut",
  "valueDisplay": "percentages",
  "showLegend": true,
  "showValueLabels": true,
  "fontColor": "#1a1a1a"
}
```

---

### 4.6 ConfigJson Schema

```json
{
  "displayName": "Agent State Distribution",
  "businessUnitId": 0,

  "distributionMode": "group",

  "groupGridId": 0,
  "groupRtsHeaderRowId": 0,
  "groupRtsDataRowId": 0,
  "groupRtsColumnIds": { "AVAILABLE": 0, "ONPHONE": 0, "BREAK": 0, "PAPERWORK": 0, "TRAINING": 0, "Total": 0 },
  "groupRtsHeaderCellIds": {},
  "groupRtsDataCellIds": {},
  "groupColumnMetricIds": {
    "AVAILABLE": "QueueLoginDataNumAvailableUsers",
    "ONPHONE": "QueueNumOnCallAgents",
    "BREAK": "QueueLoginDataNumBreakUsers",
    "PAPERWORK": "QueueLoginDataNumPaperworkUsers",
    "TRAINING": "QueueLoginDataNumTrainingUsers"
  },

  "stateGridId": 0,
  "stateRtsHeaderRowId": 0,
  "stateRtsDataRowId": 0,
  "stateRtsColumnIds": {},
  "stateRtsHeaderCellIds": {},
  "stateRtsDataCellIds": {},
  "stateColumnMetricIds": {},

  "chartType": "donut",
  "valueDisplay": "percentages",
  "showLegend": true,
  "showValueLabels": true,
  "backgroundColor": "",
  "darkBackgroundColor": "#1e1e1e",
  "fontColor": "",
  "darkFontColor": "#ffffff",
  "headerBackgroundColor": "default",
  "darkHeaderBackgroundColor": "default",
  "headerFontColor": "default",
  "darkHeaderFontColor": "default",

  "segmentColors": {
    "AVAILABLE": "#22c55e",
    "ONPHONE": "#3b82f6",
    "BREAK": "#f59e0b",
    "PAPERWORK": "#8b5cf6",
    "TRAINING": "#06b6d4"
  },
  "darkSegmentColors": {
    "AVAILABLE": "#4ade80",
    "ONPHONE": "#60a5fa",
    "BREAK": "#fbbf24",
    "PAPERWORK": "#a78bfa",
    "TRAINING": "#22d3ee"
  },

  "stateSegmentColors": {},
  "darkStateSegmentColors": {}
}
```

**Notes on key naming:**
- `segmentColors` keys = `GroupName` (CC platform code, e.g. `"AVAILABLE"`) — **not** lowercased
- `stateSegmentColors` keys = `AgentStateName` exactly as in DB (e.g. `"Available"`, `"Short Break"`)
- `*ColumnMetricIds` — populated at save time by resolving `RTSGrid_Metric`; used at render time to map MetricId → segment without DB calls
- `OTHER` segment color is hardcoded (`#6b7280` / `#9ca3af`) — not user-configurable
- Old config with lowercased keys (`"available"`, `"break"`, …) must be migrated on load (see §4.10 note 9)

---

### 4.7 Widget Settings Panel (Config Modal Tabs)

**Tab: General**
- `DisplayName` — text input, placeholder "Agent State Distribution"
- `Business Unit` — searchable dropdown (§18.1 pattern); BU is required
- `Distribution Mode` — segmented control / radio:
  - **By Group** (default) — aggregates by Status Group; uses `UsersInStatusGroupCount` metrics
  - **By State** — shows individual Agent States; uses `UsersInStatusCount` metrics
  - Changing mode does NOT reset colors already configured for the other mode
- `Chart Type` — icon button group: Donut / Pie / Bar / Horizontal Bar
- `Value Display` — **Percentages** (default) / **Numbers**
- `Show Legend` — toggle (default on)
- `Show Value Labels` — toggle (default on)

**Tab: Appearance**
- Colors — dual-column Light/Dark layout (§16.2):
  - `Widget Background` — ColorPicker (light) + ColorPicker (dark)
  - `Font Color` — ColorPicker (light) + ColorPicker (dark)
  - `Header Background` / `Header Font` — with `"default"` option (§17.4)
- **Segment Colors section** — adapts to current `distributionMode`:
  - **By Group**: rows sourced from `GetAgentStateGroupsQuery` (active groups only). One row per group showing `GroupName` + dual color pickers. "Other" row always shown at bottom (hardcoded, read-only color info note).
  - **By State**: rows sourced from `GetAgentStatesQuery` (active states only). One row per state showing `AgentStateName` + dual color pickers. "Other" row always shown at bottom.
  - When mode switches in the tab, segment color section reloads with the appropriate list.
  - Unsaved colors for the non-active mode are preserved in memory and saved together with active mode colors.

> Tabs **Columns**, **Thresholds**, **Filters**, **Score** are **hidden** for this widget type.

---

### 4.8 Access Control

| Feature | Superadmin | Administrator | Editor | Viewer |
|---|---|---|---|---|
| View widget | ✅ | ✅ | ✅ (PG) | ✅ (PG) |
| Configure widget | ✅ | ✅ | ✅ | — |
| Add to dashboard | ✅ | ✅ | ✅ | — |

---

### 4.9 Seed Data

#### New RTSGrid_Metric entry (via one-time DB migration — NOT via seeder)

```csharp
// In migration Up():
mb.Sql("""
    INSERT INTO "RTSGrid_Metric"
        ("MetricId", "Description", "DataType", "MetricFunction", "MetricParameter",
         "MetricFormat", "DefaultValue", "ValueType", "MetricType")
    VALUES
        ('QueueLoginDataNumTrainingUsers',
         'Agent Group - Number of Agents in Training State Group',
         'UsersSummary', 'UsersInStatusGroupCount', 'TRAINING',
         '', '', 'String', 'Agent')
    ON CONFLICT ("MetricId") DO NOTHING;
""");
```

#### WidgetCatalogItem seed

```csharp
new WidgetCatalogItem
{
    Id          = new Guid("a4d1e3f7-2b8c-4e9a-b1d5-6f3c2a7e0d11"),
    Category    = "Agents",
    Name        = "Agent State Distribution",
    Description = "Real-time pie/donut/bar chart showing agent distribution across status groups (Available, On Phone, Break, Paperwork, Training) for a selected Business Unit.",
    IconUrl     = "/icons/widgets/agent-state-distribution.svg",
    IsActive    = true
}
```

---

### 4.10 Implementation Notes

1. **Two RTSGrids, always both saved.** On every config save, `SaveQueueGridRtsCommand` is called twice — once for `GroupGridId`, once for `StateGridId`. Both grids are saved regardless of the current `distributionMode`, so switching modes never requires reconfiguration. On widget delete / dispose, both grids are deleted.

2. **No junction table.** `tenant_agent_state_definitions` is not used by this widget. By Group segments come from `GetAgentStateGroupsQuery`; By State segments come from `GetAgentStatesQuery`. No three-way join needed.

3. **MetricId resolution at save time only.** At config save, the handler resolves MetricIds:
   - By Group: `beDb.RtsGridMetrics WHERE MetricFunction = 'UsersInStatusGroupCount' AND MetricParameter = group.GroupName`
   - By State: `beDb.RtsGridMetrics WHERE MetricFunction = 'UsersInStatusCount' AND MetricParameter = state.AgentStateName`
   - Resolved MetricIds are stored in `GroupColumnMetricIds` / `StateColumnMetricIds` in ConfigJson.
   - At render time: look up values from SignalR push using stored MetricIds — zero DB calls.

4. **Dynamic column count.** Both grids have N+1 columns (N segments + 1 Total). Column count changes when Superadmin adds/deactivates groups or states. Re-saving widget config rebuilds the RTSGrid columns.

5. **Localization.**
   - Segment labels (group/state names from DB) — displayed as-is, not translated (user-defined content).
   - Config modal UI labels — use `@L["Key"]`. Check `.resx` for existing equivalents first.
   - Empty/error states — use `@L["Widget.ConfigureFirst"]`, `@L["Widget.NoAgentsLoggedIn"]`.

6. **BU is required.** Widget shows `@L["Widget.ConfigureFirst"]` when `BusinessUnitId == 0`.

7. **OTHER segment.** Computed as `Math.Max(0, total - sumAll)`. Shown only if > 0. Color hardcoded (`#6b7280` / `#9ca3af`) — not user-configurable.

8. **MetricFormat is empty** for all status count metrics — values arrive as plain integer strings. Use `int.TryParse`, never `double.Parse`.

9. **Legacy config migration.** Old ConfigJson uses lowercased keys (`"available"`, `"break"`, …). On deserialization: detect lowercase keys and remap to uppercase CC codes. Keep migration logic in `AgentStateDistributionConfig` constructor or a static `Migrate()` helper.

10. **Chart.js destroy on dispose.** Call `window.agentStateDistributionChart.destroy(elementId)` in `DisposeAsync`.

11. **Dark mode.** Pass `DarkMode` parameter (§16.4). Segment color selection: `DarkMode ? darkSegmentColors[key] : segmentColors[key]`.

12. **CASCADE delete.** `DeleteQueueGridRtsCommand` handles cascade automatically. Must be called for both `GroupGridId` and `StateGridId`.

---

*Widget Specification v1.6 — §4 ASD dual-mode (By Group / By State) added. Two RTSGrids, independent color dicts, no definitions junction. Next: CC-009.*

---

## 5. Agent State Definitions — Tenant Configuration Registry

### 5.1 Overview

| Field | Value |
|---|---|
| Purpose | Configurable mapping of CC-platform agent states to display groups |
| Managed by | Superadmin via Edit Tenant modal → "Agent States" tab |
| Scope | Per-tenant (multi-tenant, Global Query Filter on TenantId) |
| Consumer | `AgentStateDistributionWidget` (CC-008), any future widget needing state-group mapping |
| CC task | CC-008 |

This registry allows Superadmin to define which raw CC-platform states exist and how they group into display categories (e.g., LUNCH → "Break"). Adding a new state group requires no code change — only a new record in this registry.

---

### 5.2 Data Model

Three normalized tables. No physical deletes — all deactivation via `IsActive = false`.

#### `tenant_agent_states`

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK → tenants; GQF |
| AgentState | varchar(100) | Raw state name from CC platform (e.g., "AVAILABLE", "LUNCH") |
| IsActive | bool | Soft-delete flag |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, AgentState)`.

#### `tenant_agent_state_groups`

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK → tenants; GQF |
| GroupName | varchar(100) | Display name (e.g., "Available", "Break") |
| IsActive | bool | Soft-delete flag |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, GroupName)`.

#### `tenant_agent_state_definitions` (junction)

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK → tenants; GQF |
| AgentStateId | uuid | FK → tenant_agent_states CASCADE |
| AgentStateGroupId | uuid | FK → tenant_agent_state_groups CASCADE |
| IsActive | bool | |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, AgentStateId)` — one State maps to exactly one Group per tenant.
CASCADE: delete State or Group → delete the definition row.

#### MetricId resolution

The widget resolves MetricId at query time — no MetricId stored in these tables:

```sql
SELECT s."AgentState", g."GroupName", m."MetricId"
FROM tenant_agent_state_definitions d
JOIN tenant_agent_states s      ON s."Id" = d."AgentStateId"      AND s."IsActive" = true
JOIN tenant_agent_state_groups g ON g."Id" = d."AgentStateGroupId" AND g."IsActive" = true
JOIN "RTSGrid_Metric" m          ON m."MetricParameter" = s."AgentState"
                                 AND m."MetricType" = 'Agent'
WHERE d."TenantId" = @tenantId
  AND d."IsActive" = true
ORDER BY g."GroupName", s."AgentState"
```

---

### 5.3 Seed Data

On first run (DatabaseInitializer), seed 5 standard definitions for every existing tenant:

| AgentState | AgentStateGroup |
|---|---|
| AVAILABLE | Available |
| ONPHONE | On Phone |
| BREAK | Break |
| PAPERWORK | Paperwork |
| TRAINING | Training |

Seed is idempotent (`ON CONFLICT DO NOTHING`). Applied to all active tenants at startup.

---

### 5.4 UI — "Agent States" Tab in Edit Tenant Modal

**Access:** Superadmin only. Tab is hidden for Administrator role.

**Tab layout — two sections:**

#### Section 1: State Groups

Table columns: Group Name | Status (Active / Inactive) | Actions

Actions per row:
- **Edit** — rename the group (inline or mini-modal)
- **Deactivate** — Danger Zone: confirmation dialog with two choices:
  - **Reassign states** — dropdown to select another active group; all definitions pointing to this group are updated to the new group
  - **Deactivate all states** — all `tenant_agent_state_definitions` rows for this group → `IsActive = false`; then Group → `IsActive = false`

Button: **"+ Add State Group"** — prompts for GroupName; creates a new `tenant_agent_state_groups` row.

#### Section 2: Agent States

Table columns: Agent State | Mapped Group | Status | Actions

Actions per row:
- **Edit** — change the mapped group (dropdown of active groups)
- **Deactivate** — Danger Zone: confirmation → `IsActive = false` on `tenant_agent_states` row and its `tenant_agent_state_definitions` row

Button: **"+ Add State"** — form fields: AgentState (text input) + Group (dropdown of active groups); creates rows in both `tenant_agent_states` and `tenant_agent_state_definitions`.

**Validation:**
- `AgentState` unique per tenant (case-insensitive)
- `GroupName` unique per tenant (case-insensitive)
- Cannot deactivate the last active state in a group without also deactivating the group
- Group deactivation requires choosing Reassign or Deactivate All before saving

**Localization:** all UI labels use `@L["Key"]`; AgentState and GroupName values are user-defined strings, not translated.

---

### 5.5 Access Control

| Action | Superadmin | Administrator | Editor | Viewer |
|---|---|---|---|---|
| View Agent States tab | ✅ | — | — | — |
| Add / Edit State Group | ✅ | — | — | — |
| Deactivate State Group | ✅ | — | — | — |
| Add / Edit State | ✅ | — | — | — |
| Deactivate State | ✅ | — | — | — |

---

### 5.6 Impact on AgentStateDistributionWidget (CC-008)

After CC-008, the widget no longer uses `FixedMetricIds`. On init and on config save:

1. Load definitions via `GetAgentStateDefinitionsQuery(TenantId)`
2. Extract MetricIds (via RTSGrid_Metric join) → pass to `SaveQueueGridRtsCommand`
3. `GetChartData()` groups cell values by `AgentStateGroup`, sums MetricIds per group
4. Segment colours stored as `Dictionary<string, string>` keyed by `GroupName` (not hardcoded fields)
5. Config modal Appearance: colour pickers generated dynamically from loaded groups
6. **Backward compat:** if loaded ConfigJson has legacy hardcoded colour fields (`colorAvailable` etc.), convert to dict on load and re-save in new format

OTHER segment logic unchanged: `Math.Max(0, loggedIn - SUM(all active group values))`.

---

*Widget Specification v1.5 — §5 Agent State Definitions registry added. Next: CC-008.*


---

## 6. Info Slot — Message Display Widget

> **⚠ MANDATORY for CC implementation:** before writing any code for this widget, read
> `.claude/skills/widget-creator/widget-creator.md` — specifically **§22** (CC task template structure).
> This widget does **NOT** use Queue Grid or Agent Grid infrastructure.
> It is a **shell-managed widget** with its own SignalR hub (`InfoSlotHub`),
> new DB entities, and new admin/viewer pages.
> Inspect `InfoSlotWidget.razor` (to be created) alongside `DayTrendWidget.razor` for Blazor patterns.

### 6.1 Overview

**Widget name:** Info Slot
**WidgetCatalogItem.Category:** `General`
**WidgetCatalogItem.Name:** `Info Slot`

**Purpose:** Displays scrolling messages written by management staff in real time on contact-centre dashboards. Messages are stored in the shell's own database and pushed to widgets via a shell-owned SignalR hub (`InfoSlotHub`). This widget is **not** backed by CC platform RTS metrics.

**Key concepts:**

| Concept | Description |
|---|---|
| **Info Slot (IS)** | Named container created by an Administrator. Has a display mode; assigned to Permission Groups that can write messages. |
| **Message** | Text written by a Viewer (or higher) with optional expiry date and priority level. |
| **Widget instance** | Blazor component placed on a dashboard, connected to exactly one IS. Multiple instances on different dashboards can share the same IS. |

**Architecture:** Shell-managed. New DB entities (`info_slots`, `info_slot_permissions`, `info_slot_messages`) + `InfoSlotHub` (Blazor Server SignalR hub, separate from `SignalRQueueGridHub`) + `InfoSlotExpiryService` (BackgroundService).

---

### 6.2 Visual Layout

**Ticker mode (`DisplayMode = "Ticker"`):**

All active messages concatenated into one continuous scrolling band. High-priority messages shown first, prefixed with `★`.

```
┌────────────────────────────────────────────────────────────────────┐
│ ★ Urgent: Server maintenance at 18:00  ·····  Team meeting at 15:30  ·····  │
└────────────────────────────────────────────────────────────────────┘
```

Scroll direction (per widget config): left→right, right→left, top→bottom, bottom→top.
High-priority message segment rendered with `priorityHighBackgroundColor` + `priorityHighTextColor`.

**Sequential mode (`DisplayMode = "Sequential"`):**

One message at a time, auto-advances every `SecondsPerMessage` seconds. High-priority messages shown first, then Normal in descending `CreatedAt` order.

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   ★  Urgent: Server maintenance at 18:00                           │
│      Admin · 14:23  ·  expires 18:00                               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Empty state:**

```
┌────────────────────────────────────────────────────────────────────┐
│                    No active messages                              │
└────────────────────────────────────────────────────────────────────┘
```

Text from `emptyStateMessage` config field; falls back to `@L["InfoSlot_NoMessages"]` if empty.

---

### 6.3 Configuration Options

#### Tab: General

| Field | Type | Required | Description |
|---|---|---|---|
| `displayName` | string | No | Widget label in dashboard editor. Default: IS name. |
| `infoSlotId` | uuid | Yes | Selected Info Slot. Dropdown: IS name only. |

#### Tab: Appearance

| Field | Type | Required | Description |
|---|---|---|---|
| `scrollDirection` | enum | Yes | `LeftToRight` / `RightToLeft` / `TopToBottom` / `BottomToTop`. Default: `LeftToRight`. |
| `scrollSpeed` | enum | No | `Slow` / `Medium` / `Fast`. Default: `Medium`. Ticker only; hidden in Sequential mode. |
| `fontSize` | integer | No | Font size in px. Default: `14`. |
| `backgroundColor` | string | No | Hex colour, `"transparent"`, or `"auto"` (follows Light/Dark mode). Default: `"auto"`. |
| `textColor` | string | No | Hex colour or `"auto"`. Default: `"auto"`. |
| `priorityHighBackgroundColor` | string | No | Background for High-priority messages. Default: `"auto"` (Bootstrap warning-bg-subtle). |
| `priorityHighTextColor` | string | No | Text colour for High-priority messages. Default: `"auto"` (Bootstrap warning-text-emphasis). |
| `showAuthor` | bool | No | Show author name under message. Default: `true`. |
| `showTimestamp` | bool | No | Show creation timestamp. Default: `true`. |

#### Tab: Advanced

| Field | Type | Required | Description |
|---|---|---|---|
| `emptyStateMessage` | string | No | Text shown when no active messages. Default: `""` → uses `@L["InfoSlot_NoMessages"]`. |
| `maxMessagesVisible` | integer | No | Maximum messages in Ticker at once. `0` = all. Default: `0`. Ticker only. |

---

### 6.4 Data Model

#### `info_slots`

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK → tenants; GQF |
| Name | varchar(200) | Required; unique per tenant |
| Description | varchar(500) | Optional |
| DisplayMode | varchar(20) | `Ticker` / `Sequential` |
| SecondsPerMessage | integer | Sequential only; default 10; min 3 |
| IsActive | boolean | Deactivation/deletion blocked if placed on any dashboard |
| CreatedAt | timestamptz | UTC |
| CreatedByUserId | uuid | |
| UpdatedAt | timestamptz | UTC |
| UpdatedByUserId | uuid | |

Unique index: `(TenantId, Name)`.

#### `info_slot_permissions`

| Column | Type | Notes |
|---|---|---|
| InfoSlotId | uuid | FK → info_slots CASCADE DELETE |
| PermissionGroupId | uuid | FK → permission_groups CASCADE DELETE |
| TenantId | uuid | For GQF |

PK: `(InfoSlotId, PermissionGroupId)`.

#### `info_slot_messages`

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| InfoSlotId | uuid | FK → info_slots CASCADE DELETE |
| TenantId | uuid | For GQF |
| Content | text | Required |
| Priority | varchar(10) | `Normal` / `High` |
| ExpiresAt | timestamptz? | Nullable — if null, never expires |
| IsActive | boolean | Default true; set false on deactivation or expiry |
| CreatedAt | timestamptz | UTC |
| CreatedByUserId | uuid | |
| DeactivatedAt | timestamptz? | Set when IsActive → false |
| DeactivatedByUserId | uuid? | |

Index: `(InfoSlotId, IsActive, ExpiresAt)` for background service batch query.
Index: `(TenantId, CreatedAt DESC)` for Viewer page listing.

---

### 6.5 Real-Time Architecture

**Hub:** `InfoSlotHub : Hub` (shell-owned, separate from `SignalRQueueGridHub`)
**URL:** `/hubs/info-slot`
**Group naming:** `t:{tenantId}:is:{infoSlotId}` — per ARCH-09
**Auth:** `[Authorize]` on hub class; verify `TenantId` from `ClaimsPrincipal` inside each hub method — per CLAUDE.md §25.

#### Connection flow

```
Widget mounts
  → GetActiveMessagesQuery(infoSlotId, tenantId)   ← DB: IsActive=true, ExpiresAt IS NULL OR ExpiresAt > NOW()
  → Render initial message list
  → Connect to InfoSlotHub, join group "t:{tenantId}:is:{infoSlotId}"

Viewer submits message
  → CreateInfoSlotMessageCommand → DB INSERT → push MessageAdded to hub group

Admin/Viewer deactivates message
  → DeactivateInfoSlotMessageCommand → DB UPDATE → push MessageDeactivated to hub group

Background service (every 60 s)
  → Batch UPDATE expired messages → push MessageExpired per message to hub group

Widget DisposeAsync
  → HubConnection.DisposeAsync()
```

#### Server-push events

| Event | Payload | Trigger |
|---|---|---|
| `MessageAdded` | `InfoSlotMessageDto` | Message created via `CreateInfoSlotMessageCommand` |
| `MessageDeactivated` | `{ MessageId: Guid }` | Message deactivated by author or Admin |
| `MessageExpired` | `{ MessageId: Guid }` | `InfoSlotExpiryService` batch run |

#### Background service: `InfoSlotExpiryService`

- Inherits `BackgroundService`; registered in DI as hosted service.
- Runs every 60 seconds (configurable via `appsettings`).
- Must create a DI scope and set `TenantId` per tenant — per ARCH-07.
- Query pattern (runs for all tenants):
  ```sql
  UPDATE info_slot_messages
  SET "IsActive" = false, "DeactivatedAt" = NOW()
  WHERE "IsActive" = true
    AND "ExpiresAt" IS NOT NULL
    AND "ExpiresAt" <= NOW()
  RETURNING "Id", "TenantId", "InfoSlotId"
  ```
- For each expired row: push `MessageExpired` via `IHubContext<InfoSlotHub>` to correct group.
- Logs count of expired messages per run at Information level; no PII in log.

---

### 6.6 ConfigJson Schema

```json
{
  "infoSlotId": null,
  "displayName": "",
  "scrollDirection": "LeftToRight",
  "scrollSpeed": "Medium",
  "fontSize": 14,
  "backgroundColor": "auto",
  "textColor": "auto",
  "priorityHighBackgroundColor": "auto",
  "priorityHighTextColor": "auto",
  "showAuthor": true,
  "showTimestamp": true,
  "emptyStateMessage": "",
  "maxMessagesVisible": 0
}
```

---

### 6.7 Widget Settings Panel (for CC)

**Tab: General**
- **Widget display name** — text input. Label: `@L["Widget_DisplayName"]`. Placeholder: IS name.
- **Info Slot** — dropdown. Label: `@L["InfoSlot_SelectSlot"]`. Loads all IS accessible to user (Admin/Superadmin: all for tenant; Editor/Viewer: only IS where their PG is in `info_slot_permissions`). Shows IS name only. Required — cannot save without selection.

**Tab: Appearance**
- **Scroll Direction** — `<select>`. Label: `@L["InfoSlot_ScrollDirection"]`. Options: Left→Right, Right→Left, Top→Bottom, Bottom→Top.
- **Scroll Speed** — `<select>`. Label: `@L["InfoSlot_ScrollSpeed"]`. Options: Slow / Medium / Fast. Visible only when selected IS has `DisplayMode = "Ticker"`.
- **Font Size** — number input (px). Label: `@L["Widget_FontSize"]`.
- **Background Color** — colour picker with `transparent` and `auto` options. Label: `@L["Widget_BackgroundColor"]`. `auto` → CSS variable `var(--widget-bg)`.
- **Text Color** — colour picker with `auto`. Label: `@L["Widget_TextColor"]`.
- **High Priority Background** — colour picker with `auto`. Label: `@L["InfoSlot_PriorityHighBackground"]`. `auto` → `var(--bs-warning-bg-subtle)`.
- **High Priority Text Color** — colour picker with `auto`. Label: `@L["InfoSlot_PriorityHighText"]`. `auto` → `var(--bs-warning-text-emphasis)`.
- **Show Author** — checkbox. Label: `@L["InfoSlot_ShowAuthor"]`.
- **Show Timestamp** — checkbox. Label: `@L["InfoSlot_ShowTimestamp"]`.

**Tab: Advanced**
- **Empty State Message** — text input. Label: `@L["InfoSlot_EmptyStateMessage"]`. Placeholder: `@L["InfoSlot_NoMessages"]`.
- **Max Messages Visible** — number input. Label: `@L["InfoSlot_MaxMessages"]`. Min 0 (= all). Visible only when `DisplayMode = "Ticker"`.

---

### 6.8 New Pages

#### `/admin/info-slots` — Info Slot Management (Admin + Superadmin)

**Superadmin tenant selector:** Dropdown at the top of the page — "All Tenants" or a specific tenant. Loads tenant list via `GetTenantsQuery`. Selection reloads the IS list filtered by `SelectedTenantId`. "All Tenants" → handler uses `IgnoreQueryFilters()` + no TenantId filter → writes `Tenant.CrossTenantAccess` audit event.

**List view:**
- Table: Name | DisplayMode badge | Active messages count | PG count | Status (active/inactive) | Edit button | Delete button
- "+ New Info Slot" button (top right) → opens create modal

**Create/Edit modal — 2 tabs:**

*Tab: General*
- Name (required, unique per tenant)
- Description (optional)
- Display Mode: Ticker / Sequential
- Seconds Per Message (number, min 3, default 10) — visible only when DisplayMode = Sequential
- Is Active (toggle) — on deactivate/delete: check `dashboard_widgets` for any widget with `ConfigJson` containing this IS id; if found → block action + show warning modal listing dashboard names

*Tab: Access — PG Assignment*
- Dual-pane selector (standard project pattern): Available PGs ↔ Assigned PGs
- Label: `@L["InfoSlot_AssignedGroups"]`

**Delete IS:**
- Confirmation dialog: `@L["InfoSlot_Delete_Confirm"]`
- Pre-check: if any `DashboardWidget.ConfigJson` references this IS id → show blocking modal with list of dashboard names; delete button disabled until all placements removed
- On confirm: hard delete (CASCADE handles permissions + messages)
- Audit event: `InfoSlot.Deleted`

#### `/info-slots` — Message Management (all roles; PG-gated per IS)

**Superadmin tenant selector:** Same pattern as `/admin/info-slots` — dropdown "All Tenants" / specific tenant at top of page. Switching tenant reloads IS list. "All Tenants" → show all IS across all tenants (with tenant name badge on each IS card).

**List view:**
- Cards or table: IS name | DisplayMode badge | Active messages count | Dashboard list (names of dashboards where IS is placed) | "Manage messages" button
- User sees only IS where their PG is in `info_slot_permissions` (Admin/Superadmin see all)

**Manage messages modal (per IS):**

**Modal header area — Display Mode toggle:**
```
General Messages — messages                                              [×]

Display Mode:  [● Ticker]  [○ Sequential]   Seconds per message: [10 ▲▼]
───────────────────────────────────────────────────────────────────────
Active Messages [2]
```
- Toggle switches between `Ticker` and `Sequential` immediately on click
- `Seconds per message` input visible only when Sequential is selected (min 3, default 10)
- Change → `UpdateInfoSlotDisplayModeCommand` → persists to DB → pushes `DisplayModeChanged` hub event to all widgets showing this IS → widget switches rendering mode in real time
- **Authorization:** same as message write — users whose PG is in `info_slot_permissions` + Admin/Superadmin

*Active messages list:* Priority badge | Author · Timestamp | Content | ExpiresAt | **Edit (pencil)** | Deactivate (⊗)

Each row has two modes:

**Display mode (default):**
```
[★ High]  System Administrator · 29.05 10:35                              [✎] [⊗]
Message 2

[Normal]  System Administrator · 29.05 10:35                              [✎] [⊗]
Test Message
```

**Edit mode** (click ✎ → row expands inline):
```
[★ High]  System Administrator · 29.05 10:35
┌─────────────────────────────────────────────┐
│ Message 2 (editable)                        │
└─────────────────────────────────────────────┘
Priority: ○ Normal  ● High     Expires At: [29/05/2025 --:--]  ☑ Never expires
                                                          [Cancel]  [Save →]
```
- Clicking ✎ on another row while one is open → closes open row (one edit at a time)
- Save → `UpdateInfoSlotMessageCommand` → push `MessageUpdated` to hub group → row returns to display mode
- Cancel → discard changes, return to display mode
- Push `MessageUpdated` received by open widgets → update message in place (no full reload)

**Authorization (Edit):**
- Viewer / Editor: can edit **own** messages only (`CreatedByUserId == currentUser.UserId`) — pencil hidden on others' messages
- Admin / Superadmin: can edit any message — pencil always visible

**Deactivate:** own messages → always; others' messages → Admin/Superadmin only

**Audit event:** `InfoSlot.MessageUpdated` — `Details` includes `MessageId`, `InfoSlotId`, changed fields (old/new Priority, old/new ExpiresAt) — **not** Content (PII)

- "+ Add Message" button → inline form:
  - Content (textarea, required)
  - Priority (Normal / High)
  - Expires At (datetime picker, optional)
  - Submit → `CreateInfoSlotMessageCommand` → push `MessageAdded` to hub group

---

### 6.9 Permission Groups — New Info Slots Tab

In the PG editor (Screen 03, `/admin/permission-groups`), add a new tab **"Info Slots"**:

- Heading: `@L["PermGroup_InfoSlots"]` — `info_slot_permissions`
- Note: `@L["PermGroup_InfoSlots_Note"]` — "Members of this group can write messages to assigned Info Slots"
- List of assigned IS with remove (×) button
- "+ Add Info Slot" button → search/select dialog (IS name search)

New `MenuKey`: `menu.infoSlots` — accessible to all roles (each user sees only IS their PG can write to). Add to `menu_permissions` seed and NavMenu.

---

### 6.10 Access Control

| Action | Superadmin | Administrator | Editor | Viewer |
|---|---|---|---|---|
| View `/admin/info-slots` | ✅ | ✅ | — | — |
| Create / Edit Info Slot | ✅ | ✅ | — | — |
| Delete / Deactivate Info Slot | ✅ | ✅ | — | — |
| Assign PG to Info Slot | ✅ | ✅ | — | — |
| View `/info-slots` page | ✅ | ✅ | ✅ | ✅ (PG-gated) |
| Write message to IS | ✅ | ✅ | ✅ | ✅ (PG-gated) |
| Deactivate own message | ✅ | ✅ | ✅ | ✅ (own only) |
| Deactivate any message | ✅ | ✅ | — | — |
| Place IS widget on dashboard | ✅ | ✅ | ✅ (PG) | — |
| View IS widget on dashboard | ✅ | ✅ | ✅ | ✅ |

**PG-gated:** user must belong to a PG listed in `info_slot_permissions` for the given IS.
**[PG-04] enforced:** IS write access is checked in Application Layer (`AuthorizationBehavior`), not UI only.

---

### 6.11 WidgetCatalogItem Seed

```csharp
new WidgetCatalogItem
{
    Id = Uuid.NewSequential(),
    Category = "General",
    Name = "Info Slot",
    Description = "Displays scrolling messages written by management staff. " +
                  "Supports Ticker (continuous band) and Sequential (one-at-a-time) display modes " +
                  "with configurable scroll direction and priority highlighting.",
    IconUrl = "/icons/widgets/info-slot.svg",
    IsActive = true
}
```

---

### 6.12 Implementation Notes

**Scroll animation (CSS):**
Use `@keyframes` + `animation` on a wrapper `<div>`. Map `ScrollSpeed` to animation duration:

| Speed | Ticker duration | Notes |
|---|---|---|
| Slow | 40 s | `animation: ticker-scroll 40s linear infinite` |
| Medium | 20 s | Default |
| Fast | 10 s | |

Direction determines keyframe axis and sign:
- `LeftToRight`: `translateX(-100%) → translateX(100%)`
- `RightToLeft`: `translateX(100%) → translateX(-100%)`
- `TopToBottom`: `translateY(-100%) → translateY(100%)`
- `BottomToTop`: `translateY(100%) → translateY(-100%)`

Sequential mode: CSS `opacity` fade or slide transition between messages; JS timer advances index every `SecondsPerMessage × 1000` ms.

**Light/Dark mode colours:**
- `backgroundColor = "auto"` → `var(--widget-bg)` (already defined in project theme)
- `textColor = "auto"` → `var(--widget-text)`
- Priority High `auto` → `var(--bs-warning-bg-subtle)` / `var(--bs-warning-text-emphasis)`

**Message ordering rule:**
High priority first → within same priority, descending `CreatedAt`. In Ticker: concatenate with `·····` (5 middle dots) separator. In Sequential: cycle index; wrap around after last message.

**IS deactivation / deletion guard:**
Before UPDATE `IsActive = false` or DELETE on `info_slots`:
```csharp
var placements = await db.DashboardWidgets
    .Where(w => w.ConfigJson.Contains(infoSlotId.ToString()))
    .Select(w => new { w.Dashboard.Name })
    .ToListAsync(ct);
if (placements.Any())
    throw new DomainException($"Info Slot is placed on {placements.Count} dashboard(s): {string.Join(", ", placements.Select(p => p.Name))}");
```

**Audit events** (add to CLAUDE.md §16):
`InfoSlot.Created`, `InfoSlot.Updated`, `InfoSlot.Deactivated`, `InfoSlot.Deleted`,
`InfoSlot.MessageAdded`, `InfoSlot.MessageDeactivated`, `InfoSlot.MessageExpired`

**SignalR group naming example:**
`t:3fa85f64-5717-4562-b3fc-2c963f66afa6:is:7f3b1c2d-4e5a-6b7c-8d9e-0f1a2b3c4d5e`

**Viewer page IS list query:**
```csharp
var slots = await db.InfoSlots
    .Where(s => s.TenantId == tenantId && s.IsActive &&
                s.Permissions.Any(p => p.PermissionGroupId == currentUser.PermissionGroupId))
    .Select(s => new InfoSlotListDto
    {
        Id = s.Id,
        Name = s.Name,
        DisplayMode = s.DisplayMode,
        ActiveMessageCount = s.Messages.Count(m => m.IsActive && (m.ExpiresAt == null || m.ExpiresAt > DateTime.UtcNow)),
        Dashboards = db.DashboardWidgets
            .Where(w => w.ConfigJson.Contains(s.Id.ToString()))
            .Select(w => w.Dashboard.Name)
            .ToList()
    })
    .ToListAsync(ct);
```
Admin/Superadmin: omit the `Permissions.Any(...)` filter.

---

*Widget Specification v1.8 — §6.8 DisplayMode toggle added to messages modal (UpdateInfoSlotDisplayModeCommand, DisplayModeChanged hub event). Next: CC-012.*
