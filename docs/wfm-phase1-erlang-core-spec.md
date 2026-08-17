# WFM Phase 1 — Erlang Core + real-time staffing — implementation spec (v0.1)

> Author: metrics specialist (metrics-3-0609), 2026-07. Scope: **Phase 1** of the WFM metrics
> (`10072026/WFM_Metrics/`) — the metrics computable NOW from existing real-time data. This is the metric-DOMAIN
> spec (formulas, inputs, validation, service contract). The C# `ErlangCalculatorService` implementation + SignalR
> delivery + widgets are backend/Shell (route via §4). Analysis basis: `docs/wfm-metrics-analysis-2026-07.md`.

## 0. Phase 1 scope — 9 metrics (+1 optional)
`erlang`/`derived` metrics that need ONLY the two existing tables (`RTSData_Interaction`, `RTSData_UserStatusLog`)
+ config — NO new WFM data tables:
M-WFM-01 TrafficIntensity, 02 ErlangPwait, 03 PredictedSL, 04 PredictedASA, 05 RequiredAgents, 06 ErlangB,
07 StaffVariance, 08 OccupancyErl, 11 UnderstaffPct.
**Optional (1b):** M-WFM-10 FteRequired — usable now via `DefaultShrinkage` config fallback (real Shrinkage = Phase 2).
**Deferred to Phase 2/3:** everything needing `wfm_schedule` / `wfm_forecast_intervals` / `wfm_adherence_log`.

Computed live (NOT stored in `RTSGrid_Metric`), cadence 30 s (M-06: 300 s; M-10: daily). Per **(tenant, queue/skill)**.

## 1. Input contract (derive from EXISTING real-time data)
All inputs are per (tenant, queue) over the **current 30-minute interval** (rolling window; window length = config, default 30 min).
| Symbol | Meaning | Source | Derivation (default) |
|---|---|---|---|
| `lambda` (λ) | arrival rate, **calls/hour** | `RTSData_Interaction` | count of interactions that ARRIVED in the window (Direction=Incoming, in-queue arrivals), scaled to hourly: `count / windowMinutes * 60` |
| `AHT` | avg handle time, **seconds** | `RTSData_Interaction` | mean of (Talk + Wrap) over interactions COMPLETED in the window; guard `AHT>0` (fallback: last-known / tenant default) |
| `N_actual` | agents available now | `RTSData_UserStatusLog` | **real-time snapshot** count of agents in Ready OR Talk for this queue/skill (states mapped to AVAILABLE + ONPHONE groups) |
| `A` | offered load, **Erlangs** | computed (M-01) | `A = lambda * AHT / 3600` |
**Open (flag at §4):** window length; exact λ definition (arrivals vs offered incl. abandoned); which agent states = "N"
(Ready+Talk only, or incl. Wrap?); per-queue vs per-skill vs per-supergroup scope. Defaults above; confirm with operator.

## 2. Erlang algorithms — NUMERICALLY STABLE (do NOT use A^N/N! directly)
### Erlang B (blocking) — recursion, overflow-safe:
```
ErlangB(N, A):            # N = servers (int >=0), A = offered load (>=0)
  B = 1.0                 # B(0,A)=1
  for n in 1..N:
    B = (A * B) / (n + A * B)
  return B                # = B(N,A) in [0,1]
```
### Erlang C (prob. of wait) from Erlang B — requires N > A:
```
ErlangC(N, A):
  if N <= A: return SYSTEM_OVERLOADED     # rho>=1, queue diverges
  B = ErlangB(N, A)
  rho = A / N
  return B / (1 - rho + rho * B)          # = B / (1 - rho*(1-B))
```

## 3. The metrics (formulas, guard, cadence, thresholds)
Let `t = SlThresholdSec`, `SL_target = SlTargetPct`, `C = ErlangC(N_actual, A)`.
| M | Id | Formula | Guard | Cadence | Threshold (G/Y/R) |
|---|---|---|---|---|---|
| 01 | TrafficIntensity `A` | `lambda*AHT/3600` | — | 30s | info |
| 02 | ErlangPwait `C` | `ErlangC(N_actual,A)` | `N>A` else SystemOverloaded | 30s | <20 / 20-40 / >40 (%) |
| 03 | PredictedSL | `1 - C*exp(-(N_actual-A)*t/AHT)` (×100%) | `N>A` | 30s | >=80 / 70-79 / <70 |
| 04 | PredictedASA | `C*AHT/(N_actual-A)` (sec) | `N>A` | 30s | <15 / 15-30 / >30 |
| 05 | RequiredAgents | `min N in [ceil(A)+1 .. 200] : PredictedSL(t,N) >= SL_target` | none-in-range → cap=200+warn | 30s | info |
| 06 | ErlangB | `ErlangB(TrunkCapacity, A)` (×100%) | — | 300s | <1 / 1-5 / >5 |
| 07 | StaffVariance | `N_actual - RequiredAgents` (signed) | — | 30s | >=0 / -1..-2 / <=-3 |
| 08 | OccupancyErl | `A / N_actual * 100` | `N_actual>0` | 30s | 75-85 / >85 / >90‖<60 |
| 11 | UnderstaffPct | `max(0, RequiredAgents - N_actual)/RequiredAgents*100` | `RequiredAgents>0` | 30s | 0 / 1-15 / >15 |
| 10* | FteRequired | `RequiredAgents / (1 - Shrinkage)`; Shrinkage = M-09 or `DefaultShrinkage` | `Shrinkage<1` | daily | info |
Note M-05: PredictedSL(t,N) inside the loop uses the LOOP's N and `C=ErlangC(N,A)` — NOT N_actual.

