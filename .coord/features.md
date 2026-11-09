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

### 2026-09-26T08:45:28Z · Слово оператора — InfoSlot: метку убрать, строка на всё место, сверху раздел «название» из настроек (записал coordinator-0924)
[со слов оператора: 2026-09-26] «меняю задачу по Info Slot: строка будет без отдельного блока, покрашенного синим, будет занимать
всё пространство. вместо этого мы добавляем раздел "название", как у других виджетов, сверху. его можно будет определить
в настройках виджета».
Следствия:
- метка на кромке (792aa97, 10b9497) снимается;
- отступ ленты не нужен;
- заголовок сверху — тем же способом, что у других виджетов с заголовком из настроек; поле в редакторе — по слову оператора.
Остальное из UNIT5 остаётся: красное срочное через переменные и статика с начала.

### 2026-09-26T09:43:50Z · ПОПРАВКА к записи InfoSlot (06:4xZ): настройка цвета срочного ЕСТЬ, виджет её НЕ применяет (записал coordinator-0924)
Запись «пользовательского цвета срочного нет ни в редакторе, ни в модели» — неверна. Замер искал имя css-переменной,
а не предмет. Факт [shell-0919b, пере-снято coordinator-0924 по v4]: `PriorityHigh{Background,Text}Color` и тёмные
пары есть в WidgetConfig (ScreenEditorPage :5509-5511) и в редакторе (чтение :3329-3332, запись :4529-4532).
`InfoSlotWidget.MsgStyle` (:121-131) возвращает пустой список, переменные не задаёт. Настройка сохраняется и не действует.
Смена умолчания на красное в 792aa97 остаётся верной для случая «auto».
Дефект: `PR234-V4-INFOSLOT-PRIORITY-COLOR-UNAPPLIED-01`. Единица `V4-UNIT5-PRIORITY` — сразу после единицы заголовка, отдельно.

### 2026-09-26T11:25:30Z · Слово оператора по заголовку InfoSlot, передано shell-0919b 09:49Z (записал coordinator-0924)
[со слов оператора: 2026-09-26, через shell-0919b] «оставить одну общую полоску, которая и так есть, и просто дать возможность
включать и выключать её в настройках бегущей строки». Внутреннего заголовка у InfoSlot нет.
Переключатель `HideHeader` (существующее поле) — в настройки InfoSlot. Сделано в b0497a3.

### 2026-09-26T12:45:46Z · Слово оператора — ограничить круг: выкатываем всё сделанное, Wfm — следующим заходом (записал coordinator-0924)
[со слов оператора: 2026-09-26] «ограничиваю круг. выкатываем всё сделанное, wfm — следующий заход».
Wfm не начинаем, основание shell сохранено. Выкат v4 на 234 — devops. Отложенный выкат снят этим словом.

### 2026-10-05T06:16:27Z · FEAT-REDESIGN-01 — шесть виджетов на стенде (рейс `e7eb243`), Wfm выдан shell-0919b
[coordinator-0924] Рейс доставлен 2026-10-05, приёмка по отданному HTML зелёная (см. rejects.md, та же метка времени).
Экрана оператор ещё не видел — ни один из шести виджетов не принят глазами.
Wfm: только цвет — литералы `WfmWidget.razor` :277-279 (блоб `c0f3393`) в переменные слоя с прежними значениями.
[со слов оператора 2026-09-26] «выкатываем все сделанное, wfm — следующий заход».

### 2026-10-05T06:23:21Z · FEAT-REDESIGN-01 — первый взгляд оператора на экран стенда: четыре замечания (записал coordinator-0924)
[со слов оператора 2026-10-05, с голоса] ASD «прыгает каждый раз, когда происходит обновление» · «фонты внутри таблиц не такие,
как на эталоне» · у плитки рамку-кольцо вокруг «нужно убрать … кубик должен границы свои иметь» · полоска «разной толщины
при разном цвете, и она не такая закруглённая, как на эталоне».
Четыре предмета в rejects.md (та же метка времени). Идут перед Wfm. Остальное с экрана оператор не называл — ни принятым, ни отклонённым.

### 2026-10-05T06:26:31Z · FEAT-REDESIGN-01 — пятое замечание оператора с экрана (записал coordinator-0924)
[со слов оператора 2026-10-05, с голоса] «в таблицах не подстраивается автоматически ширина колонки к данным … обрезаются номера телефонов,
обрезаются имена статусов и обрезается время. это нужно поправить». Предмет `PR234-V4-GRID-COLUMNS-TRUNCATED-01` в rejects.md.

### 2026-10-05T06:48:18Z · FEAT-REDESIGN-01 — шестое замечание оператора с экрана (записал coordinator-0924)
[со слов оператора 2026-10-05, с голоса] «легенда и подписи на виджетах распределения агентов и Day Trend очень смазаны и плохо читаются.
посмотри, почему». Предмет `PR234-CHART-TEXT-BLUR-UNDER-SCALE-01` в rejects.md; причина — масштаб слоя против растра графика.

- 2026-10-10T19:37:02Z · coordinator-0924 · FEAT-REDESIGN-01 / Wfm: цепочка 7b52de9..4634162 принята по содержанию. Поведение: пороги плиток и списка живут в конфиге виджета; без настроенных правил виджет показывает полосу сервера (ComputeRag, цель SL организации). Сохранённые в виджете пороги predictedSl НЕ следуют за последующей сменой WfmSlTargetPct — следствие решения оператора «трешхолды переносим на виджет». Удаление WfmThresholds из организаций, SLA/WrapUp — отдельно, не в этом выкате.

- 2026-10-11T12:42:22Z · coordinator-0924 · СЛОВО ОПЕРАТОРА (ASD): «суммаризирование всех известных статусов - подгон результата… в центре круга метрика. дифф между подключенными и известными статусами - Other». Центр ASD = метрика подключённых (QueueLoginDataNumLoggedUsers / поле настройки), Other = разница; логика 68de0f9 (центр = сумма сегментов) отменена.

- 2026-10-12T10:02:10Z · coordinator-0924 · СЛОВО ОПЕРАТОРА (DayTrend): «от первого ненулевого до последнего ненулевого» — окно оси по включённым метрикам, дыры внутри остаются, только вид.
- 2026-10-12T10:12:27Z · coordinator-0924 · FEAT-ASD-OTHER-COMPOSITION-01 — слово оператора: «при наведении на other должны показываться статусы в этой категории»; на развилку (а)/(б) — «б» (фактический состав с числами, новые метрики). Ведёт metrics, сначала проект. Открыт; закрытие — словом оператора.
- 2026-10-12T10:14:11Z · coordinator-0924 · FEAT-ASD-OTHER-COMPOSITION-01 — слово оператора: «откладываю подсказку по Other». Отложен → backlog BL-V4-ASD-OTHER-COMPOSITION-01. Не закрыт.
- 2026-10-13T13:00:00Z · coordinator-0924 · FEAT-WFM-QUEUES-FROM-BU-01 — слово оператора: «в определениях в модалке дается выбор очереди и бизнес юнит - очереди быть не должно, очередь или их список берется из бизнес юнит». Разбор shell, варианты для нескольких очередей — к оператору. Открыт.
- 2026-10-13T14:27:51Z · coordinator-0924 · FEAT-WFM-SERVING-GROUPS-PICKLIST-01 — слово оператора: «Выбор из списка» (serving-группы Wfm выбираются из фактических StatusGroup, ручного ввода нет; сравнение в цикле остаётся точным). backend — источник + лог; shell — UI. Рейс один с 28ce148. Открыт.
- 2026-10-14T08:36:58Z · coordinator-0924 · FEAT-WFM-ISOLATED-SCOPE-01 — слово оператора: «сейчас к бизнес юниту הובלות привязано то, что нужно - очередь הובלות и скилл הובלות. я считаю, что нужно делать изолированные вычисления - поток и звонки считать по очереди, агентов по скилу». λ/AHT — по очереди BU; N — агенты скилла BU в обслуживающих группах сейчас. Открыт.
- 2026-10-15T16:27:55Z · coordinator-0924 · FEAT-LEGACY-PORT-1015 — перенос правок legacy (Yuval, [SYNC 2026-07-15..09-15], 183 маркера) в движок/конфиг (v4 RTM/) и адаптер (ветка adapters). Этап 1 — карта переноса (backend). Открыт.
- 2026-10-15T17:15:36Z · coordinator-0924 · FEAT-LEGACY-PORT-1015 — этап 1 принят (карта .coord/measure/legacy-port-1015/STAGE1-MAP.md). Решения оператора 15.10 (backend-1015 17:09Z): live-BU 07-20 — нужен, через Shell→/LoadData; U2 backdated — переносим; отвязка — как по коду Bezeq, удаление BU — заморозка до полуночи; U5 — как у Yuval; U8+U9 — переносим; U4 формат логов — нет; секреты в папках — игнорировать. Порядок: Д1→Д2→Д3→Д4→А1→А2→А3. Д1 выдан.

