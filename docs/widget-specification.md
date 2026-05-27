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
4. [AgentStatusCount — Current Agent Status Distribution](#4-agentstatuscount--current-agent-status-distribution)
5. [AgentStatusDuration — Agent Status Time Distribution (Daily)](#5-agentstatusduration--agent-status-time-distribution-daily)

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

// AgentStatusSnapshot metrics (source: RTSData_UserStatusLog WHERE EndTime IS NULL, agent pool via Interaction)
// MetricFunction COUNT_DISTINCT_ACTIVE = COUNT(DISTINCT UserId) on current (EndTime IS NULL) sessions
new RtsGridMetric { MetricId = "snapshot.available_count",  Description = "Available Agents (Now)",        DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:AVAILABLE",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.onphone_count",    Description = "On Phone Agents (Now)",         DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:ONPHONE",    MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.break_count",      Description = "On Break Agents (Now)",         DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:BREAK",      MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.paperwork_count",  Description = "Paperwork / ACW Agents (Now)",  DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:PAPERWORK",  MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.training_count",   Description = "Training / Back-Office (Now)",  DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:TRAINING",   MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
new RtsGridMetric { MetricId = "snapshot.total_active",     Description = "Total Active Agents (Now)",     DataType = "int", MetricFunction = "COUNT_DISTINCT_ACTIVE", MetricParameter = "group:ALL",        MetricFormat = "0", DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusSnapshot" },
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

---

## 4. AgentStatusCount — Current Agent Status Distribution

### 4.1 Overview

**Widget type ID:** `AgentStatusCount`
**Category:** Agents
**Purpose:** Displays the current distribution of agents across StatusGroups as a
Donut/Pie/Bar chart. Provides a real-time snapshot of how many agents are available,
on the phone, on break, etc. at the time of the last refresh.

**Primary users:**
- Shift Supervisor — monitors current availability vs demand; decides break rotations
- Team Lead — checks break coverage and workload distribution in real time

**Data sources:**
- Agent pool: `RTSData_Interaction` today → DISTINCT UserId answering incoming calls on BU queues
- Current status: `RTSData_UserStatusLog` WHERE EndTime IS NULL for each pooled agent

Both queries are direct read-only. No SignalR subscription. Short polling interval.  
**RTS tables required:** None (`RTSGrid_*` / `RTSUserGrid_*` not used).

---

### 4.2 Visual layout

```
┌─────────────────────────────────────────────────┐
│  Agent Status — Now           [Donut ▼]  [↺]   │
│  BU: Sales CC  ·  14:47:03   ·  ↻ 30s           │
│                                                   │
│            ████████                               │
│         ████        ████                          │
│        ██   AVAIL.   ██                           │
│       ██    8 / 20   ██                           │
│        ██           ██                            │
│         ████        ████                          │
│            ████████                               │
│                                                   │
│  ● Available  8   ● On Phone  7   ● Break  3      │
│  ● Paperwork  2   ● Training  0                   │
│                                                   │
│  Last updated: 14:47:03                           │
└─────────────────────────────────────────────────┘
```

---

### 4.3 Configuration options

#### 4.3.1 General

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string | Yes | Widget title. Default: `"Agent Status — Now"` |
| `businessUnitId` | int | Yes | BU whose agent pool is computed (queues → interactions → agents) |
| `refreshIntervalSeconds` | int | Yes | Auto-refresh period. Options: `15`, `30`, `60`, `300`. Default: `30` |

#### 4.3.2 Appearance

| Field | Type | Required | Description |
|---|---|---|---|
| `chartType` | enum | Yes | `donut` \| `pie` \| `bar`. Default: `donut` |
| `showLegend` | bool | No | Show colour legend below chart. Default: `true` |
| `showLabels` | bool | No | Show count labels on segments/bars. Default: `true` |
| `showCenterTotal` | bool | No | Donut only: show total agent count in center hole. Default: `true` |

#### 4.3.3 StatusGroup segments (`segments` array)

| # | metricId | Default label | Colour | Enabled |
|---|---|---|---|---|
| 1 | `snapshot.available_count` | Available | `#22c55e` | `true` |
| 2 | `snapshot.onphone_count` | On Phone | `#3b82f6` | `true` |
| 3 | `snapshot.break_count` | On Break | `#f59e0b` | `true` |
| 4 | `snapshot.paperwork_count` | Paperwork / ACW | `#f97316` | `true` |
| 5 | `snapshot.training_count` | Training / Back-Office | `#8b5cf6` | `true` |

---

### 4.4 Data query

**Naming convention:** `fn_<widgettype><purpose>` — all lowercase, underscore-separated.

**Output format — narrow (flat snapshot):** returns `(metric_id, value)` — one row per
StatusGroup. No time dimension (this is a snapshot, not a time series).

#### 4.4.1 Agent pool definition

Same derivation as DayTrend (§3.4.2): DISTINCT UserId from `RTSData_Interaction` today,
answered incoming calls on BU queues. Agents who have not answered any call today on
this BU's queues are excluded by design — the widget scope is tied to BU-relevant activity.

#### 4.4.2 `fn_agentstatuscount`

```sql
CREATE OR REPLACE FUNCTION fn_agentstatuscount(
    p_tenantid   uuid,
    p_ondate     varchar(50),  -- DD/MM/YYYY
    p_queuelist  text[]
)
RETURNS TABLE (
    metric_id  text,
    value      double precision
)
LANGUAGE sql STABLE
AS $$
    WITH agent_pool AS (
        -- Agents active today on this BU's queues (answered at least one incoming call)
        SELECT DISTINCT "UserId"
        FROM "RTSData_Interaction"
        WHERE "TenantId"   = p_tenantid
          AND "OnDate"     = p_ondate
          AND "Workgroup"  = ANY(p_queuelist)
          AND "IsAnswered" = true
          AND "Direction"  = 'Incoming'
    ),
    current_status AS (
        -- Each pooled agent's current status session (EndTime IS NULL = active now)
        -- DISTINCT ON handles rare case of multiple open sessions per agent
        SELECT DISTINCT ON (usl."UserId") usl."UserId", usl."StatusGroup"
        FROM "RTSData_UserStatusLog" usl
        JOIN agent_pool ap ON ap."UserId" = usl."UserId"
        WHERE usl."TenantId"    = p_tenantid
          AND usl."EndTime"     IS NULL
          AND usl."StatusGroup" IS NOT NULL
        ORDER BY usl."UserId", usl."StartTime" DESC
    ),
    counts AS (
        -- snapshot.available_count  | group:AVAILABLE
        SELECT
            COUNT(*) FILTER (WHERE "StatusGroup" = 'AVAILABLE')  AS available_count,
            -- snapshot.onphone_count    | group:ONPHONE
            COUNT(*) FILTER (WHERE "StatusGroup" = 'ONPHONE')    AS onphone_count,
            -- snapshot.break_count      | group:BREAK
            COUNT(*) FILTER (WHERE "StatusGroup" = 'BREAK')      AS break_count,
            -- snapshot.paperwork_count  | group:PAPERWORK
            COUNT(*) FILTER (WHERE "StatusGroup" = 'PAPERWORK')  AS paperwork_count,
            -- snapshot.training_count   | group:TRAINING
            COUNT(*) FILTER (WHERE "StatusGroup" = 'TRAINING')   AS training_count,
            -- snapshot.total_active     | group:ALL
            COUNT(*)                                              AS total_active
        FROM current_status
    )
    SELECT 'snapshot.available_count',  available_count::double precision  FROM counts
    UNION ALL
    SELECT 'snapshot.onphone_count',    onphone_count::double precision    FROM counts
    UNION ALL
    SELECT 'snapshot.break_count',      break_count::double precision      FROM counts
    UNION ALL
    SELECT 'snapshot.paperwork_count',  paperwork_count::double precision  FROM counts
    UNION ALL
    SELECT 'snapshot.training_count',   training_count::double precision   FROM counts
    UNION ALL
    SELECT 'snapshot.total_active',     total_active::double precision     FROM counts;
$$;
```

> **Multiple open sessions:** `DISTINCT ON (UserId) ORDER BY StartTime DESC` selects the
> most recent open session per agent. This handles CC backends that occasionally fail to
> close a previous session before opening a new one.

#### 4.4.3 Application layer — C# records and handler

```csharp
// Result type for fn_agentstatuscount (narrow snapshot format)
public record AgentStatusCountRow(string MetricId, double? Value);

public record AgentStatusCountResult(
    IReadOnlyDictionary<string, double> Segments,   // key = MetricId, value = count
    DateTime LastUpdated,
    bool NoQueues = false)
{
    public static AgentStatusCountResult Empty(bool noQueues = false) =>
        new(new Dictionary<string, double>(), DateTime.UtcNow, noQueues);
}
```

```csharp
// In AgentStatusCountQueryHandler.Handle():
var queues = await _ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
if (!queues.Any())
    return AgentStatusCountResult.Empty(noQueues: true);

var tenantId   = _tenantContext.TenantId;
var onDate     = DateTime.UtcNow.ToString("dd/MM/yyyy");   // DD/MM/YYYY
var queueArray = queues.Select(q => q.ExternalId).ToArray();

var rows = await _beDb.Database
    .SqlQuery<AgentStatusCountRow>(
        $"SELECT * FROM fn_agentstatuscount({tenantId}, {onDate}, {queueArray})")
    .ToListAsync(ct);

var segments = rows
    .Where(r => r.Value.HasValue)
    .ToDictionary(r => r.MetricId, r => r.Value!.Value);

return new AgentStatusCountResult(segments, DateTime.UtcNow);
```

#### 4.4.4 Methodology — adding a new status segment

| Step | Action |
|---|---|
| 1 | Add `RtsGridMetric` seed entry (`MetricType = "AgentStatusSnapshot"`, new `MetricId = "snapshot.xyz"`) |
| 2 | Add computed column in `counts` CTE: `COUNT(*) FILTER (WHERE "StatusGroup" = 'XYZ') AS xyz_count` |
| 3 | Add `UNION ALL SELECT 'snapshot.xyz', xyz_count::double precision FROM counts` |
| 4 | Deploy with `CREATE OR REPLACE FUNCTION` — no migration structural change, no C# change |
| 5 | Add entry to ConfigJson `segments[]` (§4.6) and §4.3.3 table |

---

### 4.5 Rendering requirements

#### 4.5.1 Donut / Pie
- One segment per `segments` entry where `enabled = true` and `value > 0`.
- Segment size proportional to `value`.
- Zero-value segments: render as thin stroke only, no label.
- `showCenterTotal = true` (Donut): total of all enabled segments + label "agents" in center hole.
- Tooltip on hover: `"{label} — {N} agents ({X}%)"`.

#### 4.5.2 Bar
- X-axis: StatusGroup labels (from `label` in ConfigJson).
- Y-axis: agent count (integer, starts at 0).
- Each bar coloured per `color` in ConfigJson.
- `showLabels = true`: count displayed above each bar.

#### 4.5.3 Refresh indicator and empty states

| State | Display |
|---|---|
| Loading (first load) | Skeleton chart placeholder |
| No queues in BU | `"No queues assigned to this Business Unit"` |
| No agents today | `"No active agents found for this Business Unit today"` |
| Query error | Error badge with retry button |
| Last updated | Footer: `"Last updated: HH:mm:ss"` |
| Stale data (refresh failed) | Last known data + `"⚠ Data may be stale"` badge |

---

### 4.6 ConfigJson schema

```json
{
  "widgetType": "AgentStatusCount",
  "title": "Agent Status — Now",
  "businessUnitId": 3,
  "refreshIntervalSeconds": 30,
  "chartType": "donut",
  "showLegend": true,
  "showLabels": true,
  "showCenterTotal": true,
  "segments": [
    { "metricId": "snapshot.available_count",  "enabled": true, "color": "#22c55e", "label": "Available"        },
    { "metricId": "snapshot.onphone_count",    "enabled": true, "color": "#3b82f6", "label": "On Phone"         },
    { "metricId": "snapshot.break_count",      "enabled": true, "color": "#f59e0b", "label": "On Break"         },
    { "metricId": "snapshot.paperwork_count",  "enabled": true, "color": "#f97316", "label": "Paperwork / ACW"  },
    { "metricId": "snapshot.training_count",   "enabled": true, "color": "#8b5cf6", "label": "Training"         }
  ]
}
```

---

### 4.7 Widget settings panel (UI — configuration form)

**Tab: General**
- Title (text input)
- Business Unit (dropdown — from `NgcBusinessUnit` filtered by user's PG `pg_business_units`)
- Auto-refresh (dropdown: 15 sec / 30 sec / 1 min / 5 min)

**Tab: Appearance**
- Chart type (icon buttons: Donut / Pie / Bar)
- Show legend (toggle)
- Show labels (toggle)
- Show total in center (toggle — visible only when Chart type = Donut)

**Tab: Status Groups**

Table with one row per StatusGroup (5 rows):

| Column | Control |
|---|---|
| On/Off | Toggle switch |
| Colour swatch | Colour picker (hex input + palette) |
| Label | Text input (placeholder: default name) |

---

### 4.8 Access control

| Role | Access |
|---|---|
| Viewer | Can view widget (if dashboard View permission granted) |
| Editor | Can view + configure widget settings |
| Administrator | Can view + configure + assign to any BU in their tenant |
| Superadmin | Full access across all tenants |

BU dropdown: shows only BUs where user's PG has access (`pg_business_units`).
Empty `pg_business_units` → show all BUs in tenant (per `[PG-03]` semantics).

---

### 4.9 WidgetCatalogItem seed entry

```csharp
new WidgetCatalogItem
{
    Id          = Uuid.NewSequential(),
    Category    = "Agents",
    Name        = "Agent Status Distribution (Now)",
    Description = "Donut/Pie/Bar chart showing the current count of agents in each "
                + "status group (Available, On Phone, Break, Paperwork, Training) "
                + "for agents active today on the selected Business Unit's queues. "
                + "Configurable chart type, colours, labels, and auto-refresh (default 30 s).",
    IconUrl     = "/icons/widgets/agent-status-count.svg",
    IsActive    = true
}
```

---

### 4.10 Implementation notes

1. **No RTSGrid_* tables.** No `SaveAgentStatusCountRtsCommand`. Direct read via `BackendEmulationDbContext`.

2. **Agent pool dependency.** Agents who have not answered any incoming call today on this
   BU's queues will not appear — even if logged in. This is a known design constraint, not a bug.
   Document in the widget tooltip / help text: _"Shows agents who handled at least one call
   today on this Business Unit."_

3. **Multiple open sessions.** The `DISTINCT ON (UserId) ORDER BY StartTime DESC` guard
   prevents double-counting in case the CC backend leaves multiple `EndTime IS NULL` rows
   for the same agent. This is a defensive measure — not expected in normal operation.

4. **OnDate format.** `DD/MM/YYYY` varchar. Always: `DateTime.UtcNow.ToString("dd/MM/yyyy")`.

5. **Migration.** `fn_agentstatuscount` and `fn_agentstatusduration` (§5) are created in the
   **same migration** `AddAgentStatusFunctions` under `BackendEmulationDbContext`.

---

## 5. AgentStatusDuration — Agent Status Time Distribution (Daily)

### 5.1 Overview

**Widget type ID:** `AgentStatusDuration`
**Category:** Agents
**Purpose:** Displays today's cumulative time distribution across StatusGroups as a
Donut/Pie/Bar chart. Shows, in aggregate, how much time all BU agents spent in each
status group today — useful for utilisation analysis and break compliance monitoring.

**Primary users:**
- Shift Manager — validates break compliance; compares ONPHONE vs AVAILABLE share
- Department Manager — reviews daily utilisation patterns and training time

**Data sources:**
- `RTSData_UserStatus`: per-agent cumulative daily totals (`TotalDuration` in seconds per StatusGroup)
- Agent pool: same BU-based derivation as AgentStatusCount (§4.4.1)

Both queries are direct read-only. No SignalR subscription.  
**RTS tables required:** None.

---

### 5.2 Visual layout

```
┌─────────────────────────────────────────────────┐
│  Agent Status — Today         [Donut ▼]  [↺]   │
│  BU: Sales CC  ·  26/05/2026  ·  ↻ 5 min        │
│                                                   │
│            ████████                               │
│         ████        ████                          │
│        ██  ON PHONE  ██                           │
│       ██   4h 23m    ██                           │
│        ██           ██                            │
│         ████        ████                          │
│            ████████                               │
│                                                   │
│  ● Available  6h 12m  ● On Phone  4h 23m          │
│  ● Break  1h 05m  ● Paperwork  0h 48m             │
│                                                   │
│  Last updated: 14:47:03                           │
└─────────────────────────────────────────────────┘
```

---

### 5.3 Configuration options

#### 5.3.1 General

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string | Yes | Widget title. Default: `"Agent Status — Today"` |
| `businessUnitId` | int | Yes | BU for agent pool derivation |
| `refreshIntervalSeconds` | int | Yes | Options: `60`, `300`, `600`. Default: `300` (5 min) |

#### 5.3.2 Appearance

| Field | Type | Required | Description |
|---|---|---|---|
| `chartType` | enum | Yes | `donut` \| `pie` \| `bar`. Default: `donut` |
| `showLegend` | bool | No | Default: `true` |
| `showLabels` | bool | No | Default: `true` |
| `showCenterTotal` | bool | No | Donut: total login time in center hole. Default: `true` |
| `durationFormat` | enum | No | `hh:mm` \| `hh:mm:ss` \| `minutes`. Default: `hh:mm` |

#### 5.3.3 StatusGroup segments (`segments` array)

| # | metricId | Default label | Colour | Enabled |
|---|---|---|---|---|
| 1 | `agentstatus.available_time` | Available | `#22c55e` | `true` |
| 2 | `agentstatus.onphone_time` | On Phone | `#3b82f6` | `true` |
| 3 | `agentstatus.break_time` | On Break | `#f59e0b` | `true` |
| 4 | `agentstatus.paperwork_time` | Paperwork / ACW | `#f97316` | `true` |
| 5 | `agentstatus.training_time` | Training / Back-Office | `#8b5cf6` | `true` |

> Reuses existing `agentstatus.*` seed entries (MetricType = `AgentStatus`). No new seeds needed.

---

### 5.4 Data query

**Output format — narrow (flat snapshot):** returns `(metric_id, value)` — one row per
StatusGroup. `value` is total seconds accumulated by all BU agents in that StatusGroup today.

#### 5.4.1 `fn_agentstatusduration`

```sql
CREATE OR REPLACE FUNCTION fn_agentstatusduration(
    p_tenantid   uuid,
    p_ondate     varchar(50),  -- DD/MM/YYYY
    p_queuelist  text[]
)
RETURNS TABLE (
    metric_id  text,
    value      double precision
)
LANGUAGE sql STABLE
AS $$
    WITH agent_pool AS (
        -- Same pool definition as AgentStatusCount (§4.4.1)
        SELECT DISTINCT "UserId"
        FROM "RTSData_Interaction"
        WHERE "TenantId"   = p_tenantid
          AND "OnDate"     = p_ondate
          AND "Workgroup"  = ANY(p_queuelist)
          AND "IsAnswered" = true
          AND "Direction"  = 'Incoming'
    ),
    totals AS (
        -- Single aggregate pass over RTSData_UserStatus for today's agent pool
        -- Column comments: MetricId | MetricParameter predicate
        SELECT
            -- agentstatus.available_time  | group:AVAILABLE
            COALESCE(SUM(us."TotalDuration") FILTER (WHERE us."StatusGroup" = 'AVAILABLE'),  0) AS available_s,
            -- agentstatus.onphone_time    | group:ONPHONE
            COALESCE(SUM(us."TotalDuration") FILTER (WHERE us."StatusGroup" = 'ONPHONE'),    0) AS onphone_s,
            -- agentstatus.break_time      | group:BREAK
            COALESCE(SUM(us."TotalDuration") FILTER (WHERE us."StatusGroup" = 'BREAK'),      0) AS break_s,
            -- agentstatus.paperwork_time  | group:PAPERWORK
            COALESCE(SUM(us."TotalDuration") FILTER (WHERE us."StatusGroup" = 'PAPERWORK'),  0) AS paperwork_s,
            -- agentstatus.training_time   | group:TRAINING
            COALESCE(SUM(us."TotalDuration") FILTER (WHERE us."StatusGroup" = 'TRAINING'),   0) AS training_s
        FROM "RTSData_UserStatus" us
        JOIN agent_pool ap ON ap."UserId" = us."UserId"
        WHERE us."TenantId" = p_tenantid
          AND us."OnDate"   = p_ondate
    )
    SELECT 'agentstatus.available_time',  available_s::double precision  FROM totals
    UNION ALL
    SELECT 'agentstatus.onphone_time',    onphone_s::double precision    FROM totals
    UNION ALL
    SELECT 'agentstatus.break_time',      break_s::double precision      FROM totals
    UNION ALL
    SELECT 'agentstatus.paperwork_time',  paperwork_s::double precision  FROM totals
    UNION ALL
    SELECT 'agentstatus.training_time',   training_s::double precision   FROM totals;
$$;
```

> `TotalDuration` in `RTSData_UserStatus` is stored in **seconds** (confirmed in `RtsDataUserStatus`
> entity: _"TotalDuration and MaxDuration are in seconds"_). The function returns seconds;
> the client formats with `TimeSpan.FromSeconds(v)`.

#### 5.4.2 Application layer — C# records and handler

```csharp
// Result type for fn_agentstatusduration
public record AgentStatusDurationRow(string MetricId, double? Value);

public record AgentStatusDurationResult(
    IReadOnlyDictionary<string, double> Segments,  // key = MetricId, value = seconds
    DateTime LastUpdated,
    bool NoQueues = false)
{
    public static AgentStatusDurationResult Empty(bool noQueues = false) =>
        new(new Dictionary<string, double>(), DateTime.UtcNow, noQueues);
}
```

```csharp
// Duration formatter (seconds → display string)
public static string FormatDuration(double seconds, string format) => format switch
{
    "hh:mm:ss" => TimeSpan.FromSeconds(seconds).ToString(@"hh\:mm\:ss"),
    "minutes"  => $"{(int)(seconds / 60)} min",
    _          => TimeSpan.FromSeconds(seconds).ToString(@"h\:mm")  // hh:mm default
};
```

```csharp
// In AgentStatusDurationQueryHandler.Handle():
var queues = await _ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
if (!queues.Any())
    return AgentStatusDurationResult.Empty(noQueues: true);

var tenantId   = _tenantContext.TenantId;
var onDate     = DateTime.UtcNow.ToString("dd/MM/yyyy");
var queueArray = queues.Select(q => q.ExternalId).ToArray();

var rows = await _beDb.Database
    .SqlQuery<AgentStatusDurationRow>(
        $"SELECT * FROM fn_agentstatusduration({tenantId}, {onDate}, {queueArray})")
    .ToListAsync(ct);

var segments = rows
    .Where(r => r.Value.HasValue)
    .ToDictionary(r => r.MetricId, r => r.Value!.Value);

return new AgentStatusDurationResult(segments, DateTime.UtcNow);
```

#### 5.4.3 Methodology — adding a new status segment

| Step | Action |
|---|---|
| 1 | Add `RtsGridMetric` seed entry if new MetricId (`MetricType = "AgentStatus"`) |
| 2 | Add column in `totals` CTE: `COALESCE(SUM(...) FILTER (WHERE StatusGroup = 'XYZ'), 0) AS xyz_s` |
| 3 | Add `UNION ALL SELECT 'agentstatus.xyz_time', xyz_s::double precision FROM totals` |
| 4 | Deploy with `CREATE OR REPLACE FUNCTION` — no C# change |
| 5 | Add to ConfigJson `segments[]` and §5.3.3 table |

---

### 5.5 Rendering requirements

#### 5.5.1 Donut / Pie
- One segment per enabled entry with `value > 0`.
- Segment size proportional to `value` (seconds).
- Tooltip: `"{label} — {formatted duration} ({X}%)"`.
- `showCenterTotal = true` (Donut): total login time (sum of all enabled segments)
  formatted per `durationFormat`, + label "total today" in center hole.

#### 5.5.2 Bar
- X-axis: StatusGroup labels.
- Y-axis: seconds. Format Y-axis tick labels per `durationFormat`.
- `showLabels = true`: formatted duration above each bar.

#### 5.5.3 Refresh indicator and empty states

| State | Display |
|---|---|
| Loading | Skeleton chart |
| No queues | `"No queues assigned to this Business Unit"` |
| No data | `"No status data recorded today for this Business Unit"` |
| Query error | Error badge + retry |
| Last updated | Footer: `"Last updated: HH:mm:ss"` |
| Stale data | Last known data + `"⚠ Data may be stale"` badge |

---

### 5.6 ConfigJson schema

```json
{
  "widgetType": "AgentStatusDuration",
  "title": "Agent Status — Today",
  "businessUnitId": 3,
  "refreshIntervalSeconds": 300,
  "chartType": "donut",
  "showLegend": true,
  "showLabels": true,
  "showCenterTotal": true,
  "durationFormat": "hh:mm",
  "segments": [
    { "metricId": "agentstatus.available_time",  "enabled": true, "color": "#22c55e", "label": "Available"        },
    { "metricId": "agentstatus.onphone_time",    "enabled": true, "color": "#3b82f6", "label": "On Phone"         },
    { "metricId": "agentstatus.break_time",      "enabled": true, "color": "#f59e0b", "label": "On Break"         },
    { "metricId": "agentstatus.paperwork_time",  "enabled": true, "color": "#f97316", "label": "Paperwork / ACW"  },
    { "metricId": "agentstatus.training_time",   "enabled": true, "color": "#8b5cf6", "label": "Training"         }
  ]
}
```

---

### 5.7 Widget settings panel (UI — configuration form)

**Tab: General**
- Title (text input)
- Business Unit (dropdown — from `NgcBusinessUnit` filtered by user's PG)
- Auto-refresh (dropdown: 1 min / 5 min / 10 min)

**Tab: Appearance**
- Chart type (icon buttons: Donut / Pie / Bar)
- Show legend (toggle)
- Show labels (toggle)
- Show total in center (toggle — visible only when Chart type = Donut)
- Duration format (radio group: `hh:mm` / `hh:mm:ss` / `minutes`)

**Tab: Status Groups**

Table with one row per StatusGroup (5 rows). Same structure as §4.7:

| Column | Control |
|---|---|
| On/Off | Toggle switch |
| Colour swatch | Colour picker (hex + palette) |
| Label | Text input (placeholder: default name) |

---

### 5.8 Access control

Same as §4.8 and §3.8: all roles can view; Editor+ can configure;
BU dropdown filtered by user's `pg_business_units`.

---

### 5.9 WidgetCatalogItem seed entry

```csharp
new WidgetCatalogItem
{
    Id          = Uuid.NewSequential(),
    Category    = "Agents",
    Name        = "Agent Status Duration (Today)",
    Description = "Donut/Pie/Bar chart showing today's cumulative time distribution "
                + "across status groups (Available, On Phone, Break, Paperwork, Training) "
                + "for agents active on the selected Business Unit. "
                + "Duration displayed as hh:mm (configurable). Auto-refresh default 5 min.",
    IconUrl     = "/icons/widgets/agent-status-duration.svg",
    IsActive    = true
}
```

---

### 5.10 Implementation notes

1. **TotalDuration unit.** `RTSData_UserStatus.TotalDuration` is **seconds** (entity comment
   confirmed). Format with `TimeSpan.FromSeconds(v)`. Do **not** divide by 1000 (that would be
   for milliseconds, which applies only to `RTSData_UserStatusLog.Duration`).

2. **Agent pool shared with AgentStatusCount.** Both widgets use the same CTE logic.
   The `fn_agentstatuscount` and `fn_agentstatusduration` functions each contain their own
   `agent_pool` CTE — no shared SQL object needed. If a shared helper function is desired in
   the future, it can be extracted without changing the calling C# code.

3. **Refresh rate default 5 min.** Unlike AgentStatusCount (30 s), `RTSData_UserStatus`
   accumulates incrementally throughout the day — rapid polling adds little value. 5 min is
   the recommended default. Allow 1 min minimum in config validation.

4. **Migration.** `fn_agentstatuscount` (§4) and `fn_agentstatusduration` (§5) are created
   in the **same migration** `AddAgentStatusFunctions` under `BackendEmulationDbContext`.

5. **No new seed entries.** `AgentStatusDuration` reuses existing `agentstatus.*` metrics
   (MetricType = `AgentStatus`) already seeded from §2.4.

---

*Widget Specification v0.9 — §4 AgentStatusCount (snapshot, fn_agentstatuscount) and §5 AgentStatusDuration (daily totals, fn_agentstatusduration) added. snapshot.* MetricType added to §2.4. Next: CC-003.*
