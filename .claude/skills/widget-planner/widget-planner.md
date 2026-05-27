# Widget Planner Skill

> End-to-end planning guide: from widget idea to a ready-to-run CC implementation task.
> Based on the DayTrend widget planning session (2026-05-26/27).
> Use this skill at the **start of any new widget planning session**.

---

## How to Use This Skill

This skill guides a **Cowork planning session**. The output is:
1. A new section in `docs/widget-specification.md`
2. A new `CC-NNN` task in `docs/backend-tasks.md`

**Rule:** Cowork writes documentation only. All code is written by CC (Claude Code).
**Rule:** The CC task must be self-contained — CC should not need to ask questions.

---

## Phase 0 — Widget Idea

Before starting, answer with the user:

| Question | Why it matters |
|---|---|
| What is the widget called? | Determines `WidgetCatalogItem.Name` and component filename |
| What does it show? | Defines the data source (SignalR vs PostgreSQL function) |
| Who is the audience? | Determines which roles have access (§3.8 pattern) |
| What is the user action? | View only, or configure + interact? |
| Is this real-time push or historical pull? | **Critical fork:** Grid architecture vs Chart/Analytics architecture |

**Architecture decision:**

| If the widget shows… | Use |
|---|---|
| Live agent/queue state, updated by server push | **Grid architecture** (SignalR + RTS tables) — `widget-creator.md §1–19` |
| Historical aggregates, trend charts, intraday data | **Chart/Analytics architecture** — `widget-creator.md §20` |
| KPI summary tiles (last N minutes) | Chart/Analytics (polling) |

> **⚠ Grid widgets — mandatory gate before any further planning:**
> Before designing any Grid (SignalR) widget, the **exact metric must be identified first**.
> Open `docs/widget-specification.md §2` and confirm:
> - Which `RTSGrid_Metric` row(s) will the widget display? (MetricId, MetricType, MetricFunction, MetricParameter)
> - Is the metric already in the catalogue, or does it need to be added?
>
> **Do not proceed to Phase 1 until the driving metric is confirmed.**
> Designing a Grid widget without a confirmed metric leads to scope creep and rework.

---

## Phase 1 — Data Exploration

### 1.1 Identify the data source

For **Chart/Analytics widgets** (historical):
- Primary table: `RTSData_Interaction` (call records, one row per interaction)
- Agent status: `RTSData_UserStatusLog` (agent state intervals, with `StatusGroup`)
- Always filter by: `TenantId`, `OnDate` (format `DD/MM/YYYY`), and queue list

For **Grid widgets** (real-time):
- Data comes via SignalR from `RTSGrid_*` tables managed by the CC platform
- No direct DB queries from the widget

### 1.2 Walk the available metrics

Open `docs/widget-specification.md §2` with the user. Review the three catalogues:
- §2.1 Interaction metrics (`MetricType = 'Interaction'`)
- §2.2 Agent status metrics (`MetricType = 'AgentStatus'`)
- §2.3 Agent status log metrics (`MetricType = 'AgentStatusLog'`)

For each candidate metric, confirm:
- **Field name** in the source table (`MetricParameter` in `RTSGrid_Metric`)
- **Filter predicate** — `WHERE` condition (e.g. `IsAnswered = true`, `Direction = 'Incoming'`)
- **Aggregate function** — COUNT / AVG / MAX / SUM_OVERLAP_MS
- **Value type** — Number (integer count), Time (seconds → `mm:ss`), TimeMs (milliseconds → `mm:ss`)

### 1.3 Schema trust rule

> Every field listed in `RTSGrid_Metric.MetricParameter` **is guaranteed to exist**
> in the source table. No pre-check needed. If the user confirms a field name, trust it.

### 1.4 Confirm new fields with the user

For any field not yet in the catalogue, ask the user to confirm:
- Does the field exist? (e.g. "Is `IsTransferred` present in `RTSData_Interaction`?")
- Once confirmed → add a `RTSGrid_Metric` seed entry and use it freely.

### 1.5 RTSGrid_Metric — adding new entries (CRITICAL RULE)

New metrics **can** be added to `RTSGrid_Metric`. Two conditions must both be met:

