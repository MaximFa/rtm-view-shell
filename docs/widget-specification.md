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
| `StatusGroup` | `AVAILABLE`, `ONPHONE`, `BREAK`, `UNAVAILABLE`, `PAPERWORK`, `SIGNOFF` | Standardised group — use for filtering |
| `TotalDuration` | 3 – 25 155 s | Cumulative seconds in this status today |
| `TotalCount` | 1 – 61 | Number of times agent entered this status today |
| `MaxDuraction` | integer (s) | Longest single session in this status |

#### StatusGroup → business meaning

| StatusGroup | Business meaning | Agent state |
|---|---|---|
| `AVAILABLE` | Agent ready to take calls | Ready / Waiting |
| `ONPHONE` | Agent handling an interaction | Talking, Hold, Ringing, Callbacks, Wrap Up |
| `BREAK` | Agent on scheduled break | Break |
| `UNAVAILABLE` | Agent logged in but unavailable | Unavailable (non-break reasons) |
| `PAPERWORK` | Agent doing post-call or admin work | ACW, Callback wrap |
| `SIGNOFF` | Agent logged off the ACD | Logged out |

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
| `Callback` | `PAPERWORK` | Agent doing callback-related wrap |
| `Callback Incoming` | `ONPHONE` | Receiving a callback call |
| `Callback Outgoing` | `ONPHONE` | Making a callback call |
| `Wrap Up` | `ONPHONE` | ACW — after call work |
| `Break` | `BREAK` | Scheduled break |
| `Back Office` | `UNAVAILABLE` | Back office / admin task |
| `Unavailable` | `PAPERWORK` | Generic unavailable |
| `SIGNOFF` | `SIGNOFF` | Logged off |

#### Metric definitions

| MetricId | Description | MetricFunction | MetricParameter | ValueType | Format |
|---|---|---|---|---|---|
| `agentstatus.available_time` | Available Time | `SUM_DURATION` | `group:AVAILABLE` | `Time` | `hh:mm:ss` |
| `agentstatus.onphone_time` | On Phone Time | `SUM_DURATION` | `group:ONPHONE` | `Time` | `hh:mm:ss` |
| `agentstatus.break_time` | Break Time | `SUM_DURATION` | `group:BREAK` | `Time` | `hh:mm:ss` |
| `agentstatus.unavailable_time` | Unavailable Time | `SUM_DURATION` | `group:UNAVAILABLE` | `Time` | `hh:mm:ss` |
| `agentstatus.paperwork_time` | Paperwork / ACW Time | `SUM_DURATION` | `group:PAPERWORK` | `Time` | `hh:mm:ss` |
| `agentstatus.signoff_time` | Sign-off Time | `SUM_DURATION` | `group:SIGNOFF` | `Time` | `hh:mm:ss` |
| `agentstatus.login_time` | Total Login Time | `SUM_DURATION` | `group:ALL_EXCEPT_SIGNOFF` | `Time` | `hh:mm:ss` |
| `agentstatus.wrap_time` | Wrap Up (ACW) Time | `SUM_DURATION` | `status:Wrap Up` | `Time` | `hh:mm:ss` |
| `agentstatus.call_count` | Calls Handled | `SUM_COUNT` | `status:Incoming Ext Call` | `Number` | `0` |
| `agentstatus.occupancy_pct` | Occupancy % | `RATIO` | `group:ONPHONE/group:ONPHONE+AVAILABLE` | `Number` | `0.0%` |

#### Predicate key → SQL filter mapping (`RTSData_UserStatus`)

| Predicate key | SQL filter |
|---|---|
| `group:AVAILABLE` | `StatusGroup = 'AVAILABLE'` |
| `group:ONPHONE` | `StatusGroup = 'ONPHONE'` |
| `group:BREAK` | `StatusGroup = 'BREAK'` |
| `group:UNAVAILABLE` | `StatusGroup = 'UNAVAILABLE'` |
| `group:PAPERWORK` | `StatusGroup = 'PAPERWORK'` |
| `group:SIGNOFF` | `StatusGroup = 'SIGNOFF'` |
| `group:ALL_EXCEPT_SIGNOFF` | `StatusGroup <> 'SIGNOFF'` |
| `status:Wrap Up` | `StatusName = 'Wrap Up'` |
| `status:Incoming Ext Call` | `StatusName = 'Incoming Ext Call'` |
| `group:ONPHONE/group:ONPHONE+AVAILABLE` | Ratio: `SUM(ONPHONE) / SUM(ONPHONE + AVAILABLE)` |

---

### 2.3 Agent status log metrics (`MetricType = 'AgentStatusLog'`)

**Source table:** `RTSData_UserStatusLog`
**Purpose:** Individual status session records (start/end/duration per session).
Used for adherence analysis and maximum session duration queries.

