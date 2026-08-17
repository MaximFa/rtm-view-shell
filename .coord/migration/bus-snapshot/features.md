# .coord/features.md — Feature-Extension Register (COORDINATOR-OWNED)

> Конституция координатора (operator 2026-07-03): реестр расширений функционала, ведётся В ДОКУМЕНТЕ,
> не по памяти. Формат идентичен реестру реджектов: каждый пункт несёт дату-время заявления,
> подтверждающие факты приёмки (скриншоты / пробы / визуальная проверка — на выбор координатора)
> и номер пуша, с которым функционал ПОДТВЕРЖДЁННО поставлен. Закрытие — только словом оператора.

**Статусы:** 🔵 DECLARED → 🛠 IN-WORK → 🟡 DELIVERED-PUSHED (ждёт подтверждения) → 🟢 ACCEPTED / ⚪ CANCELLED

| ID | Feature | Заявлено (UTC) | Owner | Факты приёмки | Пуш | Статус | Слово оператора |
|----|---------|----------------|-------|---------------|-----|--------|-----------------|
| F-SCALE-TOGGLE | Scale-mode toggle в View topbar (fit/1:1) — переквалифицирован из Edit↔View scale бага (оператор 2026-06-26) | 2026-06-26 | shell | coord live 2026-07-02: no crash, fit↔1:1 fires (dee401e); ВИЗУАЛ A/B на board>viewport не снят | origin/v3 1b5778a | 🟡 DELIVERED-PUSHED | pending |


## FEATURE/UX | Edit Tenant modal — Danger-zone-on-General + Agent-States/Groups Activate+Delete | declared 2026-07-16T08:08Z by operator
STATUS: OPEN (dispatched shell to author -> §4 -> run).
1. Danger zone (Suspend/Delete tenant) → General tab only (currently all tabs, context-confusing).
2. Agent States + State Groups: add Activate (for Inactive rows — currently no way to undo Deactivate) + Delete; context-aware icons (Active→Edit+Deactivate+Delete; Inactive→Edit+Activate+Delete). May need backend Activate/Delete commands (only Deactivate exists) — flagged for parallel backend dispatch.
FIX push #: <pending>.


## FEATURE/EPIC | LIVE (targeted) pickup of ALL UI config changes — NOT RTM restart | declared 2026-07-16T19:19Z by operator
STATUS: OPEN (design+audit dispatched). Operator directive: ANY UI config change (BU/SG/Sites/AgentStates+Groups+defs/Queues/InfoSlots/Dashboards-grids) must be picked up ON THE FLY, TARGETED/precise to the change, NOT an RTM restart, NOT full LoadData. METRICS EXCLUDED (separate echelon, own mechanism).
Grid case already DONE (961a979 on-demand grid registration). This generalizes it.
- Task 2 (Agent States/Groups Activate+Delete): Delete=HARD removal both (mapping, confirmation, no block-guard); Activate=IsActive=true; add/delete live-pickup = the PILOT.
- backend: 4 Activate/Delete commands + agent-state live-pickup pilot + DESIGN the general targeted-pickup mechanism (IConfigurationApiHook Shell->RTM notify -> scoped RTM reload per change-type / DB LISTEN-NOTIFY / on-demand) -> §4 + operator review.
- shell: Task-2 UI + AUDIT matrix (every UI config change vs current RTM pickup: live/restart-only/on-demand).
FIX push #: <pending>.


