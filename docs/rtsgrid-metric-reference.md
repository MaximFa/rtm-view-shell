# RTSGrid_Metric — Reference Guide

> Shell-owned reference for working with the CC platform's real-time metric catalogue.
> Based on `Metrics.csv` (190 entries).

---

## 1. Overview

`RTSGrid_Metric` is the CC platform's catalogue of real-time metrics delivered via SignalR.
The shell reads this table to populate widget configuration dropdowns and drive filter logic
in table widgets.

> **⚠ CRITICAL RULES:**
> 1. **Do not seed this table** — it is static. No `SeedRtsGridMetricsAsync()` or equivalent.
> 2. **Do not touch this table in general** — the CC platform manages it.
> 3. **Exception — adding a new metric for a widget:** a new entry MAY be added once via a
>    one-time DB migration during widget creation, provided:
>    - `MetricFunction` is one of the existing values listed in §3.4 — never invent a new one
>    - `MetricParameter` follows the correct format for that `MetricFunction` (see §3.4)
>    This is a deliberate one-time act, not a repeating seed operation.
> 4. Metrics with a dot in `MetricId` (e.g. `interaction.incoming_calls`) belong to
>    `History_Metric`, not `RTSGrid_Metric`.

---

## 2. Metric Categories

Metrics fall into three logical categories, identified by the **Description prefix**:

| Category | Description prefix | MetricType | Used in widgets |
|---|---|---|---|
| **Queue** | `"QM - *"` | `Data` | Queue Grid, Data Slot |
| **AgentGroup** | `"Agent Group - *"` | `Data` | Queue Grid, Data Slot |
| **Agent** | `"Agent - *"` | `Agent` | Agent Grid |

> **Note:** In the current DB all rows have `MetricType = "Agent"` due to a migration error.
> A dedicated CC task will correct this.

---

## 3. Column Reference

### 3.1 MetricId
- **Type:** `varchar`, Primary Key
- **Format:** PascalCase, no dots. Prefixes (`Mon*`, `Queue*`, `User*`, etc.) are historical with no enforced logic.
- **Rule:** MetricIds with a dot (e.g. `interaction.incoming_calls`) belong to the shell-owned `History_Metric` table — never to `RTSGrid_Metric`.
- **New metrics:** Only via a one-time migration during widget creation — never via seeding. See §1 for rules.

### 3.2 Description
- **Type:** `varchar`
- **Purpose:** Display name shown to the user in the metric selection dropdown inside widgets.
- **Convention:** Prefix determines category (see §2).

### 3.3 DataType
- **Type:** `varchar`
- **Values:** `User`, `Interactions Summary`, `UsersSummary`, `UsersInteraction`
- **Purpose:** Internal computation type used by the SignalR server. Transparent to the shell — do not interpret or filter by this field.

### 3.4 MetricFunction
- **Type:** `varchar`
- **Purpose:** Defines **what the metric calculates**, in combination with `MetricParameter`.
  This is the primary field for selecting the right metric for a widget.

| MetricFunction | Meaning | MetricParameter contains |
|---|---|---|
| `InteractionsCount` | Count of interactions matching a filter | C# filter expression |
| `Calc` | Calculated formula referencing other metrics via `[MetricId]` | C# expression with `[MetricId]` references |
| `WaitDurationAvg` | Average wait time | C# filter expression |
| `TalkDurationAvg` | Average talk duration | C# filter expression |
| `WaitDurationCurMax` | Current maximum wait time (real-time) | C# filter expression |
| `UsersInStatusGroupCount` | Count of agents currently in a StatusGroup | StatusGroup name (`AVAILABLE`, `BREAK`, `ONPHONE`, `PAPERWORK`, `TRAINING`) |
| `TotalStatusGroupDuration` | Cumulative time agent spent in a StatusGroup (session/day) | StatusGroup name |
| `TotalStatusDuration` | Cumulative time agent spent in a specific status (not group) | Status name (e.g. `Wrap Up`, `Hold`, `Incoming Ext Call`) |
| `UsersInStatusGroupDurationPercent` | Percent of time agents in a StatusGroup spent there | StatusGroup name |
| `UsersInStatusCount` | Count of agents currently in a specific status (not group) | Status name (e.g. `Missed Call`) |
| `TotalStatusDurationAvg` | Average cumulative time per agent in a specific status per shift | Status name |
| `TotalStatusCount` | Cumulative count of times agent entered a specific status | Status name |
| `NumWaitings` | Count of interactions currently waiting in queue | C# filter expression |
| `MessagesAvgResponseTime` | Average response time for messages | C# filter expression |
| `MessagesAvgFirstResponseTime` | Average first response time for messages | C# filter expression |
| `MessagesMaxFirstResponseTime` | Maximum first response time for messages per shift | C# filter expression |
| `LogedInUsersCount` | Count of currently logged-in agents | Empty |
| `CurStatusDuration` | Duration of agent's current status in real-time | Status name |
| `CPH` | Calls Per Hour | C# filter expression |
| `UsersInStatusGroupDurationCurMax` | Current maximum duration in a StatusGroup across all agents | StatusGroup name |
| `TotalStatusGroupPercent` | Percent of login time agent spent in a StatusGroup | StatusGroup name |
| `TotalStatusGroupDurationAvg` | Average time in a StatusGroup per shift | StatusGroup name |
| `TalkDurationMax` | Maximum talk duration per shift | C# filter expression |
| `TalkDurationCurMax` | Current maximum talk duration in real-time | C# filter expression |
| `CurLoginDuration` | Duration of agent's current login session | Empty |
| `TotalLoginDuration` | Total login time across all sessions today | Empty |
| `LongestInteractionId` | ID of agent's longest active interaction | Empty |
| `LongestInteractionType` | Type of agent's longest active interaction | Empty |
| `LongestInteractionState` | State of agent's longest active interaction | Empty |
| `LongestInteractionStateDuration` | Duration of state of agent's longest active interaction | Empty |
| `LongestInteractionWorkgroup` | Queue name of agent's longest active interaction | Empty |
| `LongestInteractionRemoteAddress` | Customer phone number of agent's longest active interaction | Empty |
| `UserID` | Agent's user ID (static) | Empty |
| `UserExtension` | Agent's extension (static) | Empty |
| `Station` | Agent's station ID (static) | Empty |
| `DisplayName` | Agent's display name (static) | Empty |
| `IsTodayLogin` | Whether agent logged in today (static) | Empty |
| `FirstLoginTimestamp` | Agent's first login timestamp today (static) | Empty |
| `CurLoginTimeStamp` | Agent's current login timestamp (static) | Empty |

