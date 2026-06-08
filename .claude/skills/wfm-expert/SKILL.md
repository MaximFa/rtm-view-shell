---
name: wfm-expert
description: >
  Workforce Management domain expert for RTM View Shell. Covers WFM concepts,
  data models, scheduling logic, adherence calculation, and implementation guidance.
  Trigger this skill whenever the user mentions: WFM, workforce management,
  workforce planning, staffing, headcount, scheduling, schedule, roster, rostering,
  Erlang C, Erlang B, traffic intensity, call arrival rate, service level target,
  required agents, shrinkage, shrinkage factor, occupancy target, utilisation target,
  adherence, schedule adherence, real-time adherence, RTA, conformance,
  schedule compliance, planned vs actual, schedule deviation,
  forecast, forecasting, call volume forecast, intraday forecast, intraday reforecast,
  staffing requirement, FTE, full-time equivalent, agent requirement,
  shift pattern, shift type, shift schedule, shift template, shift bid,
  break schedule, lunch rotation, off-phone activity, training time,
  absence management, absenteeism, sick leave impact on staffing,
  NICE IEX, Verint WFM, Aspect WFM, Genesys WFM, NICE WFM, Calabrio, Injixo,
  capacity planning, annual leave planning, vacation planning,
  intraday management, intraday adjustment, skill blending,
  "how many agents do I need", "staffing model", "coverage requirement",
  "schedule view", "adherence report", "schedule vs actual",
  or any request to design, implement, or calculate workforce planning features
  in RTM View Shell or connected CC systems.
  Never skip this skill when designing adherence views, schedule screens,
  staffing dashboards, or WFM data models in RTM View Shell.
---

# WFM Expert — RTM View Shell

This skill provides **Workforce Management (WFM)** domain knowledge and implementation
guidance for RTM View Shell. WFM is the discipline of getting the right number of
agents with the right skills in the right place at the right time.

> **Boundary:** RTM View Shell does NOT replace a WFM system (NICE IEX, Verint, etc.).
> It can: (a) display WFM schedule data imported from an external WFM system,
> (b) calculate and display schedule adherence using RTM real-time agent state data,
> (c) provide a lightweight schedule view for smaller centres without a dedicated WFM tool.

---

## 1. WFM process overview

```
FORECAST                  SCHEDULE                 INTRADAY               ANALYSIS
──────────────────────────────────────────────────────────────────────────────────────
Historical call volume  → Staffing requirement  → Monitor adherence  → Adherence report
  by interval + day       by interval            in real time         Agent performance
  + growth factor       → Shift patterns                              SLA vs forecast
  + seasonality         → Break allocation       → Reforecast          Shrinkage actual
  = Erlang C input      → Published schedule     → Adjust coverage      vs planned
```

---

## 2. Forecasting — how staffing requirements are calculated

### 2.1 Erlang C model (standard for voice CC)

Erlang C calculates the **minimum number of agents** needed to achieve a service level target.

**Inputs:**
| Input | Description | Typical source |
|-------|-------------|----------------|
| λ (lambda) | Call arrival rate per interval (calls/hour) | Historical data, 30-min intervals |
| AHT | Average Handle Time in seconds | Historical (talk + hold + ACW) |
| SL target | e.g. 80% answered in 20 seconds | Business requirement |
| t | Threshold in seconds (the "20" in 80/20) | Business requirement |

**Output:** minimum agents N such that SL(N) ≥ target.

**Erlang C formula** (implement as a utility function):
```csharp
// Traffic intensity
double A = (lambda * aht) / 3600.0;  // Erlangs

// Erlang C(N, A): probability call waits
// C(N,A) = (A^N / N!) * (N/(N-A)) / [sum(A^k/k!, k=0..N-1) + (A^N/N!)*(N/(N-A))]

// Service Level
// SL(N, t) = 1 - C(N,A) * exp(-(N-A) * t / AHT)

// Find minimum N where SL(N, t) >= slTarget
```

