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
| Live agent/queue state, updated by server push, **displayed as a table** | **Grid architecture** (SignalR + RTS tables) — `widget-creator.md §1–19` |
| Historical aggregates, trend charts, intraday data | **Chart/Analytics architecture** — `widget-creator.md §20` |
| KPI summary tiles (last N minutes) | Chart/Analytics (polling) |
| Live data from RTSGrid, **displayed as chart / gauge / tile / distribution** (not a table) | **Specialized Grid Widget** — Queue Grid infrastructure + custom renderer (see L-22) |

**Queue Grid vs Agent Grid — mandatory question for all Grid widgets:**

| Pattern | RTS Command | Key structure | Use when |
|---|---|---|---|
| **Queue Grid** | `SaveQueueGridRtsCommand` | Grid → Columns (MetricIds) → Rows (one per BU, UnionId=BusinessUnitId) → Cells (Data, Value=MetricId) | Widget data is bound to BU rows; metrics are per-BU aggregates |
| **Agent Grid** | `SaveAgentGridRtsCommand` | Grid → ColumnsSet → Columns → per-agent rows | Widget shows per-agent rows with individual agent metrics |

> Ask the user directly: "Как Queue Grid или как Agent Grid?" — determines all downstream commands and RTS table writes.
> Wrong choice here means rewriting the entire save/delete/clone flow.

> **⚠ DELETION RULE — applies to ALL Specialized Grid Widgets (L-26):**
> A Specialized Grid Widget uses Queue Grid infrastructure. Therefore its **deletion process
> must be EXACTLY identical to Queue Grid** — same deferred mechanism, same command.
>
> Deletion is NOT done in `DisposeAsync`. It is deferred through `ScreenEditorPage.razor`:
> `RemoveWidget` → `ConfirmDeleteWidget` → `WidgetsPendingRtsDeletion` → `DeleteQueueGridRtsCommand` on Save.
>
> **Invariant: the number of `DeleteQueueGridRtsCommand` calls on delete MUST equal
> the number of `SaveQueueGridRtsCommand` calls on config save.**
> ASD (CC-009) calls `SaveQueueGridRtsCommand` twice (GroupGridId + StateGridId) →
> must call `DeleteQueueGridRtsCommand` twice on delete.
> A widget with 1 grid → 1 delete call. 3 grids → 3 delete calls. No exceptions.
>
> **Every new Specialized Grid Widget MUST be added to all 3 places in `ScreenEditorPage.razor`
> before the PR is merged.** Missing even one place leaves orphaned `RTSGrid_*` records.
> See Phase 5 checklist and L-26 for the exact three locations.

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

### 3.0 Mandatory widget-creator notice (first thing in every spec section)

**Always** open the new spec section `## N. Widget Name` with this blockquote — fill in the correct sections for the widget type:

```markdown
> **⚠ MANDATORY for CC implementation:** before writing any code for this widget, read
> `.claude/skills/widget-creator/widget-creator.md` — specifically:
> **§15** (Queue Grid patterns), **§16** (Dark Mode), **§17** (Header Colors),
> **§18** (UI Guidelines), **§19** (RTS Infrastructure), **§21** (Config Modal Tabs),
> **§22** (CC task template).
> Then inspect `QueueGridWidget.razor` to confirm exact field names and SignalR patterns used in this project.
```

Adjust the section list to match the widget type:
- **Queue Grid** → §15, §16, §17, §18, §19, §21, §22 + inspect `QueueGridWidget.razor`
- **Agent Grid** → §1–14, §16, §17, §18, §19, §21, §22 + inspect `AgentGridWidget.razor`
- **Chart/Analytics** → §20, §21, §22, §23 + inspect `DayTrendWidget.razor`

This notice is not optional — it is the first thing CC reads in the spec and triggers the mandatory skill read.

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
- [ ] **Real-time Grid widgets only:** CC task includes simulator step (L-19):
      `GridRowData` has `UnionId`, `GetMetricsForGridAsync` covers new MetricIds,
      `QueueDataGenerator` populates `UnionId` from DB rows
- [ ] **⚠ Specialized Grid Widget deletion — all 3 places in `ScreenEditorPage.razor` (L-26):**
  - [ ] Delete dialog `@if` condition — new widget predicate added
  - [ ] `ConfirmDeleteWidget()` `if` condition — new widget predicate added
  - [ ] Save loop `foreach (WidgetsPendingRtsDeletion)` — new `else if` block with `DeleteQueueGridRtsCommand`
  - [ ] **`DeleteQueueGridRtsCommand` called once per GridId** — count must match `SaveQueueGridRtsCommand` count on save
    - 1 grid (standard) → 1 delete call
    - 2 grids (e.g. ASD dual-mode: GroupGridId + StateGridId) → 2 delete calls
    - N grids → N delete calls
