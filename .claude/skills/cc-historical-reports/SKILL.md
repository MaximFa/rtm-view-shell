---
name: cc-historical-reports
description: >
  Expert guide for designing and implementing historical reporting features in RTM View Shell.
  Trigger this skill whenever the user mentions: historical report, history, historical data,
  interval report, daily report, weekly report, monthly report, EOD report, end-of-day report,
  report period, date range, time range, report filter, export to Excel, export to CSV,
  historical metrics, historical SLA, SLA trend, abandon trend, AHT trend, occupancy trend,
  historical queue performance, historical agent performance, queue statistics, agent statistics,
  wrap code report, disposition report, call driver report, staffing report, headcount report,
  reporting screen, report builder, report scheduler, scheduled report, custom report,
  report widget, analytics view, trend chart historical, bar chart historical,
  date picker, interval selector, queue filter, agent filter, BU filter,
  report aggregation, hourly aggregation, daily aggregation, report export,
  reporting database, reporting tables, summary tables, historical schema,
  "show me the last 30 days", "report for last month", "week-over-week comparison",
  "how did we perform yesterday", "historical SLA", "trends over time",
  or any request to design, implement, or query historical contact centre data.
  Never skip this skill when building any screen, widget, or data model related to
  past performance data, trends, or time-series analysis in RTM View Shell.
---

# CC Historical Reports — RTM View Shell

This skill guides the design and implementation of **historical reporting features**
in RTM View Shell. The shell's real-time monitoring (RTM) captures live CC data;
historical reports aggregate that data for trend analysis, performance reviews, and export.

> **Boundary:** RTM View Shell stores and serves historical data. The CC platform
> (Avaya, Genesys, NICE, etc.) is the source of truth for raw CDR/event data.
> RTM Service writes real-time snapshots to `RTSData_*` tables; historical summaries
> are derived from those or from direct platform integration.

---

## 1. Report taxonomy

Contact centres need four time-horizon report families:

| Family | Granularity | Primary audience | Typical use |
|--------|-------------|-----------------|-------------|
| **Interval** | 15 min / 30 min / 60 min | Shift supervisor | Intraday SLA tracking, WFM comparison |
| **Daily (EOD)** | Day total | Supervisor + Manager | End-of-day ops review |
| **Weekly** | Week total + daily breakdown | Manager | Performance trend, coaching input |
| **Monthly / Custom** | Month / any date range | Manager + Director | KPI reporting, QBR, budgeting |

For RTM View Shell v1: implement **Interval** and **Daily** first. Weekly/Monthly follow
the same query patterns with a wider date range.

---

## 2. Core metrics by report type

### 2.1 Queue-level historical metrics

| Metric | DB source | Interval | Daily |
|--------|-----------|:--------:|:-----:|
| Calls Offered (Incoming) | RTSData_Interaction count | ✓ | ✓ |
| Calls Answered | RTSData_Interaction (completed) | ✓ | ✓ |
| Calls Abandoned | Offered − Answered (before threshold) | ✓ | ✓ |
| Abandon Rate % | Abandoned / Offered × 100 | ✓ | ✓ |
| Service Level % | Answered within threshold / Offered × 100 | ✓ | ✓ |
| Average Speed of Answer (ASA) | Avg wait time of answered calls | ✓ | ✓ |
| Average Handle Time (AHT) | Avg (talk + hold + ACW) | ✓ | ✓ |
| Average Talk Time | Avg talk duration | ✓ | ✓ |
| Average ACW | Avg after-call work duration | ✓ | ✓ |
| Max Wait Time | Longest wait in interval | ✓ | ✓ |
| Calls in Queue (peak) | Max simultaneous waiting | ✓ | – |
| Occupancy % | (Talk + ACW) / (Talk + ACW + Ready) × 100 | ✓ | ✓ |
| Agents Staffed | Count of logged-in agents | ✓ | ✓ |

### 2.2 Agent-level historical metrics

| Metric | Notes |
|--------|-------|
| Login Time | Total duration agent was logged in |
| Ready Time | Total duration in READY state |
| Calls Handled | Count answered by this agent |
| Talk Time | Total talk duration |
| Hold Time | Total hold duration |
| ACW Time | Total after-call work duration |
| Occupancy % | (Talk + ACW) / (Talk + ACW + Ready) × 100 |
| AHT | (Talk + Hold + ACW) / Calls Handled |
| Not-Ready Time | Total duration in NOT_READY (by reason code if available) |
| Adherence % | Scheduled on-phone time / Actual on-phone time (requires WFM data) |