Fields available:

| Field | Notes |
|---|---|
| `StartTime` | Session start timestamp |
| `EndTime` | Session end timestamp |
| `Duration` | Session duration in seconds |
| `StatusId` | Status identifier (join to UserStatus for StatusName) |

> **Note:** `StatusName` is not present in `RTSData_UserStatusLog` in the production data sample.
> Must be resolved via `StatusId` join to `RTSData_UserStatus` or a separate status lookup.

Metric definitions for this source are deferred to a future sprint
when adherence widgets are designed.

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
new RtsGridMetric { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
new RtsGridMetric { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon",  DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

// Agent status metrics
new RtsGridMetric { MetricId = "agentstatus.available_time",      Description = "Available Time",           DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:AVAILABLE",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.onphone_time",        Description = "On Phone Time",            DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ONPHONE",                          MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.break_time",          Description = "Break Time",               DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:BREAK",                            MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.unavailable_time",    Description = "Unavailable Time",         DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:UNAVAILABLE",                      MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.paperwork_time",      Description = "Paperwork / ACW Time",     DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:PAPERWORK",                        MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.signoff_time",        Description = "Sign-off Time",            DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:SIGNOFF",                          MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.login_time",          Description = "Total Login Time",         DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "group:ALL_EXCEPT_SIGNOFF",               MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.wrap_time",           Description = "Wrap Up (ACW) Time",       DataType = "int",     MetricFunction = "SUM_DURATION", MetricParameter = "status:Wrap Up",                         MetricFormat = "hh:mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.call_count",          Description = "Calls Handled",            DataType = "int",     MetricFunction = "SUM_COUNT",    MetricParameter = "status:Incoming Ext Call",               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },
new RtsGridMetric { MetricId = "agentstatus.occupancy_pct",       Description = "Occupancy %",              DataType = "decimal", MetricFunction = "RATIO",        MetricParameter = "group:ONPHONE/group:ONPHONE+AVAILABLE",  MetricFormat = "0.0%",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatus" },
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

**Data source:** `RTSData_Interaction` — direct read-only query. No SignalR subscription.
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

#### 3.3.3 Metrics (array — ordered, each independently configurable)

Available metrics are loaded from `RTSGrid_Metric WHERE MetricType = 'Interaction'`
(via `GetRtsGridMetricsQuery`). The widget settings panel populates the metric picker from this list.

Each metric entry in ConfigJson:

| Field | Type | Required | Description |
|---|---|---|---|
| `metricId` | string | Yes | `RTSGrid_Metric.MetricId` (e.g. `interaction.incoming_calls`) |
| `enabled` | bool | Yes | Whether this metric is shown. Default: `true` |
| `color` | string | Yes | Hex colour code, e.g. `#3b82f6` |
| `label` | string | No | Override display name. Falls back to `RTSGrid_Metric.Description`. |

**Default metric set (in display order):**

| # | metricId | Default label | Default colour | Default enabled |
|---|---|---|---|---|
| 1 | `interaction.incoming_calls` | Incoming Calls | `#3b82f6` (blue) | `true` |
| 2 | `interaction.answered_calls` | Answered Calls | `#22c55e` (green) | `true` |
| 3 | `interaction.abandoned_calls` | Abandoned Calls | `#ef4444` (red) | `true` |
| 4 | `interaction.callback_requests` | Callback Requests | `#f59e0b` (amber) | `false` |
| 5 | `interaction.completed_callbacks` | Completed Callbacks | `#8b5cf6` (violet) | `false` |
| 6 | `interaction.avg_wait_time` | Avg Wait Time | `#06b6d4` (cyan) | `false` |
| 7 | `interaction.avg_talk_time` | Avg Talk Time | `#64748b` (slate) | `false` |

> **Note:** `avg_wait_time` and `avg_talk_time` are time-based (seconds → `mm:ss`)
> while all other metrics are counts. If both count and time metrics are enabled
> simultaneously, render on **dual Y-axes** (counts on left, seconds on right).

---

### 3.4 Data query

#### 3.4.1 Query logic

```sql
-- Step 1: resolve queues for the BU
-- (performed in application layer via NgcBusinessUnitQueueClassification)
-- Result: @queueList = ['UK - Support', 'UK - Retail', ...]

-- Step 2: query intervals for today
SELECT
    DATE_TRUNC('hour', "InQueueDateTime") +
        (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / @intervalMinutes)
         * (@intervalMinutes || ' minutes')::interval)
        AS interval_start,

    COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                      AND "Direction" = 'Incoming')               AS incoming_calls,

    COUNT(*) FILTER (WHERE "IsAnswered" = true)                   AS answered_calls,

    COUNT(*) FILTER (WHERE "IsAbandoned" = true)                  AS abandoned_calls,

    COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                      AND "Direction" = 'Incoming')               AS callback_requests,

    COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                      AND "Direction" = 'Outgoing'
                      AND "IsAnswered" = true)                    AS completed_callbacks,

    AVG("TimeInQueue") FILTER (WHERE "IsAnswered" = true)         AS avg_wait_time,

    AVG("TalkTime")    FILTER (WHERE "IsAnswered" = true)         AS avg_talk_time

FROM "RTSData_Interaction"
WHERE "TenantId"   = @tenantId
  AND "OnDate"     = TO_CHAR(CURRENT_DATE, 'DD/MM/YYYY')   -- matches DD/MM/YYYY storage format
  AND "Workgroup"  = ANY(@queueList)
GROUP BY interval_start
ORDER BY interval_start;
```

#### 3.4.2 Important notes

- `OnDate` is stored as `varchar` in format `DD/MM/YYYY`. Always pass the date in this format.
- `AnsweredDateTime` null is stored as `1753-01-01 00:00:00.000` — treat as absent, not a real date. Do not use `AnsweredDateTime` for interval grouping.
- `InQueueDateTime` is the canonical timestamp for grouping (when the interaction entered the queue).
- If `@queueList` is empty (BU has no queue assignments), return empty dataset and display
  a warning: _"No queues assigned to this Business Unit"_.
- EF Core / raw SQL: use `FromSqlInterpolated` or parameterised `ExecuteSqlRaw`. Never string concatenation. **[CODE-01]**

#### 3.4.3 EF Core query (application layer)

```csharp
public record DayTrendInterval(
    DateTime IntervalStart,
    int IncomingCalls,
    int AnsweredCalls,
    int AbandonedCalls,
    int CallbackRequests,
    int CompletedCallbacks,
    double? AvgWaitTime,
    double? AvgTalkTime);

// In DayTrendQueryHandler:
var queues = await _ngcRepo.GetQueuesByBusinessUnitAsync(query.BusinessUnitId, ct);
if (!queues.Any())
    return DayTrendResult.NoQueues();

var today = DateTime.UtcNow.ToString("dd/MM/yyyy");  // matches OnDate format
var intervalMinutes = query.IntervalMinutes;           // 15 | 30 | 60

var data = await _beDb.RtsInteractions
    .Where(x => x.TenantId == _tenantContext.TenantId
             && x.OnDate == today
             && queues.Contains(x.Workgroup))
    .GroupBy(x => new {
        IntervalStart = x.InQueueDateTime.HasValue
            ? x.InQueueDateTime.Value
                .AddMinutes(-(x.InQueueDateTime.Value.Minute % intervalMinutes))
                .AddSeconds(-x.InQueueDateTime.Value.Second)
            : (DateTime?)null
    })
    .Where(g => g.Key.IntervalStart != null)
    .Select(g => new DayTrendInterval(
        g.Key.IntervalStart!.Value,
        g.Count(x => x.InteractionType == "Call" && x.Direction == "Incoming"),
        g.Count(x => x.IsAnswered),
        g.Count(x => x.IsAbandoned),
        g.Count(x => x.InteractionType == "Callback" && x.Direction == "Incoming"),
        g.Count(x => x.InteractionType == "Callback" && x.Direction == "Outgoing" && x.IsAnswered),
        g.Where(x => x.IsAnswered && x.TimeInQueue.HasValue).Average(x => (double?)x.TimeInQueue),
        g.Where(x => x.IsAnswered && x.TalkTime.HasValue).Average(x => (double?)x.TalkTime)
    ))
    .OrderBy(x => x.IntervalStart)
    .AsNoTracking()
    .ToListAsync(ct);
```

---

### 3.5 Rendering requirements

#### 3.5.1 Chart

- X-axis: interval start times formatted as `HH:mm`. Show only intervals up to the current time (do not render future empty intervals).
- Y-axis (left): count metrics (integers). Start at 0. Grid lines at reasonable intervals.
- Y-axis (right, optional): time metrics (`avg_wait_time`, `avg_talk_time`) in seconds. Label as `mm:ss`. Only rendered when a time metric is enabled.
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
    { "metricId": "interaction.avg_talk_time",       "enabled": false, "color": "#64748b", "label": "Avg Talk Time"       }
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

**Tab: Metrics**

Table with one row per metric (fixed set of 7):

| Column | Control |
|---|---|
| On/Off | Toggle switch |
| Colour swatch | Colour picker (hex input + palette) |
| Label | Text input (placeholder: default name) |
| Preview | Coloured line/bar sample |

Drag-to-reorder rows changes display order in chart and legend.

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

1. **No RTSGrid_* tables.** DayTrend uses direct `BackendEmulationDbContext` queries only.
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

---

*Widget Specification v0.1 — DayTrend completed. Next: Comparation widget.*