## 2026-11-03T04:09:03Z coordinator-1019 · новый заход — задания оператора (слово оператора 2026-11-03 06:08 +02:00), дословно
1. FEAT-HE-DROPDOWNS-01 — «Дропдауны на иврите». Уточняется у оператора.
2. FEAT-RTL-RESIZE-01 — «Ресайзинг РТЛ». Уточняется.
3. FEAT-REPORT-EOS-AGENTS-01 — «Отчет конца шифта, выбирается только дата без периода. Самари по агентам. строчка на агента».
4. FEAT-REPORT-EOS-QUEUES-01 — «Отчет конца шифта, выбирается только дата без периода. Самари по очередям. строчка на очередь».
5. FEAT-REPORT-AGENT-PERF-01 — «Отчет, агент перформанс: опции – саммари за выбранный период – один агент – одна строчка за период, детализация по датам – один агент – количество строк по выбранному периоду. Фильтрация по имени агента».
Статус всех — OPEN; приёмка — фактами по каждому; закрытие — только словом оператора.

## 2026-11-03T04:12:23Z coordinator-1019 · FEAT-HE-DROPDOWNS-01 · уточнение оператора
Слово оператора 2026-11-03 06:12 (+02:00): «дропдауны на иврите — стрелочки справа, загораживают текст». Снимок оператора: три фильтра («כל הסטטוסים», «כל הקטגוריות», «כל הארגונים») — значок раскрытия справа накладывается на начало текста. В RTL значок должен быть слева, отступ под него — слева; область — все выпадающие списки (form-select) при dir=rtl, не один экран. Проверка — глазами на 234 в Chrome, he-IL, с отрицательной половиной в en-US (стрелка справа, как была).

## 2026-11-03T04:14:02Z coordinator-1019 · FEAT-RTL-RESIZE-01 · уточнение оператора
Слово оператора 2026-11-03 06:13 (+02:00): «при ресайзинге виджетов при раскладке RTL виджеты тянутся в обратном направлении». Редактор экрана, dir=rtl: при перетаскивании ручки размера виджет растёт/сжимается противоположно движению мыши (знак смещения по X не зеркалится для RTL). Проверка — в редакторе на 234, he-IL: тянешь ручку — край идёт за мышью; отрицательная половина — en-US без изменений; плюс сохранённая ширина/позиция после сохранения и перезагрузки совпадает с видимой.

## 2026-11-03T04:16:19Z coordinator-1019 · FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-EOS-QUEUES-01 · уточнение оператора
Слово оператора 2026-11-03 06:16 (+02:00): «выбирается дата и часы начала и конца смены». Окно отчёта = дата + час начала + час конца смены (местное время площадки, хранение — UTC после 66b302a). Открыто: смена через полночь (конец раньше начала) — уточнить; набор колонок — уточнить.

## 2026-11-03T04:18:10Z coordinator-1019 · FEAT-REPORT-EOS-*-01, FEAT-REPORT-AGENT-PERF-01 · уточнение оператора: колонки выбирает пользователь
Слово оператора 2026-11-03 06:18 (+02:00): «выбирает колонки» — колонки отчёта пользователь выбирает из каталога метрик, как в нынешних отчётах (ReportEditorPage). Фиксированного набора нет.

## 2026-11-03T04:19:00Z coordinator-1019 · FEAT-REPORT-EOS-*-01 · смена через полночь — не делаем
Слово оператора 2026-11-03 06:18 (+02:00): «через полночь пока не делаем». Конец смены позже начала в тех же сутках; ввод «конец ≤ начала» — отклоняется валидацией с понятным сообщением.

## 2026-11-03T04:20:04Z coordinator-1019 · FEAT-REPORT-AGENT-PERF-01 · фильтр — выбор нескольких агентов
Слово оператора 2026-11-03 06:19 (+02:00): «выбор нескольких». Решение координатора по неотвеченной половине (оператор может поправить): без фильтра — все агенты, каждый своими строками. Режимы: «саммари» — одна строка на агента за период; «детализация по датам» — на агента по строке на каждую дату периода. Колонки — выбор пользователя из каталога.

## 2026-11-03T04:27:37Z coordinator-1019 · FEAT-REPORT-* · решения координатора по разбору backend/metrics (оператор может поправить)
1. Свежесть: в ответе DataThroughUtc и признак Incomplete (to > водяной отметки) — оболочка показывает предупреждение «данные за конец смены ещё не собраны». Догон агрегации по запросу — не делаем сейчас.
2. AgentPerformance «по датам»: дата без данных — строка не выводится (как во всех нынешних отчётах).
3. AgentPerformance: период — целые местные сутки, как сейчас.
4. Правила границы окна (metrics): звонок — одна точка привязки для всех счётчиков (UpdateTime завершённой строки, решение оператора 26.06); время статусов агента обрезается окном; средние/доли/формулы — пересчёт из сумм окна, не усреднение готовых. Мгновенные метрики (45) в выбор колонок отчёта не предлагаются; Station/UserExtension — текущие значения, не давать.
Открыто, вопрос оператору: колонки — из каталога метрик реального времени (до 152 годных, считать по сырым строкам; агентские суммы с обрезкой окном из hist_* невозможны) или из фиксированного набора полей исторических агрегатов (~9 агентских + 6 очередных сумм и производные).

## 2026-11-03T04:31:11Z coordinator-1019 · FEAT-REPORT-* · ответ оператора: «у нас есть уже отчёты по агентам и очередям, этим занималась роль BI»
Слово оператора 2026-11-03 06:30 (+02:00). Существующие отчёты BI (v4): AgentMonthly, AgentShiftDetail, QueueInterval, QueueWaitTime (ReportWidgetType), источник — исторические агрегаты hist_*. Чтение координатора (оператор может поправить): новые три отчёта строятся в том же семействе, на тех же агрегатах; колонки — выбор из полей этих отчётов (включить выбор колонок, сейчас «stub-disabled»), а не каталог реального времени. Роль BI неактивна с 03.07 — работу ведёт backend.

