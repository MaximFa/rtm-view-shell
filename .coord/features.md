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


## FEATURE/EPIC | AI-чат виджет по данным КЦ (реалтайм + история) через внешний LLM-API | declared 2026-08-29 by operator

**Статус: 🔵 DECLARED. Не в работе. Ждёт операторского решения по ИБ-гейту (вопрос задан 2026-08-29).**

**Заявление (оператор, дословно по смыслу):** виджет чатового типа, в котором можно задавать вопросы по
историческим данным и данным реального времени; анализ и ответы выдаются через обращение во внешний API
(Claude, OpenAI и т.д.). Примеры вопросов оператора:
- сколько агентов я могу сейчас перевести на другую очередь без падения SLA;
- сколько операторов мне нужно сейчас для SLA;
- скольких я могу перевести на другие активности.

**ЭТО НЕ НОВЫЙ ПУНКТ — это Concept 1 из `[FUTURE-FEATURE] AI-виджет RTM`, заведённого 2026-06-08.**
Тогда же оператором был зафиксирован ПОРЯДОК: **Concept 2 первым** (кнопка на Agent Grid: анализ текущего
расклада -> рекомендация старшему смены; bounded, pull, чистый data-контракт, демоабельно), **Concept 1
вторым** (чат по КЦ-данным — нужен tool-use слой доступа к БД, выше риск галлюцинаций и стоимость).
Нынешнее заявление идёт сразу в Concept 1. **Порядок меняется решением оператора, а не моим выводом** —
пункт зафиксирован как заявленный, переприоритизация ждёт его слова.

### Существенное, чего не было 2026-06-08
Все три примера оператора — это **Erlang-вопросы, а не вопросы к языковой модели.** С 2026-07-21 у нас есть
`ErlangCalculatorService` (`4e21796`, чистая математика Erlang B/C + юнит-тесты против сверенного якоря) и
WFM Phase 1 с per-BU агрегатами (`d1982de`), C2-гейт пройден на живых данных 2026-07-22.
=> Проектный инвариант, который я закладываю в любой вариант архитектуры: **считает НАША математика,
модель только разбирает намерение и излагает результат.** Модель не выполняет арифметику, не оценивает
SLA и не выводит числа сама. Это снимает основную долю риска галлюцинаций (E-002/E-005) и основную долю
стоимости токенов, и превращает «AI-виджет» в «естественно-языковой фронт к уже проверенному WFM-ядру».

### Гейты (из записи 2026-06-08, в силе; статус на 2026-08-29)
1. **ИБ/приватность (§8-14) — ГЛАВНЫЙ ГЕЙТ, ОТКРЫТ.** Что именно из данных КЦ покидает периметр,
   в каком виде, с какой анонимизацией, при какой tenant data-protection. Решение операторское и
   юридическое, не архитектурное. Вопрос задан оператору 2026-08-29, ответа нет.
2. **КОНФЛИКТ СО СТОЯЧИМ ОГРАНИЧЕНИЕМ, ОТКРЫТ.** `avoid-paid-components` (operator 2026-06-21): весь стек
   free/open/built-in, платных компонентов избегаем. Внешний LLM-API — платный и с ПОВТОРЯЮЩЕЙСЯ платой за
   токен, то есть первый в проекте компонент с операционной стоимостью на запрос. Ограничение снимается
   только словом оператора, точечно и с записью.
3. **Курация контекста:** инсайт не лучше поданного контекста; домен идёт в промпт, а не в модель.
4. **Заземление:** каждая рекомендация цитирует фактические цифры; РЕШАЕТ человек, не AI.
5. **«Что такое хорошая рекомендация» = дыра #1** (need-fitness): валидатор — старший смены, нужна метрика
   исхода. По-прежнему не закрыта.
6. **Архитектурная граница (§18):** первый виджет с ЛОГИКОЙ, пересекает границу shell-vs-widget-library.
   Отдельно: по ТЗ оболочки компоненты визуализации в неё не входят — куда селится виджет с логикой,
   вопрос архитектурный и не решён.

### Что НЕ делается до операторского OK
Не проектируется, не диспатчится, не пишется код, промпты не авторятся. Read-only разбор разрешён.

**Факты приёмки:** <нет, не начато> · **Пуш поставки:** <нет>