### 2.3 SLA threshold definition

SLA % = calls answered within N seconds / total offered × 100.
Standard threshold: **20 seconds** (industry default; configurable per queue in TenantSettings).
Green ≥ target (e.g. 80%), Yellow 70–79%, Red < 70%.

---

## 3. Data model — historical summary tables

### Strategy: dual-layer storage

```
Raw layer  (existing):   RTSData_Interaction, RTSData_UserStatus  — row per event
Summary layer (new):     hist_queue_interval, hist_agent_interval  — pre-aggregated
```

Pre-aggregating saves query time for reporting screens. Summaries are populated by a
background job (IHostedService) that runs every 30 minutes.

### 3.1 hist_queue_interval

```sql
CREATE TABLE hist_queue_interval (
    id              uuid PRIMARY KEY,           -- UUIDv7
    tenant_id       uuid NOT NULL,              -- FK → tenants
    queue_id        uuid NOT NULL,              -- FK → queues
    interval_start  timestamptz NOT NULL,       -- e.g. 09:00:00 UTC
    interval_minutes smallint NOT NULL,         -- 15, 30, or 60
    -- volume
    calls_offered   integer NOT NULL DEFAULT 0,
    calls_answered  integer NOT NULL DEFAULT 0,
    calls_abandoned integer NOT NULL DEFAULT 0,
    -- timing (seconds)
    sum_wait_answered  bigint NOT NULL DEFAULT 0,  -- for ASA calculation
    sum_handle_time    bigint NOT NULL DEFAULT 0,  -- talk+hold+ACW, for AHT
    sum_talk_time      bigint NOT NULL DEFAULT 0,
    sum_acw_time       bigint NOT NULL DEFAULT 0,
    max_wait_time      integer NOT NULL DEFAULT 0,
    -- service level
    calls_in_sl        integer NOT NULL DEFAULT 0, -- answered within threshold
    sl_threshold_sec   smallint NOT NULL DEFAULT 20,
    -- staffing
    agents_staffed     smallint NOT NULL DEFAULT 0,
    sum_ready_seconds  bigint NOT NULL DEFAULT 0,  -- for occupancy
    sum_busy_seconds   bigint NOT NULL DEFAULT 0,  -- talk+acw seconds
    -- metadata
    computed_at     timestamptz NOT NULL,
    UNIQUE (tenant_id, queue_id, interval_start, interval_minutes)
);
CREATE INDEX ON hist_queue_interval (tenant_id, queue_id, interval_start DESC);
CREATE INDEX ON hist_queue_interval (tenant_id, interval_start DESC);
```

### 3.2 hist_agent_interval

```sql
CREATE TABLE hist_agent_interval (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    agent_id        uuid NOT NULL,              -- FK → identity.users
    queue_id        uuid,                       -- NULL = all queues combined
    interval_start  timestamptz NOT NULL,
    interval_minutes smallint NOT NULL,
    -- activity
    calls_handled   integer NOT NULL DEFAULT 0,
    sum_talk_seconds  bigint NOT NULL DEFAULT 0,
    sum_hold_seconds  bigint NOT NULL DEFAULT 0,
    sum_acw_seconds   bigint NOT NULL DEFAULT 0,
    sum_ready_seconds bigint NOT NULL DEFAULT 0,
    sum_not_ready_seconds bigint NOT NULL DEFAULT 0,
    login_at        timestamptz,
    logout_at       timestamptz,
    -- metadata
    computed_at     timestamptz NOT NULL,
    UNIQUE (tenant_id, agent_id, queue_id, interval_start, interval_minutes)
);
CREATE INDEX ON hist_agent_interval (tenant_id, agent_id, interval_start DESC);
```

---

## 4. SQL query patterns

### 4.1 Queue interval report (30-min bands, one day)

```sql
SELECT
    i.interval_start AT TIME ZONE :tz           AS interval_local,
    q.name                                       AS queue_name,
    i.calls_offered,
    i.calls_answered,
    i.calls_abandoned,
    ROUND(i.calls_abandoned::numeric
          / NULLIF(i.calls_offered,0) * 100, 1)  AS abandon_pct,
    ROUND(i.calls_in_sl::numeric
          / NULLIF(i.calls_offered,0) * 100, 1)  AS sl_pct,
    ROUND(i.sum_wait_answered::numeric
          / NULLIF(i.calls_answered,0), 1)        AS asa_sec,
    ROUND(i.sum_handle_time::numeric
          / NULLIF(i.calls_answered,0), 1)        AS aht_sec,
    i.agents_staffed,
    ROUND(i.sum_busy_seconds::numeric
          / NULLIF(i.sum_busy_seconds + i.sum_ready_seconds,0) * 100, 1) AS occupancy_pct
FROM hist_queue_interval i
JOIN queues q ON q.id = i.queue_id
WHERE i.tenant_id       = :tenant_id
  AND i.queue_id        = ANY(:queue_ids)        -- pass null for all queues
  AND i.interval_start >= :date_from
  AND i.interval_start <  :date_to
  AND i.interval_minutes = 30
ORDER BY i.interval_start, q.name;
```