## 2026-11-03T04:41:25Z coordinator-1019 · FEAT-HE-DROPDOWNS-01 и FEAT-RTL-RESIZE-01 — один предмет
shell 04:50Z: обе — «логическая разметка + физическая арифметика/позиция» под RTL (стрелка селекта: логический отступ, физическая позиция; ручки размера: логические места, физическая математика смещения). Ведутся одной заявкой на прогон и одним выкатом; страж RtlPhysicalSidesGuardTests покрывает оба.

## 2026-11-03T04:44:40Z coordinator-1019 · FEAT-REPORT-* · слово оператора: отчёты — как существующие, в виде виджетов
Слово оператора 2026-11-03 06:44 (+02:00): «отчеты должны быть как существующие, в виде виджетов». Три новых отчёта — виджеты отчётов того же вида, что AgentMonthly / AgentShiftDetail / QueueInterval / QueueWaitTime: выбираются в палитре ReportEditorPage, ставятся на экран, настраиваются конфигом виджета (часы смены, режим, агенты, колонки), отрисовываются своим компонентом рядом с существующими (Components/Reports). Отдельной страницы отчёта не делаем.

## 2026-11-03T20:20:18Z coordinator-1019 · FEAT-REPORT-* · виджет EOS-очереди в v4 (b5b0674); выбора колонок в интерфейсе ещё нет
shell b5b0674 (19 путей, родитель 04bebbd): виджет EndOfShiftQueues, единое правило колонок (серверное), палитра только готовых типов, вынос ReportFormat; сборка 739 -> 739, Architecture 51 -> 56, Unit 623 -> 638. НЕ сделано: выбор колонок пользователем (требование оператора 06:18) — AllowedColumns в Web не используется, виджет показывает набор по умолчанию; это обязательная часть, в очереди shell. Вид на he-IL — после выката.

## 2026-11-05T05:37:39Z coordinator-1104 · FEAT-REPORT-WIDGET-RENAME-IN-EDITOR-01 · заявлено оператором · возможность уже существует — ждёт подтверждения оператора
Слово оператора 2026-11-05 07:36 (+02:00): «ещё нужно добавить возможность изменять название отчёта (виджета) на экране редактора».
Факт [измерено coordinator-1104 по коду v4]: поле есть с aa544d0 (2026-06-24) и стоит на 234 (e8e67a1): редактор отчёта -> шестерёнка виджета -> окно настроек, вкладка «Общие» (_tab "general") -> поле ReportWidget_Title (en Title / ru Заголовок / he כותרת), пишется в ConfigJson.title; редактор показывает его в шапке (ReportEditorPage: DisplayName = cfg.Title, иначе имя типа), экран просмотра — через GetWidgetTitle. Не проверено на экране 234 живьём.
Открыто: достаточно ли поля в настройках, или нужно переименование прямо в шапке виджета на холсте редактора. Приёмка — живая проверка shell на 234 (задать заголовок -> виден в редакторе и на просмотре, he-IL), затем слово оператора.

## 2026-11-06T18:17:20Z coordinator-1104 · FEAT-REPORT-WIDGET-RENAME-IN-EDITOR-01 · проверено оператором на 234
Со слов оператора (передано shell-0919b 2026-11-06T18:09:09Z): «я проверил, переименование работает» — поле «כותרת» в настройках виджета. Закрытие — только явным словом оператора «закрываем».

## 2026-11-07T07:19:02Z coordinator-1104 · FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01 + FEAT-REPORT-COLUMN-PICKER-ALL-01 · в работу backend + shell · слово оператора
Слово оператора 2026-11-07 09:18 (+02:00), дословно: «берем, но не по трем отчетам, а по всем существующим табличным отчетам. так же, проверяем, что во всех отчетах есть выбор полей, если нет - выравниваем». Контекст вопроса оператора 09:14: фильтр должен быть как в сетках реального времени — воронка у колонки, по всем полям, без отдельной полосы кнопок, дублирующей колонки.
Объём: (1) воронка в шапке КАЖДОЙ колонки всех табличных виджетов отчётов — QueueInterval, QueueWaitTime, AgentMonthly, AgentShiftDetail, EndOfShiftAgents, EndOfShiftQueues, AgentPerformance (Distribution — диаграмма, не таблица; /reports-legacy — не в меню, вне объёма до слова оператора); полоса кнопок над таблицей убирается; текстовые колонки — тип совпадения + текст + галочки, числовые/время/проценты — условие (больше/меньше/между), фильтр по ИТОГОВОЙ строке, до страниц и в выгрузке; окно фильтра не обрезается низким виджетом. (2) выбор полей во всех табличных отчетах: замер coordinator-1104 на 84b7fdd/c2e71b9 — вкладка выбора полей в редакторе предлагается для всех типов (AllowedColumns), но четыре виджета (QueueInterval, QueueWaitTime, AgentMonthly, AgentShiftDetail) рисуют жёсткие колонки и выбор игнорируют — выравнивается.
Связано: PR234-V4-REPORT-FILTER-POPUP-CLIPPED-01 (решение по окну входит сюда), BL-V4-GRID-FILTER-SHARED-COMPONENT-01 (сетки реального времени — по-прежнему бэклог).
— coordinator-1104

## 2026-11-07T07:27:45Z coordinator-1104 · FEAT-REPORT-LEGACY-PAGE-REMOVE-01 · в работу shell (+ замер backend) · слово оператора
Слово оператора 2026-11-07 09:27 (+02:00): «да, убираем» на вопрос «убираем старую страницу отчётов в этой же партии?». Предмет: /reports-legacy (src/CcDashboard.Web/Components/Reports/ReportsPage.razor) и её четыре вкладки QueueIntervalReport / QueueWaitTimeReport / AgentMonthlyReport / AgentShiftDetailReport.razor; в меню ссылки нет с 3de9dc9 (2026-06-25), открывается по адресу любым вошедшим. Партия — общая с FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01.
— coordinator-1104

## 2026-11-07T08:57:53Z coordinator-1104 · FEAT-REPORT-EOS-CONFIGURABLE-01 · формулируется · слова оператора
Оператор 2026-11-07 10:46 (+02:00), дословно: «так, я достаточно кардинально меняю задание. мы убираем все отчеты по очередям, берем отчет конца смены и делаем его конфигурабильным: 1 - убираем часы начала и конца смены в конфиге 2 - добавляем на екране просмотра интервал - день/час/пол часа/15 мин 3 - возвращаем от - до на экране просмотра 4 - фильтры имплементируем на этом отчете 5 - вопрос: добавляя виджет отчета на экран, как определить дату, которая будет отображать даннэ? я попал в ситуацию, когда добавляю виджет, а он выбирает дату, в которой нет данных и конфигурировать виджет невозможно».
Оператор 10:57 (+02:00), дословно: «шагг 15 мин убираем, интервал устанавливаем на самом виджете на экране просмотра, тем же способом, как в виджете дейтренд, на уровне экрана - толко дата, часы не выбираем».
Зафиксировано: шаги день / час / полчаса (15 мин — нет); шаг выбирается на виджете на экране просмотра тем же способом, что в DayTrendWidget (окно «Widget_LocalViewSettings», кнопки шага, сохранение на пользователя и экземпляр виджета через Get/Save/DeleteUserWidgetSettings — замер coordinator-1104 по c2e71b9, DayTrendWidget.razor:146–156, 263–272, 700–857); на экране — только даты «от – до», без часов; часы смены из конфига виджета убираются; фильтры-воронки — на этом отчёте.
Открыто: какой отчёт конца смены (агенты / очереди / оба) — вопрос оператору 10:47 без ответа. По п.5 предложено (не решено): поле даты и в редакторе, по умолчанию — последний день с данными в области видимости.
Текущая партия FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: прогон довести, пакет не собирать.
— coordinator-1104