## РЕШЕНИЕ ОПЕРАТОРА | AI-виджет: порядок и разделение ответственности | 2026-08-29

Относится к пункту `FEATURE/EPIC | AI-чат виджет ...` выше и к `[FUTURE-FEATURE] AI-виджет RTM`
(backlog, 2026-06-08). Первоисточник обсуждения — **ветка `lab`, `Method-Discussion-Log.md` §10–11**
(блоб `839bfac`, `lab` = `c43347c`); в шине от него оставались только две однострочные ссылки.

**1. ПОРЯДОК ПОДТВЕРЖДЁН: КНОПКА ПЕРВОЙ.** Concept 2 (кнопка на Agent Grid: анализ текущего расклада ->
рекомендация старшему смены) идёт первым. Concept 1 (чат по данным КЦ, заявлен 2026-08-29) — вторым.
Это подтверждение исходного решения от 2026-06-08, не новое: заявление на чат было отклонено от
первоочередности САМИМ оператором после разбора, а не моим выводом.
Основания кнопки (записаны 2026-06-08, в силе): ограничена одним экраном/моментом/вопросом · **pull**
(жмут — считает, ничего не крутится фоном) · чистый data-контракт (набор полей известен заранее, а не
выбирается моделью на лету) · демоабельна.

**2. РАЗДЕЛЕНИЕ ОТВЕТСТВЕННОСТИ — ПРОДУКТОВЫЙ ИНВАРИАНТ (оператор, дословно):**
> «кнопка на Agent Grid закрывает нашей математикой, а модели остаётся только изложить результат»

Раскрытие, обязательное для ТЗ и для §4 любого промпта по этой фиче:
- **СЧИТАЕТ НАША МАТЕМАТИКА.** `ErlangCalculatorService` (`4e21796`, чистая Erlang B/C + юнит-тесты против
  сверенного якоря) + WFM Phase 1 / per-BU агрегаты (`d1982de`, C2-гейт на живых данных 2026-07-22).
- **МОДЕЛЬ ТОЛЬКО ИЗЛАГАЕТ.** Она не выполняет арифметику, не оценивает SLA, не выводит и не округляет
  числа, не изобретает вариантов сверх посчитанных. Любое число в ответе обязано существовать во входном
  data-контракте ДО обращения к API. Число, которого нет во входе, — дефект, а не «инсайт».
- **Следствие для верификации:** правильность ответа проверяется против нашего же расчёта, а не
  экспертной оценкой текста. Это делает фичу тестируемой юнит-тестом, чего у «AI даёт инсайты» не бывает.
- **Следствие для риска и стоимости:** снимается основная доля галлюцинаций (E-002/E-005) и основная доля
  токенов — за периметр уходит короткий посчитанный результат, а не сырьё.

**3. Что это НЕ отменяет.** Открытыми остаются: ИБ-гейт §8-14 (что именно и в каком виде покидает
периметр — теперь предмет уже, но решение всё равно операторское); конфликт с `avoid-paid-components`
(внешний LLM-API платный, плата повторяющаяся — снимается только словом оператора); дыра #1 «что такое
хорошая рекомендация» (валидатор = живой старший смены, нужна метрика исхода); архитектурная граница
§18 (первый виджет с ЛОГИКОЙ). Процесс из §11 Discussion-Log — в силе, включая **обязательный ack
Security** и верификацию исходом, а не рендером. Сборка — целиком в A (поправка оператора 2026-06-08).

**Статус: 🔵 DECLARED, порядок и инвариант зафиксированы. В работу НЕ передано.**
Приоритет на сейчас — не эта фича: оператор объявил 2026-08-29, что следующим идёт разбор списка багов.

**Факты приёмки:** <нет> · **Пуш поставки:** <нет>

## FEAT-REDESIGN-01 · РЕДИЗАЙН ЭКРАНОВ ПО ЭТАЛОНУ · заведён coordinator-0919b 2026-09-24

### Область, заданная оператором
[со слов оператора 2026-09-24] «редизайн самого экрана, не только виджетов»
[со слов оператора 2026-09-24] «все упоминания LIVE нужно убрать»
[со слов оператора 2026-09-24] телефоны в эталоне — «выдуманные»