**Shrinkage adjustment:** raw Erlang N is the on-phone requirement.
Multiply by `1 / (1 - shrinkageRate)` to get **rostered headcount**.

Example: Erlang says 12 agents on-phone. Shrinkage 30% → roster 12 / 0.7 = **17.1 → 18 agents**.

### 2.2 Interval granularity

WFM schedules use **30-minute intervals** (universal WFM standard).
15-minute granularity is used for real-time adjustment only; it does not affect shift length.

### 2.3 Growth and seasonality

```
Adjusted forecast = base_volume × day_of_week_factor × month_factor × growth_factor
```

Day-of-week factors and month factors are derived from 12 months of historical data.
RTM View Shell can expose this data via `hist_queue_interval` (§3 of cc-historical-reports skill).

---

## 3. Shrinkage

**Shrinkage** = the percentage of scheduled time agents are unavailable for calls.

### 3.1 Categories

| Category | Type | Typical % | Notes |
|----------|------|-----------|-------|
| Scheduled breaks | Internal | 10–12% | Tea/coffee breaks, included in shift |
| Scheduled lunch | Internal | 7–8% | 30–60 min per shift |
| Training / team meetings | Internal | 3–5% | Planned off-phone time |
| Coaching / 1:1 | Internal | 2–3% | Supervisor sessions |
| Sick leave | External | 3–5% | Unplanned, historical average |
| Vacation / annual leave | External | 8–10% | Planned, varies by season |
| Late arrival / early leave | External | 1–2% | Punctuality shrinkage |
| Tech issues / system down | External | 1–2% | Unplanned |
| **Total typical** | | **35–45%** | Higher in busy centres |

### 3.2 Shrinkage in RTM View Shell

Store planned vs actual shrinkage:

```sql
CREATE TABLE wfm_shrinkage_plan (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    period_start    date NOT NULL,
    period_end      date NOT NULL,         -- inclusive
    category        varchar(50) NOT NULL,  -- enum above
    shrinkage_pct   numeric(5,2) NOT NULL, -- e.g. 12.50 = 12.5%
    UNIQUE (tenant_id, period_start, period_end, category)
);
```

Actual shrinkage = derive from `hist_agent_interval.sum_not_ready_seconds` grouped by not-ready reason code.

---

## 4. Schedule data model

### 4.1 Core tables

```sql
-- A published schedule for one agent, one day
CREATE TABLE wfm_schedule (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    agent_id        uuid NOT NULL,         -- FK → identity.users
    schedule_date   date NOT NULL,
    shift_start     timestamptz NOT NULL,  -- UTC
    shift_end       timestamptz NOT NULL,  -- UTC
    queue_id        uuid,                  -- primary queue assignment (NULL = any)
    status          varchar(20) NOT NULL   -- Draft | Published | Cancelled
        DEFAULT 'Published',
    source          varchar(30),           -- 'WFM_IMPORT' | 'MANUAL' | 'SYSTEM'
    external_id     varchar(100),          -- ID in external WFM system for sync
    created_at      timestamptz NOT NULL,
    updated_at      timestamptz NOT NULL,
    UNIQUE (tenant_id, agent_id, schedule_date)
);

-- Off-phone activities within a shift (breaks, lunch, training)
CREATE TABLE wfm_schedule_activity (
    id              uuid PRIMARY KEY,
    schedule_id     uuid NOT NULL REFERENCES wfm_schedule(id) ON DELETE CASCADE,
    tenant_id       uuid NOT NULL,
    activity_type   varchar(30) NOT NULL,  -- Break | Lunch | Training | Meeting | Coaching
    planned_start   timestamptz NOT NULL,
    planned_end     timestamptz NOT NULL,
    is_paid         boolean NOT NULL DEFAULT true
);

-- Indexes
CREATE INDEX ON wfm_schedule (tenant_id, schedule_date, agent_id);
CREATE INDEX ON wfm_schedule (tenant_id, agent_id, schedule_date);
CREATE INDEX ON wfm_schedule_activity (schedule_id);
```