- [ ] Acceptance criteria in CC task include: "Deleting widget + Save removes **all** RTSGrid_* records from DB (verify count = 0 for each GridId)"
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


### L-19: Real-time Grid widgets — simulator must be updated for new metrics

**Root cause (CC-007 ASD widget, 2026-05-28):** After implementing a new real-time Grid widget,
the widget connected to SignalR successfully but showed empty data ("Live · 0 agents").
Two simulator defects caused this:

1. **`UnionId` absent from `GridRowData`** — simulator sent `(string RowId, Dictionary Metrics)`
   but widget expected `(string RowId, int? UnionId, Dictionary Metrics)`. After JSON
   deserialization `UnionId` was always `null` → `r.UnionId == _businessUnitId` always false
   → no row ever matched.

2. **New widget metrics not returned by `GetQueueMetricsAsync`** — the method filtered only
   metrics with Description starting "QM" or "Agent Group". ASD metrics (`QueueLoginData*`,
   `QueueNum*`) didn't match → generator produced no values for them.

**Rule — for every new real-time Grid widget, the CC task MUST include a simulator step:**

> **⚠ Simulator step (mandatory for all real-time Grid widgets):**
> After implementing the widget, verify `tools/SignalRSimulator/` supports it:
> 1. **`Models/GridModels.cs`** — `GridRowData` must include `int? UnionId` field.
>    If absent, add it. Widget's `GridRowUpdate` local record must match.
> 2. **`Services/DbMetricService.cs`** — `GetQueueMetricsAsync` (or `GetAgentMetricsAsync`)
>    must return the new widget's MetricIds. If the new metrics have a different
>    Description prefix, extend the filter or add `GetMetricsForGridAsync(int gridId)` that
>    reads actual MetricIds from `RTSGrid_Cell` for the given grid.
> 3. **`Generators/QueueDataGenerator.cs`** (or `AgentDataGenerator.cs`) — generator must
>    populate `UnionId` from `RTSGrid_Row.UnionId` (DB lookup). Use `GetRowsForGridAsync`.
> 4. Build and restart simulator. Confirm widget shows live data within 5 s.

**Add to CC task Acceptance criteria:**
- [ ] Simulator sends `QueueGridUpdate` / `AgentGridUpdate` with correct `UnionId` and
      non-zero values for all widget MetricIds
- [ ] Widget canvas shows real data (not "0 agents" / "0 calls") within 5 s of page load

**Add to Phase 5 Final Checklist** (see § below).

---


### L-20: DashboardWidget.GridId ≠ RTSGrid_Grid.GridId — два разных auto-increment

**Критический нюанс (CC-007 ASD, 2026-05-28).**

В системе сосуществуют два независимых auto-increment GridId:

| Источник | Таблица | Доступ в коде |
|---|---|---|
| `DashboardWidget.GridId` | `dashboard_widgets.GridId` | `Widget.GridId` / `GridId` параметр виджета |
| `RTSGrid_Grid.GridId` | `RTSGrid_Grid` | `Config.GridId` (из `WidgetConfig.GridId`) |

`preassignedGridId` в `SaveWidgetConfig` **всегда `null`** → `DashboardWidget.GridId` всегда генерируется DB автоматически, независимо от `RTSGrid_Grid.GridId`.

**Правило для SignalR виджетов:**

> Для URL подключения к хабу (`hubs/queue-grid?gridId=X`) **всегда** использовать
> `Config.GridId` (`RTSGrid_Grid.GridId`), а НЕ параметр `GridId` (`DashboardWidget.GridId`).
> Паттерн:
> ```csharp
> private int RtsGridId => Config?.GridId ?? GridId;
> var fullUrl = $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";
> ```

**Почему Queue Grid «работает» без этого фикса:**
Queue Grid не фильтрует строки по UnionId — показывает все строки из симулятора включая random fallback.
Любой виджет, который ищет строку по `r.UnionId == buId`, сломается без этого фикса.

**Правило для спецификации:**
В §N.10 Implementation Notes каждого real-time Grid виджета с BU-фильтрацией добавлять:
> "SignalR hub URL must use Config.GridId (RTSGrid_Grid.GridId), not the GridId component parameter."

