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
| **Grid widgets only:** Queue Grid or Agent Grid pattern? | Determines which RTS commands, repositories, and tables are used |

**Architecture decision:**

| If the widget shows… | Use |
|---|---|
| Live agent/queue state, updated by server push | **Grid architecture** (SignalR + RTS tables) — `widget-creator.md §1–19` |
| Historical aggregates, trend charts, intraday data | **Chart/Analytics architecture** — `widget-creator.md §20` |
| KPI summary tiles (last N minutes) | Chart/Analytics (polling) |

**Queue Grid vs Agent Grid — mandatory question for all Grid widgets:**

| Pattern | RTS Command | Key structure | Use when |
|---|---|---|---|
| **Queue Grid** | `SaveQueueGridRtsCommand` | Grid → Columns (MetricIds) → Rows (one per BU, UnionId=BusinessUnitId) → Cells (Data, Value=MetricId) | Widget data is bound to BU rows; metrics are per-BU aggregates |
| **Agent Grid** | `SaveAgentGridRtsCommand` | Grid → ColumnsSet → Columns → per-agent rows | Widget shows per-agent rows with individual agent metrics |

> Ask the user directly: "Как Queue Grid или как Agent Grid?" — determines all downstream commands and RTS table writes.
> Wrong choice here means rewriting the entire save/delete/clone flow.

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

### 1.5 RTSGrid_Metric — rules for new metrics (CRITICAL)

`RTSGrid_Metric` is a **static table** managed by the CC platform. Default rule: **do not touch it**.

**Exception — if a widget truly requires a metric not in the catalogue:**
- Discuss during planning: is there an existing metric that covers the need?
- If not: a new entry MAY be added **once** via a one-time DB migration during widget creation.
- Requirements: `MetricFunction` must be an existing value (see `docs/rtsgrid-metric-reference.md §3.4`);
  `MetricParameter` must follow the correct format for that function.
- **Never add via seeding** (`DatabaseInitializer` or similar). One-time migration only.
- Metrics with a dot in `MetricId` belong to `History_Metric`, not `RTSGrid_Metric`.

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

## Phase 2.5 — Config Tab Design (MANDATORY before writing spec)

> **⚠ Do NOT skip.** Config tab structure must be agreed with the user before writing §N.3, §N.6, or §N.7.
> Proposing and confirming the tab layout here prevents mismatches between spec and CC implementation.

### Step 1 — Propose tab structure

Based on the widget type and collected parameters, draft a table:

| Tab name | Fields on this tab |
|---|---|
| General | display name, primary filter (BU / Queue / etc.), main behavioural options |
| Data / Metrics | metric selection, thresholds, sort order — only if widget has configurable metrics |
| Appearance | colours, font size, background, chart type, legend toggle |
| Advanced | refresh interval, empty-state message, anything that doesn't fit above |

**Rules for the proposal:**
- **General** tab always exists and always contains the primary filter (BU, Queue, etc.)
- **Appearance** tab always exists (background colour, font colour, font size at minimum)
- Merge **Data** and **Metrics** tabs into one if there are fewer than 4 metric fields
- Only add **Advanced** tab if there are ≥2 fields that don't fit elsewhere
- Fields that affect what data is shown go in General or Data; fields that affect how it looks go in Appearance
- Widget display name always lives in General tab

### Step 2 — Ask the user

Present the proposed tabs as a table, then ask:

> "Вот предлагаемая структура табов конфигуратора. Что изменить?"

Wait for the response. Apply all changes before proceeding.

### Step 3 — Lock the tab structure

Record the agreed structure in the spec session notes and use it verbatim in §N.3, §N.6, and §N.7.

---

## Phase 2.6 — Localization Audit (MANDATORY before writing spec)

> **⚠ Do NOT skip.** Localization decisions must be recorded in §N.10 (Implementation Notes) and applied consistently in §N.7 (Widget Settings Panel) and any C# code snippets in the spec and CC task.

### Step 1 — Classify every user-visible string in the widget

Go through the widget's surfaces and assign each category to one of three buckets:

| Bucket | Rule | Examples |
|---|---|---|
| `@L["Key"]` | Any label the **end user reads** in the UI | Config modal field names, tab names, button text, empty-state messages, error messages, tooltips |
| Hardcoded English | Platform-standard technical terms that are **never translated** in this project | Metric names, status group labels (Available, On Phone, Break…), chart axis labels, MetricId strings |
| User-defined | Text the **user entered themselves** (stored in config) | Widget display name, custom threshold labels |

### Step 2 — Check existing `.resx` keys first

Before assigning a new `@L["Key"]`, check `SharedResources.resx` (and locale variants) for an existing equivalent. CC must search the file, not assume. New keys only if no match exists.

### Step 3 — Record in spec §N.10

Add a **Localization** sub-point to §N.10 with a table:

| Surface | Approach | New keys needed? |
|---|---|---|
| Config modal labels | `@L["Key"]` — reuse existing | List any new keys |
| Empty / error states | `@L["Key"]` — reuse existing | List any new keys |
| [Platform terms] | Hardcoded English | — |

### Step 4 — Add to CC task §3.x

In the CC task, add an explicit instruction:

> "Use `@L["Key"]` for all visible Blazor markup labels (tab names, field labels, button text, empty-state messages). Check `SharedResources.resx` for existing keys before adding new ones. [Platform terms] are hardcoded English — do not wrap in `@L`."

---