1. **`MetricFunction` must be an existing value** — never invent a new one.
   Full list in `docs/rtsgrid-metric-reference.md §3.4`.
2. **`MetricParameter` must follow the correct format** for that `MetricFunction`:
   - StatusGroup-based functions → StatusGroup name: `AVAILABLE`, `ONPHONE`, `BREAK`, `PAPERWORK`, `TRAINING`
   - Status-based functions → exact status name: `Wrap Up`, `Hold`, `Incoming Ext Call`, etc.
   - Count/duration functions → C# filter expression matching existing patterns in the catalogue

Metrics with a dot in `MetricId` belong to `History_Metric`, not `RTSGrid_Metric`.

---

## Phase 2 — Metric Design

### 2.1 Narrow format principle

All PostgreSQL functions for Chart/Analytics widgets use **narrow format**:

```sql
RETURNS TABLE (interval_start timestamptz, metric_id text, value double precision)
```

One row per metric per interval. **Never wide format** (fixed columns = code change per metric).

**Benefit:** Adding a new metric = one UNION ALL row in SQL only. Zero C# changes.

### 2.2 Metric ID consistency rule

The `metric_id` string in every UNION ALL row **must exactly match** `RTSGrid_Metric.MetricId`.
This is the single source of truth — no divergence between UI labels and query output.

Convention: `{domain}.{metric_name}` — e.g. `interaction.incoming_calls`, `statuslog.available_agents`.

### 2.3 Predicate catalogue

Maintain a shared predicate key table (spec §2.1 header). Each unique `WHERE` condition
gets a short key. Reference it in SQL comments:

```sql
-- interaction.incoming_calls | CALL_IN
COUNT(*) FILTER (WHERE "InteractionType"='Call' AND "Direction"='Incoming') AS incoming_calls,
```

### 2.4 Time metrics (SUM_OVERLAP_MS pattern)

For agent status duration metrics, use interval clipping (not raw `Duration`):

```sql
SUM(GREATEST(0,
    EXTRACT(EPOCH FROM (
        LEAST(COALESCE(usl."EndTime", interval_end), interval_end)
        - GREATEST(usl."StartTime", interval_start)
    )) * 1000
)) FILTER (WHERE usl."StatusGroup" = 'AVAILABLE') AS available_time_ms
```

This clips each status period to the interval boundary — essential for accuracy.

### 2.5 Agent pool pattern (logged_in_agents)

To count agents active in an interval (not just those with status records):

```sql
-- Separate CTE before JOIN with UserStatusLog
agent_pool AS (
    SELECT DISTINCT "UserId"
    FROM "RTSData_Interaction"
    WHERE "TenantId"  = p_tenantid
      AND "OnDate"    = p_ondate
      AND "Workgroup" = ANY(p_queuelist)
      AND "IsAnswered" = true
      AND "Direction"  = 'Incoming'
),
pool_summary AS (
    SELECT i.interval_start, COUNT(DISTINCT ap."UserId") AS logged_in_agents
    FROM intervals i
    LEFT JOIN "RTSData_Interaction" ri ON ...
    JOIN agent_pool ap ON ap."UserId" = ri."UserId"
    GROUP BY i.interval_start
)
```

Then LEFT JOIN pool_summary into the main aggregation. Ensures agents without
status records are still counted.

### 2.6 Dual Y-axis decision

If the widget mixes count metrics with time metrics:
- Counts → **left Y-axis** (integers)
- Time values (seconds / ms) → **right Y-axis** (formatted as `mm:ss`)
- Agent metrics use **dashed lines** to distinguish visually from call volume metrics

---

## Phase 3 — Widget Specification

Write a new section in `docs/widget-specification.md`. Required subsections:

### 3.1 Subsection checklist

```
§N.1  Overview              — purpose, data source, widget type
§N.2  Visual layout         — description or ASCII mockup of the rendered widget
§N.3  Configuration options — tables for each config tab (General, Appearance, metrics)
§N.4  Data query            — SQL function bodies; methodology §N.4.3 checklist; C# records
§N.5  Rendering requirements — chart types, Y-axes, formatting, empty/error states
§N.6  ConfigJson schema     — full JSON with defaults
§N.7  Widget settings panel — tab-by-tab UI description (mirrors §N.3 but as prose for CC)
§N.8  Access control        — Role × permission table
§N.9  WidgetCatalogItem seed — C# seed code block
§N.10 Implementation notes  — timezone, performance, known limitations
```