## 4. Dependency / evaluation order (single 30s pass)
`A (01) -> C (02) -> {SL(03), ASA(04)} -> RequiredAgents(05) -> {StaffVariance(07), UnderstaffPct(11)}`;
independent: `OccupancyErl(08)` from A+N_actual; `ErlangB(06)` from A+TrunkCapacity (300s). `FteRequired(10)` daily from 05+Shrinkage.

## 5. Config (TenantSettings → WFM section) — all Phase 1
`SlThresholdSec` int (def 20) · `SlTargetPct` double (def 80) · `TrunkCapacity` int (def 100, M-06) ·
`DefaultShrinkage` double (def 0.28, M-10 fallback) · `WfmWindowMinutes` int (def 30) ·
`EnableWfmRealtime` bool (def true). Threshold bands per-metric = defaults above, per-tenant overridable.

## 6. Validation / edge cases (MUST handle — the "does it compile & not throw" gate)
- `N_actual <= A` (overload): M-02..05 return **SystemOverloaded** sentinel (i18n `Wfm.SystemOverloaded`); no NaN/Inf to UI.
- `AHT <= 0` or no completed interactions in window: skip SL/ASA/A (show NoData), do NOT divide by zero.
- `N_actual == 0`: Occupancy/Understaff = NoData (guarded).
- `RequiredAgents` search: start `ceil(A)+1`; cap 200 → if unmet, return 200 + `warn` flag.
- All ratios guarded for zero denominator; percentages clamped to [0,100] where semantically bounded (SL, Understaff).
- Erlang B/C: N up to 200 in the recursion — stable (no factorials); A can be large (overload path guards it).

## 7. WORKED NUMERIC EXAMPLE (unit-test anchor — backend MUST reproduce)
Given: `lambda = 160 calls/hr`, `AHT = 180 s`, `N_actual = 10`, `t = 20 s`, `SlTargetPct = 80`, `TrunkCapacity = 100`.
| Metric | Expected (±rounding) |
|---|---|
| M-01 A | `160*180/3600` = **8.0** Erlang |
| M-02 C(10,8) | **0.409** (40.9%) |
| M-03 PredictedSL(20) | `1 - 0.409*exp(-(10-8)*20/180)` = `1 - 0.409*0.8007` ≈ **67.2%** |
| M-04 PredictedASA | `0.409*180/(10-8)` ≈ **36.8 s** |
| M-05 RequiredAgents | **11**  (N=10→SL 67.2%, N=11→SL 82.4% ≥80) |
| M-07 StaffVariance | `10 - 11` = **-1** |
| M-08 OccupancyErl | `8/10*100` = **80%** |
| M-11 UnderstaffPct | `max(0,11-10)/11*100` ≈ **9.1%** |
Intermediate ErlangB(10,8) ≈ **0.1217** (chain B0..B10). These are exact enough for a ±0.5% unit test.

## 8. Service contract (for backend impl)
- New `IErlangCalculatorService` (Application) + `ErlangCalculatorService` (Infrastructure). Pure functions
  `ErlangB(n,A)`, `ErlangC(n,A)`, `PredictedSL(N,A,AHT,t)`, `PredictedASA(N,A,AHT)`, `RequiredAgents(A,AHT,t,target)`
  — deterministic, unit-testable in isolation (anchor §7).
- A hosted 30s loop (`IHostedService`) per active (tenant, queue): reads λ/AHT/N (§1), runs the §4 pass, emits a
  `WfmSnapshot { queueId, metrics{id->{value, ragState, sentinel?}} }`.
- **Multi-tenant (§33):** loop creates a DI scope, sets `ITenantContext.TenantId` before any DB read.
- **Delivery:** push `WfmSnapshot` to the WFM widgets via SignalR (own hub or the RTM relay §34) — NOT the RTSGrid
  grid-cell path. Backend + Shell define the transport + widget set (wallboard tiles, manager tabs, queueCard, erlangCalc).
- **NOT** `RTSGrid_Metric` rows; **NOT** the Deploy-New-Metrics/apply-service flow. Separate subsystem.

## 9. Deliverables & routing
- THIS spec (metrics domain) — done. Next: a backend CC prompt to implement `ErlangCalculatorService` + hosted loop
  + unit tests against §7 (backend-owned, my §4 on the formulas). Shell: WFM widgets + threshold rendering. DBA:
  confirm λ/AHT/N queries on RTSData are SARGable at 30s cadence. Config: TenantSettings WFM section (§5).
- Phase 2 (Adherence) / Phase 3 (Forecast) remain blocked on their data sources (scheduling, forecasting).