## 2026-11-07T08:59:19Z coordinator-1104 · FEAT-REPORT-EOS-CONFIGURABLE-01 · ответ оператора: сначала очереди · в работу backend + shell + замер devops
Оператор 10:58 (+02:00), дословно: «сначала по очередям, потом пойдем по агентам». Первая единица — EndOfShiftQueues: окно = даты «от – до» экрана целиком (местные сутки площадки), без часов смены; шаг день / час / полчаса — на виджете в окне его настроек на экране просмотра, как DayTrend (UserWidgetSettings на пользователя и экземпляр); воронки по всем колонкам; выгрузка = экрану (с шагом виджета). Отчёты по очередям QueueInterval, QueueWaitTime, Distribution — убираются из каталога; уже стоящие на экранах — «отчёт снят», без падения. EndOfShiftAgents — следующей единицей, сейчас не трогаем. П.5 (дата по умолчанию в редакторе) — вопрос оператору.
— coordinator-1104

## 2026-11-07T09:05:58Z coordinator-1104 · FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01 · в объём FEAT-REPORT-EOS-CONFIGURABLE-01 · слово оператора
Оператор 2026-11-07 11:05 (+02:00): «в редакторе экрана тоже есть поле даты, и по умолчанию оно встаёт на последний день, за который есть данные? - да».
Объём: в редакторе экрана — поле даты (диапазон по тем же правилам, что экран просмотра); по умолчанию — последний местный день с данными в области видимости пользователя (сервер, одним запросом; цена — PROBE.sql backend .coord/measure/lastday-1107/, замер на 234 у devops). То же правило — для первого открытия экрана просмотра, если за сегодня данных нет [предложено оператору 10:47, принято вместе].
— coordinator-1104

## 2026-11-07T10:31:55Z coordinator-1104 · FEAT-REPORT-EOS-CONFIGURABLE-01 · шаги месяц и год · слово оператора
Оператор 2026-11-07 12:31 (+02:00), дословно: «еще нужны шаги месяц и год». Шаги: день / час / полчаса / месяц / год.
— coordinator-1104

## 2026-11-07T11:25:39Z coordinator-1104 · FEAT-REPORT-EOS-CONFIGURABLE-01 · шаг по умолчанию в настройке виджета · слово оператора
Оператор 2026-11-07 13:25 (+02:00), дословно: «еще в устаноках на редакторе нужно поле интервал по умолчанию, который можно будет изменить определением на экране просмотра».
Правило: шаг виджета = личный выбор на экране просмотра (UserWidgetSettings) → иначе шаг по умолчанию из настройки виджета (редактор) → иначе День. Сброс личного выбора возвращает к шагу по умолчанию.
— coordinator-1104

## 2026-11-07T14:22:57Z coordinator-1104 · FEAT-REPORT-FILTER-MODAL-01 · в работу shell · слово оператора
Оператор 2026-11-07 16:22 (+02:00), дословно: «делаем модалку. в сетках реального времени сделаем так же, но другим заходом, запиши в беклог». Фильтр колонки во всех табличных отчётах открывается модальным окном по центру экрана, в заголовке — название колонки; окно не зависит от высоты виджета, прокрутки и шапки таблицы. Закрывает PR234-V4-REPORT-FILTER-POPUP-UNDER-HEADER-01 и PR234-V4-REPORT-FILTER-POPUP-CLIPPED-01.
— coordinator-1104

## 2026-11-07T14:25:31Z coordinator-1104 · FEAT-REPORT-QUEUE-REPORT-NAME-01 · в работу shell · слово оператора
Оператор 2026-11-07 16:25 (+02:00), дословно: «и виджет должен называться не конец смены, а Queue Report». Тип EndOfShiftQueues в палитре/каталоге и по умолчанию в заголовке — «Queue Report» (ru «Отчёт по очередям», he «דוח תורים»); описание без «окна смены». Переводы — .coord/l10n_queue_report_name_terms.md.
— coordinator-1104

## 2026-11-07T16:10:32Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · ЗАДАНИЕ СФОРМИРОВАНО, НЕ В РАБОТЕ · в работу только по слову оператора, после закрытия круга EOS-2
Оператор 2026-11-07 18:10 (+02:00), дословно: «пока идет сборка и выкат. задача на после закрытия данного круга после проверок: построить графическийвиджет на основе графического элемента дейтрнд (график), позволяющего сравнивать даные очерей по интервал отчета с интервалом, который будет задаваться в висжете на экране просмотра. возможные графики на отчете - все метрики очереди. конфигурация на просмотре будет позволять задавать шаг, интервал для сравнения (ели не указан, то только интервал отчета, сравнительнэ графики показываться не будут). Графики по интервалу отчета - сплошная лини, по интервалу сравнения - пунктирная того же цвета. В работу вводим только по моему слову, сейцхас только сформируй задание».

Задание (формулировка coordinator-1104; основа — замер кода v4 3756cce: DayTrendWidget + wwwroot/js/daytrendChart.js на Chart.js, пунктир уже есть — borderDash для агентских метрик, daytrendChart.js:220; данные — hist_queue_intervals тем же путём, что EndOfShiftQueues):
1. Новый тип отчёта-виджета (рабочее имя QueueTrend) в палитре отчётов; рисует график приёмом DayTrend (тот же JS-модуль или его общая часть, без второй копии).
2. Ось X — интервалы ОСНОВНОГО периода (даты «с–по» экрана) по шагу; линии — метрики очереди. Набор метрик — все колонки QueueSummaryRow вида Count / Percent / DurationSec (ReportColumns), выбор метрик — в настройках виджета (редактор), как DayTrend; цвета — как у DayTrend.
3. На просмотре (окно настроек виджета, через хозяина модалок отчётов): шаг (полчаса / час / день / месяц / год, по умолчанию — из редактора) и ПЕРИОД СРАВНЕНИЯ («с–по»). Выбор — личный, UserWidgetSettings на экземпляр (как шаг сейчас).
4. Нет периода сравнения — только сплошные линии основного периода. Есть — для каждой метрики вторая линия пунктиром ТОГО ЖЕ цвета; точки сравнения выравниваются по ПОРЯДКОВОМУ номеру интервала в периоде (1-й с 1-м), подпись оси — основного периода, во всплывающей подсказке — обе даты.
5. Фильтр по очередям — как в отчёте очередей (воронок нет — это график; набор очередей — в настройках), суммы по выбранным очередям; производные (%, ASA, AHT) — из сумм, не средние от средних.
6. Сервер: тот же запрос шагов, что EndOfShiftQueues (одно правило StepKey, местное время, переходы часов), второй период — вторым вызовом того же правила; выгрузка — обе серии листом таблицы.
Открытые вопросы — к оператору по одному, при вводе в работу: (а) выравнивание сравнения по порядковому номеру интервала — или по дню недели / календарной дате; (б) разные длины периодов — обрезать по короткому или показывать сколько есть; (в) одна ось Y для разных единиц (штуки, %, секунды) — или вторая ось / выбор одной единицы на график; (г) выгрузка нужна ли для графика.
— coordinator-1104