### 3.5 MetricParameter
- **Type:** `varchar`
- **Purpose:** Filter or parameter for `MetricFunction`. Meaning depends on `MetricFunction` (see §3.4).
- **`Calc` special case:** Contains a C# expression referencing other MetricIds via `[MetricId]`.
  Computed by SignalR server — shell does not parse it.
  **If an equivalent metric is needed in `History_Metric`, the formula must be manually
  analysed and re-implemented as a SQL expression.**

### 3.6 MetricFormat
- **Type:** `varchar`, mostly empty
- **Purpose:** Format in which the value **arrives in the SignalR push**.
  If `##0.0%` — value arrives as a formatted string e.g. `"85.3%"`.
  If empty — value arrives as a plain numeric string.
  Widgets must account for this when parsing incoming values.

### 3.7 DefaultValue
- **Type:** `varchar`, mostly empty
- **Purpose:** Transparent to the shell.

### 3.8 ValueType
- **Type:** `varchar`
- **Values:** `"number"`, `"time"`, `"text"`
- **Purpose:** Shell-added field. Determines the **filter type** shown in table widget columns
  (Queue Grid, Agent Grid):
  - `number` → numeric operators: less than / greater than / equal; supports time format `MM:SS`
  - `time` → same numeric operators, value interpreted as duration
  - `text` → string operators: contains / equal / starts with / ends with + distinct value list
- **Current state:** All rows have `"String"` — not yet populated correctly. Requires a CC task.

### 3.9 MetricType
- **Type:** `varchar`
- **Values:** `"Data"` (Queue + AgentGroup), `"Agent"`
- **Purpose:** Determines which widget types can use the metric:
  - `Data` → Queue Grid, Data Slot
  - `Agent` → Agent Grid
- **Current state:** All rows have `"Agent"` due to a migration error. CC task pending.

---

## 4. StatusGroup canonical values

Used in `MetricParameter` for StatusGroup-based MetricFunctions:

| Value | Meaning |
|---|---|
| `AVAILABLE` | Agent available for calls |
| `ONPHONE` | Agent on a call |
| `BREAK` | Agent on break |
| `PAPERWORK` | Agent doing paperwork / ACW |
| `TRAINING` | Agent in training / back-office |

> **Note:** `TRAINING` has **no corresponding real-time count metric** in `RTSGrid_Metric`.
> Widgets requiring a TRAINING count must use `History_Metric` (historical data).

---

## 5. Selecting the right metric for a widget

| I need to show… | Look for MetricFunction | Example MetricId |
|---|---|---|
| Count of agents in a status NOW | `UsersInStatusGroupCount` | `QueueLoginDataNumAvailableUsers` |
| Count of agents in a raw status NOW | `UsersInStatusCount` | `MonSumAgentsInMissedCall` |
| Count of calls/interactions | `InteractionsCount` | `QueueNumAnsweredCalls` |
| Average wait time | `WaitDurationAvg` | `QueueAvgWaitTimeCalls` |
| Max wait time NOW | `WaitDurationCurMax` | `QueueCurMaxWaitTimeCalls` |
| Average talk time | `TalkDurationAvg` | `QueueAvgTalkingDurationCalls` |
| Agent's cumulative time in status group | `TotalStatusGroupDuration` | `MonAgentBreakDuration` |
| Agent's cumulative time in specific status | `TotalStatusDuration` | `MonAgentWrapUpDuration` |
| Answered % / SLA % (derived) | `Calc` | `QueuePctAnsweredCalls60secInc` |
| Agents logged in | `LogedInUsersCount` | `QueueLoginDataNumLoggedUsers` |
| Agent identity / static info | `UserID`, `DisplayName`, etc. | `AgentLoginName` |

---

## 6. Pending CC tasks

| Issue | Action |
|---|---|
| `MetricType = "Agent"` for all rows | CC task: set `"Data"` for Queue and AgentGroup metrics |
| `ValueType = "String"` for all rows | CC task: populate correct `"number"` / `"time"` / `"text"` values |

---

*Created: 2026-05-27. Source: `Metrics.csv` (190 entries) + domain knowledge session.*