---

### L-21: ConfigBusinessUnit хранит integer ID как строку — не имя BU

`ConfigBusinessUnit` (string?) заполняется в момент выбора BU через dropdown:
```csharp
ConfigBusinessUnit = bu?.BusinessUnitId.ToString();  // e.g. "5", not "Billing Department"
```

При сохранении конфига виджета:
```csharp
BusinessUnitId = int.TryParse(ConfigBusinessUnit, out var parsedBuId) ? parsedBuId : (int?)null
```

`int.TryParse` работает корректно, т.к. `ConfigBusinessUnit = "5"`.

**Не путать с `BuSearchText`** — это текстовое поле поиска, хранит имя BU для отображения.
При открытии dropdown: `BuSearchText = string.Empty` (очистить поиск).
При закрытии: `BuSearchText = GetBusinessUnitName(ConfigBusinessUnit)` (восстановить имя).

---


---

## Lessons Learned (2026-05-28 — ASD Widget / Specialized Grid Pattern)

### L-22: 90% of widgets are Specialized Grid Widgets — Queue Grid with custom renderer

**Critical architectural insight (2026-05-28, ASD planning session).**

The **Queue Grid** is not just a "table widget" — it is the **universal real-time data layer**
for any BU-scoped, SignalR-pushed metric. The table view is only one renderer on top of it.

**Specialized Grid Widget** = Queue Grid infrastructure + a non-table renderer (chart, gauge, tile, bar, etc.)

This pattern covers approximately **90% of RTM widgets**:
- Agent State Distribution (ASD) — donut / bar chart over `UsersInStatusGroupCount` / `UsersInStatusCount` metrics
- SLA gauge — gauge chart over queue SLA metrics
- Occupancy gauge — gauge over occupancy metrics
- KPI tile row — tiles over queue/agent aggregate metrics
- Abandoned calls bar — bar chart over abandoned call metrics

**All of these reuse the same infrastructure as Queue Grid:**
- `SaveQueueGridRtsCommand` for RTS configuration
- `SignalRQueueGridHub` for real-time push
- `RTSGrid_Grid / RTSGrid_Row / RTSGrid_Cell` tables
- `GridId` from `Config.GridId` (not `DashboardWidget.GridId` — see L-20)
- BU-scoped rows with `UnionId = BusinessUnitId`

**What differs from a standard Queue Grid:**
- The Blazor component renders a chart/gauge/tile instead of a `<table>`
- SignalR subscription and data parsing are identical
- Config modal has custom fields (e.g., segment colors, distribution mode) in addition to standard fields

**Rule for planning:**
> "Is this widget showing live BU-scoped data?"
> → YES → It is a Specialized Grid Widget. Start from Queue Grid patterns, add custom renderer.
> → NO → Chart/Analytics (historical) or Agent Grid (per-agent rows).

**Queue Grid spec section (§15 of widget-creator.md) and `QueueGridWidget.razor` are the
primary reference for all Specialized Grid Widgets — read them before planning any new widget.**

---

### L-23: Two-RTSGrid pattern for dual-mode widgets (By Group / By State)

Some widgets must support two aggregation levels on the same data, switchable by the user.
The canonical example is ASD (Agent State Distribution):
- **By Group** mode: aggregates agents by Status Group (`UsersInStatusGroupCount`) — shows e.g. Available, Break, On Phone
- **By State** mode: shows individual Agent States (`UsersInStatusCount`) — shows e.g. Available, Short Break, Lunch, Coffee Break

**Pattern: two separate GridIds in `WidgetConfig`**

```csharp
// In WidgetConfig
public int? GridId { get; set; }       // Group mode: RTSGrid for UsersInStatusGroupCount
public int? StateGridId { get; set; }  // State mode:  RTSGrid for UsersInStatusCount
```

At render time:
```csharp
private int RtsGridId => DistributionMode == "state"
    ? (Config?.StateGridId ?? GridId)
    : (Config?.GridId ?? GridId);

var fullUrl = $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";
```

At config save time: two `SaveQueueGridRtsCommand` calls, one per GridId.

**When to use this pattern:**
- Widget needs two incompatible MetricFunctions for the same display
- User switches between detail and summary levels
- Different column sets required per mode

**Phase 0 question — if dual-mode is possible:** "Should the user be able to switch between
summary (By Group) and detail (By State) views? If yes, two GridIds must be configured."

**MetricId resolver pattern — both grids use the same lookup logic, different MetricFunction:**