### 4.2 Daily rollup from intervals

```sql
SELECT
    date_trunc('day', i.interval_start AT TIME ZONE :tz) AS report_date,
    SUM(i.calls_offered)     AS calls_offered,
    SUM(i.calls_answered)    AS calls_answered,
    SUM(i.calls_abandoned)   AS calls_abandoned,
    ROUND(SUM(i.calls_in_sl)::numeric
          / NULLIF(SUM(i.calls_offered),0) * 100, 1) AS sl_pct,
    ROUND(SUM(i.sum_wait_answered)::numeric
          / NULLIF(SUM(i.calls_answered),0), 1)       AS asa_sec,
    ROUND(SUM(i.sum_handle_time)::numeric
          / NULLIF(SUM(i.calls_answered),0), 1)       AS aht_sec
FROM hist_queue_interval i
WHERE i.tenant_id       = :tenant_id
  AND i.queue_id        = ANY(:queue_ids)
  AND i.interval_start >= :date_from
  AND i.interval_start <  :date_to
  AND i.interval_minutes = 30
GROUP BY 1
ORDER BY 1;
```

### 4.3 Agent performance — daily summary

```sql
SELECT
    u.first_name || ' ' || u.last_name          AS agent_name,
    SUM(a.calls_handled)                          AS calls_handled,
    ROUND(SUM(a.sum_talk_seconds)::numeric
          / NULLIF(SUM(a.calls_handled),0), 1)   AS avg_talk_sec,
    ROUND(SUM(a.sum_acw_seconds)::numeric
          / NULLIF(SUM(a.calls_handled),0), 1)   AS avg_acw_sec,
    ROUND((SUM(a.sum_talk_seconds) + SUM(a.sum_acw_seconds))::numeric
          / NULLIF(SUM(a.calls_handled),0), 1)   AS aht_sec,
    ROUND((SUM(a.sum_talk_seconds) + SUM(a.sum_acw_seconds))::numeric
          / NULLIF(SUM(a.sum_talk_seconds)
                  + SUM(a.sum_acw_seconds)
                  + SUM(a.sum_ready_seconds),0) * 100, 1) AS occupancy_pct
FROM hist_agent_interval a
JOIN identity.users u ON u.id = a.agent_id
WHERE a.tenant_id       = :tenant_id
  AND a.interval_start >= :date_from
  AND a.interval_start <  :date_to
  AND a.interval_minutes = 30
GROUP BY u.id, u.first_name, u.last_name
ORDER BY SUM(a.calls_handled) DESC;
```

---

## 5. Background aggregation service

### Architecture

```
IHostedService: HistoricalAggregationService
  - Runs every 30 minutes (aligned to :00 and :30)
  - For each active tenant:
      1. Find last computed interval_start per (tenant, queue, interval_minutes)
      2. Query RTSData_Interaction for new complete intervals
      3. Aggregate → INSERT ON CONFLICT DO UPDATE into hist_queue_interval
      4. Same for hist_agent_interval from RTSData_UserStatus
  - Write audit event: System.HistoricalAggregation (count of rows, duration)
```

### Key aggregation logic (pseudocode)

```csharp
// Completed interval = interval_start + interval_minutes < NOW()
// Only aggregate COMPLETE intervals — never partial current interval
var cutoff = DateTime.UtcNow;
var lastInterval = FloorToInterval(cutoff, intervalMinutes);  // e.g. 09:30:00

// SLA: count calls where (answered_at - arrived_at) <= sl_threshold_sec
// Abandoned: arrived_at set, answered_at null, left_at set, wait > abandon_threshold (often 5s)
```

---

## 6. Blazor UI patterns

### 6.1 Report filter bar (shared across all report screens)

```
[Date range: from □ to □]  [Queue: ▼ All]  [Agent: ▼ All]  [Interval: ▼ 30 min]  [Export ▼]
```