### 4.2 Schedule import from external WFM

Most mid-size centres have an external WFM tool (NICE IEX, Verint, Calabrio).
RTM View Shell imports schedule data via:

1. **CSV import**: WFM exports a CSV → admin uploads in Tenant Settings → parsed into `wfm_schedule`.
2. **API polling**: RTM Service calls WFM REST API periodically (if available) → stores in `wfm_schedule`.
3. **Manual entry**: small centres without WFM enter schedules directly in the Shell UI.

**CSV import format (recommended standard):**
```
AgentId,AgentName,Date,ShiftStart,ShiftEnd,Break1Start,Break1End,LunchStart,LunchEnd
user@email.com,John Smith,2026-06-09,08:00,17:00,10:15,10:30,12:30,13:00
```
Parse: match `AgentId` (email) to `ApplicationUser.Email` within the tenant.

---

## 5. Schedule adherence

Adherence measures how closely agents follow their published schedule.

### 5.1 Definition

```
Adherence % = (minutes in correct state) / (total scheduled minutes) × 100

Correct state = agent is doing what the schedule says at that minute:
  - Shift time + not in off-phone activity → agent should be in READY or TALKING
  - Scheduled break/lunch → agent should be in NOT_READY (break code)
  - Before shift start or after shift end → agent should be logged out
```

### 5.2 Adherence states matrix

| Scheduled state | Actual agent state | Adherent? |
|----------------|-------------------|-----------|
| On-phone (READY/TALKING) | READY, TALKING, HOLD, ACW | ✓ Yes |
| On-phone | NOT_READY | ✗ No — unavailable when should be available |
| On-phone | Logged out | ✗ No — absent |
| Break (NOT_READY) | NOT_READY | ✓ Yes |
| Break (NOT_READY) | READY, TALKING | ✓ Yes (working through break — usually counts as adherent) |
| Not scheduled (before/after shift) | Logged in | ✓ Yes (overtime — usually counted separately) |
| Not scheduled | Logged out | ✓ Yes |

### 5.3 Adherence calculation SQL

```sql
-- Calculate adherence for one agent for one day
-- Requires: wfm_schedule, wfm_schedule_activity, RTSData_UserStatus (agent state log)

WITH schedule AS (
    SELECT
        s.shift_start,
        s.shift_end,
        COALESCE(
            json_agg(
                json_build_object(
                    'start', a.planned_start,
                    'end',   a.planned_end,
                    'type',  a.activity_type
                ) ORDER BY a.planned_start
            ) FILTER (WHERE a.id IS NOT NULL),
            '[]'::json
        ) AS activities
    FROM wfm_schedule s
    LEFT JOIN wfm_schedule_activity a ON a.schedule_id = s.id
    WHERE s.tenant_id = :tenant_id
      AND s.agent_id  = :agent_id
      AND s.schedule_date = :report_date
    GROUP BY s.shift_start, s.shift_end
),
-- Agent state log for the day (from RTSData_UserStatus)
agent_states AS (
    SELECT
        status_started_at AS from_ts,
        COALESCE(
            LEAD(status_started_at) OVER (ORDER BY status_started_at),
            :report_date::timestamptz + INTERVAL '1 day'
        ) AS to_ts,
        status_name         -- READY | TALKING | NOT_READY | LOGGED_OUT
    FROM "RTSData_UserStatus"
    WHERE "TenantId"  = :tenant_id
      AND "UserId"    = :agent_id
      AND status_started_at >= :report_date::timestamptz
      AND status_started_at <  :report_date::timestamptz + INTERVAL '1 day'
)
-- Join on overlapping time windows and score each minute
-- (implementation: generate minute series, join schedule + state, classify each minute)
SELECT
    COUNT(*) FILTER (WHERE is_adherent) AS adherent_minutes,
    COUNT(*)                            AS total_scheduled_minutes,
    ROUND(
        COUNT(*) FILTER (WHERE is_adherent)::numeric / NULLIF(COUNT(*),0) * 100,
    1) AS adherence_pct
FROM generate_series(
    (SELECT shift_start FROM schedule),
    (SELECT shift_end   FROM schedule) - INTERVAL '1 minute',
    INTERVAL '1 minute'
) AS t(minute)
CROSS JOIN schedule
-- ... (classify each minute based on schedule + actual state)
;
```