| Grid | MetricFunction | MetricParameter | Source table |
|---|---|---|---|
| GroupGridId | `UsersInStatusGroupCount` | `AgentStateGroup.GroupName` (CC code: `AVAILABLE`, `BREAK`, …) | `tenant_agent_state_groups` |
| StateGridId | `UsersInStatusCount` | `AgentState.AgentStateName` (e.g. `Available`, `Short Break`, `Lunch`) | `tenant_agent_states` |

Both MetricIds are **concrete entries in `RTSGrid_Metric`** — not dynamically generated.
The resolver queries `RTSGrid_Metric WHERE MetricFunction = X AND MetricParameter = Y`.
Existing `GetAgentStateDefinitionsQueryHandler` covers Group mode. State mode needs an analogous lookup.

**SaveQueueGridRtsCommand is called twice** when saving ASD config (once per GridId).
Both grids are always saved regardless of current DistributionMode — so mode switching
never requires reconfiguration.

---

### L-24: UsersInStatusGroupCount vs UsersInStatusCount — MetricFunction selection rule

Two MetricFunctions serve the ASD domain:

| MetricFunction | MetricParameter | What it counts | Use when |
|---|---|---|---|
| `UsersInStatusGroupCount` | CC platform code (e.g. `AVAILABLE`, `BREAK`) | Agents in a **Status Group** — ALL states mapped to that group | Aggregate / summary view |
| `UsersInStatusCount` | Agent State name (e.g. `LUNCH`, `SHORT_BREAK`) | Agents in one **specific Agent State** | Detailed / per-state view |

**Key distinction:**
- `UsersInStatusGroupCount` uses the **Status Group code** as MetricParameter (e.g. `BREAK` covers Lunch + Short Break + Coffee Break)
- `UsersInStatusCount` uses the **Agent State name** as MetricParameter (platform-specific, client-defined, e.g. `Available`, `Short Break`, `Lunch`)

**MetricParameter format matters:** `UsersInStatusCount` MetricParameters match `AgentState.AgentStateName` exactly
as stored in the catalogue (case-sensitive). Verify against actual `RTSGrid_Metric` rows before coding.

**MetricType for both is `"Data"`** (not `"Agent"`) — both are BU-aggregate metrics, not per-agent.
This was a critical bug in CC-008: filtering by `MetricType == "Agent"` excluded all ASD metrics.
**Always filter by `MetricFunction` name, not `MetricType`.**

**MetricParameter lookup rule:**
- For `UsersInStatusGroupCount`: MetricParameter = `GroupName` (CC code stored in `AgentStateGroup.GroupName`)
- For `UsersInStatusCount`: MetricParameter = `AgentStateName` (raw CC state name in `AgentState.AgentStateName`)

---

### L-25: Agent State vs Status Group — two distinct concepts

These are often confused. Clear definitions:

| Concept | Where defined | Examples | Used by |
|---|---|---|---|
| **Agent State** | CC platform (client-configurable) | `AVAILABLE`, `LUNCH`, `SHORT_BREAK`, `COFFEE_BREAK`, `BACK_OFFICE` | `UsersInStatusCount`, `tenant_agent_states` |
| **Status Group** | SignalR Server config (CC platform concept), mirrored by Superadmin | `AVAILABLE`, `BREAK`, `ONPHONE`, `PAPERWORK`, `TRAINING` | `UsersInStatusGroupCount`, `tenant_agent_state_groups` |

- **One Status Group → many Agent States** (e.g. BREAK = {SHORT_BREAK, LUNCH, COFFEE_BREAK, GYM_BREAK, ...})
- The mapping is maintained in `tenant_agent_state_definitions` (AgentStateId → AgentStateGroupId)
- **Status Group codes are canonical** (fixed CC platform values); Agent States are deployment-specific
- When a Superadmin adds a new Agent State, they assign it to an existing Status Group

**For metric queries:**
- Always use `GroupName` (CC code like `BREAK`) — not the display name ("Break") — as MetricParameter for `UsersInStatusGroupCount`
- `GetAgentStateDefinitionsQueryHandler` resolves MetricIds at query time by joining on `GroupName`
- MetricId is **never stored** in the DB — derived from `RTSGrid_Metric.MetricParameter = GroupName`

### L-26: Specialized Grid Widgets — deletion must mirror Queue Grid EXACTLY (3 places)

**Bug found post-CC-008 (2026-05-28):** ASD widget left orphaned `RTSGrid_*` records on deletion because
`ScreenEditorPage.razor` had no ASD case in its deletion chain.