## STANDING ITEMS (backlog) — DayTrend ~4h lag decomposition | 2026-07-20T13:50Z | source: DE probe (backend-0626), empirically grounded
Operator observed DE DayTrend lagging ~4h. Backend DE probe (Asia/Jerusalem +0300, 10 newest DE rows): writes LIVE (not halted); TimeZone="-01:00" on ALL DE rows (WRONG — July CEST should be +02:00). NOT this-week regression, NOT ad73870 (writes live + fn_daytrendinteractions unchanged 0c67438/d50f1f1). Lag = ~3h (DayTrend renders bucket in UTC while viewer reads Israel +3) + ~1h (wrong -01:00 stamp shifts InQueueDateTime 1h early) + ~30m (bucket floor). Backend RETRACTED its earlier US "-4h store-local-as-UTC" math (spurious fit, wrong site/sign).
- ITEM A [config/data — HIGH FLAG]: DE interactions stamped TimeZone="-01:00" (should be +02:00 CEST). Systematic DE site/adapter misconfig. ⚠ AFFECTS ALL InQueueDateTime-based DE logic (queue date filters, etc.), NOT just DayTrend. Owner: trace where TimeZone is populated for the DE target (adapter config / RTM site config) — devops/config or adapters-branch; backend can trace the adapter TZ plumbing. NOT a hotfix.
- ITEM B [display — SHELL]: DayTrend widget renders buckets in UTC (naive) — should render in the viewer's/site's zone. daytrendChart.js + DayTrendResult formatting. NOT a hotfix.
STATUS: HELD (backlog) — Max Wait remains the active regression. Priority TBD by operator.


## ITEM A (FORMALIZED) — Site TimeZone config wrong + not DST-aware | 2026-07-20T14:00Z | source: operator Site-config screenshot + coord audit + backend DE probe
FINDING (coord audit of the Site TimeZone config screen, July 2026 = northern summer, DST active):
| Site | Config offset | Correct now (July) | Verdict |
| DE Germany | -01:00 | +02:00 CEST (std +01:00) | ❌ GROSS — matches neither std nor DST; sign-error-looking. THE root of DE DayTrend ~1h + earlier DE data discrepancies. |
| IL Israel | +02:00 | +03:00 IDT | ❌ winter value, DST not applied (-1h now) |
| NZ New Zealand | +12:00 | +12:00 NZST | ✅ (southern winter, no DST) |
| UK | +00:00 | +01:00 BST | ❌ winter value, DST not applied (-1h now) |
| US | -04:00 | -04:00 EDT (if Eastern) | ✅ if US=Eastern (ambiguous, US multi-zone) |
ROOT: (1) DE value is a plain error; (2) STATIC per-site UTC offset is DST-broken by design — any DST-observing site is wrong half the year; the entered values mix current (NZ/US) and standard (IL/UK) conventions inconsistently. Source of the wrong per-interaction TimeZone backend found = THIS Site config (InQueueDateTime stamping reads site TZ).
SCOPE: broader than DayTrend — the site TZ feeds InQueueDateTime stamping (RTM) + the restart interaction-load filter (DB) + DayTrend display (Shell). Wrong TZ skews ALL InQueueDateTime-based DE logic.
FIX (operator-prioritized 2026-07-20, "сначала таймзону + рестарт с учётом таймзоны"): coherent TZ model — correct site TZ representation (IANA vs offset — DECISION) + timezone-aware restart load + consistent stamping/display. DESIGN-FIRST (TZ burned us 4x: 0b07651->0329bf0->e58cac8->01dbc2c). Backend leads design + dba review -> coordinator §4 -> operator decides -> implement. STATUS: ACTIVE (prioritized).


## STATUS UPDATE — ITEM A (Timezone) -> BACKLOG (operator-deferred) | 2026-07-21T04:23Z
Operator deferred ALL timezone work to backlog 2026-07-20. RESUME-READY state captured:
- Design: docs/design/RTM-Timezone-Coherence-Design.md (coord §4-PASS + 2 conditions C1 IANA-on-Windows / C2 dba-gates-3&4).
- Operator quick-path DECISIONS (locked): 1=IANA zone names; 2=server-local "today" interim; 5=interim full-/LoadData pickup (no restart); 3(storage UTC)/4(re-stamp migration)=pending dba.
- First step on resume: C1 gate (FindSystemTimeZoneById('Europe/Berlin') resolves on 140), then NGC_Site offsets->IANA (DE Europe/Berlin, IL Asia/Jerusalem, UK Europe/London, NZ Pacific/Auckland, US America/New_York) + Edit Site UI selector; DayTrend ~3h display + storage = 3/4 follow-up.
- KNOWN LIVE IMPACT while deferred: DE interactions keep stamping TimeZone=-01:00 (wrong, should +02:00) -> DE InQueueDateTime-based data stays ~1h off + DayTrend ~4h lag persists. Accepted by operator.
STATUS: BACKLOG (all sub-tasks HELD).


