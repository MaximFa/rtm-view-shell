# Metric Change Procedure — add / edit / delete a metric (repo-driven)

> Canonical, reproducible workflow for changing the metric catalogue now that the Metrics admin page
> is READ-ONLY. Metrics are a repo+deploy artefact. Driven by Cowork (design) → CC (execution).
> Read `.claude/skills/rtm-metrics-expert/rtm-metrics-expert.md` before any metric work.
>
> KEY CONSTRAINT: the RTM engine reads & Roslyn-compiles all metrics ONCE at startup
> (LoadData, Engine.cs). Any add/edit/delete takes effect in the engine ONLY after an RTM Service
> RESTART. The Shell sees catalogue rows live (DB read) but shows no data until RTM restarts.

This file is a TEMPLATE. For each concrete change, Cowork fills the placeholders and emits a CC prompt
(or runs the steps as one CC task). Do NOT run raw — it is the recipe, not an executable task.

---

## A. ADD a new metric

**Design (Cowork + operator, using rtm-metrics-expert):**
- Pick an EXISTING `MetricFunction` (§10.2 of the skill — never invent). Decide `MetricParameter`
  (filter expr / status name / Calc), `ValueType` (number|time|text), `MetricType` (Data|Agent),
  `DataType` (Interactions Summary|UsersInteraction|UsersSummary|User), `Description` (correct prefix),
  `MetricFormat` if % / Fn.
- Confirm it is NOT a duplicate (skill §6 canonical key). Choose a MetricId following family naming
  (no dots, no dashes).
- Author the catalogue card: short + long description, category, family, channel/threshold, KPI, similar.

**Execution (CC):**
1. Migration `db/migrations/YYYYMMDD_NNN_add_<metric>.sql` — idempotent:
   `INSERT INTO "RTSGrid_Metric" (...9 cols...) VALUES (...) ON CONFLICT ("MetricId") DO NOTHING;`
2. Catalogue card → `docs/metrics-catalog.json` (+ family table row in `docs/RTM_Shell_Metrics_Overview.md`).
3. `python3 tools/lint_metrics.py` → MUST be 0 errors (function exists, no dup, calc/literal clean,
   coverage satisfied). Fix until green.
4. Apply to dev DB: `psql -U ccdashboard_user -d rtmviewdb -f <migration>`.
5. `db/tools/Export-All.ps1 -Password ... -CommitMessage "db: add <MetricId>"` — regenerates
   db/data/02_metrics.sql (linter gate runs inside); creates `db:` commit.
6. `docs:` commit for catalogue card + Overview (separate, §39.3).
7. Push via the coord barrier (§42). Deploy: apply migration on prod → **RESTART RTM Service**.

## B. EDIT an existing metric

Same as ADD but:
- Migration uses `UPDATE "RTSGrid_Metric" SET ... WHERE "MetricId" = '...';` (idempotent by nature).
- Editing `MetricFunction` / `MetricParameter` changes the Roslyn-compiled function → RTM RESTART mandatory.
- Editing only `Description` / catalogue card → still requires Export-All + commit; engine restart only
  if an engine-read column (the 7 cols RTM loads: DataType, MetricFunction, MetricParameter, MetricFormat,
  DefaultValue + id/desc) changed. ValueType/MetricType are Shell-only → no RTM restart, but redeploy Shell.
- Update the catalogue card to match.

## C. DELETE a metric

**Reference check FIRST (mandatory — skill §6):** before removing, confirm no live references:
```sql
SELECT count(*) FROM "RTSGrid_Cell" WHERE "Value" = '<MetricId>';                 -- grid cells
SELECT "MetricId" FROM "RTSGrid_Metric"
  WHERE "MetricFunction"='Calc' AND "MetricParameter" LIKE '%[' || '<MetricId>' || ']%';  -- calc refs
SELECT w."Id", d."Name" FROM dashboard_widgets w JOIN dashboards d ON w."DashboardId"=d."Id"
  WHERE w."ConfigJson"::text ILIKE '%<MetricId>%';                                 -- widget configs
```
Also `grep -rn "<MetricId>" src/ tools/SignalRSimulator/`. Re-point or remove every reference to the
canonical metric BEFORE deletion (see migration 20260605_004 as the worked example).

**Execution (CC):**
1. Migration: re-point references (UPDATE RTSGrid_Cell.Value …), then
   `DELETE FROM "RTSGrid_Metric" WHERE "MetricId" IN (...);`
2. Remove/retire the catalogue card: set its `status` to `deprecated` (keep for reference) OR delete it.
   Coverage gate (linter) treats deprecated as WARNING, not ERROR.
3. Linter → 0 errors. Apply to dev → Export-All (`db:`). docs commit. Push barrier. Prod + RTM RESTART.

---

## Invariants (do not violate)
- Never seed RTSGrid_Metric from DatabaseInitializer — migration only (skill §4).
- Never invent a MetricFunction — use §10.2 list.
- Calc refs: existing MetricIds, no spaces inside `[...]`.
- No property name inside a string literal in MetricParameter (Roslyn TransformQuery gotcha, §12.2).
- Every change ends with: linter green → Export-All → commit(s) → push barrier → prod + RTM restart.
- The Metrics admin page is READ-ONLY; do not re-introduce write commands there.

*Created 2026-06-06 (RTM Metrics session, Stage 2). Pairs with tools/lint_metrics.py and
docs/metrics-catalog.json. RTM restart requirement verified in Engine.cs LoadData (startup-only).*