## Phase 3 — Widget Specification

> **⚠ MANDATORY for Grid widgets (Queue Grid or Agent Grid):**
> Before writing any spec section, read `.claude/skills/widget-creator/widget-creator.md`.
> - **Queue Grid widget** → focus on §15 (Queue Grid patterns), §16 (Dark Mode), §17 (Header Colors), §18 (UI Guidelines), §19 (RTS Infrastructure), §21 (Config Modal Tabs), §22 (CC task template).
> - **Agent Grid widget** → focus on §1–14 (Agent Grid patterns), §16, §17, §18, §19, §21, §22.
> - **Chart/Analytics widget** → focus on §20 (architecture), §21, §22, §23 (methodology).
>
> Writing a spec without reading widget-creator risks missing cascading-delete rules, SignalR binding patterns, dark-mode CSS conventions, and config-modal tab structure — all of which cause rework in CC.

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

## Lessons Learned (2026-05-27 — Metric Architecture Session)

### L-11: RTSGrid_Metric is static — never seed it
The CC platform owns and manages `RTSGrid_Metric`. The shell does not seed it via
`DatabaseInitializer` or any startup mechanism. A new metric can only be added once, via
a one-time DB migration during widget creation — and only if no existing metric covers the need.
**Seeding this table was the root cause of the CC-003 architectural error.**

### L-12: Three metric categories — identified by Description prefix
| Prefix | Category | MetricType |
|---|---|---|
| `"QM - *"` | Queue | `Data` |
| `"Agent Group - *"` | AgentGroup (Skills) | `Data` |
| `"Agent - *"` | Agent | `Agent` |

`MetricType = "Data"` → Queue Grid, Data Slot widgets.
`MetricType = "Agent"` → Agent Grid widgets.
Current DB has `"Agent"` for all rows (migration error — CC task pending).

### L-13: Metric split is by data type, not widget architecture
The correct division is:
- **Real-time** → `RTSGrid_Metric` → SignalR push
- **Historical** → `History_Metric` → polling from `RTSData_*` tables
- **Hybrid** → widget uses both sources simultaneously

A Chart/Analytics widget CAN include a real-time SignalR component.
A Grid widget CAN include historical data alongside live data.
Do NOT assume architecture type = metric source type.

### L-14: MetricFunction + MetricParameter is the key to metric selection
`MetricFunction` defines **what** is calculated. `MetricParameter` defines **how** (filter, group, status).
Together they are the primary reference for choosing the right metric for a widget.
Full catalogue in `docs/rtsgrid-metric-reference.md §3.4`.
**Never invent a new MetricFunction value** — use only those present in the catalogue.

### L-15: Missing metrics can be derived from existing MetricFunction patterns
If a metric is absent from `RTSGrid_Metric` but follows an existing `MetricFunction` pattern,
it can be added via a one-time migration — no need to ask the user or block planning.

**Example — TRAINING agent count:**
`QueueLoginDataNumBreakUsers` uses `UsersInStatusGroupCount` / `BREAK`.
By the same pattern: add `QueueLoginDataNumTrainingUsers` with `UsersInStatusGroupCount` / `TRAINING`.

**Rule:** scan the catalogue for similar MetricIds, copy the pattern, change only `MetricParameter`.

### L-16: ValueType drives filter UI — currently wrong in DB
`ValueType` is a shell-added field: `"number"`, `"time"`, `"text"`.
It controls the filter operator set shown in Queue Grid / Agent Grid column filters.
Currently all rows have `"String"` (wrong) — CC task pending to correct.

### L-17: MetricFormat = format of value as it arrives in SignalR push
If `MetricFormat = "##0.0%"` — the value arrives as a formatted string e.g. `"85.3%"`.
If empty — arrives as a plain numeric string. Widgets must handle this when parsing.
`DefaultValue` and `DataType` (the column, not the ValueType field) are transparent to the shell.

---

### L-18: Queue Grid vs Agent Grid — ask before designing RTS flow
Two separate RTS infrastructure patterns exist. Mixing them causes wrong table writes and broken SignalR subscriptions.

- **Queue Grid** (`SaveQueueGridRtsCommand`): rows bound to BU via `UnionId=BusinessUnitId`; columns = MetricIds; cells carry MetricId as Value for SignalR binding. Use for any widget showing BU-scoped aggregate metrics.
- **Agent Grid** (`SaveAgentGridRtsCommand`): rows are per-agent; uses a different table set (`RtsUserGrid*`). Use for per-agent row display.

**Rule:** Ask "Как Queue Grid или как Agent Grid?" in Phase 0 before writing any spec or task. Record the answer in §N.1 of the spec.

---

## Quick Reference — Key Paths

| Artifact | Path |
|---|---|
| Widget specification | `docs/widget-specification.md` |
| CC implementation tasks | `docs/backend-tasks.md` |
| Widget creator skill (Grid + Chart patterns) | `.claude/skills/widget-creator/widget-creator.md` |
| RTSGrid_Metric reference | `docs/rtsgrid-metric-reference.md` |
| Widget catalogue | `docs/widget-catalogue.md` |
| RTS infrastructure docs | `docs/architecture/rts-infrastructure.md` |
| Project status snapshot | `PROJECT_STATUS.md` |

---

*Widget Planner Skill — created 2026-05-27. Based on DayTrend + metric architecture sessions.*
*Captures: metric design methodology, narrow format rationale, spec structure, CC task template, 17 lessons learned.*