## WFM Phase 1 — LOCKED INPUTS (operator 2026-07-20) | 2026-07-21T09:46Z
Operator chose the recommended set for the hosted-loop follow-up:
- WINDOW: 30 min rolling (loop refresh 30s). Candidate: per-tenant configurable for low-volume queues.
- LAMBDA: offered incoming = answered + abandoned + queued arrivals, Type=Call||Callback, Direction=Incoming (calls+callbacks; RTM QueueNumIncomingOnlineCallsAndCallbacks bundles them). NOT answered-only. NOT outbound.
- N (serving pool): Ready + Talking + Wrap = agents in SERVING agent-state groups (default AVAILABLE+ONPHONE+PAPERWORK; BREAK/TRAINING excluded). CONFIGURABLE via TenantSettings WFM (which state-groups count as serving) — ties to Agent State Definitions.
- SCOPE: per-queue (union) for Phase 1. per-skill deferred (Erlang C multi-skill = double-count/simulation, out of scope).
- SL target: configurable, default 80% in 20s. AHT = talk+hold+wrap avg over window.
Core done (4e21796 ErlangCalculatorService, 18 tests, anchor GREEN). Follow-up = hosted 30s loop + WfmSnapshot SignalR + Shell widgets + TenantSettings WFM. STATUS: data-layer spec next (metrics+dba), then impl.


## WFM B1 window-frame — INTERIM link to TZ backlog (ITEM A) | 2026-07-21T11:39Z
dba LOCKED (14:22) the WFM λ/AHT window-frame as an INTERIM tied to the mislabel (DBMng.cs:396 SpecifyKind Utc):
per-distinct-site-TZ tight 30-min SARGable scan; offset from the interaction's OWN "TimeZone" column (self-consistent
with the stamp — works correctly DESPITE the wrong DE -01:00, no need to unblock the TZ backlog). Block tagged `-- DBA-FRAME: INTERIM`.
⚠ LINK: when TZ ITEM A (backlogged) lands the store-true-UTC fix (Decision 3), this per-site partition COLLAPSES to
ONE global one-pass (@winHi=UtcNow, no per-site scan). MUST remove the -- DBA-FRAME: INTERIM block then. Cross-ref ITEM A.


## WFM Phase 1 — C2 LIVE GATE: pipeline PROVEN, numeric check PENDING daytime traffic | 2026-07-22T10:43Z
After d1982de redeploy, coord verified live on 140 (WFM Dashboard, widget scoped BU "US All"):
- ✅ "Waiting for data" GONE -> the widget FOUND its snapshot (BU-id key now matches loop Set) = the key-mismatch chain is CLOSED.
- ✅ Renders the §4 contract: State badge "No Data" + message "Waiting for calls or agents" + footer "Live · <AsOfUtc> · 30 min window".
- ✅ LOOP IS LIVE: AsOfUtc ticked 13:41:32 -> 13:42:02 (exactly one 30s loop tick) = loop->store->widget end-to-end proven.
- ✅ Correct sentinel behavior: shows the nodata MESSAGE, not raw zeros (§4 requirement honored).
- ⚠ NUMERIC validation NOT yet possible: post-midnight rollover — the ENTIRE dashboard is zeros (Incoming 0, AHT 00:00, Abandoned 0, Callbacks 0, all queues 0, 0 agents). No traffic at this hour, so λ/N are genuinely empty.
=> C2 TECHNICALLY CLOSED (pipeline). REMAINING: re-check during BUSINESS HOURS with live traffic to validate the NUMBERS (real λ/AHT/N, Erlang outputs, RAG bands, percents not double-scaled).
COSMETIC FOLLOW-UP (non-blocking): 2 residual `WFM key collision` WARNs (UK - Retail/Support) — the collision DETECTION still compares by NAME though the store key is now the id; harmless noise, small backend cleanup.
WFM chain (8 commits, unpushed v3): 4e21796 Erlang · 83ce56b idx · 07b48a1 B0 · 515c355 B1 · 6e3c922 N-fix · fb9a6a4 BU-agg · d1982de BU-key · 30225d6 shell widget.