## 2026-11-07T16:12:04Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · поправка оператора к п.2
Оператор 2026-11-07 18:11 (+02:00), дословно: «Какие показывать, выбирается в редакторе, как в дейтренде - нет на экране просмотра, как в дейтренд, в редакторе указываются только по умолчанию, изменяются пользователем». П.2 читать так: набор метрик выбирает пользователь на экране просмотра (окно настроек виджета, личный выбор на экземпляр, как в DayTrend); в редакторе задаётся только набор по умолчанию; «сбросить» возвращает к набору по умолчанию. То же правило, что для шага: личный выбор → умолчание из редактора.
— coordinator-1104

## 2026-11-07T16:51:39Z coordinator-1104 · FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01 · в работу shell (+ backend выгрузка) · слово оператора
Оператор 2026-11-07 18:51 (+02:00), дословно: «в дате убрать то, что в скобках». Снимок .coord/measure/report-f7006b5-live-1107/op_20261107_1851_interval_mark.png: Queue Report, шаг «месяц», строки «10.2026 (מ-30.10)», «11.2026 (עד 06.11)». Подпись начала интервала — без пометки обрезанного края, на экране и в выгрузке (одно правило ReportIntervalLabel). Отменяет пометку из FEAT-REPORT-EOS-CONFIGURABLE-01 (решение координатора 10:38Z) — словом оператора.
— coordinator-1104

## 2026-11-07T20:20:08Z coordinator-1104 · ЗАКРЫТЫ словом оператора
Оператор 2026-11-07 22:18 (+02:00): «да» (тот же вопрос, что в rejects.md 2026-11-07T20:20:08Z). Закрыты (на 234, d2454c9): FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01, FEAT-REPORT-COLUMN-PICKER-ALL-01, FEAT-REPORT-LEGACY-PAGE-REMOVE-01, FEAT-REPORT-EOS-CONFIGURABLE-01 (часть «очереди»; агенты — следующей единицей), FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01, FEAT-REPORT-FILTER-MODAL-01, FEAT-REPORT-QUEUE-REPORT-NAME-01, FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01. Не затронут: FEAT-REPORT-QUEUE-TREND-COMPARE-01 (задание, в работу — по слову).
— coordinator-1104

## 2026-11-07T20:30:54Z coordinator-1104 · FEAT-REPORT-QUEUE-DATE-FORMAT-01 + FEAT-REPORT-QUEUE-COLUMN-SORT-01 · в работу shell (+ backend выгрузка) · слово оператора
Оператор 2026-11-07 22:29 (+02:00), дословно: «закроем еще 2 вещи по таблице очередей: 1 - дата должна быть DD\MM\YYYY HH:MI. везде и когда до агентов дойдем 2 - нет сортировки при нажатии на имя колонки».
FEAT-REPORT-QUEUE-DATE-FORMAT-01 — в Queue Report каждая дата/время пишется dd/MM/yyyy HH:mm (разделитель «/», как в DayTrend; принято координатором — обратный слеш в слове оператора прочитан как «/»): колонка интервала при любом шаге (год/месяц/день тоже — полной датой начала), штамп «данные по», колонки вида DateTime, поля даты в окне фильтра, выгрузка. Сейчас: ReportIntervalLabel.Start — yyyy / MM.yyyy / "d" CurrentCulture / yyyy-MM-dd HH:mm; ReportCellFormat DateTime — yyyy-MM-dd HH:mm; штамп EndOfShiftQueuesReportWidget:479 — yyyy-MM-dd HH:mm; ColumnFilterPopup — yyyy-MM-dd. Тот же формат — норма для отчётов по агентам, когда до них дойдём.
FEAT-REPORT-QUEUE-COLUMN-SORT-01 — щелчок по имени колонки в Queue Report сортирует строки: первый щелчок — по возрастанию, второй — по убыванию, значок направления у колонки; сортировка по значению (число, время, дата начала интервала), не по тексту; работает вместе с фильтрами; итоговая строка не сортируется. Сейчас в отчётах сортировки нет вовсе (есть только в сетках реального времени AgentGridWidget/QueueGridWidget).
Объём: только Queue Report. Общие места (ReportCellFormat, ReportIntervalLabel, ColumnFilterPopup) задевают и отчёты по агентам — до слова оператора по этому вопросу агентов не менять; если общее правило иначе не развести, — стоп и письмо координатору.
— coordinator-1104

## 2026-11-07T20:33:04Z coordinator-1104 · FEAT-REPORT-QUEUE-DATE-FORMAT-01 · уточнение оператора
Оператор 2026-11-07 22:32 (+02:00), дословно: «нет. там, где только месяц, MM/YYYY, где день - DD/MM/YYYY, где пол часа - час- DD/MM/YYYY HH:MI». «нет» — ответ на «меняем дату в отчётах по агентам сразу?»: агентов сейчас не менять, общие места развести по виджету. Формат по шагу (заменяет «полной датой при любом шаге» из записи 20:30:54Z): год — yyyy (без изменений); месяц — MM/yyyy; день — dd/MM/yyyy; час и полчаса — dd/MM/yyyy HH:mm. Значения, которые сами по себе дата+время (штамп «данные по», колонки DateTime) — dd/MM/yyyy HH:mm; поля только даты в окне фильтра — dd/MM/yyyy.
— coordinator-1104

## 2026-11-07T20:49:02Z coordinator-1104 · FEAT-REPORT-QUEUE-COLUMN-SORT-01 · выгрузка вне объёма · слово оператора
Оператор 2026-11-07 22:48 (+02:00): «нет» на вопрос «Включаем сортировку выгрузки в этот круг?». Выгрузка Queue Report остаётся в прежнем порядке; ExportReportCommand по сортировке не трогать.
— coordinator-1104

## 2026-11-08T04:55:20Z coordinator-1104 · FEAT-REPORT-QUEUE-DATE-FORMAT-01 + FEAT-REPORT-QUEUE-COLUMN-SORT-01 · ЗАКРЫТЫ словом оператора
Оператор 2026-11-08 06:55 (+02:00): «да» на вопрос «Закрываем в реестре формат даты и сортировку в Queue Report?». Коммит v4 8dfc8e6ad854 (дерево 3b476f7a = TESTED TREE devops r2), пакет 08112026.0001.zip (8873481C…) на 234, RESULT DONE 2026-11-08T04:33:54Z. Живая проверка shell-1107 04:41:12Z: месяц 11/2026 (16/16), день dd/MM/yyyy; поле фильтра dd/MM/yyyy, неверный ввод не применяется (16 -> 16); сортировка возр./убыв./исходный, с фильтром, через страницы max(стр.1) ≤ min(стр.2), агенты без сортировки. Оговорка: штамп «данные по» вживую не виден (данные полные), покрыт стражем.
— coordinator-1104