### Эталон
`docs/new-design/` — 3 HTML (светлые, самодостаточные, сеть не тянут) + 2 PNG (тёмные).
НЕ в ветке, НЕ на сервере, НЕ в .gitignore. Кладётся в ветку отдельным решением.

### Что измерено по эталону
```
[измерено coordinator-0919b 2026-09-24, ОБЛАСТЬ: docs/new-design, ЕДИНИЦА указана у каждого числа]
экраны: 3 · dir=rtl lang=he во всех трёх
иврит (символы): 568 · 1390 · 1301   -> каждая надпись станет ключом словаря
латиница внутри RTL: SLA, AHT, Wrap, Erlang C, WFM — смешанное направление в одной строке
CSS-переменные эталона: 19 коротких (--ok/--warn/--bad/--ink/--muted/--brand)
тёмная тема в HTML: prefers-color-scheme 0 · data-theme 0 · слово dark 0 — ТОЛЬКО в PNG
скрипты: 1 блок на файл, 7-19 КБ; Math.random 7/17/11; setInterval 1; keyframes 2/6/6
```

### Покрытие нашими виджетами — 1:1, новых заводить НЕ НАДО
| панель эталона | наш виджет |
|---|---|
| מצבי נציגים (кольцо состояний) | AgentStateDistributionWidget |
| מצב נציגים בזמן אמת (таблица) | AgentGridWidget |
| ספי התראה — SLA | KpiWidget |
| WFM — תחזית 30 דקות | WfmWidget |
| תמונת תורים | QueueGridWidget · QueueSummaryWidget |
| מגמה יומית | DayTrendWidget |
| бегущая строка снизу | InfoSlotWidget |
| полоса из 8 показателей сверху | KpiWidget · DataSlotWidget |
Всего виджетов в продукте: 9 + каталог. Непокрытых панелей эталона: 0.

### ⛔ LIVE: три РАЗНЫЕ вещи носят это слово, и снести надо одну
```
[ОБЛАСТЬ: src без obj и bin, ЕДИНИЦА: вхождения]
широкая игла "live" где угодно      75   <- ЛОЖНОЕ основание для правки
из них deliverystatus                12   — вообще другое слово
из них unionalive / gridalive         6   — внутренние имена
отдельное слово LIVE                 43
```
Разложение по смыслу:
1. **НАДПИСЬ — сносится.** `Widget_Live` (4 вызова), `Widget_LiveDataUpdating` (2 вызова),
   в эталоне `livebadge` ×2 на файл.
2. **`aria-live="polite"` — НЕ ТРОГАТЬ, 6 мест** (AppToast, AgentGrid ×2, AgentStateDistribution,
   QueueGrid ×2). Это атрибут доступности, а не надпись: снос выключает объявление изменений
   для незрячих. Правка «убрать все упоминания LIVE» широкой иглой убьёт их все шесть.
3. **Внутренние имена — не трогать:** класс `.live-dot`, комментарии, `UnionAlive`, `GridAlive`.

Сирота найдена попутно: `Screens_LiveIndicator` — 0 вызовов, в бэклог.

### Открытый вопрос к оператору (несёт координатор)
Индикатор соединения `.live-dot` — зелёная пульсирующая точка при связи, красная при обрыве.
Это НЕ надпись, а состояние связи. Уходит ли он вместе со словом LIVE — отдельное решение.


### 2026-09-24 · ПЕРВЫЙ ЭКРАН ВЫБРАН + найдена развилка крупнее цветов
[со слов оператора 2026-09-24] первый экран — операционный валлборд; ветка `v4`,
каталог `D:\Claude\Projects\RTM-design`, эталон и скилл в ветке (`74c35a8`), сверены по блобам.

**Развилка, найденная при разборе скелета экрана:**
```
[измерено coordinator-0919b 2026-09-24, ОБЛАСТЬ: docs/new-design/..._ops.html + skill assets/shell.html]
сетки эталона: repeat(8,1fr) · 216px 1fr 302px · 1fr 690px · 1fr 1fr
то есть колонки заданы ПИКСЕЛЯМИ и рукой — экран скомпонован дизайнером
продукт: ScreenEditorPage.razor = 5808 строк — экран СОБИРАЕТ ПОЛЬЗОВАТЕЛЬ из виджетов
```
Эталон — это **готовый экран**, продукт — **конструктор экранов**. Два разных устройства.
Отсюда два несовместимых пути, и выбор не дизайнерский, а архитектурный:
- **A. Переодеть виджеты.** Виджеты получают новый вид, компоновку по-прежнему делает пользователь
  в редакторе. Эталон становится образцом стиля, но точная картинка эталона не воспроизводится:
  пиксельные колонки редактор не умеет.