- Date range: DatePicker pair, default = today. Max range = 90 days (configurable).
- Queue multi-select: populated from `queues` table filtered by user's PG `pg_queues`.
- Agent multi-select: optional; appears on Agent Report screens only.
- Interval: 15 / 30 / 60 min / Day — controls `interval_minutes` param.
- Export: CSV / Excel (download via `IBlobStorage` or inline byte array for < 10k rows).

### 6.2 Report screen structure (Blazor Server)

```
/reports/queues          — Queue Interval / Daily report
/reports/agents          — Agent Performance report
/reports/sla-trend       — SLA trend chart (last 30 days, by queue)
/reports/overview        — Management summary (totals across all queues, by day)
```

Each screen: thin `@page` + `InteractiveServer` report component.
Use `[Authorize(Roles = "Administrator,Editor,Viewer")]` — all roles can view.
Superadmin sees all queues; others filtered by PG.

### 6.3 Table display conventions

- Server-side pagination: 25 rows per page default.
- Sortable columns (click header).
- SL% cell coloured: ≥ target = green background, 70–target = yellow, < 70 = red.
- Abandon% cell coloured: ≤ 5% = green, 5–10% = yellow, > 10% = red.
- Show totals/averages row at bottom (pinned).
- Numbers: calls = integer, percentages = 1 decimal, seconds = 1 decimal or MM:SS format.

---

## 7. Data population from RTM Service

RTM Service writes to `RTSData_Interaction` and `RTSData_UserStatus` in real-time.
The aggregation service reads from these tables.

### Minimum required columns in RTSData_Interaction (verify against live schema):

| Column | Notes |
|--------|-------|
| TenantId | Multi-tenant GQF |
| QueueId / BusinessUnitId | Which queue |
| ArrivedAt | When call entered queue |
| AnsweredAt | NULL if abandoned |
| LeftAt | When call ended (abandoned or completed) |
| TalkDuration | Seconds in TALKING state |
| HoldDuration | Seconds in HOLD state |
| AcwDuration | Seconds in ACW state |

If columns are missing, the aggregation query must adapt (derive from state transitions
in RTSData_UserStatus or skip that metric).

---

## 8. Permissions

Historical reports follow the existing PG permission model:
- Users see only queues in their `pg_queues` list (GQF enforced at query time).
- Agent report: Viewer sees only their own data; Editor/Admin/Superadmin see all agents in their PG queues.
- No separate "reports" permission — if you can view the queue real-time, you can view its history.
- Export (CSV/Excel): same permission as view; no additional gate needed.

---

## 9. Implementation checklist (CC task reference)

When writing a CC task prompt for historical reports, include:

- [ ] EF migration for `hist_queue_interval` and `hist_agent_interval`
- [ ] `HistoricalAggregationService : IHostedService` in Infrastructure
- [ ] Repository: `IHistoricalReportRepository` with async query methods
- [ ] MediatR query: `GetQueueIntervalReportQuery`, `GetAgentDailyReportQuery`
- [ ] Blazor pages: `/reports/queues`, `/reports/agents`
- [ ] Report filter bar component (reusable `ReportFilterBar.razor`)
- [ ] CSV/Excel export via `ClosedXML` (already available in NuGet or add it)
- [ ] i18n: all column headers and labels in SharedResources.resx
- [ ] Unit tests: aggregation logic (null handling, division-by-zero guards)
- [ ] Integration test: seed RTSData_Interaction rows → run aggregation → verify hist_ rows

---

## 10. Known pitfalls

1. **Timezone**: `RTSData_Interaction.ArrivedAt` is UTC. Reports must convert to tenant
   local time for display. Use `AT TIME ZONE tenant_settings.default_locale` — or pass
   the IANA timezone from the Blazor client.

2. **Abandoned threshold**: Not every call that didn't answer is a "reported abandon".
   Short rings (< 5 seconds) are often excluded (IVR bounce, wrong number). Filter:
   `WHERE left_at - arrived_at > INTERVAL '5 seconds'` for abandon counting.

3. **SLA denominator**: Some centres count SLA as "answered in N sec / (offered − short-abandon)".
   Others include all offered. Agree with the customer and make it configurable in
   `TenantSettings.SlaDenominatorIncludesShortAbandons` (boolean).

4. **Re-aggregation**: If RTM Service misses an interval (service restart), the aggregation
   service must back-fill. Add a "back-fill from date" admin action in the report admin screen.

5. **Large exports**: > 10k rows → async background job → notify via email (see [AUD-08] pattern).