## 2026-11-08T05:55:50Z coordinator-1104 · FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 · в работу backend + shell · слово оператора
Оператор 2026-11-08 07:54 (+02:00), дословно: «да, идея та же - убираем все отчеты кроме конца смены, делаем точно такую же конфигурацию по шагам, но добавляем возможность в просмотре установить вот это. фильтры и сортировка уже есть». Снимок: поле «מצב הדוח» окна настройки AgentPerformance — «מרוכז — שורה אחת לכל נציג לתקופה» / «לפי תאריך — שורה אחת לכל נציג לכל תאריך».
Объём (по образцу FEAT-REPORT-EOS-CONFIGURABLE-01 для очередей, 8dfc8e6):
1. Отчёты по агентам AgentMonthly, AgentShiftDetail, AgentPerformance — убираются из каталога; уже стоящие на экранах — «отчёт снят», без падения (как QueueInterval/QueueWaitTime/Distribution).
2. EndOfShiftAgents: окно = даты «от – до» экрана, без часов смены; шаги год / месяц / день / час / полчаса; шаг по умолчанию — в настройке виджета (редактор), личный выбор — на экране просмотра (UserWidgetSettings), как у Queue Report.
3. Новое: режим на экране просмотра рядом с шагом — «сводный» (одна строка на агента за весь период) или «по шагу» (одна строка на агента на интервал шага). Правило выбора то же, что у шага: личный → по умолчанию из настройки виджета → иначе «сводный» [решение координатора: так отчёт конца смены по агентам выглядит сейчас]. В сводном режиме шаг не применяется.
4. Даты — норма оператора 22:32 07.11: месяц MM/yyyy, день dd/MM/yyyy, час и полчаса dd/MM/yyyy HH:mm, год yyyy; штамп «данные по» и колонки DateTime — dd/MM/yyyy HH:mm; поле даты в окне фильтра — dd/MM/yyyy.
5. Фильтры-воронки и сортировка щелчком — как у Queue Report («уже есть»: воронки есть у всех отчётов; сортировку на сервере распространить на EndOfShiftAgents тем же контрактом SortColumn/SortDescending).
6. Выгрузка = экрану (шаг и режим виджета, формат дат); порядок строк в файле прежний, без сортировки экрана (по образцу слова оператора 22:48 07.11).
Вне объёма: статус «недоступен» в отчётах по агентам (BL-V4-REPORT-AGENT-UNAVAILABLE-MISSING-01), новые метрики, сравнительный график.
— coordinator-1104

## 2026-11-08T05:57:22Z coordinator-1104 · FEAT-REPORT-QUEUE-REPORT-ICON-01 · в работу shell (в партию агентов) · слово оператора
Оператор 2026-11-08 07:56 (+02:00), дословно: «и еще заменить иконку, она символизировала конец смены, а теперь ето отчет по очередям». Снимок: каталог, раздел QUEUES, «דוח תורים» с иконкой двери. Сейчас: ReportWidgetPalette.Icon EndOfShiftQueues => "bi-door-closed". Замена — "bi-telephone-inbound" [решение координатора: входящие звонки в очередь; bi-people занят агентами, bi-people-fill — сетками очередей в редакторе]. Везде, где иконка типа берётся из Palette (каталог, редактор, рамка виджета).
— coordinator-1104

## 2026-11-08T06:04:30Z coordinator-1104 · FEAT-REPORT-QUEUE-REPORT-ICON-01 · уточнение оператора
Оператор 2026-11-08 08:04 (+02:00), дословно: «нет, не телефон, что-то означающее очередь обслуживания». Замена: EndOfShiftQueues => "bi-ticket-perforated" (талон электронной очереди) [решение координатора; есть в подключённом bootstrap/bootstrap-icons.min.css — .bi-ticket-perforated::before найдено]. Отменяет bi-telephone-inbound из записи 05:57:22Z.
— coordinator-1104

## 2026-11-08T06:05:04Z coordinator-1104 · FEAT-REPORT-AGENT-REPORT-NAME-01 · в объём FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 · слово оператора
Оператор 2026-11-08 08:04 (+02:00): «да» на вопрос «Отчёт по агентам после переделки переименовываем в Agent Report, по образцу Queue Report?». EndOfShiftAgents: имя "Agent Report" везде, где Queue Report получил своё (ReportTypeNames.English, каталог, редактор, заголовок по умолчанию, выгрузка), переводы — по образцу l10n_queue_report_name_terms.md (иврит: «דוח נציגים» по образцу «דוח תורים», русский: «Отчёт по агентам») — таблица .coord/l10n_agent_report_name_terms.md. Описание в каталоге — под новый смысл (за период или по шагу), не «shift window». Имя типа в базе (EndOfShiftAgents) не меняется.
— coordinator-1104

## 2026-11-08T08:40:03Z coordinator-1104 · FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 + FEAT-REPORT-AGENT-REPORT-NAME-01 + FEAT-REPORT-QUEUE-REPORT-ICON-01 · ЗАКРЫТЫ словом оператора
Оператор 2026-11-08 10:39 (+02:00): «да» на вопрос «Закрываем в реестре Agent Report, снятие трёх старых отчётов по агентам, иконку-талон и имя?». Коммит v4 ba7297303efd (дерево d0f36f1b = TESTED TREE), пакет 08112026.0949.zip (51A903B6…) на 234, RESULT DONE (отчёт .measurements/234_20261108_101032_install-ba72973.txt; письмо devops 08:32:00Z). Живая проверка shell-1107 08:38:11Z + 08:38:58Z: палитра 2 пункта (талон, Agent Report), снятых 0, двери 0; снятые виджеты — «отчёт снят» (со слов оператора, убраны им); сводный/по шагу, шаг выключен в сводном, даты по норме; умолчания в редакторе; сортировка сервером через страницы; поле фильтра dd/MM/yyyy; часов смены 0.
Оговорка: одна личная настройка UserWidgetSettings виджета Agent Report на «test» сброшена shell при проверке (значения = умолчанию, вид не изменился, владелец неизвестен).
Отдельно поднять: выбор, совпадающий с умолчанием, не закрепляется (Queue и Agent Report) — замечание shell, решение оператора.
— coordinator-1104

## 2026-11-08T14:41:52Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · В РАБОТУ backend + shell · слово оператора
Оператор 2026-11-08 16:41 (+02:00): «начинаем круг новых виджетов» — после моего вопроса «начинаем со сравнительного графика очередей, задание на который уже лежит?». Задание — записи 2026-11-07T16:10:32Z и 16:12:04Z выше (метрики — личный выбор на просмотре, умолчание в редакторе). База v4 c3d7636 (на 234 и на origin).
Нормы, принятые с тех пор и действующие здесь: шаги год/месяц/день/час/полчаса, правило «личный → умолчание виджета → день»; формат дат по шагу (норма 22:32 07.11); период «с–по» экрана; последний день с данными; имя типа в каталоге и иконка — предложить; Agent-аналог — не в этом круге.
Открытые вопросы (а)–(г) — к оператору по одному; первый задан (2026-11-08T14:41:52Z): выравнивание сравнения. До ответа — контракт полей и всё, что от (а)–(г) не зависит.
— coordinator-1104

## 2026-11-08T16:08:25Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · ответ оператора: период сравнения и оси
Оператор 2026-11-08 18:08 (+02:00), дословно: «сравнения интервалов - выбирается дата начала интервала сравнения, а дата завершения берется по количеству дней, заданных на экран. нижняя ось - даты по отчету, ось сверху - даты интервала сравнения». Читается так: на просмотре задаётся только дата НАЧАЛА периода сравнения; его длина = числу дней периода «с–по» экрана (конец вычисляется); выравнивание — по порядковому номеру интервала (1-й с 1-м). Ось X снизу — подписи интервалов основного периода, ось X сверху — подписи соответствующих интервалов периода сравнения (тот же формат дат по шагу). Закрывает открытые вопросы (а) и (б): длины равны по построению. Остаются (в) единицы на оси Y и (г) выгрузка.
— coordinator-1104

## 2026-11-08T16:20:04Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · макет и две правки оператора
Макет shell: .coord/measure/queue-trend-1108/mockup.html (11703 B, sha256 3014da335efb07b7… — снято мной, = поправке shell 16:19:08Z) + chart.umd.min.js (копия wwwroot, sha256 48444a82d4ed…). Три кадра: со сравнением, окно настроек, без сравнения.
Оператор 2026-11-08 18:17 (+02:00), дословно (через shell 16:18:26Z): «в легенде показывать только цвет, нет смысла дублировать описание. при наводе мышки на график показывать дату и значение». Правило в контракт виджета: легенда — одна запись на метрику (цвет и имя), без записей сравнения; подсказка — только точка под мышью: её дата (отчёта или сравнения) и значение.
Открыто: направление оси X в RTL (вопрос 18:14), (в) единицы оси Y, (г) выгрузка.
— coordinator-1104