### 3.2 Configuration tables (§N.3 pattern)

For each config tab, write a Markdown table:

| Field | Type | Required | Description |
|---|---|---|---|
| `fieldName` | type | Yes/No | What it controls. Default: `value`. |

Always include a **"Default metrics set"** table for metric arrays showing which metrics
are enabled by default, with colours and labels.

### 3.3 Methodology section (§N.4.3 — always include)

Every widget spec must have the 7-step checklist for adding a new metric:

1. Add `RTSGrid_Metric` seed entry (§2.4)
2. Add predicate key to §2.1 if new filter
3. Add column to `agg` / `status_summary` CTE (comment: `MetricId | predicate_key`)
4. Add UNION ALL row
5. Deploy with `CREATE OR REPLACE FUNCTION` (no migration change, no C# change)
6. Add entry to `ConfigJson` metrics array default set
7. Add row to default metrics table in spec

### 3.4 Version footer

End each spec section edit with a version note:

```
*Widget Specification vX.Y — [what changed]. Next: CC-NNN.*
```

---

## Phase 4 — CC Task Writing

Write a new `## CC-NNN` section in `docs/backend-tasks.md`.

### 4.1 Task header block (always include all fields)

```markdown
## CC-NNN

### Implement {Widget Name} — {one-line summary of deliverables}

**Status:** 🔲 Ready
**Priority:** 🔴 High / 🟡 Medium / 🟢 Low
**Depends on:** CC-XXX ✅ (or "none")
**Spec reference:** `docs/widget-specification.md` §N — read in full before starting
**Skill:** `.claude/skills/widget-creator/widget-creator.md` — read §20–23 before implementing
**Commit:** —
```

### 4.2 Deliverables table

| # | Deliverable | Location |
|---|---|---|
| N.1 | Migration `AddXxxFunctions` | `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/` |
| N.2 | Query + Handler | `src/CcDashboard.Application/Queries/Widgets/` |
| N.3 | `{Name}Widget.razor` | `src/CcDashboard.Web/Components/Dashboard/Widgets/` |
| N.4 | JS interop file | `src/CcDashboard.Web/wwwroot/js/{name}Chart.js` |
| N.5 | `RTSGridMetric` seed | `src/CcDashboard.Infrastructure/Persistence/Seed/` |
| N.6 | `WidgetCatalogItem` seed | same seed file |
| N.7 | Config modal tabs | `ScreenEditorPage.razor` |

### 4.3 Content rules for CC tasks

**The task must be self-contained.** CC should not need to open spec files unless
you explicitly say "copy from spec §X.Y". Provide:

- Full C# record definitions (copy from spec)
- Migration pattern (`Up()` / `Down()` stubs with "paste from spec §X.Y")
- Full handler code with correct parameter names
- JS interop contract (`window.{name}.render / destroy`)
- Config modal: list all 4 tabs with fields per tab (brief, not full spec prose)
- "Save as Template" button directive (per `widget-creator.md §22.4`)
- Queue resolution note: `NgcQueue.ExternalId = Workgroup in RTSData_Interaction`

### 4.4 Acceptance criteria (always 10–15 items)

Structure:
1. Migration / DB function existence checks
2. Handler behaviour (happy path + edge cases: empty BU, NoQueues)
3. Component renders without JS errors
4. Auto-refresh / dispose (no memory leak)
5. Seed data visible in UI
6. Build clean (`dotnet build` — zero errors)
7. Unit tests (handler pivoting + NoQueues branch)
8. **Config modal opens and saves correctly**
9. **"Save as Template" dispatches `CreateWidgetTemplateCommand`**

---

## Phase 5 — Final Checklist Before Handing to CC

Before saying "готово, запускай CC":

- [ ] `docs/widget-specification.md` — new section written and version footer updated
- [ ] `docs/backend-tasks.md` — CC-NNN task complete with all required fields
- [ ] Task header has **Skill** line with path and relevant section numbers
- [ ] All `RTSGrid_Metric` seed entries present in spec §2.4
- [ ] `WidgetCatalogItem` seed block present in spec §N.9
- [ ] SQL function bodies in spec use narrow format `(interval_start, metric_id, value)`
- [ ] All metric IDs follow `{domain}.{metric_name}` convention
- [ ] Config modal tabs described in spec §N.7 AND in CC task deliverables
- [ ] "Save as Template" directive in CC task
- [ ] Acceptance criteria include config modal + template items
- [ ] Git commit: `docs/widget-specification.md` + `docs/backend-tasks.md` together

---

## Lessons Learned (DayTrend Session)

These are non-obvious decisions made during the DayTrend planning session.
Review before starting a new widget.

### L-01: Wide vs Narrow format
First draft used wide format (fixed columns per function). Switched to narrow format
after realising every new metric would require a C# change. **Always start with narrow.**

### L-02: Time metrics need SUM_OVERLAP_MS, not SUM(Duration)
`Duration` in `RTSData_UserStatusLog` is the raw session duration — it crosses interval
boundaries. Using `SUM(Duration)` gives wrong results. Use the LEAST/GREATEST clip formula.

### L-03: logged_in_agents needs a separate agent_pool CTE
A naive `COUNT(DISTINCT usl.UserId)` after JOIN with UserStatusLog misses agents who
answered calls but have no status records in that interval. Always derive the agent pool
from `RTSData_Interaction` first, then LEFT JOIN with status data.

### L-04: Duration in UserStatusLog is milliseconds, not seconds
Common assumption: duration = seconds. Actual: milliseconds. Format with
`TimeSpan.FromMilliseconds(v).ToString(@"mm\:ss")`. Confirmed from schema.

### L-05: OnDate format is DD/MM/YYYY
`RTSData_Interaction.OnDate` is `varchar` in `DD/MM/YYYY` format — not ISO, not epoch.
Always construct: `DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy")`.

### L-06: Queue resolution via ExternalId
`NgcQueue.ExternalId` = `Workgroup` field in `RTSData_Interaction`. The JOIN is:
`NgcBusinessUnitQueueClassification.QueueId = NgcQueue.Id`, then `NgcQueue.ExternalId = Workgroup`.

### L-07: Conditional agent query = performance optimisation
If no agent metric is enabled, skip `fn_daytrendagentstatus` entirely.
`IncludeAgentMetrics = agentMetrics.Any(m => m.Enabled)` passed in the query record.

### L-08: Schema trust rule simplifies planning
Once a field appears in `RTSGrid_Metric.MetricParameter`, it exists in the table.
No need to write "verify field exists" tasks — remove friction, trust the catalogue.

### L-09: Resolving field uncertainty quickly
Initially uncertain whether `IsTransferred` exists. Resolution pattern: ask the user
directly → user confirms → add to catalogue + mark schema trust rule as established.
Do not block metric addition on uncertainty — ask once, get confirmation, move on.

### L-10: StatusGroup as canonical enum
`RTSData_UserStatusLog.StatusGroup` is a normalised field (added via CC-001 migration)
with canonical values: `AVAILABLE`, `ONPHONE`, `BREAK`, `PAPERWORK`, `TRAINING`.
Raw `StatusId` values from the CC platform vary by deployment — always use `StatusGroup`.

---

## Quick Reference — Key Paths

| Artifact | Path |
|---|---|
| Widget specification | `docs/widget-specification.md` |
| CC implementation tasks | `docs/backend-tasks.md` |
| Widget creator skill (Grid + Chart patterns) | `.claude/skills/widget-creator/widget-creator.md` |
| Widget catalogue | `docs/widget-catalogue.md` |
| RTS infrastructure docs | `docs/architecture/rts-infrastructure.md` |
| Project status snapshot | `PROJECT_STATUS.md` |

---

*Widget Planner Skill — created 2026-05-27. Based on DayTrend planning session.*
*Captures: metric design methodology, narrow format rationale, spec structure, CC task template, 10 lessons learned.*