## WFM Phase 1 — C2 LIVE GATE **PASSED** (live non-zero data) | 2026-07-22T10:52Z
Re-checked on the DE General Manager dashboard (live traffic) per the operator's ZERO-DATA RULE — the earlier post-midnight zero screen was NOT a valid verification.
WFM Forecast widget, live, State=**OK**:
- INPUTS: Arrivals λ **36.0/hr** · AHT **5:44** (344s) · Serving Agents **14**
- ERLANG: Traffic **3.44 Erl** · P(wait) 0.0% · Predicted SL **100.0%** · Predicted ASA 0.0s · Erlang B 0.0% · Occupancy **24.6%** · Understaff 0.0% · Variance **+8**
- Live footer AsOfUtc TICKS every 30s (13:50:02 -> 13:51:02).
HAND-VERIFIED MATH (coordinator, independent): A = λ·AHT/3600 = 36.0·344/3600 = **3.44 Erl** == displayed. Occupancy = A/N = 3.44/14 = **24.6%** == displayed. Variance +8 => Required ≈ 6 (plausible for A=3.44 @ 80/20). With N=14 >> A=3.44 the queue is heavily overstaffed => P(wait)≈0, SL≈100%, ASA≈0s — all mathematically correct. Percentages NOT double-scaled (24.6%, not 2460%) = the §4 condition MET.
=> Erlang core + loop + store + widget verified END-TO-END on live production data. WFM Phase 1 FUNCTIONALLY VALIDATED.
Open (non-blocking): (1) 2 residual `WFM key collision` WARNs — detection still name-based though the store key is id (cosmetic backend cleanup); (2) sanity: WFM N=14 vs AgentGrid 13 rows vs AgentStateDistribution bars ~9 — likely different BU scopes per widget; operator to confirm the intended scope alignment.


