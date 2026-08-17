# WFM metrics — analysis vs RTM View Shell (metrics specialist, 2026-07)

> Source: `10072026/WFM_Metrics/` (WFM_Metric_Definitions.md/.docx + wfm-metrics-definitions.json).
> 20 metrics M-WFM-01..20, 4 categories. Author: metrics-3-0609. Read-only analysis.

## 1. What this is
20 Workforce-Management metrics in 4 groups, with 3 compute classes (per the doc §1.2):
- **Erlang Core (6):** TrafficIntensity(A), ErlangPwait C(N,A), PredictedSL, PredictedASA, RequiredAgents, ErlangB.
- **Staffing (6):** StaffVariance, OccupancyErl, ShrinkagePct, FteRequired, UnderstaffPct, StaffUtilization.
- **Adherence (4):** AdherencePct, ConformancePct, PunctualityPct, ScheduleDeviation.
- **Forecast (4):** ForecastAccuracy, MAPE, VolumeVariance, AhtVariance.
Compute classes: `erlang` (real-time, 30s), `aggregate` (background 30min/hourly/nightly), `derived` (from other metrics).

## 2. ARCHITECTURAL VERDICT — these are a NEW SUBSYSTEM, not RTSGrid_Metric rows
Our live-metric engine (`RTSGrid_Metric`) does exactly three things: `InteractionsCount`, agent-status counters, and
`Calc` = **basic C# arithmetic over numbers** (skill §2: no rolling windows, no factorials/exponentials, no iterative solving).
The WFM metrics need:
- **Erlang C/B math** — factorials `A^N/N!`, exponentials `exp()`, and an **iterative agent solver** (`min N: SL(t,N)>=target`).
  None of this is expressible in `RTSGrid_Metric.Calc`.
- **Cross-table aggregation** over schedule/forecast/adherence — not our real-time interaction model.
- A **dependency DAG** with ordered evaluation and **multiple cadences** (30s → daily).

**The doc itself already says this** (§1.2): erlang metrics are *"НЕ хранятся в RTSGrid_Metric; считаются
`ErlangCalculatorService` на лету"*, aggregates by *"`WfmCalculationService` / `WfmAdherenceService`"*.
So: **WFM = a new calculation module + new services + new tables + new UI widgets**, NOT catalogue metrics.
=> The "Deploy New Metrics" UI / hot-reload path (RTSGrid_Metric + apply-service) does **NOT** apply here. Different animal.

## 3. Data availability — what feeds exist vs what is NEW
| Input source | Status | Feeds |
|---|---|---|
| `RTSData_Interaction` (λ, AHT) | **EXISTS** (our RTM real-time) | Erlang Core, Forecast (actual), AhtVariance |
| `RTSData_UserStatusLog` (N, TalkTime, logins) | **EXISTS** | N-actual, Utilization, Adherence, Punctuality |
| `wfm_schedule` (agent shifts/plan) | **NEW — does not exist** | Adherence, Conformance, Punctuality, Deviation, Utilization |
| `wfm_forecast_intervals` (30-min volume/AHT forecast) | **NEW** | all Forecast-accuracy metrics |
| `wfm_adherence_log` (hourly adherence agg) | **NEW** | Shrinkage, Adherence history |
| `hist_queue_intervals` (30-min actual agg) | **NEW** (we have raw, not this agg) | Forecast Accuracy (actual side) |
Config params (NEW, TenantSettings WFM): `SlThresholdSec`, `SlTargetPct`, `DefaultShrinkage`, `TrunkCapacity`,
`EnableAdherence`, `EnableForecast`.

## 4. Feasibility & recommended phasing (by data readiness / value)
- **Phase 1 — Erlang Core + real-time staffing (M-01..08, 11): FEASIBLE NOW.** Inputs (λ, AHT, N) come from the two
  EXISTING RTSData tables. Only NEW work = the `ErlangCalculatorService` (pure math, 30s) + `TrunkCapacity` config for
  M-06. No new data tables. This is the high-value real-time WFM core ("predicted SL / how many agents needed / occupancy").