## 2026-11-08T16:21:03Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · направление оси X
Оператор 2026-11-08 18:20 (+02:00): «оставляем» — на вопрос «ось дат слева направо, как DayTrend, или справа налево под иврит?». Ось X — слева направо (первый интервал слева), как DayTrend; reverse не включать.
— coordinator-1104

## 2026-11-08T16:21:44Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · ось Y — ответ оператора (в)
Оператор 2026-11-08 18:21 (+02:00): «так оставляем» — на вопрос об оси Y. Две оси, как DayTrend: слева — штуки и проценты, справа — время (mm:ss / hh:mm:ss). Закрывает открытый вопрос (в).
— coordinator-1104

## 2026-11-08T16:22:21Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 · выгрузка — ответ оператора (г)
Оператор 2026-11-08 18:22 (+02:00): «пока не выгружаем, запиши в беклог» — на вопрос о выгрузке данных графика в Excel. QueueTrend в выгрузку не идёт; в списке «не выгружено» — с понятной причиной (тип не выгружается), файл строится всегда. Закрывает открытый вопрос (г); открытых вопросов по заданию нет.
— coordinator-1104

## 2026-11-08T18:44:06Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-CHART-TYPE-01 + PR234-V4-QUEUE-TREND-INCOMPLETE-BANNER-TALL-01 · в работу shell · слово оператора
Оператор 2026-11-08 20:43 (+02:00), дословно: «да и еще: добавить виды графика как в дейтренд, в редакторе как дифолт, на экране просмотра как выбор». Снимок: блок DayTrend «סוג תרשים (CHART TYPE)» — четыре кнопки «קו», «עמודות», «שטח», «מדרגות».
1. «да» — на вопрос «полосу „последний интервал ещё идёт“ ужимаем в одну тонкую строку?»: в Queue Trend баннер незавершённого периода — одна тонкая строка, графику остаётся высота (замер shell: при 400×300 баннер ~треть, холст 374×180).
2. Виды графика Queue Trend — те же четыре, что DayTrend, тем же кодом общего модуля (без второй копии): умолчание — в редакторе (вкладка «כללי»), выбор — на просмотре (окно настроек, личный UserWidgetSettings), правило «личный → умолчание → קו».
Открыто (предложить shell, решу или спрошу): как рисуется сравнение в «עמודות»/«שטח»/«מדרגות» — пунктир имеет смысл для линий; для столбцов — парные столбцы, сравнение светлее/штрихом того же цвета.
— coordinator-1104

## 2026-11-08T18:49:36Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-CHART-TYPE-01 · изменение оператора
Оператор 2026-11-08 20:49 (+02:00), дословно: «меняю зачу по видам: если включается сравнение - только линии. если сравнения нет - можно выбрать вид». Правило: при заданной дате сравнения график всегда «קו» (выбор вида на просмотре недоступен/выключен с подписью, личный и умолчание игнорируются, но не стираются); без сравнения — вид по правилу «личный → умолчание → קו». Вопрос «как рисовать сравнение в 4 видах» снят.
— coordinator-1104

## 2026-11-08T19:52:55Z coordinator-1104 · FEAT-REPORT-QUEUE-TREND-COMPARE-01 + FEAT-REPORT-QUEUE-TREND-CHART-TYPE-01 · ЗАКРЫТЫ словом оператора
Оператор 2026-11-08 21:52 (+02:00): «да» на вопрос «Закрываем в реестре сравнительный график, виды графика и два дефекта этого круга (календарь и формат строки периода), с именем „Queue Trend“ и иконкой графика со стрелкой как окончательными?». v4 12faa24 (круг 1, дерево 38e4b228) и edb7e6a (круг 2, дерево 7ae56ce9) на 234: .measurements/234_20261108_200420_install-12faa24.txt и 234_20261108_213205_install-edb7e6a.txt, оба DONE. Живые проверки shell-1107 18:18:40Z, 19:44:28Z, 19:51:48Z: каталог, окно редактора, умолчания, легенда, подсказка, DayTrend не изменён; строка периода во всех 4 виджетах 01/11/2026 – 08/11/2026; тонкая строка 16 px; пикер type=date; сравнение — 3 сплошные + 3 пунктир того же цвета, x2 с датами сравнения, подсказка на пунктире — дата сравнения; виды bar/area/stepped; со сравнением — line и выбор выключен; выбор сохраняется. Имя «Queue Trend»/«מגמת תורים», иконка bi-graph-up-arrow — окончательные. Выгрузка — BL-V4-REPORT-QUEUE-TREND-EXPORT-01.
— coordinator-1104

## 2026-11-08T19:55:28Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-TREND-01 (в работу backend + shell) + FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 (следующим, не в работе) · слово оператора
Оператор 2026-11-08 21:54 (+02:00), дословно: «далее делаем такой же график, но по процетам вемени агентов в различных статус группах от времени логина, затем график типа Agent State Distribution на тех же данных».
Единица 1 — FEAT-REPORT-AGENT-STATE-TREND-01: отчёт-виджет-график, устроенный как Queue Trend (12faa24/edb7e6a, тем же общим модулем и теми же правилами): период «с–по» экрана, шаг, дата начала сравнения (длина = период, по индексу, нижняя ось — отчёт, верхняя — сравнение), пунктир того же цвета, со сравнением — только линии, без — вид по выбору; легенда — цвет и имя; подсказка — дата и значение; метрики — личный выбор на просмотре, умолчание в редакторе; выгрузки нет («not-exportable»).
Линии — доля времени в статус-группе от времени логина, %: Sum<Группа>Ms / SumLoggedInMs по выбранным агентам (суммы по агентам, потом доля — не среднее от долей). Данные — hist_agent_intervals (Domain HistAgentInterval): SumAvailableMs, SumOnphoneMs, SumHoldMs, SumPaperworkMs, SumBreakMs, SumTrainingMs, SumUnavailableMs, SumLoggedInMs. Ось Y одна — проценты.
Область: бизнес-юниты и агенты — как у Agent Report (область пользователя, NarrowToPicked, GetScopedAgentsQuery).
Открыто к оператору по одному: (а) набор групп — все семь или как в ASD реального времени (там AVAILABLE/BREAK/ONPHONE/PAPERWORK/TRAINING); куда Hold и Unavailable. До ответа backend меряет, входит ли Hold в Onphone и сходится ли сумма групп с LoggedIn (замер на 234 — по моему слову через devops, только чтение).
Единица 2 — FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01: круговая диаграмма в стиле AgentStateDistributionWidget на тех же данных за период отчёта — после закрытия единицы 1; задание сформирую тогда.
— coordinator-1104

## 2026-11-08T19:57:39Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-TREND-01 · ответ оператора (а): группы
Оператор 2026-11-08 21:57 (+02:00), дословно: «все семь плюс Other, как в ASD». Линии: Available, Onphone, Hold, Paperwork, Break, Training, Unavailable + Other. Other = LoggedIn − Σ семи групп (правило ASD: «Other = разница», без подгона), доля от LoggedIn; отрицательная разница (группы пересекаются, например Hold внутри Onphone) — показывать не нулём, а назвать: замер backend решает, корректно ли вычитать Hold. Сумма восьми линий = 100 % только если группы не пересекаются — это проверяемое свойство, страж.
— coordinator-1104