## WFM sub-BU "No Data" — RESOLVED: CONFIG gap, NOT a code bug | 2026-07-22T11:19Z
Symptom: WFM widgets scoped to sub-BUs "DE - Accounting" / "DE - Support" showed **No Data** while DE All showed full numbers.
Coord live check: the snapshots ARRIVE correctly — λ and AHT are real (Accounting λ 18.0/hr AHT 1:57; Support λ 16.0/hr AHT 8:18; Queue Grid 40/73 incoming). The ONLY reason for No Data = **Serving Agents 0** (nodata guard: Erlang undefined without agents).
**OPERATOR-DETERMINED ROOT: those Business Units have NO SuperGroups assigned** → empty agent pool → N=0. => DATA/CONFIG gap in the customer's BU setup, **NOT** a WFM code defect. The devops SG probe was cancelled (answer already known).
⭐ WFM behaved CORRECTLY: it showed the honest nodata sentinel instead of fabricating zeros — exactly the §4 design requirement. No code change needed; assigning SuperGroups to those BUs will make the numbers appear.
OPTIONAL UX follow-up (operator's call, low priority): distinguish "no agents because the BU has NO agent-group/SG configuration" from "no agents because all are in non-serving states" — a config-hint message would be more actionable than the generic "Waiting for calls or agents".


## WFM — BACKLOG (operator, 2026-07-22T13:20Z) — Phase-2 candidates, all "рассмотрение" (design/analysis first, not yet approved for build)
Source: operator directive after the Phase-1 live validation on 140. NOT scheduled; each needs its own design + §4 before any code.

**WFM-B1 — Определение SLA под BU (per-BU SLA definition).**
Today SLA target/threshold are TENANT-level (`TenantSettings.WfmSlTargetPct`=80, `WfmSlThresholdSec`=20) → the same 80/20 applies to every BU. Different BUs/lines of business commonly carry DIFFERENT SLA contracts. Consider per-BU SLA (target % + threshold sec), overriding the tenant default. Impacts: RequiredAgents, PredictedSL, Understaff/Variance, and the RAG bands — all are computed against the SLA, so a wrong-scope SLA silently mis-sizes staffing per BU. Design Qs: storage (per-BU settings table vs JSON on the BU), UI (where the admin edits it), fallback to tenant default, and whether per-QUEUE SLA is also needed.

**WFM-B2 — Обработка данных в памяти по эвентам, а не сканированием БД (event-driven in-memory, like the Data Slot widget).**
Today the WFM loop QUERIES the DB every 30s (λ/AHT from RTSData_Interaction, N from RTSData_UserStatus — hence the 3 covering indexes + the SARGability work). Consider instead accumulating λ/AHT/N IN MEMORY from the RTM event stream — the way the Data Slot widget already works — so WFM stops scanning the DB.
⚖ TRADE-OFF to weigh explicitly in the design: DB-polling is what makes WFM pick up CONFIG changes for free (it re-reads BU/queue config every tick — the exact asymmetry vs Queue Grid, which needs LoadData). Going in-memory/event-driven would gain: near-zero DB load, sub-second freshness. It would lose: the automatic config-refresh (would then need the same targeted-pickup mechanism as T2), plus it needs a 30-min rolling window held in memory + a cold-start/restart backfill story (in-memory has no history after a restart). Also interacts with the still-open TZ/window-frame INTERIM.

**WFM-B3 — Конфигурация виджета: что показывать, что нет и как (трешхолды).**
Today the widget renders ALL §4 fields in a fixed order, and RAG bands come only from `TenantSettings.WfmThresholds` (tenant-wide JSON). Consider per-WIDGET-instance configuration: choose which metrics to show/hide, their order/layout, and per-instance thresholds (so one screen can flag Occupancy hard while another watches SL). Design Qs: where it lives (WidgetConfig), inheritance/override vs tenant defaults, and a sane default preset.

**WFM-B4 — Разложение данных на график (Required / Logged In / Variance).**
Today WFM is a numeric tile = a point-in-time snapshot. Consider a CHART view plotting the staffing story over time (intraday), e.g. Required vs Actual (Logged In / Serving Agents) vs Variance — the same idea as the Day Trend Chart. Makes over/under-staffing visible as a shape (when the gap opens/closes during the day) instead of a single number. Design Qs: data source for history (the current WfmSnapshot store is in-memory & point-in-time only → needs persistence or a rollup — ties to WFM-B2's history question), granularity (per 30-min bucket?), and whether it's a new widget or a mode of the existing one.

CROSS-CUTTING NOTE: B2 and B4 are coupled — both hinge on where WFM history lives (in-memory vs persisted/rollup). Decide that once, for both.


## WFM BACKLOG — AMENDMENT (operator, 2026-07-22T13:26Z): B2/B4 DECOUPLED — two separate widgets
Operator resolved the history coupling I flagged. Decision: **TWO widgets, different natures — not one widget with two modes.**

**(1) WFM (the "now" widget)** — ALREADY BUILT + live-validated on 140 (Phase 1). Point-in-time snapshot, seconds-fresh, 30s loop.
   => Because it needs NO history, **WFM-B2 (event-driven in-memory, Data-Slot style) now applies ONLY to this widget** and the history objection EVAPORATES. The remaining B2 trade-off is just the config-refresh one (in-memory loses the free BU/queue config re-read that DB-polling gives → would need the T2 targeted-pickup). Decide B2 on that alone.

**(2) WFM Graph (NEW widget)** — intraday HISTORY for today. Explicitly **DB-based (NOT memory)**, refresh **15 / 30 / 60 min** (configurable), NOT seconds.
   => Plots the staffing story over the day: **Required / Logged In (actual) / Variance**.
   => The slow refresh is the point: a few queries per hour, so it can afford heavier historical aggregation.

DESIGN NOTES for WFM Graph (for the design phase — NOT decided):
- HISTORY SOURCE — two options: (a) RECOMPUTE per time-bucket from raw data (RTSData_Interaction + RTSData_UserStatusLog), re-running ErlangCalculatorService per bucket; or (b) PERSIST each WfmSnapshot tick into a table and read it back. (a) needs NO new write path, no storage growth, and works RETROACTIVELY (history exists for periods before the feature shipped) — same pattern as DayTrend. Lean (a) unless the design finds a blocker.
- ⚠ HISTORICAL N: the current N query reads `RTSData_UserStatus` = CURRENT status only. Historical agent counts per bucket need **`RTSData_UserStatusLog`** (the history table). That's the key new data dependency for this widget — pin it early.
- Bucket size should align with the refresh (15/30/60) and with the WFM window semantics; reuse the same λ/AHT/N definitions as the "now" widget so the two widgets never disagree at the same timestamp.
- Same SLA scope question as WFM-B1 applies (Required depends on the SLA target).
=> B4 is now its own item: **a separate widget spec**, independent of B2. Neither blocks the other.


## WFM Graph — SERIES SELECTION & TOOLTIP requirement (operator, 2026-07-22T13:30Z)
Addition to the WFM Graph widget spec (B4). Operator requirement, verbatim intent:

**1. Any WFM-widget parameter can be plotted, by user choice.** The graph is NOT limited to Required/LoggedIn/Variance — the user may plot ANY of the metrics that currently live on the "now" WFM widget:
   INPUTS: Arrivals (λ) /hr · AHT · Serving Agents  (Wrap Included = boolean flag, not chartable)
   ERLANG: Traffic (Erl) · P(wait) % · Predicted SL % · Predicted ASA (s) · Required (agents) · Erlang B % · Occupancy % · Understaff % · Variance (±agents)
**2. Per-series CHECKBOX** — tick which series to show / hide.
**3. Per-series COLOR** — the user picks the colour of each plotted series.
**4. Scale is SECONDARY.** The vertical axis is deliberately not the authoritative reading — the point is the SHAPE/comparison over the day, not exact axis alignment.
**5. HOVER on a point = the authoritative value, IN THAT METRIC'S OWN UNITS.** The tooltip is where the user reads the real number (e.g. "AHT 4:57", "SL 100.0%", "Required 6 agents", "λ 40.0/hr"), each formatted in its own unit.

⚠ DESIGN DECISION to settle in the spec (NOT decided here): the selectable metrics span **5 different unit families** — rate (calls/hr), time (AHT/ASA in sec), count (Serving Agents / Required / Variance), Erlangs (Traffic), percent (P(wait)/SL/ErlangB/Occupancy/Understaff). Plotting them on ONE chart needs an explicit choice:
   (a) per-series NORMALISATION to its own range (pure shape comparison — fits "scale is secondary" best), or
   (b) one shared axis (a 100% SL next to 6 agents renders unreadable), or
   (c) multiple Y-axes (accurate but cluttered at >2 series).
The operator's "шкала вторична" + "hover gives the units" points AWAY from a strict shared axis. Pick in the design; whatever is chosen, the TOOLTIP stays the source of truth.
NOTE: these per-series colours are USER-CHOSEN and are a different concept from the RAG bands on the "now" widget (B3) — don't conflate them.