- **B. Готовые экраны.** Валлборд поставляется как собранный шаблон, пользователь его выбирает,
  а не складывает. Картинка эталона воспроизводится точно; редактор к этому экрану не применяется.

Пока оператор не назвал путь, единицы не выдаются: цвета и типографика нужны обоим, но всё, что
касается сетки и компоновки, у A и B противоположно.

### 2026-09-24T16:17:22Z · Слово оператора — стоп снят на ОДНУ единицу исправления (записал coordinator-0924)
[со слов оператора: 2026-09-24] «нет, сначала убедиться, что мы строим не картинку по эталону, а соответствуем механике
продукта и определениям, которые делает пользователь — никаких "наших" цветов пилюль, всё в соответствии с определениями
установок виджетов». На вопрос о снятии стопа ради одной исправляющей единицы: «снимаем и исправляем».
- Единица: `V4-FIX-USERSET` (shell), предмет `PR234-V4-SKIN-OVERRIDES-USER-01` в `.coord/rejects.md`.
- `UNIT2-A-2` и `UNIT2-B` этим словом НЕ открыты — остаются под стопом, не двигаются и не отзываются.
- Выкат на 234 отложен тем же словом («нет, сначала убедиться…»).

### 2026-09-24T17:04:11Z · Слово оператора — цвет подписей шапки по умолчанию (записал coordinator-0924)
Вопрос: когда пользователь не задал цвет шрифта, подписи шапки таблицы — серые как в эталоне (`--wb-muted` #7a869a, контраст на белом 3.68:1)
или тёмные (~16:1)? [со слов оператора: 2026-09-24] «как в эталоне». Остаётся как в `b0fcf4b`; заданный пользователем цвет шрифта применяется всегда.

### 2026-09-25T03:55:39Z · Слово оператора — редизайн ПРОДОЛЖАЕТСЯ, это основная задача; «стоп» не подтверждён (записал coordinator-0924)
[со слов оператора: 2026-09-25] на вопрос «продолжаем редизайн экранов по эталону?» — «конечно продолжаем! это основная задача!!!».
До этого — «не понял, на каком стопе?». Запись «СТОП по решению оператора 2026-09-24» в передаче дел coordinator-0919b
не несёт ни цитаты, ни времени, и оператор её не узнаёт. Считаю её ошибкой записи. `UNIT2-A-2` и `UNIT2-B` открыты.
Путь A/B (переодеть виджеты или готовые экраны): читаю слово 24.09 «соответствуем механике продукта и определениям,
которые делает пользователь» как путь A — виджеты получают вид эталона, компоновку делает пользователь в редакторе,
настройки виджета пользователя сильнее слоя редизайна. Это толкование координатора, объявлено оператору.
Первая единица после снятия — надпись LIVE. Замер по v4 (249b203), ОБЛАСТЬ src, ЕДИНИЦА вызовы:
- видимая `Widget_Live` — 2: AgentStateDistribution :64 (только при связи; при обрыве `Widget_Disconnected`), Wfm :135;
- `Widget_LiveDataUpdating` — 2, только `aria-label` (AgentGrid :183, QueueGrid :174), на экране не видна;
- `aria-live` — 6, не трогать.
Попутно: в Wfm точка `.live-dot` зашита как `connected` без учёта состояния связи, то есть зелёная всегда.
Судьба точки `.live-dot` — вопрос оператору.

### 2026-09-25T03:57:11Z · Слово оператора — точка связи уходит вместе со словом Live (записал coordinator-0924)
[со слов оператора: 2026-09-25] «точку связи убираем вместе со словом Live».
Для `V4-REDESIGN-LIVE`: убираются видимая `Widget_Live` и `.live-dot` в подвалах AgentStateDistribution и Wfm.
Текст `Widget_Disconnected` при обрыве — не надпись LIVE, остаётся. `aria-live` 6 и aria-label `Widget_LiveDataUpdating` — не трогаются.
Дефект «точка в Wfm всегда зелёная» уходит вместе с точкой, отдельной единицы не нужно.

### 2026-09-25T19:19:22Z · Слова оператора по `UNIT2-B` (DataSlot), переданы shell-0919b 2026-09-25, записал coordinator-0924
[со слов оператора: 2026-09-25, через shell-0919b] «полоска слева красится в цвет порога, установленного для фонта».
[со слов оператора: 2026-09-25, через shell-0919b] «сегодня расположение всех трёх визуальных компонентов — название, значение,
стрелка/таргет — определяется одним параметром: лево-право-центр. Нужно изменить так, чтобы у каждого из трёх было своё».
[со слов оператора: 2026-09-25, через shell-0919b] про мини-график: «плитка показывает одну метрику… график — это другой виджет,
до которого мы ещё доберёмся».
Следствия для единицы:
- заливка — от порога фона, полоса — от порога шрифта;
- три выравнивания — три поля и три селектора в редакторе; пустое новое поле читается как старое `DataSlotAlign`;
- график в плитке не делаем.

### 2026-09-25T20:04:03Z · Слово оператора — дизайн меняем, структуру и архитектуру не меняем (записал coordinator-0924)
[со слов оператора: 2026-09-25] «а проверь как сейчас? моя директива была однозначной — меняем дизайн, не меняем структуру и архитектуру».
Проверено [coordinator-0924, ОБЛАСТЬ: DataSlotWidget.razor на v3, 0a1ca48b, cbebcec, 1d8e42a]: на v3 и до 1d8e42a дельта красная,
когда значение хуже цели, и зелёная иначе (`GetDeltaStyle` :518-527, флаг `_isWorseThanTarget`). В 1d8e42a это поведение снято.
Решение: вернуть поведение дельты как на v3. Единица `V4-UNIT2-B-FIX`, shell.
Мой промах: я одобрил пункт «дельта перестаёт краситься зашитыми цветами» как дизайн, а это изменение поведения.
После вопроса оператора я ещё и принёс варианты с новыми настройками, то есть с изменением структуры.
Правило для приёмки впредь: всё, что меняет поведение виджета (что и когда он показывает), сверяется с v3 и в редизайн не входит.
Исключение — прямое слово оператора, как три выравнивания.

### 2026-09-25T20:06:09Z · Слово оператора — ничего, кроме визуала; «как у нас» проверяет исполнитель, а не спрашивает оператора (записал coordinator-0924)
[со слов оператора: 2026-09-25] «ещё раз — ничего не меняем кроме визуала. если кто-то не помнит как у нас — проверяет и делает анализ.
я не должен быть бутылочным горлом».
Порядок для редизайна:
1. Эталон переносит вид: цвет, шрифт, отступы, рамки, радиусы, расположение внутри виджета.
2. Поведение (что, когда и при каком условии виджет показывает), настройки, модель, редактор и архитектура остаются как на v3.
3. Вопрос «как у нас сейчас» решается замером по v3, а не вопросом оператору.
4. Оператору несут только то, что замером не решается и меняет продукт.

[со слов оператора: 2026-09-25T20:07:53Z] «если есть вопросы по функционалу после анализа кода — ко мне, я отвечу. но не зацикливать продвижение».
Порядок: сначала анализ кода v3, потом вопрос оператору с выводом анализа. Пока ждём ответа, работа идёт дальше по другим частям, а не стоит. (записал coordinator-0924)

### 2026-09-26T05:50:41Z · Слово оператора — следующая часть редизайна: AgentStateDistribution (записал coordinator-0924)
[со слов оператора: 2026-09-26] «следующий — ASD. сделать как на эталоне: числовые значения, размещение легенды и т.д.».
Эталон: панель «מצבי נציגים» (кольцо состояний). Поведение, настройки и источник цветов состояний — как на v3.

### 2026-09-26T06:10:25Z · ASD: общее число — в центр кольца (решение координатора по слову оператора о размещении)
Для `doughnut` общее число стоит в центре, подвал `N Agents` у этого типа не печатается: значение переезжает, а не снимается.
Для pie/bar/horizbar подвал остаётся как на v3. Основание: [со слов оператора 2026-09-26] «как на эталоне: числовые значения,
размещение легенды и т.д.». Вид и размещение — в области редизайна, вопрос оператору не нужен.