## 2026-11-08T20:00:01Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-TREND-01 · группы — уточнение оператора
Оператор 2026-11-08 21:58–21:59 (+02:00), дословно: снимок легенды ASD (AVAILABLE, BREAK, ONPHONE, PAPERWORK, TRAINING) + «плюс Other», затем «Hold входит в Onphone, Unavailable в Paperwork». Заменяет «все семь плюс Other» (19:57:39Z). Линий шесть, как в ASD: Available; Break; Onphone (с Hold); Paperwork (с Unavailable); Training; Other = LoggedIn − Σ пяти групп. Как складывать — решает замер backend по агрегатору: если SumOnphoneMs уже включает удержание — Hold не прибавлять; если нет — Onphone = SumOnphoneMs + SumHoldMs. То же для Unavailable в Paperwork. Цели: группы не пересекаются, Σ шести = 100 % LoggedIn (страж), Other ≥ 0 (отрицательное — дефект, не ноль).
— coordinator-1104

## 2026-11-09T04:35:58Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-TREND-01 · ЗАКРЫТ словом оператора
Оператор 2026-11-09 06:35 (+02:00): «да» на вопрос «Закрываем в реестре Agent State Trend (имя и иконка человека за столом окончательные) и дефект с разрывами и провалом кривой?». v4 27e4161 (дерево 298075bf) и 6b76608 (дерево b203a3a7) на 234: .measurements/234_20261108_230430_install-27e4161.txt и 234_20261109_002150_install-6b76608.txt, оба DONE. Живые проверки shell-1107 2026-11-08T21:14:27Z и 2026-11-09T04:34:38Z: 6 групп с цветами ASD, Σ = 100 % в каждом дне с логином; нули вместо разрывов (07/11 = 0 на всех сериях); монотонная кривая — выход за точки и ниже 0 = 0/0 на 01/11–08/11 и на периоде снимка оператора 14/09–20/09. Имя «Agent State Trend»/«מגמת מצבי נציגים», иконка bi-person-workspace — окончательные. DayTrend вживую — после первых звонков (путь без опций проверен на стенде). Открыты и идут в следующую партию: PR234-V4-REPORT-UNCONFIGURED-TEXT-SAYS-QUEUE-01, PR234-V4-REPORT-AGENT-PICKER-TAB-01.
— coordinator-1104

## 2026-11-09T04:41:18Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 · В РАБОТУ backend + shell · слово оператора
Оператор 2026-11-09 06:41 (+02:00), дословно: «добавляем возможность задать интервал в самом виджете в просмотре. если задан - идет по нему, если не задан - по интервалу отчета» — на вопрос «один круг за период отчёта, как ASD, или и сравнение вторым кругом?». Читается: один круг без сравнения; на просмотре в окне настроек виджета — свой период «с–по» (даты, без часов, пикер); задан — данные за него; пуст — период страницы отчёта. Личный выбор (UserWidgetSettings), «איפוס» возвращает к периоду отчёта.
Виджет — круговая диаграмма в стиле AgentStateDistributionWidget реального времени: шесть групп Agent State Trend (Available, Onphone с Hold, Paperwork с Unavailable, Break, Training, Other = LoggedIn − Σ пяти), доли от времени логина за период, цвета ASD, легенда как у ASD (группа, %, и время — предложить), центр — предложить (например суммарное время логина).
Данные и область — те же функции, что Agent State Trend (hist_agent_intervals, BU + агенты, NarrowToPicked), без второй копии правила долей; последний день с данными — агенты; выгрузки нет (not-exportable).
В ту же партию: PR234-V4-REPORT-UNCONFIGURED-TEXT-SAYS-QUEUE-01 (текст ненастроенного виджета по виду отчёта) и PR234-V4-REPORT-AGENT-PICKER-TAB-01 (выбор агентов — на «טווח» у всех агентских отчётов).
Имя и иконку — предложить, подтвержу у оператора при закрытии.
— coordinator-1104

## 2026-11-09T06:01:01Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 · центр круга — слово оператора
Оператор 2026-11-09 07:54 (+02:00), дословно (через shell 05:57:57Z): «в центре круга - количество уникальных агентов, которые подключались в период отчета». Центр = AgentCount (различные AgentExternalId с SumLoggedInMs > 0 за запрошенный период — свой виджета или страницы), подпись Widget_Agents («סוכנים»). Предложение «время логина в центре» снято. Обе половины на диске, общая сборка shell зелёная (Unit 867, Architecture 174, WARN NEW 0).
— coordinator-1104

## 2026-11-09T08:23:54Z coordinator-1104 · FEAT-REPORT-INCOMPLETE-NOTE-THIN-ALL-01 · в работу shell (в текущую партию) · слово оператора
Оператор 2026-11-09 10:23 (+02:00), дословно: «и еше - предупрездение о неполных данных во всех вджетах сделать узкой полосой без фона маленькими буквами под указанем интервала как в Queue Trend». Все отчёты-виджеты (Queue Report, Agent Report, Agent State Distribution; тренды уже так): пометка о неполных данных — одна узкая строка без фона, мелким шрифтом, сразу под строкой периода, полный текст — в подсказке; одно правило/компонент на все виджеты, без копий.
— coordinator-1104

## 2026-11-09T12:08:27Z coordinator-1104 · FEAT-REPORT-TREND-TRIM-ZERO-EDGES-01 · в работу shell (в текущую партию) · слово оператора
Оператор 2026-11-09 14:07 (+02:00), дословно: «дополнительно - графики должны начинаться с ненулевых значений и ими же заканчиваться. иначе масса места занимается нулями». Снимок .coord/measure/agent-state-dist-1109/op_20261109_1407_trend_zero_edges.png: 04/10/2026, шаг полчаса/час — Queue Trend и Agent State Trend: данные только ~13:00–17:30 и ~14:00–20:00, остальная ось — нули. Правило (оба тренда): ось X начинается с первого интервала, где хоть одна показанная серия ненулевая, и кончается последним таким; нули ВНУТРИ диапазона остаются (слово 23:21 08.11). Со сравнением — обрезка одними индексами для основной и сравнительной серий (по индексу, как выравнивание), граница — по объединению обеих. Все нули — пустое состояние «нет данных», а не пустая ось.
— coordinator-1104

## 2026-11-09T20:56:36Z coordinator-1104 · FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 + FEAT-REPORT-INCOMPLETE-NOTE-THIN-ALL-01 + FEAT-REPORT-TREND-TRIM-ZERO-EDGES-01 · ЗАКРЫТЫ словом оператора
Оператор 2026-11-09 22:56 (+02:00): «да» на вопрос о закрытии пяти пунктов, проверенных на 234. На 234: c959380 (.measurements/234_20261109_094529_install-c959380.txt), 67f3678 = 9164877 + 67f3678 (234_20261109_182858_install-67f3678.txt), 53783f0 (234_20261109_224210_install-53783f0.txt) — все DONE. Живые проверки shell-1107 08:11:37Z, 08:15:54Z, 19:25:51Z, 20:52:36Z; журнал devops r3 20:13:29Z: после выката 216 запусков RunReportWidgetQuery, «A second operation» 0, ERR 0 (до: 3 случая за 12 мин). Имя «Agent State Distribution»/«התפלגות מצבי נציגים», иконка bi-pie-chart-fill — окончательные. Вживую не проверено: обрезка сравнения одними индексами — покрыто стражем и контролем T1 EXACT.
— coordinator-1104