- **Phase 2 — Adherence module (M-09, 12, 13..16): needs `wfm_schedule` + `wfm_adherence_log`.** Blocked on an agent
  **scheduling data source** (import or build). `EnableAdherence` gate.
- **Phase 3 — Forecast module (M-10 FTE, 17..20): needs `wfm_forecast_intervals` + `hist_queue_intervals` + a
  forecasting capability.** Biggest lift (a forecast engine/import + historical interval store). `EnableForecast` gate.

## 5. Erlang math — implementation risks to flag
- **Numeric overflow:** the doc writes `B=(A^N/N!)/Σ A^k/k!` (textbook form). `A^N` and `N!` overflow fast → MUST implement
  via the **stable Erlang-B recursion** `B(0)=1; B(n)=A·B(n-1)/(n + A·B(n-1))`, and derive Erlang-C from B. Do NOT compute
  factorials directly.
- **`N>A` guard (M-02..05,08):** Erlang C assumes offered load < agents; when `N ≤ A` the formulas diverge → the doc's
  `SystemOverloaded` state is correct and must short-circuit (no NaN/Inf to the tile).
- **RequiredAgents solver:** `iterate ceil(A)+1..200` — bounded, good; surface a cap/warn if >200 needed.
- **Cadence/host:** who runs the 30s ErlangCalculatorService loop + the background aggregators? (RTM Service vs a new WFM
  service) — an architecture decision; must set `TenantId` scope per §33 (multi-tenant) and push results to the WFM widgets.
- **Delivery to UI:** these are computed values for wallboard tiles / manager tabs — needs a push path (SignalR/relay), NOT
  the RTSGrid grid-cell path. New WFM widgets (wallboard.tile1..4, manager.tab1/2, queueCard, erlangCalc).

## 6. Convention / catalogue notes
- MetricIds are PascalCase `Wfm*` — consistent with our naming. But the WFM json schema
  (`calcType, formula, dependsOn, cadenceSec, thresholds{RAG}, dashboards, requiresModule, guard`) is a **separate
  WFM catalogue**, distinct from our `docs/metrics-catalog.json` (which is RTSGrid_Metric display metadata). Keep them separate.
- Threshold RAG bands (green/yellow/red) are a **new capability** — our RTSGrid metrics have no built-in RAG; the WFM
  widgets need a threshold-evaluation layer (per-tenant configurable, §8).

## 7. Open decisions (doc §10) + my additions
Doc: D-1 SlThresholdSec(20), D-2 threshold defaults, D-3 N_req window for FTE (95th pct/4wk), D-4 adherence aggregation
level (agent/team/supergroup), D-5 forecast actual source. Add:
- **D-6:** host + scheduler for the WFM compute services (RTM vs new WFM service); multi-tenant scoping (§33).
- **D-7:** where agent SCHEDULES come from (there is no scheduling system today) — this gates all of Adherence + FTE.
- **D-8:** forecasting — build vs import; this gates all of Forecast Accuracy.
- **D-9:** UI push/transport for computed WFM values + the new WFM widget set.

## 8. Bottom line
The definitions are solid and internally consistent (clear DAG, cadences, guards, thresholds). But this is **NOT a
metrics-catalogue addition** — it is a **new WFM calculation subsystem** (services + 4 new data tables + config + i18n +
widgets). Recommend: **greenlight Phase 1 (Erlang Core, feasible on existing real-time data) as a standalone
`ErlangCalculatorService`**, and treat Adherence/Forecast as separate epics blocked on their data sources
(scheduling, forecasting). My metrics-domain role covers the metric DEFINITIONS/formulas/validation; the services +
tables + widgets are backend/DBA/Shell architecture — route accordingly.