**Implementation note:** the minute-by-minute approach is accurate but slow for large
teams. For production, pre-compute adherence into:

```sql
CREATE TABLE hist_agent_adherence (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    agent_id        uuid NOT NULL,
    report_date     date NOT NULL,
    scheduled_minutes   integer NOT NULL,
    adherent_minutes    integer NOT NULL,
    non_adherent_minutes integer NOT NULL,
    adherence_pct   numeric(5,2) NOT NULL,
    computed_at     timestamptz NOT NULL,
    UNIQUE (tenant_id, agent_id, report_date)
);
```

---

## 6. WFM screens in RTM View Shell

### 6.1 Screen inventory

| Route | Name | Roles | Purpose |
|-------|------|-------|---------|
| `/wfm/schedule` | Schedule View | All | See own/team schedule for today and next 7 days |
| `/wfm/adherence` | Adherence Monitor | Admin, Editor | Real-time adherence status of live team |
| `/reports/adherence` | Adherence Report | Admin, Editor | Historical adherence by date range |
| `/admin/wfm/import` | Schedule Import | Admin, Superadmin | Upload WFM CSV file |
| `/admin/wfm/shrinkage` | Shrinkage Setup | Admin, Superadmin | Enter planned shrinkage by category |

### 6.2 Schedule View UI

```
Today: Monday 09 Jun 2026
──────────────────────────────────────────────────────────
Agent          Shift         Break      Lunch     Status
──────────────────────────────────────────────────────────
John Smith     08:00–17:00   10:15      12:30     🟢 On shift
Maria Garcia   09:00–18:00   11:00      13:30     🟢 On shift
Ali Hassan     (day off)                          ⬜ Off
──────────────────────────────────────────────────────────
```

- **Colour coding:** 🟢 on shift (adherent), 🟡 on shift (deviation detected), 🔴 absent when scheduled, ⬜ off.
- **Current time indicator:** vertical line on timeline (if showing hour view).
- **Filtering:** by team / queue / date range.

### 6.3 Real-time adherence monitor

Shows live adherence status for all agents currently scheduled:

```
Agent         Scheduled      Actual State   Adherent   Deviation
─────────────────────────────────────────────────────────────────
John Smith    On-phone       READY          ✓          —
Maria Garcia  On-phone       NOT_READY      ✗          +8 min
Ali Hassan    Break          NOT_READY      ✓          —
Sara Lee      On-phone       TALKING        ✓          —
```

Update via SignalR: subscribe to `RTSData_UserStatus` changes from RtmRelayService.
Deviation = minutes continuously out of adherence (reset when returns to correct state).

---

## 7. Staffing requirement calculator (lightweight)

For centres without external WFM, RTM View Shell can offer a simple staffing calculator:

**Input:** historical calls_offered per 30-min interval (from hist_queue_interval),
desired SL target (%), AHT (seconds), shrinkage (%).

**Output:** required rostered headcount per 30-min interval.

**Expose as:** an admin tool page `/admin/wfm/staffing-calculator` with:
- Date range selector (pulls historical average calls per interval)
- AHT input (can default from historical avg)
- SL target and threshold inputs
- Shrinkage input
- Output: table of 48 half-hour intervals with required agents + downloadable CSV

**Erlang C implementation:** use an existing NuGet package (`ErlangB`, `ErlangCalculator`)
or implement from scratch — the formula is compact (see §2.1).

---

## 8. Integration with RtmRelayService (real-time adherence)

Real-time adherence combines:
- **Schedule** (from `wfm_schedule` DB — static, updated on import/sync)
- **Actual state** (from `RtmRelayService` — live `RTSData_UserStatus` events)