**The deletion flow for ANY Specialized Grid Widget is deferred (not in DisposeAsync):**
1. User clicks ✕ on widget → `RemoveWidget(widgetId)` → shows confirmation dialog
2. Dialog shows `@L["Widget_DeleteRtsWarning"]` only if the widget IS in the deletion check
3. User confirms → `ConfirmDeleteWidget()` → adds to `WidgetsPendingRtsDeletion` list
4. On "Save layout" click → `foreach (WidgetsPendingRtsDeletion)` → `DeleteQueueGridRtsCommand`

**Three places in `ScreenEditorPage.razor` that ALL must include the new widget type:**

| # | Location | What to add |
|---|---|---|
| 1 | Delete dialog `@if` condition (~line 1926) | `\|\| (IsYourWidget(WidgetToDelete) && WidgetToDelete.Config?.GridId > 0)` |
| 2 | `ConfirmDeleteWidget()` `if` condition (~line 2809) | Same condition as #1 |
| 3 | Save loop `foreach (WidgetsPendingRtsDeletion)` (~line 4241) | New `else if` block calling `DeleteQueueGridRtsCommand` |

**For dual-mode widgets (two GridIds — e.g. CC-009 ASD):** call `DeleteQueueGridRtsCommand` twice:
```csharp
else if (IsAgentStateDistributionWidget(widget))
{
    if (widget.Config?.GroupGridId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(widget.Config.GroupGridId.Value), _cts.Token);
    if (widget.Config?.StateGridId > 0)
        await Mediator.Send(new DeleteQueueGridRtsCommand(widget.Config.StateGridId.Value), _cts.Token);
}
```

**Core invariant:**
> `DeleteQueueGridRtsCommand` call count on delete = `SaveQueueGridRtsCommand` call count on save.
>
> - Standard widget (1 RTSGrid) → 1 `SaveQueueGridRtsCommand` on save → 1 `DeleteQueueGridRtsCommand` on delete
> - ASD dual-mode (2 RTSGrids: GroupGridId + StateGridId) → 2 `Save...` → 2 `Delete...`
> - Any widget with N RTSGrids → N deletes. **Never fewer.**

**Rule for every new Specialized Grid Widget:**
> Add the widget predicate to all 3 places in `ScreenEditorPage.razor` BEFORE merging the widget PR.
> Add to Phase 5 checklist: "All 3 ScreenEditorPage.razor deletion places updated?""

**Add to Phase 5 Final Checklist:**
- [ ] `ScreenEditorPage.razor` — delete dialog warning includes new widget
- [ ] `ScreenEditorPage.razor` — `ConfirmDeleteWidget()` adds new widget to `WidgetsPendingRtsDeletion`
- [ ] `ScreenEditorPage.razor` — save loop calls `DeleteQueueGridRtsCommand` for new widget's GridId(s)

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

---

## Lesson 11: QueueGrid production checklist (2026-06-03)

Before marking a DataGrid/QueueGrid widget as delivered, verify:

1. **GridId sync**: `dashboard_widgets.GridId` == `RTSGrid_Grid.GridId`
   (NOT the auto-increment PK of dashboard_widgets)

2. **CellMap populated**: After saving, `Config.QueueGridRows[i].CellIds[colId]`
   contains real CellIds from `RTSGrid_GetDataCells(gridId)`.
   If CellIds are null/empty, no data will ever display.

3. **Newtonsoft + JToken**: If relay uses Newtonsoft protocol,
   `On<JsonElement>` silently drops all messages. Use `On<JToken>`.

4. **Blazor lifecycle**: Widget subscribe must be in `OnAfterRenderAsync(firstRender)`
   only. SSR pre-render in `OnInitializedAsync`/`OnParametersSetAsync` causes
   subscribe→dispose cycles that make the relay grace timer kill the connection.

5. **RTM Service LoadData**: Calling `/LoadData` (e.g., after SaveQueueGridRts)
   causes RTM Service to close all SignalR connections. The relay reconnects
   automatically via backoff, but there will be a brief data interruption.

---

*Widget Planner Skill — created 2026-05-27. Updated 2026-05-28 (L-22–L-26), 2026-06-03 (L-11 QueueGrid checklist).*
*L-22: Specialized Grid Widget pattern. L-23: dual-mode RTSGrid. L-24: MetricFunction rules. L-25: State vs Group. L-26: 3-place deletion rule.*
*23 lessons learned.*