### Pattern

```csharp
// WfmAdherenceService (Singleton, receives RTM state changes)
public class WfmAdherenceService : IWfmAdherenceService
{
    private readonly ConcurrentDictionary<Guid, AgentAdherenceState> _states = new();

    // Called by RtmRelayService on every agent state change
    public void OnAgentStateChange(Guid tenantId, Guid agentId, string newState, DateTime at)
    {
        // 1. Load agent's schedule for today (cache 5 min in Redis)
        // 2. Determine what state they SHOULD be in at 'at'
        // 3. Classify: adherent or not
        // 4. Update _states[agentId]
        // 5. Notify all subscribed Blazor components via delegate callbacks
    }
}
```

---

## 9. Permissions model for WFM features

| Feature | Viewer | Editor | Admin | Superadmin |
|---------|--------|--------|-------|------------|
| View own schedule | ✓ | ✓ | ✓ | ✓ |
| View team schedule | — | ✓ (PG queues) | ✓ | ✓ |
| Real-time adherence monitor | — | ✓ | ✓ | ✓ |
| Adherence report | — | ✓ | ✓ | ✓ |
| Import schedule CSV | — | — | ✓ | ✓ |
| Configure shrinkage | — | — | ✓ | ✓ |
| Run staffing calculator | — | ✓ | ✓ | ✓ |

---

## 10. Key WFM terms quick reference

| Term | Definition |
|------|-----------|
| **Adherence** | How closely agents follow their published schedule (%) |
| **Conformance** | Similar to adherence; sometimes = did the agent work the right total time |
| **Erlang C** | Queueing model for voice CC: calculates required agents for a SL target |
| **Erlang** (traffic) | Unit of traffic intensity = call rate × AHT (in hours) |
| **FTE** | Full-Time Equivalent: one FTE = one full-time scheduled agent |
| **Intraday** | Within the current day; "intraday management" = adjusting staffing live |
| **Reforecast** | Updated call volume prediction made during the day when reality diverges |
| **Shrinkage** | % of scheduled time agents are unavailable for calls |
| **Occupancy** | % of on-phone time agents are active (talking/ACW) vs idle (READY) |
| **Rostered headcount** | Erlang requirement ÷ (1 − shrinkage) = agents to schedule |
| **Half-time** | 30-minute scheduling interval (universal WFM standard) |
| **RTA** | Real-Time Adherence: live adherence monitoring (vs historical) |

---

## 11. Implementation checklist (CC task reference)

When writing a CC task prompt for WFM features, include:

- [ ] EF migration: `wfm_schedule`, `wfm_schedule_activity`, `hist_agent_adherence`, `wfm_shrinkage_plan`
- [ ] `WfmAdherenceService : IWfmAdherenceService` (Singleton) registered in DI
- [ ] Integration point with `IRtmRelayService` (subscribe to agent state changes)
- [ ] Repository: `IWfmRepository` with `GetScheduleAsync`, `GetAdherenceAsync`, `ImportScheduleAsync`
- [ ] CSV import parser: `WfmScheduleImportParser` — handles NICE IEX / Verint export formats
- [ ] MediatR: `GetTeamScheduleQuery`, `GetAdherenceReportQuery`, `ImportWfmScheduleCommand`
- [ ] Blazor pages: `/wfm/schedule`, `/wfm/adherence`, `/reports/adherence`, `/admin/wfm/import`
- [ ] Erlang C calculator utility: `ErlangC.CalculateRequiredAgents(lambda, aht, slTarget, threshold)`
- [ ] Staffing calculator page: `/admin/wfm/staffing-calculator`
- [ ] i18n: all WFM labels in SharedResources.resx (schedule, adherence, shrinkage, etc.)
- [ ] Unit tests: Erlang C calculation (known values), adherence classification matrix (§5.2)
- [ ] Security: agent can only see own schedule; PG gate for team schedule and adherence views
