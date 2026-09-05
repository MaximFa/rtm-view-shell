# .coord/rejects.md — Reject Register (COORDINATOR-OWNED)

> **КОНСТИТУЦИЯ (operator 2026-07-03):** реестр ведётся В ЭТОМ ДОКУМЕНТЕ, не по памяти. Каждый реджект несёт:
> дату-время заявления · подтверждающие факты (скриншоты/пробы/визуальная проверка — выбор координатора) ·
> номер пуша подтверждённого закрытия. Парный реестр функционала: `.coord/features.md`.
> **Standing rule (operator directive 2026-06-26):** every DECLARED reject is logged here the moment it is
> declared and stays **OPEN** until the operator EXPLICITLY **CONFIRMS the fix** or **DECLARES cancellation**.
> A reject is NEVER closed on coordinator inference, a commit, or object-store alone. This register is the
> coordinator's responsibility (role-coordinator §A). Surfaced every dispatch/status turn.

**Status legend — only 🟢 CONFIRMED and ⚪ CANCELLED close a reject:**
- 🔴 OPEN — declared, not fixed
- 🟡 FIXED-PUSHED — fix committed+pushed, **awaiting operator confirmation**
- 🟢 CONFIRMED — operator confirmed the fix (CLOSED)
- ⚪ CANCELLED — operator declared cancellation (CLOSED)

---

## Batch: Reports v1 — prod-mirror (234 data), pushed origin/v3 e08ee69 (2026-06-26)

| ID | Reject | Owner | Fix commit | Status | Operator sign-off |
|----|--------|-------|-----------|--------|-------------------|
| R1 | DateTime Kind=Unspecified → viewer error | bi | 6319f86 | 🟡 FIXED-PUSHED | data rendered live (Test66); explicit confirm pending |
| R2 | "A command is already in progress" (parallel widgets, shared DbContext) | bi | 6477675 | 🟡 FIXED-PUSHED | 4 widgets rendered live (coord Chrome); explicit confirm pending |
| R3 | no vertical scroll inside card | shell | 510fb80 | 🟢 CONFIRMED | operator "фикс shell подтверждаю" |
| R4 | pagination (prev/next + p/N) | shell | 55879dd/510fb80 | 🟢 CONFIRMED | operator (table-chrome confirm) |
| R5 | column headers not visible | shell | 510fb80 | 🟢 CONFIRMED | operator "фикс shell подтверждаю" |
| R6 | "Showing X of Y" → footer | shell | 510fb80 | 🟢 CONFIRMED | operator (table-chrome confirm) |
| R8 | sticky column headers on scroll | shell | 510fb80 | 🟢 CONFIRMED | operator "фикс shell подтверждаю" |
| R9 | rows-per-page → footer, arbitrary 1..1000 (view-mode) | bi+shell | 3118a6a + a96c4de | 🟡 FIXED-PUSHED | live confirm of arbitrary value pending |
| R7 | Export → .xlsx (whole report, sync) | bi+shell | 152bed7 + 6718f75 | 🔴 OPEN | **RUNTIME ERROR on click** — bi owns post-push fix |

## Batch: Test suite

| ID | Reject | Owner | Fix commit | Status | Operator sign-off |
|----|--------|-------|-----------|--------|-------------------|
| TEST-SUITE-RED | **CcDashboard.Tests.Unit does NOT COMPILE** — 62 errors, ALL in Reports/HistoricalReports tests (prod drift: R2 ctor / R9 ValidPageSizes / AllRows param). Suite RED since the bi/backend Reports work landed → unit gate down for EVERYONE; all Reports work shipped untested | bi/backend | 7085ee6 | 🟢 VERIFIED | tests restored; INDEPENDENT /ops/test = **258/258 failed=0** (devops, not CC-self-report). Prevention C: CI 166a5b3 + Soma e6a6675 + norm b9fa318 |

## Batch: Prod 234 — RELEASE (dashboards) version

| ID | Reject | Owner | Fix commit | Status | Operator sign-off |
|----|--------|-------|-----------|--------|-------------------|
| PR234-1a | config saves **null** — ROOT: ParseWidgetConfig(:5247) silent-catch → empty overwrite of un-deserializable old ConfigJson (schema b58e2c2). NOT backend | shell | probe c23ec1f (RETAINED) | 🟡 OPEN — STRATEGY | operator: diagnose on 234 (data-dependent; prod configs live there). Converge-deploy v3 to 234 → observe via Chrome + operator backend logs → probe captures config-loss → fix → THEN remove probe. Probe stays IN the 234 build |
| PR234-1b | Thresholds tab gone in DataSlot — ROOT: tab gate :275 excludes DataSlot; introduced **924e444** (CC-007) | shell | 9045398 | 🟢 CONFIRMED | coord live: Thresholds tab present in DataSlot config |
| PR234-2 | **Editor widget palette COLLAPSED to ~1px** — `.editor-palette` renders (display:flex,visible) but zero-width → can't drag/add widgets (editor unusable). Toggle=btn title="Widgets" (bi-layout-sidebar-inset). ALSO: DataSlot possibly missing from palette list (saw only Agent Grid/Day Trend/Queue Grid) | shell | f0be9d6 | 🟢 CONFIRMED | coord live: palette opens 300px + all 6 widgets incl DataSlot listed + draggable (?v=30). **BLOCKER** ROOT CONFIRMED (coord live+fetch): STALE app.css?v=29 cache — served CSS HAS `.editor-palette.open{width:300px}` but browser runs cached v=29 without it (open class present, width stays 1px). FIX = bump App.razor app.css?v=29→30. Fixes other stale-CSS regressions too | | Edit↔View scale → NOW A FEATURE: **scale-mode TOGGLE in View topbar next to Dark/Light** (A scale-to-fit / B 1:1). Operator-decided | PR234-1c | scale toggle (df95ff3) **BROKEN**: clicking it throws unhandled exception → **Blazor circuit TERMINATED** → Dark/Light + all interactivity die. Console: 'circuit will be terminated' + 'No interop methods registered for renderer 1' (viewerScale JS interop) | shell | dee401e | 🟢 CONFIRMED | coord live (ЧП p.4): scale toggle NO circuit-crash (console clean), Dark/Light works before+after scale (.dark-mode applies), fit↔1:1 fires, widget-resize.js?v=1; build 0 + unit 258/258. Caveat: A/B scale VISUAL needs board>viewport (mechanism+no-crash confirmed) |

**PR234 strategy (operator 2026-06-26):** FIX-FORWARD / CONVERGE on v3 — NO rollback, NO hotfix-fork. Deployed 234=b58e2c2 (ancestor of v3); bugs live in v3 too (no fix commit in the 136 since). GARNET validated (accepted 2026-07-01); CONSOLIDATE now RUNNING: merge v2-backend 7 commits (INC-001d Garnet + curator/skill docs) into v3 → single superset line; then fix PR234-1a/b/c on v3 → QA functional gate → unified build to 234.

---

*Last updated: 2026-07-01T14:55:46Z by coordinator. Add every new declared reject here immediately; move to 🟢/⚪ ONLY on operator word.*


### GARNET-FLAP (INC-001d) — 🔴 OPEN — logged 2026-07-02T20:28:48Z
**Batch:** Garnet validation (Memurai replacement). **Reporter:** QA test-5-0607 (20:24/20:30).
**Symptom:** Garnet backplane flapped /health/ready 200→503→200→503, now STABLY 503 Unhealthy. Cookie-auth pages serve, but readiness (Redis/Garnet) red; SecurityStamp/session backplane-dependent → a drop logs users out.
**Release relevance:** Garnet is the Redis replacement being validated IN THIS BUNDLE (INC-001d, Memurai Dev-edition 10-day auto-shutdown was INC-001 root). Its FLAPPING is itself a release-blocking signal, not just test-env noise.
**Blocks:** QA UI regression (held at 503 — no degraded-env run, load-bearing gate). Push quorum cannot complete.
**Owner:** devops — bring Garnet to STABLE /health/ready=200 + ROOT-CAUSE the flap (NSSM service crash/restart? --auth? resource? conn-string? Windows service recovery cycling?).
**Closes when:** Garnet stable-200 sustained + root cause identified + (if a Garnet/config defect) fixed → QA resumes → consolidated GREEN.

> 2026-07-02T20:35:17Z update: ROOT = Garnet hand-launched as foreground PS process (fragile). FIX = install as LOCAL Windows service via prod NSSM tooling (Install-RTMView.ps1 path) → local mirrors prod. devops tasked. Closes on sustained /health=200 + service Running(Automatic)+recovery.

> 2026-07-02T20:39:24Z CORRECTION (truth-duty): the 'ROOT = hand-launched PS' line is a HYPOTHESIS, NOT verified. VERIFIED FACT = /health + /health/ready = 503 (coordinator live-checked via Chrome) + widgets 'Reconnection failed'. Real root cause is STILL OPEN — devops to find it, do NOT assume the PS-launch. Separately: env is being rebuilt to prod topology (services via prod tooling) regardless of the flap's cause.

> 2026-07-02T22:05:59Z ROOT-CAUSE FOUND (STEP6): GARNET-FLAP was NOT foreground-fragility — it's a BAD-ARGS bug in the Garnet service registration. Garnet 1.1.10 rejects `--recover` without a value (needs `--recover true`) AND `--checkpoint-freq` is an UNKNOWN option → GarnetServer.exe exits on every start → NSSM shows Paused/flap. Confirmed working args (manual run, 'Ready to accept connections'): `--bind 127.0.0.1 --port 6379 --checkpointdir C:\Garnet\data --recover true`. FIX: correct both Garnet arg lines in Install-RTMView.ps1 (GarnetNoAuth + prod auth paths) + Update-RTMView.ps1. CRITICAL for 234 (same bug ships). Vindicates 'root OPEN, don't assume PS-launch'.

> 2026-07-02T22:18:50Z ROOT (4th install bug): Install-RTMView.ps1 does NOT inject the DB conn-string into the deployed Shell's PRODUCTION appsettings.json. -DBAppPassword is used ONLY in the DB-restore block (L359) which -SkipDB skips → deployed appsettings.json keeps `Password=REPLACE_ME` → the Shell service (runs Production) gets 28P01 password authentication failed. Local DB password is CORRECT = value in src/CcDashboard.Web/appsettings.Development.json (dev Shell connects fine). FIX (local): patch C:\RTMView\Shell\appsettings.json REPLACE_ME→real pw + restart. FIX (source, CRITICAL 234): install MUST write the ConnectionStrings:Default (with -DBAppPassword) into the deployed Production config (or set env var ConnectionStrings__Default) — a fresh 234 install fails identically. ~3h lost on this rake.

> 2026-07-02T22:42:22Z GARNET-FLAP INC-001d = 🟢 LOCALLY RESOLVED + VALIDATED: after fixing Garnet args, all 3 services auto-started clean on a full reboot; coordinator live-verified /health + /health/ready = 200 Healthy. Prod-parity env GREEN. (Register stays OPEN until the devops SOURCE fixes land in the canonical 234 package — local used staging patches.) QA unblocked for full regression.

> 2026-07-02T23:07:18Z 5th deploy gap (operator-caught): Shell has NO Kestrel/HTTPS/cert config anywhere (appsettings empty of Kestrel; Program.cs only UseHttpsRedirection). --urls CLI has no slot for a cert → Shell can't serve HTTPS → violates §24 DEPLOY-07 on 234 (Kestrel services, no IIS front). RTM does it right (Kestrel:Endpoints:Https:Certificate + password injected, Program.cs:59). FIX (operator directive 'сейчас'): move port+domain+cert into Shell appsettings Kestrel mirroring RTM + install injects. Bundled item 6 for canonical 234 pkg.

> 2026-07-02T23:15:49Z GRABLI (config file location, hours lost): this project has NO `appsettings.Production.json` — deployed config lives in `appsettings.json`. Service runs Production env but reads base appsettings.json (no Production file). Writing to appsettings.Production.json = no-op (app never reads it). ALL install config injection (conn-string, Kestrel/HTTPS, port/domain/cert) targets `C:\RTMView\Shell\appsettings.json` ONLY. Do NOT create a Production variant.




### Batch: 234 post-converge (declared by operator 2026-07-03, v3 build on 234)

| ID | Reject | Owner | Fix commit | Status | Operator sign-off |
|----|--------|-------|-----------|--------|-------------------|
| REP-MENU-PG | **Reports отсутствует на уровне определения PG**: ключа `menu.reports` НЕТ в кодовой базе (verified: grep=0 в src) — нет строки в PG-редакторе (таб Menu), нет в сидах menu_permissions, NavMenu `/reports` без PG-menu гейта → Reports невозможно ВЫДАТЬ группе; для PG-юзеров пункт скрыт, для остальных — вне permission-модели (CODE-03 двухуровневость не выполняется для Reports) | shell+bi | — | 🔴 OPEN | declared 2026-07-03 (уточнение smазанной REPORTS-PG-GAPS bullet 1 до корня) |
| REP-DATA-RANGE | **Отчёт: июньские даты пусты — root = пробел агрегации (НЕ баг фильтра)**. Фильтр корректен (from=From.Date, toExclusive=To+1день, To включительно). hist_queue_intervals имел только 02-04/07 т.к. HistoricalAggregationService делал только forward (~с 02/07); историческое июньское сырьё (RTSData_Interaction с 02/06) не бэкфиллилось. Скриншот оператора был стартовый (03/07 доагрегировался позже). ФИКС: one-time backfill (Historical:BackfillOnStartup, env-var, без правки appsettings) отработал 2026-07-04 → hist теперь 02/06-04/07 (30 дней), флаг снят. Deploy-V3 backfill-учёт → devops. | backend/ops | one-time backfill (код не менялся) | 🟡 FIXED — backfill выполнен, hist покрыл 26/06-03/07; **ждёт re-run Test1 + слова оператора** | declared 2026-07-03T13:41Z; root+fix coord 2026-07-04 |
| EDIT-500 | **Экран «12» (ca5c23ac) не работает — view И edit. КОРЕНЬ ПОДТВЕРЖДЁН логом 234:** `System.InvalidOperationException: A second operation was started on this context instance ... concurrently using the same DbContext` при `GetInfoSlotWidgetDataQuery` → unhandled в Blazor Renderer → 500. Несколько InfoSlot-виджетов экрана рендерятся параллельно на одном circuit и бьют запрос по SHARED request-scoped IAppDbContext (сам хендлер уже изолирован через IAppDbContextFactory→fresh ctx; гонка в MediatR-behaviors на scoped-контексте). Класс = R2 (concurrent shared DbContext); ШИРЕ экрана 12 — любой экран с параллельными виджет-запросами (12 стабильно ловит гонку; на view = интермиттент). Точный behaviors-виновник → backend-трасса. 234 log C:\Logs\RTMViewShell\log-20260703.txt 16:48-16:58 [ERR] | shell+bi | b03b870 — DEPLOYED на 234 (Update-RTMView, config preserved, drift reconcile'нут GATE CLEAN 2026-07-04) | 🟢 CONFIRMED — **оператор закрыл 2026-07-04**; view+edit «12» без 500. Задеплоен на 234 + **запушен origin/v3 (26d6d9e, барьер QA+Sec+TW GREEN 2026-07-04T13:59Z)** | operator «EDIT-500 закрывай» 2026-07-04 | declared 2026-07-03 (edit+view operator-confirmed); ROOT CONFIRMED coord 2026-07-03 via 234 Serilog (InvalidOperationException concurrent DbContext, GetInfoSlotWidgetDataQuery) |

### ASD-NORENDER — 🔴 OPEN — declared 2026-07-04
**Widget «Agent State Distribution» рендерит пусто («Live / 0 agents», без диаграммы)** на экране «12» (ca5c23ac), 234. coord-разбор (Chrome + серверный лог): НЕ config-0 skip, НЕ JS-краш (консоль чиста). Виджет ПОДПИСАЛСЯ на GridId 33, но `loaded 0 cells for grid 33` → **грид 33 имеет 0 ячеек** в RTSGrid_Cell → пустое распределение. Ячейки ASD создаются из маппинга agent-state→metric (config «By State»). Гипотеза: (a) маппинг не задан/не сохранён у этого инстанса виджета, либо (b) cells-creation не отработал при сохранении конфига. Owner: shell (widget) + возм. RTSGrid-wiring. declared оператором 2026-07-04 · факт: coord Chrome (виджет пуст) + Serilog 234 (subscribe GridId33 / loaded 0 cells). **РАЗГРАНИЧИТЕЛЬ (coord DB-проба 234, ConfigJson виджета ffaaab90):** КОД-БАГ, не setup. distributionMode=group, groupGridId=33, маппинг ЗАДАН (groupColumnMetricIds: BREAK/ONPHONE/TRAINING/AVAILABLE/PAPERWORK→метрики), НО RTS-обвязка ПУСТА (groupRtsColumnIds={}, groupRtsDataRowId=null, groupRtsDataCellIds={}) → RTSGrid_Row/Cell grid33=0/0. Путь сохранения ASD group-конфига НЕ создал ячейки грида (QueueGrid/DataSlot — создают). Owner shell(widget). 🔴 OPEN, локализовано. **ПОЧИНЕНО (A) 2026-07-04 (coord Chrome live):** data-fix (drop stale groupGridId/stateGridId 33) → re-save в редакторе (создал гриды 65/66 + 10 ячеек, метрики UsersInStatusGroupCount) → Restart RTMService (RTM перечитал+зарегистрировал грид §36) → ASD рисует распределение по группам (AVAILABLE/BREAK/ONPHONE/PAPERWORK/TRAINING бары). Durable: (B) 9648c09 (wire GroupRts*+BU-валидация, деплой барьером) + missing-grid guard (shell авторит). Минор: лейбл «0 agents» при данных — косметика. 🟡 FIXED — ждёт слова оператора. Урок: пере-создание грида виджета требует Restart RTMService.

### WIDGET-STICK — 🔴 OPEN — declared 2026-07-04
**Виджеты «прилипают» при клике** — в редакторе экрана клик по виджету запускает перетаскивание, виджет тянется за курсором без возможности «отпустить» (drop не срабатывает). Owner: shell/widget (drag-drop, widget-resize.js / ScreenEditorPage). declared оператором 2026-07-04 · факт: coord репродюсит на 234 через Chrome. **КОРЕНЬ (coord, object-store):** move стартует через Blazor async interop — `@onmousedown=StartMove` (ScreenEditorPage:220) → C# StartMove (3163) → `await JS.InvokeVoidAsync(widgetResize.startMove)` (3165). На Blazor Server round-trip латентен → native mouseup срабатывает РАНЬШЕ startMove → onMouseUp выходит (activeWidget null, L571) → потом startMove ставит mode=move → виджет прилипает (mouseup прошёл). ФИКС: startMove из реал-DOM mousedown-листенера (синхронно, как marquee), не через Blazor interop. Owner shell. 🔴 OPEN, локализовано. **ФИКС В РАБОТЕ:** 8b285eb (убрал Blazor-триггеры+C#, ?v=2) НО НЕПОЛНЫЙ — widget-resize.js Part-A пропущена → move/resize МЁРТВЫ (shell поймал `..`-verify). Completion adbf5d7 (onMouseDown sync-start): build 0 + unit 258/258 ✓. Пара 8b285eb+adbf5d7. 🟢 **LIVE-VERIFIED на 234 (2026-07-06)**: оператор ручным drag подтвердил no-stick («больше не прилипает»), coordinator ЧП-p.4 подтвердил release + click-select. Closure-push: **origin/v3 = adbf5d7 (PUSHED 2026-07-06)** + deploy 06072026.1147 на 234 LIVE-verified. Ждёт слова оператора на CLOSED.

### REPORTS-PG-GAPS — 🟠 KNOWN-OPEN (documented, ships with this push — operator-accepted 2026-07-02T23:47:43Z)
- Reports MENU not rendered for PG-limited (non-Superadmin) users — permissions/menu gap. + other PG gaps in Reports.
- BU∩PG intersection runtime filtering NOT verified (PG-04 enforcement path) — deferred, needs PG-limited user.
- Agent Grid lifecycle not re-run on prod-parity env (passed in a prior session).
- Export .xlsx runtime error (post-push).
- PR234-1a config→null (data-dependent; probe c23ec1f retained).
Operator decision 2026-07-02: document as known-open, DO NOT block the push; address in a follow-up.


---

### ASD-BAR-BLUR  🔴 OPEN (declared 2026-07-06)
**Facts:** screen «12» edit, 234 (platform.insightense.com), coordinator ЧП-p.4 + оператор наблюдение 2026-07-06. Виджет «Agent State Distribution» рисует бары (BREAK/ONPHONE/PAPERWORK и т.д.), НО края баров **размыты по периметру** («ощущение плохого зрения»), в отличие от бейджей соседних виджетов, у которых границы чёткие. Рендерит корректно данные — дефект чисто визуальный (blur/anti-alias/box-shadow/sub-pixel/transform в render-пути AgentStateDistributionWidget.razor или его chart-CSS).
**НЕ регрессия этого барьера:** 9648c09 (ASD-NORENDER-B) = save-path wiring, не render; размытие в отдельном render-пути, вероятно pre-existing. Барьер adbf5d7 закрытию не мешает.
**ROOT (замерено на 234 через JS, 2026-07-06):** canvas bitmap 327×209 отображается в 364×232 (×1.11 апскейл) при DPR=0.9; в agentStateDistributionChart.js НЕ задан devicePixelRatio → Chart.js рисует bitmap = CSS×0.9 < display → мыло. Тот же дефект в daytrendChart.js + reportDistributionChart.js.
**FIX (dispatched → shell):** tools/cc_prompt_shell_asd_bar_blur.md — `devicePixelRatio: Math.max(2, window.devicePixelRatio||1)` во всех 3 Chart.js виджетах + ?v=2. Fill-opacity `clr+'40'` (дизайн) не трогаем.
**Owner:** shell. **Статус:** 🟢 **LIVE-VERIFIED на 234 (2026-07-10, deploy 10072026.1309=12480b2)**: DPR supersampling жив — DayTrend canvas ratio bitmap/display ×1.999 CRISP (было бы ×0.9 blur без фикса @DPR0.9). ASD идентичный код (пуст сейчас из-за 0 live-агентов). Commits 7a8a4a8(blur)+21ecb84(guard)+12480b2(test), unit 260/260. Closure-push: **origin/v3 = 12480b2 (PUSHED 2026-07-10)** + deploy 10072026.1309 на 234 LIVE-verified (×1.999). Ждёт слова оператора на CLOSED.


## 2026-07-13T05:36Z | §A#4 SEAL (coordinator personal visual, Chrome) — BU Queues picker FIXED
Original operator issue: "в определении Business Units нет списка Queues" (BU Edit → Queues picker empty: Available "All items selected", Selected "None selected").
VISUAL CONFIRM @ nayax.insightense.com:8444/admin/configuration/business-units → Edit(Callbacks):
- Available: queues LIST rendered (DE-Accounting, DE-EV, DE-Retail, DE-Support, Everyone, Global-Tigapo, Internal Calls, IT-Support, Nobody, … scrollable). 
- Selected(1): "Callbacks" resolves by name (was "None selected"). No Blazor unhandled-error banner.
Root fixed: NGC_Queues was empty (live adapter path never wrote it) → cf18c8b getOrCreateQueue on live workgroup-add → NGC_Queues=30 (WHERE TenantId=019f58ea) after RTMService bounce re-feed. B(1+2) chain: Defect F (Shell crash) cleared, G (find-by-Name slug), H (per-tenant username index) live & verified.
STATUS: FIXED-PENDING-OPERATOR-CONFIRM (constitution — closes only on operator word).
OPEN: Defect I (QueueGrid RTS-column save 23505 PK_RTSGrid_Column, RtsRepository.InsertQueueGridColumnAsync — non-idempotent, surfaces during QueueGrid config) — widget/backend track, NOT deploy. Backlog: Update-RTMView drift-gate path bug (Compare-ToBaseline path resolution).


## 2026-07-13T05:39Z | REJECT CLOSED (operator CONFIRM) — BU Queues picker empty
Operator confirmed the §A#4 seal (2026-07-13T05:39Z). BU Edit → Queues picker lists queues (Available 30 + Selected resolves). Root fix = cf18c8b NGC_Queues live-populate + B(1+2) chain (Defect F/G/H) deployed & visually verified on 140. STATUS: CONFIRMED-CLOSED. (Product Release ID / push = pending — v3 commits cf18c8b/a261840/f486e4c deployed+sanity-verified on 140, UNPUSHED per IRON RULE; push = separate operator decision + quorum barrier.)


## 2026-07-13T06:20Z | §A#4 SEAL (coordinator visual) — Defect I FULLY RESOLVED (QueueGrid save + zeros)
Defect I (QueueGrid RTS-column save 23505 PK_RTSGrid_Column): root=IDENTITY-seq lag (COPY-into-GENERATED-ALWAYS, no setval). Fix = staging/defect_i_setval_140.sql (12 setvals, operator ran on 140 as postgres).
VISUAL CONFIRM @ screens/019f59ea-9d34-7715-b00f-4f519e07364c/edit: QueueGrid saves (no 23505) AND renders zeros — DE-Accounting + US-Support: Waiting/Abandoned=0, Max Wait=00:00, "Live". (Blank-cells sub-symptom resolved after RTM restart registered the newly-created grid cells; my "restart no help" was premature.)
STATUS: FIXED-PENDING-OPERATOR-CONFIRM.
PENDING: STEP 2 (dba) baseline setval in db/data/03_rtsgrid.sql + NGC data + Provision/Restore = PERMANENT save-fix for fresh installs (140 already patched one-time).


## 2026-07-14T13:06Z | §A#4 SEAL (coordinator visual, 140) — Shell batch db5af40+baf8968 GREEN
Verified on 140 (Chrome, post-redeploy baf8968):
- (a) TABLE tune: Metrics/202 pagination fully visible (pb_bottom 834<=vh855), .table-responsive max-height 535px (calc 100vh-320px), internal scroll + sticky thead. ✓
- (b) FUNNEL top-align: funnel_top_in_th 33->12 (flex align-items:flex-start; funnels inline with header line 1). ✓
- (c) SEARCH+FILTERS: BusinessUnits search "DE" narrowed 30->4 (client-side LINQ), "All Site" filter + Tenant selector present; feature live on BU/SG/Sites/InfoSlots. ✓
All operator UI asks (4-edit batch + tune + funnel + search/filters feature) DELIVERED + visually verified on 140. FIXED-PENDING-OPERATOR-CONFIRM (constitution).


## 2026-07-14T14:01Z | INCIDENT (adapter 6ebd39f warm-swap FAILED, rolled back) — reject on auto-reconnect
Adapter redeploy 6ebd39f on 140 (operator window): after binary swap, the NEW adapter did NOT reconnect to EITHER pipe (legacy rtmpipe + our rtmpipe_v3) with the RTM servers running (warm swap). Both feeds down (agents gone). ROLLBACK (rollback_adapter_140.md: old adapter from backup twilio_20260714_1630 + services restarted) -> legacy + our feeds RESTORED, all 3 services Running. Crisis over.
Root AMBIGUOUS (recovery restarted ALL services -> binary-vs-procedure confounded). OPERATOR DIRECTIVE (hard): legacy RTM is NEVER restarted by our procedure (live prod, not ours). Corrected acceptance: adapter must SELF-reconnect to a RUNNING/never-restarted legacy pipe-server (at most bounce OUR RTMService). 6ebd39f failed that = the real defect. WIRE 14/14 (format) did NOT catch the live connect regression.
6ebd39f = DO NOT REDEPLOY until backend fixes + a LIVE WARM-SWAP CONNECT test passes. STATUS: OPEN (auto-reconnect not delivered).
LESSON: adapter deploy needs a live warm-swap connect-lifecycle test, not only the format WIRE round-trip.


## REJECT | US Queue Grid — empty cells (no data, not even 0) | declared 2026-07-16T05:35Z by operator
STATUS: OPEN (awaiting operator CONFIRM on fix+push).
SYMPTOM (coordinator authed-visual, nayax US General Manager /screens/019f624d...): US Queue Grid renders 15 rows (US - Canada OEM/Canteen/Carwash/Compliance/EV/Finance/Onboarding/Retail/Sales/Support/Tigapo/VIP/YA 24-7/Yellow Account/US All) but ALL cells EMPTY — no numbers, not even 0. DE Queue Grid renders the same columns WITH 0s (cells registered+delivering). Legacy US HAS data. So US queue-grid CELL VALUES never populate while DE's do.
CONFIRMING FACTS: page-text + screenshot ss_5991tzr3r (US rows have NO trailing values; DE earlier '0 0 0 00:00 ...').
LIKELY LAYER (§36 QueueGrid data flow): US grid cells / US queue→BU classifications not registered in RTM engine (US union 32 was built LATE via re-LoadData after config; LoadData startup-only). Trace = backend.
FIX push #: <pending>.


## REJECT UPDATE | US Queue Grid empty | 2026-07-16T07:47Z
RESOLVED-VIA-RESTART (operational): full RTMService restart → grid registered via LoadData → US Queue Grid populated. ROOT = LoadData startup-only (runtime-created grid not registered until restart) — 4th occurrence of this recurring limitation (Defect B union / AgentGrid US / BU-SG live-pickup / grid). Code root OPEN as the A/B decision (operational-restart vs engineering on-demand registration). Not a code fix yet.

## REJECT | US Queue Grid counts INFLATED vs legacy | declared 2026-07-16T07:47Z by operator
STATUS: OPEN (fix authored+§4-PASS, awaiting apply+140-verify+operator CONFIRM).
SYMPTOM: after the restart populated US Queue Grid, counts >> legacy (US-Support Incoming 71 vs 4; US All 158 vs Total 6); current-state metrics (Waiting Callbacks 4, Max Wait ~06:47) MATCH → only cumulative Incoming/Abandoned/CallbackRequests inflated.
ROOT (backend, object-store+DB): RTSData_Interaction accumulates (4 days, never cleared); OUR 'today' load polluted — OnDate mis-stamp / server-TZ (UTC vs +03) day-boundary pulls stale rows into today. Legacy accumulates too (2.5mo) but displays right (old rows keep real OnDate, filtered out).
FIX: TZ-aware UpdateTime load-guard (tools/cc_prompt_interactions_updatetime_guard.md, §4-PASS) — filter RTSData_GetInteractions by UpdateTime local-date=today per row TimeZone offset. FIX push #: <pending>.


## REJECT UPDATE | US Queue Grid counts INFLATED | 2026-07-16T16:37Z
FIX 0b07651 (TZ-guard) FAILED on 140 + ROLLED BACK (service restored). Root: 0b07651 casts TimeZone::interval; 140 TimeZone = mixed (offsets + <empty> + IANA 'Israel') -> 22007 on 'Israel' -> fn errors -> today blank. Dev-assumption (TimeZone=offset) vs prod IANA names. STILL OPEN. Redesign blessed: AT TIME ZONE zone-name TEXT form (no ::interval) + probe UpdateTime tz-kind first; patches 0b07651 in repo + same for RTSData_getUsersStatuses. PUSH-BLOCKER for the v3 3-commit stack until patched. FIX push #: <pending redesign>.

## REJECT UPDATE | US Queue Grid empty | 2026-07-16T16:37Z
Grid on-demand fix 961a979 = SEALED on 140 (new QueueGrid on existing-BU populates without restart). GRID-case of LoadData-startup-only addressed. Broader BU/SG hot-reload = backlog epic. Awaiting operator CONFIRM + push.


## REJECT UPDATE | US Queue Grid counts INFLATED | 2026-07-16T21:49Z
TZ-guard track CLOSED + VERIFIED: sign-fix e58cac8 on 140 (per-zone probe GREEN, case_mismatch_ref=0/12474, 2018 rows corrected; snapshot metrics MATCH legacy). Push-blocker lifted. BUT the inflation PERSISTS on CUMULATIVE counters (Incoming US-Support 701 vs 36; US All 1317 vs 87; CallbackRequests 259 vs 2; Abandoned 90 vs 0 ~20x) — ROOT MOVED from TZ to METRIC DEFINITION: our Incoming/CallbackRequests/Abandoned count a BROADER set than legacy's narrow definition. NOT TZ/segments/date-filter (DBA ruled out). Routed to backend/metrics for predicate-delta diagnosis (read-only) -> metric-definition alignment (vendor echelon, operator decision). STILL OPEN. FIX push #: <pending metric-definition>.


## REJECT UPDATE | US Queue Grid counts INFLATED | 2026-07-16T22:01Z
Operator CHANGED the approach: load filter = UpdateTime date = today in SERVER-LOCAL time, REMOVE per-row TimeZone (supersedes TZ-aware 0b07651/0329bf0/e58cac8). Simplifies + kills the sign-bug class. Backend authoring the server-local WHERE -> §4 -> apply 140 -> re-check. NOTE (DBA analysis): the ~20x CUMULATIVE inflation was NOT the date filter (snapshot matched legacy) -> likely metric aggregation (current-vs-cumulative); if it persists after the server-local change, that residual = separate metric-aggregation issue. STILL OPEN. FIX push #: <pending server-local WHERE>.


## REJECT UPDATE | US Queue Grid counts INFLATED | 2026-07-16T22:28Z
✅ RESOLVED. Server-local date-guard 01dbc2c: WHERE = UpdateTime server-local date=today (current_setting('TimeZone')=Asia/Jerusalem +03, Npgsql inherits, = legacy server-day). Applied on 140 + bounced -> US grid == legacy EXACTLY (US All Incoming 88=88; US-Support 39/4/35; Waiting 4=4/84=84). Operator confirmed ('наконец-то'). ROOT (operator was RIGHT, DBA metric-definition hypothesis DISPROVEN): the per-row-TZ guard (e58cac8) evaluated 'today' per each row's TZ -> mixed-TZ data spanned many day-boundaries -> over-inclusion (1317); server-local single server-day collapsed to 88. Repo HEAD 01dbc2c; push-blocker lifted. FIX push #: <pending next barrier (v3 +6: date-guard chain + grid 961a979 + danger-zone 2293f6b)>.


## REJECT | Queue Grid — Wait Time (Max Wait) ZEROES on refresh | declared 2026-07-16T22:30Z by operator
STATUS: OPEN. QUEUED (not dispatched — backend is mid-flight on T2 live-pickup; per the don't-overload rule, held to avoid collision).
SYMPTOM (operator): the WAIT TIME on the Queue Grid ('время ожидания') resets to 0 on each grid refresh (should persist/accumulate, not zero every refresh cycle).
LIKELY LAYER (to diagnose): (a) RTM metric — Max Wait = QueueCurMaxWaitTimeCallsAndCallbacks / QueueCurMaxWaitTimeCallbacks is a CURRENT-state gauge; on refresh with no currently-waiting call it may correctly show 0, OR the value is being recomputed/lost each cycle; vs (b) Shell widget — the cell value is cleared then repopulated on the periodic updateGridData refresh (flicker/reset to 0). Need to confirm: is it 0 PERSISTENTLY after refresh, or a transient flicker; and whether legacy holds the value across refresh.
OWNER (tbd): RTM/metrics (if engine metric behavior) OR shell (if widget refresh clears the cell). Determine on diagnosis.
FIX push #: <pending>. DISPATCH: after backend's T2 design lands (or route to shell if characterized as a widget-refresh issue and shell is free).


## REJECT UPDATE | Queue Grid Wait Time zeroes/over-climbs on refresh | 2026-07-16T22:44Z
CHARACTERIZED (coordinator authed-visual): NOT literal 0 — the Max Wait duration OVER-increments ~10x real-time while the page is open (US-Support 00:54->01:23->02:40 in ~11s) and RESETS to the real wire value (~00:53) on F5. ROOT (strong): SHELL widget client-side duration timer over-increments (double-count / wrong tick) between server pushes; F5 resets the local timer. RTM wire value appears correct (~00:53, 1s/s). OWNER = shell (dispatched now per operator). Fix = render duration as serverValue + real-elapsed-since-push, re-anchor on each updateGridData. Caveat: shell to confirm client-tick vs raw-wire (if raw-wire inflated -> RTM). FIX push #: <pending>.


## REJECT CORRECTION | Queue Grid Max Wait resets on F5 | 2026-07-16T23:01Z
CORRECTED (my earlier 'x10 over-climb' was a mis-read, RETRACTED). ACTUAL (operator, 2 screenshots): Max Wait accumulates NORMALLY (US-Support 16:50 before F5); on F5/re-subscribe it RESETS to ~00:41-00:42 and climbs from there — the true accumulated wait is LOST across reload. OWNER NOT YET PINNED (do not assume): shell widget re-anchoring to subscribe-moment, OR RTM re-pushing a re-subscribe-relative value on init/refreshCells. Decider = the RtmRelay updateGridData Max Wait value right after F5 (16:50=widget resets / 00:42=RTM sends reset). Dispatched shell to DIAGNOSE first, then fix per owner. FIX push #: <pending>.


## REJECT UPDATE | Queue Grid Max Wait resets on F5 | 2026-07-16T23:27Z
OWNER PINNED = RTM/backend (shell wire-evidence via DiagPushLogging config flag, NO rebuild). Widget FAITHFUL (renders serverValue + 1s/s tick), cleared. Root: RTM re-bases '+'-duration Max Wait to the re-subscribe moment on init/refreshCells (counters stayed continuous = no RTM restart) instead of now-enqueue. Operator chose B (priority now) -> T2 live-pickup PAUSED, backend dispatched the RTM fix (emit '+'-duration as now-enqueue, consistent across refreshCells). FIX push #: <pending>.

## PR234-BU-01 — во ВСЕХ виджетах пуст список Business Unit (только `All`)
- **Заявлен:** оператором 2026-08-30, лично, на 234 после converge. Скриншот: модалка
  `Configure: Data Slot`, экран `019ea62d-4be6-730b-b575-03185b9a6ea5` (`Test2`), поле Business Unit
  -> `Search...` + единственный пункт `All`.
- **Факты на момент заявления (измеренные, не предположенные):** целевая БД 5433,
  `NGC_BusinessUnit` = 59 строк, имена человеческие — принято координатором в заходе 2 захода
  converge-234 по счётчикам и списку имён. Шелл поднят, вход работает, список экранов = 9.
- **Класс НЕ ОПРЕДЕЛЁН.** Возможны две разные болезни, и их нельзя смешивать: продуктовый дефект
  (источник списка) ЛИБО последствие переноса (данные под другим тенантом / колонка не приехала).
  Диагностика выдана devops-0829 (только чтение, 5 фактов, без гипотез).
- **Закрывается ТОЛЬКО словом оператора** (CONFIRM/CANCEL), не «по коду» и не «по объяснению».
- **Статус:** OPEN.

### PR234-BU-01 · UPDATE 2026-08-31 — ответ оператора: наблюдение снято, класс определён
**Слово оператора (2026-08-31):** на 140 тенант **Customer1 был выбран по ошибке**, и он **действительно
пустой**; на тенанте **Platform всё работает**.
**Что это закрывает.** Исчезает единственный факт, ради которого пункт держался открытым, — расхождение
«на 234 пусто, на 140 работает». Расхождения нет: обе машины ведут себя одинаково.
**Механизм подтверждён тремя независимыми опорами (не «по объяснению»):**
- КОД: `ScreenEditorPage.razor:2963` шлёт `GetBusinessUnitsQuery(Dashboard.TenantId)` — тенант ЭКРАНА;
  `ConfigurationQueries.cs:33-37` -> `GetAllByTenantAsync(tenantId)`; `NgcRepositories.cs:29-36`
  `.Where(b => tenantId == null || b.TenantId == tenantId)`.
- ДАННЫЕ (замер devops-0829, БД 5433): `NGC_BusinessUnit` platform = **59**, customer1 = **0**.
  Экран из бага `019ea62d-…` = `Test2`, его `TenantId` = **customer1**. Список пуст ПО ПОСТРОЕНИЮ ФИЛЬТРА.
- НАБЛЮДЕНИЕ (оператор, 2026-08-31): Platform — работает, Customer1 — пусто. Совпало с предсказанием.
**Класс: НЕ дефект переноса.** Старая боевая БД (5432, не тронута) и новая (5433) дают идентичные числа —
`BU/platform=59`, `BU/customer1` отсутствует, `screens platform=6`, `screens customer1=4`. Converge
ничего не потерял; ситуация существовала до нас.
**Замеры на 140 ОТМЕНЕНЫ** — предсказание подтвердилось, парная проверка не нужна (экономия окна на
боевой машине; §7 «не чини на боевой то, что можно измерить»).
**СТАТУС: остаётся OPEN.** Механизм объяснён — но объяснение НЕ закрывает пункт (конституция: только
CONFIRM/CANCEL оператора). Открытым остаётся не техника, а ПРОДУКТОВЫЙ вопрос, который координатор
не вправе решать сам (норма 2026-06-26, доменная семантика — оператору): **должны ли у тенанта
`customer1` вообще быть Business Unit?**
- «не должны» -> пункт CANCEL, поведение штатное;
- «должны» -> это КОНФИГ-пробел, а не баг кода, и заводится отдельным пунктом (тот же класс, что
  WFM sub-BU «No Data» 2026-07-22 — конфиг, не код).
Вопрос задан оператору 2026-08-31. Номер пуша закрытия: `<n/a — кода не меняли>`.

### PR234-BU-01 · ⚪ CANCELLED — 2026-08-31, словом оператора
**Слово оператора (2026-08-31, дословно): «не должны».** Ответ на прямо поставленный вопрос — должны ли
у тенанта `customer1` вообще быть Business Unit. Не должны.

**Следовательно пункт ЗАКРЫТ как ⚪ CANCELLED, а не CONFIRMED.** Разница существенна и это не
формальность: CONFIRMED означало бы, что мы что-то починили и оператор принял починку. Здесь **не было
поставки вовсе** — ни строки кода, ни правки данных. Оператор снял заявление, признав наблюдаемое
поведение штатным. (Норма разделения DELIVERED / CLOSED, куратор `958f58b`: доставка — факт с автором и
пином, закрытие — решение, и только оператора.)

**Итоговая картина, все три опоры — на месте, ни одна не «по объяснению»:**
- КОД: список BU фильтруется по тенанту ЭКРАНА — `ScreenEditorPage.razor:2963`
  (`GetBusinessUnitsQuery(Dashboard.TenantId)`) -> `ConfigurationQueries.cs:33-37` -> 
  `NgcRepositories.cs:29-36` (`.Where(b => tenantId == null || b.TenantId == tenantId)`).
- ДАННЫЕ: `NGC_BusinessUnit` platform = 59, customer1 = 0; экран `Test2` (`019ea62d-…`) принадлежит
  `customer1`. Старая БД 5432 и новая 5433 — идентично. Перенос ничего не потерял.
- НАБЛЮДЕНИЕ (оператор): на 140 тенант Customer1 был выбран по ошибке и он действительно пуст;
  на Platform всё работает. Расхождения между машинами не существовало.

**Что НЕ заводится следствием.** Конфиг-пробел не открывается: у `customer1` BU быть не должно, значит
пустой список — правильный ответ системы, а не пробел в настройке. Отдельного пункта нет.
**Номер пуша закрытия: `n/a` — кода не меняли.** Замеры на 140 отменены и не выполнялись.

**Урок, который остаётся дороже самого пункта:** «пусто во ВСЕХ виджетах» звучало как отказ подсистемы,
а оказалось корректной фильтрацией по тенанту. Симптом «пусто везде» одинаково выглядит при поломке и
при верной работе на пустом множестве — тот же класс, что запрет проверять на нулевых данных
(урок 2026-07-22). Прежде чем искать поломку в коде, спроси, каким должно быть множество.

## 2026-08-31T10:5xZ | §A#4 SEAL (coordinator-0818, личный визуал, Chrome) — 234 после converge
Стенд: `https://platform.insightense.com:8444` (DNS: `platform.insightense.com` -> `20.80.36.234`).
Вход Superadmin/`admin`, тенант `platform`. Всё ниже — увидено мной, не пересказ.

**Живость.** `/health` = `Healthy`. Список экранов: **9** (Platform 6, Customer1 3).
Экран `Screen 3` (`019ec16c-b48d-755d-97c7-2312ce6abe24`): `Data Slot` прошёл `מתחבר...` -> отрисовал
значение; `Queue Grid` рисует колонки и несёт зелёный индикатор живого потока, пагинация `4 / 20`.
Редактор открывается, виджеты на месте, консоль чиста (`error|circuit|unhandled|failed` — пусто).
**Оговорка по §A (никогда не подписываться на нулях):** `Data Slot` показывает `0`. Это доказывает,
что провод жив и виджет рисует, и НЕ доказывает корректность числа. Числовая приёмка — на живых
ненулевых данных, отдельно.

**PR234-BU-01 — подтверждён МОИМ наблюдением, а не только словом оператора.** В `Widgets_Configure:
Data Slot` на экране тенанта `platform` список Business Unit **непустой**: `הכל`, `5002`, `5003`,
`5004`, `5005`, `5006`, `5007`… (прокручивается), текущее значение `הרכבות`. Предсказание devops
(«фильтр по тенанту экрана; на `platform` список есть») подтверждено первой рукой. Пункт остаётся
⚪ CANCELLED — это не пере-открытие, а укрепление закрытия наблюдением.

**PR234-1b держится на новой сборке:** в конфиге `Data Slot` присутствуют все три вкладки —
`כללי` / `מראה` / **`ספים` (Thresholds)**. Вкладка, которая пропадала, на месте.

**Ничего не менял:** конфиг закрыт кнопкой `ביטול`, `שמור` не нажималась, `Screens_Publish` не
трогался. Проба (б) фиксируется на SAVE — SAVE не было, значит и пробы не было.

## НАХОДКА КООРДИНАТОРА (не заявление оператора) | UI-LOC-KEYS | 2026-08-31T10:5xZ
**В ивритском UI видны СЫРЫЕ КЛЮЧИ ЛОКАЛИЗАЦИИ вместо текста** — на каждом просмотренном экране:
- список экранов: `COMMON_UPDATEDBY`, `COMMON_CREATEDBY`, `COMMON_WIDGETS`, `Screens_Trash`;
- меню: `Nav_InfoSlots`, `Nav_InfoSlotsAdmin`;
- редактор: `Screens_Edit`, `Screens_Publish`;
- модалка конфига: `Widgets_Configure`, `Widgets_Name`, `Widgets_BusinessUnit`.
Соседние подписи переведены (`מסכים`, `דוחות`, `כותרת`, `מדד`, `יעד`), то есть ресурс подключён —
отсутствуют КОНКРЕТНЫЕ ключи. Класс: пробел в `SharedResources` (he-IL), не поломка локализации.
**Почему поднимаю:** ЧП п.1 — любая визуальная деталь критически RED; и это первое, что видит
заказчик, открыв экран. Оценка серьёзности не моя.
**Статус: НЕ реджект.** Это моя находка, а не ваше заявление. Реджектом станет по вашему слову;
закрытие — тоже только по нему. Владелец фикса при заведении — shell (ресурсы) + techwriter (тексты).

## НАХОДКА КООРДИНАТОРА | VIEW-OFFCANVAS | 2026-08-31T11:0xZ | §A#4, измерено, не «на глаз»
**Виджет, видимый в РЕДАКТОРЕ, в РЕЖИМЕ ПРОСМОТРА уходит за край и недостижим.**
Экран `Screen 3` (`019ec16c-b48d-755d-97c7-2312ce6abe24`, тенант `platform`, 2 виджета).
- В редакторе (`/edit`) видны ОБА: `Data Slot` и `Queue Grid`, оба рисуют.
- В просмотре (`/screens/<id>`) на экране ТОЛЬКО `Data Slot`. `Queue Grid` есть в DOM
  (`querySelectorAll('.widget')` = 2, заголовки `Data Slot`, `Queue Grid`), он `display:flex`,
  `visibility:visible`, `opacity:1` — то есть НЕ скрыт стилями.
**Числа (`getBoundingClientRect`, вьюпорт 2133x1012, `window.innerHeight` 950):**
```
Data Slot   x=1519 w=419  -> 1519..1938   ВНУТРИ вьюпорта
Queue Grid  x=2343 w=419  -> 2343..2762   ЗА краем (>2133)
document.body.scrollHeight = 950 == window.innerHeight  -> страница НЕ прокручивается
```
То есть виджет не «спрятан» и не «не отрисовался» — он **вынесен за границу вьюпорта, и доскроллить
до него нельзя**. Для пользователя виджета просто нет.
**Класс:** маппинг координат редактор->просмотр (семейство Edit<->View scale, ср. `PR234-1c`
и `F-SCALE-TOGGLE`), НЕ «виджет не работает» — в редакторе он рисует данные.
**Гипотеза, помечена гипотезой:** интерфейс RTL (иврит), и позиция, заданная в редакторе, может
зеркалиться при переносе в просмотр. НЕ проверено, предикатом не объявляю.
**Статус: НЕ реджект** — находка координатора, а не заявление оператора. Владелец при заведении: shell.

## НАХОДКА КООРДИНАТОРА | QGRID-DASHES-BEZEQ | 2026-08-31T11:0xZ | §A#4, на ЖИВЫХ НЕНУЛЕВЫХ данных
Экран `בזק - ניהול משמרת פרטי` (`01a04c39-caac-7107-8d59-d40fb48a94fa`, `platform`, 9 виджетов,
опубликован, создан 2026-08-29 — то есть УЖЕ на новой сборке).
**Система жива и данные ненулевые** — это важно, потому что на нулях подписываться запрещено:
инфо-слоты `נציגים מחוברים 30` · `זמינים 3` · `בשיחה 8` · `בהפסקה 6` · `אחוז נטישה 1.9%` (Target < 20%);
`Agent grid` — **43 агента**, живые имена, статусы (`הפסקת אוכל`, `פרויקט`, `SIGNOFF`, `דיגיטל`),
длительности и проценты заполнены (`71.2%`, `01:15:28`, `04:22:25`).
**НО `Queue Grid` на том же экране — ВСЕ ячейки `-`.** 4 очереди (`לפני_רכישה`, `אחרי_רכישה`,
`הרכבות`, `מטבחים`) x 13 колонок, ни одного значения, при этом индикатор внизу справа — **зелёный
`חי` (live)**, то есть виджет считает себя подписанным. Наблюдал ~35 секунд, картина не менялась.
**Почему это не «просто нет трафика»:** различитель установлен в июле по реджекту «US Queue Grid —
empty cells (no data, not even 0)» — отсутствие трафика рисует **`0`**, а незарегистрированные ячейки
рисуют **`-`** (тогда DE показывал нули, US — пусто). Здесь `-`.
**Родство:** тот реджект был снят рестартом (`LoadData` только на старте), код-фикс on-demand
`961a979` — и он до сих пор 🟡 ждёт операторского CONFIRM. Возможен рецидив того же корня после
converge, но **утверждать не буду: не проверял регистрацию грида в движке**.
**Статус: НЕ реджект** — находка координатора. Владелец при заведении: backend/RTM (регистрация грида)
либо shell (рендер), различается замером `updateGridData`, а не мнением.

## REJECT | Queue Grid — прочерки во ВСЕХ ячейках на живом экране | заявлен 2026-08-31 оператором
**СТАТУС: 🔴 OPEN.** Заявлено оператором 2026-08-31 в ответ на находку координатора (`§A#4` визуал).
Закрывается ТОЛЬКО словом оператора (CONFIRM/CANCEL), не по коду и не по объяснению.

**СИМПТОМ.** Экран `בזק - ניהול משמרת פרטי` (`01a04c39-caac-7107-8d59-d40fb48a94fa`, тенант `platform`,
9 виджетов, ОПУБЛИКОВАН, создан 2026-08-29 — уже на новой сборке), 234, просмотр:
`Queue Grid` — 4 очереди (`לפני_רכישה`, `אחרי_רכישה`, `הרכבות`, `מטבחים`) x 13 колонок,
**во всех ячейках `-`**, ни одного значения. Индикатор виджета — **зелёный `חי` (live)**.
Наблюдение координатора ~35 секунд, картина не менялась.

**ПОДТВЕРЖДАЮЩИЕ ФАКТЫ (вид выбран координатором: личный визуал + числа с экрана).**
Данные на экране ЖИВЫЕ И НЕНУЛЕВЫЕ — это снимает объяснение «нет трафика / нулевое состояние»
(норма 2026-07-22: на нулях не подписываться, и обратно — нули нельзя выдавать за поломку):
- инфо-слоты: `נציגים מחוברים 30` · `זמינים 3` · `בשיחה 8` · `לא זמינים 0` · `בהפסקה 6` ·
  `אחוז נטישה 1.9%` (Target < 20%) · `שיחות ממתינות 0`;
- `Agent grid` на ТОМ ЖЕ экране: **43 агента**, реальные имена, статусы (`הפסקת אוכל`, `פרויקט`,
  `SIGNOFF`, `דיגיטל`, `פני`), длительности и проценты заполнены (`71.2%`, `01:15:28`, `04:22:25`).
Агентский поток идёт, очередной — нет.

**РАЗЛИЧИТЕЛЬ `-` ПРОТИВ `0` (установлен в июле, не изобретён сейчас).** По реджекту
«US Queue Grid — empty cells (no data, not even 0)» от 2026-07-16: отсутствие трафика рисует **`0`**
(так вёл себя DE), незарегистрированные ячейки рисуют **`-`** (так вёл себя US). Здесь `-`.

**РОДСТВО, НЕ ДИАГНОЗ.** Тот июльский случай снимался РЕСТАРТОМ (`LoadData` только на старте
-> рантайм-созданный грид не регистрируется до перезапуска), код-фикс on-demand `961a979` —
и он ДО СИХ ПОР 🟡 ждёт операторского CONFIRM. Похоже на рецидив того же корня после converge.
**Диагнозом это не объявляется:** регистрация грида в движке не проверялась.
⛔ **РЕСТАРТ ЗАПРЕЩЁН до замера** — в июле именно рестарт «починил» симптом и скрыл корень.

**ВЛАДЕЛЕЦ: не пришпилен.** Различается замером, а не мнением: движок не шлёт значения (RTM/backend)
ЛИБО шлёт, а виджет не рисует (shell). Диагностика выдана `devops-0831`, только чтение.
**НОМЕР ПУША ЗАКРЫТИЯ: `<pending>`.**

> **UPDATE 2026-08-31T12:1xZ | диагностика №1 ОБОРВАНА — но обрыв сам стал уликой.**
> Прогон `qgdiag_20260831_145947.sql` упал на секции C: `ERROR: invalid input syntax for type json`,
> `DETAIL: The input string ended unexpectedly`, `psql exit code = 3`. Секция A отработала (оба экрана
> найдены, оба тенанта `platform`, `IsDeleted=false`; `Screen 3` = `Draft`, `בזק` = `Published`).
> **Числа C/D/E НЕ получены. Замер НЕ выполнен** — блок вердикта отработал и не дал прочитать обрыв
> как «получились нули».
> **ЧТО ОБНАРУЖЕНО ПОПУТНО:** хотя бы у ОДНОГО виджета на этих двух экранах `ConfigJson`
> **не является валидным JSON** — не пустая строка (её ловил `NULLIF`), а непарсящееся значение.
> Это класс `PR234-1a` (🟡 в реестре, silent-catch в `ParseWidgetConfig`).
> **КАНДИДАТ В ПРИЧИНУ, НЕ ПРИЧИНА.** Гипотеза с пином на код: `QueueGridWidget.razor:451-453` —
> если `Config.GridId` не разобран, виджет пишет warning и **не подписывается вовсе**, и тогда грид
> остаётся пустым при живом `Agent grid` на том же экране, что в точности совпадает с симптомом.
> **НЕ УСТАНОВЛЕНО:** на КАКОМ из двух экранов лежит битый конфиг и у КАКОГО виджета — CTE покрывал
> оба экрана, обрыв случился до печати строк. Битый на сломанном экране у `Queue Grid` -> кандидат в
> причину; битый в другом месте -> отдельный дефект, к этому пункту отношения не имеет.
> Диагностика REV2 (валидатор `pg_input_is_valid` вместо каста + опознание виджета) выдана под §4.
> Статус пункта БЕЗ ИЗМЕНЕНИЙ: 🔴 OPEN, владелец не пришпилен, номер пуша `<pending>`.

## 2026-08-31T12:5xZ | §A#4 SEAL (coordinator-0818, личный визуал) — ОТЧЁТЫ на 234 работают
Отчёт `Test1` (`019f2775-bcc2-7124-83ee-114321e0b486`), диапазон 24/08–31/08/2026, тенант `platform`.
**Данные живые и ненулевые** — интервалы `07:00…13:00` за `2026-08-30`, по каждому: `הוצעו`/`נענו`
(предложено/отвечено) 7..23, `% נטישה` 0.0–7.7%, `% SL` 23.5–100%, `ASA` 0:02–1:03, `AHT` 1:54–4:56.
Пагинация `1 / 2`, подпись «показано 25 из 31», поле «строк» в подвале = 25.

**Что это подтверждает моим наблюдением (не закрывает — закрывает оператор):**
- **R1** (`DateTime Kind=Unspecified` -> ошибка вьюера) — даты рисуются, ошибки нет, экран цел. Опора есть.
- **R9** (строк-на-страницу вынесено в подвал) — поле в подвале **присутствует**. Произвольное значение
  1..1000 я НЕ проверил: попал тройным кликом в ячейку таблицы вместо поля, выделил текст и на этом
  остановился. Говорю как есть, чтобы не выдать непроверенное за проверенное.
- **REP-DATA-RANGE** — на диапазоне 24–31/08 данные ЕСТЬ. Июньский провал (ради которого делали
  бэкфилл) этим прогоном НЕ проверен: другой диапазон.
- **R2** (параллельные виджеты на общем DbContext) — на этом экране один виджет, нагрузка не создаётся.
  НЕ проверено.
**Ничего не менял:** отчёт не редактировался, конфиг не сохранялся, `ייצוא` (экспорт) НЕ нажимался.

**R7 (Export -> .xlsx, 🔴 OPEN) — кнопка `ייצוא` на панели присутствует и активна.** Проверку не
проводил: клик может скачать файл, а загрузка файлов требует явного разрешения оператора. Запрошено.

**Сырые ключи локализации (UI-LOC-KEYS) — подтверждены и на этих экранах:** список отчётов несёт
`COMMON_UPDATED`, `COMMON_UPDATEDBY`, `Screens_Trash`; **страница ВХОДА несёт `Login_OrCredentials`** —
то есть дефект виден ДО аутентификации, на первом экране, который видит заказчик.

## НАБЛЮДЕНИЕ | SESSION-DROP | 2026-08-31T12:4xZ — не заявлено, зафиксировано
Сессия Superadmin, открытая ~11:0xZ и активно использовавшаяся, к 12:4xZ была сброшена: переход на
`/reports` дал редирект `/login?ReturnUrl=%2Freports`. Выхода из системы не было, вкладка не менялась,
браузер не перезапускался. Причина неизвестна: короткое время жизни cookie по настройке, рестарт
пула/службы, или разрыв. **Не диагностировано, владелец не назначен, реджектом не объявлено.**

> ⛔ **ОТЗЫВ 2026-08-31T13:3xZ — ЗАПИСЬ ВЫШЕ ПРО «НЕВАЛИДНЫЙ `ConfigJson`» НЕВЕРНА. Снимаю.**
> Никакого битого конфига в базе НЕ обнаружено. Ошибка `invalid input syntax for type json` пришла
> **из моего же диагностического выражения**, а не из данных.
> **Корень — моя ложная посылка.** Я написал: «`ConfigJson` объявлен `string?` (`Dashboard.cs:40`),
> **значит колонка TEXT**». Вывод неверен: `string?` в C# — это nullable-аннотация, она ничего не
> говорит о типе колонки; тип задаёт маппинг EF. Проверено мной сейчас, три пина:
> `Migrations/App/20260507135247_InitialCreate.cs:455` -> `ConfigJson = table.Column<string>(type: "jsonb")`;
> `AppDbContextModelSnapshot.cs:256/945/1229` -> `.HasColumnType("jsonb")`.
> **Колонка `jsonb`, а не TEXT.**
> **Механика обрыва.** На `jsonb`-колонке `NULLIF(w."ConfigJson", '')` вынуждает Postgres привести
> литерал `''` к `jsonb` — и падает `The input string ended unexpectedly` при ЛЮБЫХ данных, даже
> идеально валидных. То есть прогон оборвала **предложенная мной мера**, а «непарсящееся значение в
> базе» — фантом, порождённый ею же. Подтверждено независимо: `devops-0831` предъявил с сервера
> `ERROR: function length(jsonb) does not exist` (12:35), `backend-0831` пришёл к тому же из кода (13:2x).
> **Что НЕ отозвано и остаётся в силе:** механизм перезаписи сохранённого конфига дефолтом на `v3`
> (`ScreenEditorPage:3017 -> :3030 -> :5041 -> UpdateDashboardWidgetsCommand:50`; `SaveLayout` шлёт ВСЕ
> виджеты) плюс молчащий `catch {}` в `ScreenFullscreenPage:315-325`. Он срабатывает от ЛЮБОГО пустого
> или непарсящегося конфига, включая штатный `NULL` — и объясняет симптом `PR234-1a` «конфиг сохраняется
> null» **без всякого битого JSON**.
> **Гипотеза «битый конфиг = причина реджекта Queue Grid» СНЯТА.** Реджект остаётся 🔴 OPEN, владелец
> по-прежнему не пришпилен, замер REV2 остаётся нужным — но искать он должен пустой/отсутствующий
> `Config.GridId`, а не невалидный JSON.
> **Класс ошибки, для протокола:** свойство ОДНОЙ поверхности (модель C#) выдано за свойство ДРУГОЙ
> (схема БД). Родня «`git status` вместо object store» и «есть вывод -> предикат сработал».

> **ЗАМЕР 2026-08-31T14:0xZ — координатор, БЕЗ SQL и без рук оператора. Гипотеза «пустой `GridId`» СНЯТА.**
> Открыл конфиг виджета `Queue Grid` на сломанном экране прямо в редакторе (только чтение, `ביטול`,
> `שמור` не нажималась, диалогов не осталось — проверено `querySelectorAll('.modal')` = 0).
> ```
> экран  01a04c39-caac-7107-8d59-d40fb48a94fa  (בזק, Published)
> виджет 8382cd56-49ad-439a-a883-705d8e0c3b3e  "Queue Grid"
> מזהה רשת (Config.GridId) = 78     <- ЗАПОЛНЕН, не пуст и не NULL
> ```
> Для сравнения, исправный `Data Slot` на `Screen 3` несёт `GridId = 54`.
> **Следствия, по одному:**
> 1. **Ветка «виджет не подписался, потому что `Config.GridId` пуст» — ЗАКРЫТА.** Идентификатор есть,
>    значит `QueueGridWidget:451-453` (warning + выход) не срабатывает.
> 2. **Механизм backend'а (`SaveLayout` перезаписывает конфиг дефолтом) на ЭТОТ случай не ложится** —
>    конфиг не обнулён. Как объяснение `PR234-1a` он остаётся, как причина ЭТОГО реджекта — нет.
> 3. **Прочерки в редакторе те же, что в просмотре** — 4 очереди x 13 колонок, все `-`, при живом
>    `Agent grid` (66 звонков, 71.8% в разговоре, значения меняются на глазах). То есть это не дефект
>    режима просмотра.
> **Остаются ровно две ветки, и обе требуют БД/движка, интерфейс их не различает:**
> (а) грид 78 не имеет строк/ячеек в RTS — не зарегистрирован;
> (б) строки/ячейки есть, движок не шлёт значения.
> Замер devops перенацелен на это и сокращён до одного запроса: строки/колонки/ячейки для грида **78**
> против рабочего **54**. Статус пункта без изменений: 🔴 OPEN, владелец не пришпилен.

## НАХОДКИ КООРДИНАТОРА | экран `WFM` | 2026-08-31T14:1xZ | §A#4, живой просмотр
Экран `WFM` (`01a05191-7752-7338-9c1b-4a00df14bd92`, `platform`, 5 виджетов, создан 30.08 — новая сборка).

**1. `WFM-N-ZERO` — два виджета на ОДНОМ экране противоречат друг другу.**
`WFM Forecast` показывает `No Data` / `Waiting for calls or agents`, вход:
`Arrivals (λ) 8.0 /hr` · `AHT 6:17` · **`Serving Agents 0`** · `min window 30` · `17:14:40`.
Тут же, на том же экране, `Agent State Distribution` **рисует непустую диаграмму** с секторами
`AVAILABLE` / `BREAK` / `ONPHONE` / `PAPERWORK` / `TRAINING`. Агенты есть, но `N = 0`.
**Альтернатива, которую называю ЧЕСТНО и первой:** `Serving Agents` считается по настроенным
`WfmServingStateGroups`; если для этого тенанта/BU группы обслуживания не заданы или не совпадают с
именами статусов, `N=0` — **штатный** результат, а не дефект. Это ровно прецедент 2026-07-22
(«sub-BU No Data оказался КОНФИГ-пробелом, а не багом»). Различается чтением `TenantSettings.Wfm*`
и сопоставлением с фактическими именами статусов — **не мой вердикт, не рассуждением**.

**2. `WIDGET-NODATA-KEY` — сырой ключ ресурса как СОДЕРЖИМОЕ виджета.**
Три виджета `Day Trend Chart` вместо пустого состояния показывают пользователю строку
**`Widget_NoDataToday`**. Это не подпись поля, а основной текст в теле виджета — то есть класс
`UI-LOC-KEYS`, но на порядок заметнее: пользователь видит идентификатор ресурса вместо сообщения.

**3. `ASD-AGENTS-ZERO-LABEL` — подтверждение старого минора, он жив.**
`Agent State Distribution` рисует распределение и одновременно подписан **`0 סוכנים` (0 агентов)**.
Внутреннее противоречие в одном виджете. Помечен как «минор, косметика» ещё 2026-07-04 — **дожил до
новой сборки**.

**4. Не дефект, фиксирую, чтобы не завели:** `Agent State Distribution` подключался ~20 секунд
(`מתחבר...`), после чего отрисовался нормально. Ранний скриншот показал бы «виджет не работает».
Наблюдать до подключения, а не по первому кадру.

Все четыре — **находки координатора, не заявленные реджекты.** Владельцы при заведении: (1) backend/WFM
либо конфигурация тенанта; (2) и (3) shell.

> ⭐ **ПАРНОЕ НАБЛЮДЕНИЕ 2026-08-31T14:2xZ — РЕШАЮЩЕЕ. Queue Grid НЕ сломан как виджет.**
> Экран `דמו מסך 1` = **`ca5c23ac-73ed-4bbf-9df4-c5b008f98fc7`** (это исторический «экран 12» из
> июльских реджектов), `platform`, опубликован. Его `Queue Grid` **РАБОТАЕТ И ПОЛОН**:
> ```
> очередь        Incoming  Available  loggedIn  Answered  WaitTime  Waiting
> הרכבות             183       1          5        176      00:00      0
> לפני_רכישה          86       1          5         85      00:00      0
> מטבחים              67       1          5         66      00:00      0
> תמיכה               51       2          2         43      00:00      0
> הובלה               77       1          5         72      00:00      0
> ```
> индикатор — зелёный `חי`.
> **Ключевое:** очереди `הרכבות`, `לפני_רכישה`, `מטבחים` присутствуют В ОБОИХ экранах. На `בזק`
> (грид **78**) те же самые очереди рисуют `-`, здесь — живые числа. **Один сервер, один тенант, один
> момент времени, одни и те же очереди: один грид наполнен, другой пуст.**
> **Следствия:**
> 1. Виджет `Queue Grid` как таковой ИСПРАВЕН — рендер, подписка, колонки, живой индикатор работают.
> 2. Данные по этим очередям в движке ЕСТЬ — их отдают другому гриду прямо сейчас.
> 3. Значит дефект локализован в **конкретном экземпляре грида 78**: он либо не зарегистрирован в RTS,
>    либо зарегистрирован без ячеек. Ветка «движок вообще не шлёт очередные данные» — **закрыта**.
> Это ровно та парность, ради которой заказывался SQL-замер, и она получена глазами, без прогона.
> Замер сокращается до одного вопроса: **что отличает грид 78 от грида этого экрана.**

## НАХОДКИ КООРДИНАТОРА | экран `ca5c23ac` (`דמו מסך 1`) | 2026-08-31T14:2xZ
**1. `INFOSLOT-CLIP` — текст виджета обрезан и налезает сам на себя.**
`Info Slot` показывает `שלום ערן 08:04` и поверх/встык — хвост `ninistrator` (обрубок
`System Administrator`). Пользователь видит склеенную строку из приветствия, времени и куска чужого
идентификатора. Владелец при заведении: shell.
**2. `Widget_NoDataToday` — четвёртый экран подряд.** `Day Trend Chart` снова показывает сырой ключ
ресурса вместо сообщения. Подтверждено на `WFM` (3 виджета), `Nayax Support Executive View`,
`ca5c23ac`. **Day Trend не имеет данных за сегодня НИ НА ОДНОМ проверенном экране** — при том, что
очереди и агенты живые. В бэклоге числится «DayTrend ~4ч лаг»; наблюдаемое (14:2xZ, ни одной точки)
на лаг не похоже, но **вердикта не выношу** — нужен замер источника DayTrend, не глаз.
**3. `ASD-CONNECTING` — `Agent State Distribution` не подключился за ~20 с** на этом экране, тогда как
соседние виджеты того же экрана уже несут живые числа. На экране `WFM` тот же виджет подключился за
~20 с и отрисовался. То есть подключение медленное/нестабильное, а не мёртвое. Наблюдение оборвано на
20 секундах — **это ограничение моего наблюдения, а не свойство виджета.**

> ⭐ **ЧИСЛА ПОЛУЧЕНЫ 2026-08-31T15:0xZ (devops, psql rc=0, негативный контроль = 0).**
> ```
> grid 55 (исправный, Screen 3):  rows=5  cols=6  cells=30  nonempty=25
> grid 78 (СЛОМАННЫЙ, בזק):       rows=1  cols=0  cells=12  nonempty=12  Title='Queue Grid'  UnionId=-1
> grid 54:                        rows=1  cols=1  cells=1   nonempty=1
> ```
> **ДВЕ ВЕТКИ ИЗ ТРЁХ ОПРОВЕРГНУТЫ ЧИСЛАМИ:**
> - «грид не зарегистрирован / ячеек нет» — НЕТ: строка в `RTSGrid_Grid` есть, ячейки есть;
> - «движок не шлёт значения» — НЕТ: 12 ячеек из 12 несут непустые значения.
> **Истинно третье: значения ЕСТЬ, а виджет рисует `-`.**
> **СТРУКТУРНОЕ РАСХОЖДЕНИЕ — вот оно, и оно грубое:** в RTS у грида 78 **1 строка и 0 колонок**,
> а виджет отрисовывает **4 очереди × 13 колонок = 52 ячейки**. Двенадцать живых ячеек принадлежат
> одной строке при нуле зарегистрированных колонок. То есть форма грида в движке и форма, ожидаемая
> конфигом виджета, — **разные**.
> **Механизм отрисовки (пин, devops по коду):** `QueueGridWidget.razor:397` строит `_columnDefs` из
> КОНФИГА (`queueGridColumnDefs`), `:441-445` строит `_cellMap` из `queueGridRows[].cellIds`, а `:480`
> отбрасывает пришедшую ячейку (`continue`), если её `CellId` нет в этой карте. Таблицу `RTSGrid_Column`
> виджет НЕ читает. Значит `cols=0` — симптом того же корня, а не причина отрисовки прочерков.
> **ГИПОТЕЗА (помечена гипотезой):** грид 78 зарегистрирован в движке в СТАРОЙ/частичной форме и не
> перерегистрирован после того, как виджет настроили на 4 очереди × 13 колонок. Тогда ни один входящий
> `CellId` не совпадает с `cellIds` конфига — и все 52 клетки рисуют `-` при 12 живых ячейках в БД.
> Это согласуется с июльским корнем (`LoadData` только на старте) и объясняет, **почему тогда «помог»
> рестарт**: он перестраивал грид и уничтожал именно эту разницу.
> **Проверяется одним чтением:** множество `RTSGrid_Cell.CellId` грида 78 против множества `cellIds`
> из `queueGridRows` в конфиге виджета 78; та же пара для 55. Плюс `UnionId` исправного грида для
> сравнения с `-1` у сломанного.
> **Владелец пока НЕ пришпилен** — и это правильно: если конфиг ждёт `cellIds`, которых движок не
> выдаёт, чинить надо регистрацию (backend/RTM), а не рендер (shell). Один запрос разделяет.
> ⛔ **Рестарт по-прежнему запрещён:** он перерегистрирует грид и уничтожит измеряемую разницу.

> **ПОПРАВКА К МОЕМУ ЗАМЕРУ 14:0xZ (координатор, сам себя):** я записал «`Config.GridId` = 78,
> заполнен». **Верно по значению, НЕ обосновано по источнику.** Поле в редакторе, подписанное
> «מזהה רשת», привязано к `ConfiguringWidget.GridId` (`:319-320`), а не к `Config.gridId`; у этого
> виджета оба числа случайно совпали (78 и 78). По данным (devops, S2) `Config.gridId` заполнен
> **лишь у 2 виджетов из 11** — у остальных девяти он `null`, и там мой способ чтения дал бы ложь.
> Вывод устоял, метод — нет. Класс: **прочитал не то поле, совпавшее по числу.**

## ⭐ `VIEW-OFFCANVAS` — МЕХАНИЗМ НАЙДЕН И ВОСПРОИЗВЕДЁН | 2026-08-31T15:2xZ | координатор, числами
Раньше я записал это как «виджет в просмотре уезжает за край» на `Screen 3`. Нашёл механизм, и он
общий, а не свойство одного экрана.

**Экран `Nayax Support Executive View` (`019efdbf-51e5-70bc-918b-fd5d663e6951`, `platform`, 2 виджета).**
Сразу после открытия, замер `getBoundingClientRect` (вьюпорт 2133x1012):
```
виджет 1:  x=1455  w=882  -> 1455..2337   ОБРЕЗАН правым краем (2337 > 2133)
виджет 2:  x=2558  w=882  -> 2558..3440   ЦЕЛИКОМ ЗА ПРЕДЕЛАМИ вьюпорта
document.documentElement.scrollWidth = 2133 == innerWidth  -> ГОРИЗОНТАЛЬНОЙ ПРОКРУТКИ НЕТ
```
Визуально: `Service Le…` и `61.7…` обрезаны на полуслове, второго виджета не видно вообще.
Суммарная ширина содержимого **3440 px против вьюпорта 2133** — и контейнер **обрезает, а не
прокручивает**, поэтому недостающее не просто «за краем», а **недостижимо**.

**Нажал ТРЕТЬЮ кнопку панели инструментов (иконка «вписать»). Тот же замер после нажатия:**
```
виджет 1:  x=1455  w=280  -> 1455..1735   внутри
виджет 2:  x=1805  w=280  -> 1805..2085   внутри
```
Оба виджета отрисовались полностью: `Service Level 61.7% (Target 80%)` и `Talk D…`.
**Ширина виджета изменилась 882 -> 280, то есть режим масштабирования переключился, и содержимое
стало достижимым.**

**ВЫВОД (механизм, не гипотеза):** экран ОТКРЫВАЕТСЯ в режиме, при котором содержимое шире вьюпорта,
а горизонтальной прокрутки нет — часть виджетов недостижима, пока пользователь сам не найдёт и не
нажмёт кнопку «вписать». На опубликованном экране это означает: **заказчик открывает и видит обрезок.**
Внутренних имён режимов не знаю и не выдумываю — фиксирую наблюдаемое: «состояние по умолчанию» и
«состояние после третьей кнопки».

**Это же объясняет мою запись по `Screen 3`** (`Queue Grid` при `x=2343` вне вьюпорта 2133): тот же
корень, а не отдельный дефект. Обе записи сводятся в одну.
**Побочно, к `F-SCALE-TOGGLE` (🟡 «поставлено, визуальное A/B не снято»):** A/B фактически снято мной
сейчас — режим «вписать» работает и чинит перекрытие; режим по умолчанию делает часть экрана
недостижимой. Это наблюдение к пункту, а не его закрытие.
**Владелец при заведении: shell.** Статус: находка координатора, реджектом не объявлена.


---

## QGRID-78-RTS — ВЛАДЕЛЕЦ ПРИШПИЛЕН ИЗМЕРЕНИЕМ (🔴 OPEN)
> Запись координатора-0831, 2026-08-31T15:4xZ. Источник — финальный замер devops-0831 (15:35Z),
> `psql rc=0`, отрицательный контроль 0. Реджект НЕ закрывается: закрытие только по слову оператора.

**Симптом (заявлен оператором):** виджет Queue Grid на экране пуст/без данных, грид `78`.

**Числа (три грида, один прогон):**

| gid | cfg строк×колонок | движок: строк/кол/ячеек/непустых | cfg_ids | eng_ids | ПЕРЕСЕЧЕНИЕ |
|---|---|---|---|---|---|
| 29 | 5×6 | 6 / 6 / 36 / 36 | 30 | 36 | **30 (полное)** |
| 55 | 4×6 | 5 / 6 / 30 / 25 | 24 | 30 | **24 (полное)** |
| 78 | 4×12 | 1 / 0 / 12 / 12 | 48 | 12 | **0 из 48** |

Оба ИСПРАВНЫХ грида дают полное пересечение идентификаторов ячеек; сломанный — ноль.
Дефект = рассинхронизация «конфиг виджета ↔ регистрация грида в RTS», а не отсутствие данных:
ячейки движка непусты (12/12), просто их `CellId` не те, что ищет конфиг
(`QueueGridWidget.razor:441-445` строит `_cellMap` из конфиговых `cellIds`, `:480` молча
`continue` на каждом несовпадении — отсюда пустой экран без единой ошибки).

**ВЛАДЕЛЕЦ — SHELL.** Структуру грида в RTS создаёт САМ РЕДАКТОР при сохранении виджета:
`SaveQueueGridRtsCommand.cs` + `ScreenEditorPage.razor:4284` пишут `RTSGrid_Grid/Row/Column/Cell`.
Движок только кладёт `Value` в уже существующие ячейки. Значит расхождение 4×12 (конфиг) против
1 строки / 0 колонок (RTS) породил путь сохранения шелла, не движок и не backend.

**СНИМАЮ СВОЮ ГИПОТЕЗУ:** «движок зарегистрировал старую форму грида (июльский корень `LoadData`)» —
НЕВЕРНА ПО АТРИБУЦИИ. Записана здесь как промах, чтобы не всплыла повторно.
**СНИМАЮ ЛОЖНЫЙ СЛЕД:** `UnionId = -1` — он одинаков на ВСЕХ трёх гридах, включая два исправных,
следовательно сигналом не является. Третья точка данных была затребована именно ради этого.

**ЗАПРЕТ:** рестарт/пересохранение виджета 78 ЗАПРЕЩЁН до слова оператора — пересохранение перезапишет
RTS-регистрацию и уничтожит саму рассинхронизацию, которая и есть единственная улика.

**Следующий шаг (не выполнять без слова оператора):** прочитать в коде `SaveQueueGridRtsCommand`
условие, при котором 4 строки конфига дают 1 строку RTS и 0 колонок (кандидат — сохранение виджета
до того, как в конфиге появились колонки, либо частичный проход по `cellIds`).

status: 🔴 OPEN


---

## СКОП НА БЛИЖАЙШИЕ ЧАСЫ — слово оператора 2026-08-31T15:5xZ
**Только дешборды.** В работе: уже найденное мной по дешбордам + «DayTrend не работает».
**R7 (Экспорт отчёта в .xlsx) — ОТЛОЖЕН В БЭКЛОГ** по слову оператора. Не трогать, не спрашивать.

В скопе (🔴 работаем):
- `QGRID-78-RTS` — владелец пришпилен (shell), идёт чтение пути сохранения.
- `DAYTREND-NODATA` — DayTrend не отдаёт данные ни на одном экране (ключ ресурса вместо графика).
- `WFM-N-ZERO` · `ASD-AGENTS-ZERO-LABEL` · `WIDGET-NODATA-KEY` · `INFOSLOT-CLIP` · `VIEW-OFFCANVAS`.

Вне скопа до слова оператора: `UI-LOC-KEYS` (экран входа), `SESSION-DROP`, `R7`, нормо-правки CLAUDE.md.


## DAYTREND-UTC-DAY — находка из кода, ждёт слова оператора
`DayTrendQueryHandler.cs:40`: день по умолчанию берётся как `DateOnly.FromDateTime(DateTime.UtcNow)`,
а данные `RTSData_Interaction."OnDate"` пишутся по МЕСТНОЙ дате. Израиль = UTC+3, поэтому с 00:00 до
03:00 по местному времени UTC ещё показывает ВЧЕРА, и виджет три часа в сутки строит вчерашний день.
Сегодня (18:5x местного) на симптом не влияет — это отдельный латентный дефект, не причина
`DAYTREND-NODATA`. Фиксирую, чтобы не потерялся. status: 🔴 OPEN (реджект? — слово оператора)


## DAYTREND-CULTURE-SEP — ПРИЧИНА НАЙДЕНА, механизм пришпилен (🔴 OPEN)
> coordinator-0831, 2026-08-31T16:1xZ. Снято по коду + сырой лог devops-0831 (19:2x местного).

**Симптом:** DayTrend пуст на всех экранах. Замер devops: ветка 2 — `Got 0 interaction rows`,
функция исполняется, очереди у BU есть, исключений нет.

**МЕХАНИЗМ.** `DayTrendQueryHandler.cs:40-41`:
`DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy")` — **без `CultureInfo.InvariantCulture`**.
В .NET символ `/` внутри строки формата НЕ литерал: он подменяется на
`CurrentCulture.DateTimeFormat.DateSeparator`. `Program.cs:109` объявляет поддерживаемые культуры
`en-US`, `ru-RU`, `he-IL`; у `he-IL` и `ru-RU` разделитель даты — **точка**.
Оператор работает в ивритской локали, поэтому параметр уходит в SQL как `31.08.2026`,
а `RTSData_Interaction."OnDate"` хранит `31/08/2026` (`RtsDataEntities.cs:13`).
Сравнение varchar `"OnDate" = p_ondate` не совпадает НИКОГДА → ноль строк, без ошибки.

**Доказательство, что это фактический параметр, а не украшение лога:** строка лога печатает
переменную `onDate` (`:45-46`), то есть уже отформатированное значение. devops видел в логе
`Date=31.08.2026` и осторожно не стал делать из этого вывод — вывод делается, потому что
источник строки лога и источник параметра SQL один и тот же.

**Свою же более раннюю запись «формат даты — ложный след» СНИМАЮ.** Она была верна по коду
(маска везде одна) и неверна по исполнению: я сверил маски и не сверил культуру. Урок в §B:
**маска формата — не значение; `/` в .NET-формате культурозависим.**

**Тот же дефект по тому же образцу:** `DatabaseInitializer.cs:736` и `:788`.

**Проверка ценой одного клика, оператору:** переключить язык интерфейса на English и открыть экран
с DayTrend. Заполнился — механизм подтверждён окончательно. Пусто — механизм неверен, идём в данные.

**Владелец: shell / backend** (одна строка, `.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture)`).
Чинить только по слову оператора. status: 🔴 OPEN


### DAYTREND-CULTURE-SEP — ПОДТВЕРЖДЁН ЛИЧНЫМ ВИЗУАЛОМ (ЧП п.4), 2026-08-31T16:3xZ
Оператор переключил интерфейс на English. Я лично открыл
`/screens/ca5c23ac-73ed-4bbf-9df4-c5b008f98fc7` («דמו מסך 1», Platform).
**`Day Trend Chart` ПОЛОН ДАННЫХ:** четыре серии (Abandoned / Answered / Incoming / Total Agents),
шкала 07:00–19:00, пики до 8, `Last updated: 19:39:08`. В ивритской локали тот же виджет пуст.
Механизм подтверждён окончательно: разделитель даты культуры ломает сравнение `OnDate`.
**Правка — одна строка:** `DayTrendQueryHandler.cs:41` → `.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture)`;
тот же образец в `DatabaseInitializer.cs:736` и `:788`. Ждёт слова оператора на исполнение.

### ЧТО ЕЩЁ УВИДЕЛ НА ЭТОМ ЖЕ ЭКРАНЕ (личный визуал, тот же заход)
- `Queue Grid` здесь **РАБОТАЕТ** — 5 очередей, числа Answered 176/85/66/48/72, метка `Live`.
  То есть `QGRID-78-RTS` — дефект КОНКРЕТНОЙ регистрации грида 78, а не класса виджета. Сужает поиск.
- `Agent State Distribution` — вечное `Connecting...`, график не появляется (`ASD-CONNECTING`, ПОДТВЕРЖДЁН).
- `Agent Grid Support` — `No agents match filters`, пагинация `/ 0`, при этом в Queue Grid
  `logged In` = 2 по очереди `תמיכה`. Агенты в системе есть, в гриде агентов их нет. Новая находка,
  помечаю `AGRID-EMPTY-VS-QGRID`, требует отдельного разбора.
- `Info Slot` — текст обрезан по правому краю (`System Administrato`), `INFOSLOT-CLIP` ПОДТВЕРЖДЁН.
- На `/screens` в разметке присутствует `An unhandled error has occurred.` — упавший Blazor-контур;
  из-за него клики по списку не срабатывали, пока я не перешёл по прямому URL. `SESSION-DROP`,
  подтверждён механизмом: контур падает, страница выглядит живой, клики молча игнорируются.


### DAYTREND-CULTURE-SEP — правка в дереве, гейт НЕ снят (🔴 OPEN)
`v3 = ab20897` (backend-0831): три строки + два `using System.Globalization`.
Сквозная проверка границы на самом коммите: культурно-зависимых масок вне отображения — 0;
20 отображающих вызовов в `.razor` не тронуты. Диск == дерево побайтно. Непушенных 5.
**Гейт не снят: редеплоя на 234 НЕТ.** Ивритская проверка на дореплейсной сборке ничего не значит.
Блокер — слово оператора на выкат: рестарт `RTMService` ОБЯЗАН сопровождаться рестартом `RTMTwilio_1`.


## SEC-XMLCRYPTO-HIGH — стоячая уязвимость в поставке, поднято devops-0831 (🔴 OPEN, не блокирует выкат)
Сборка `ab20897` (22:26, машина оператора) дала пять advisories HIGH SEVERITY на ОДИН пакет:
`System.Security.Cryptography.Xml` 8.0.3 — `GHSA-23rf-6693-g89p`, `GHSA-8q5v-6pqq-x66h`,
`GHSA-cvvh-rhrc-wg4q`, `GHSA-g8r8-53c2-pm3f`, `GHSA-mmjf-rqrv-855v`. Тянется через `CcDashboard.Web`
и `CcDashboard.Infrastructure`.
**Почему НЕ блокирую сегодняшний выкат:** тот же пакет уже стоит в развёрнутом `141899b`, то есть это
не регрессия однострочной правки, а стоячее состояние. Блокировать фикс DayTrend из-за него было бы
подменой задачи. Но пакет с известными уязвимостями едет в прод и едет давно — это отдельный предмет.
Там же `EF1002`: `SqlQueryRaw` с интерполяцией, `InfoSlotHandlers.cs:153` и `:239` — предупреждение
об SQL-инъекции от самого EF.
Оба факта — не вердикт devops и не мой; поднимаю в реестр, чтобы не растворились в 40 строках warning.
Владелец разбора: security (вне этапа). status: 🔴 OPEN


### DAYTREND-CULTURE-SEP — ГЕЙТ СНЯТ ПО ВИЗУАЛУ (ЧП п.4), 2026-08-31T20:1xZ
Личная проверка координатора-0831 после выката `ab20897`, локаль `he-IL`
(`?culture=he-IL&ui-culture=he-IL`), экран `ca5c23ac-…`, вход выполнен оператором.
**`Day Trend Chart` ПОЛОН ДАННЫХ в ивритской локали:** 4 серии, шкала 07:00–19:00,
`Last updated: 23:07:37` по часам сервера. Разметка RTL — то есть локаль действительно ивритская,
а не английская под другим адресом. Отрицательный контроль дня: в той же локали до выката — пусто,
`Got 0 interaction rows` ×3210.
**Половина гейта по логу (`Got N rows`, N>0, и `Date=` через КОСУЮ) — запрошена у devops.**
До неё вердикт: 🟢 подтверждён визуально, ⏳ ждёт числовой половины. Закрытие — слово оператора.

### ПОБОЧНО: ASD-CONNECTING БОЛЬШЕ НЕ ВОСПРОИЗВОДИТСЯ
`Agent State Distribution` на том же экране теперь РИСУЕТСЯ: оси 0–1.0, категории
`AVAILABLE / BREAK / ONPHONE / PAPERWORK / TRAINING`, метка `agents 0`, `Live`.
Вечное `Connecting…`, зафиксированное мной в 16:3xZ, ушло. Причина ухода НЕ УСТАНОВЛЕНА — совпало с
рестартом службы, и это ровно тот случай, когда «починилось само» означает «причина не найдена».
Понижаю до 🟡 НЕ ВОСПРОИЗВОДИТСЯ, НЕ закрываю: симптом «пустой зал» (`agents 0`) остался,
и связка с `AGRID-EMPTY-VS-QGRID` (в очереди `logged In` 2, в гриде агентов 0) не разобрана.


### ✅ DAYTREND-CULTURE-SEP — ЗАКРЫТ. CONFIRM ОПЕРАТОРА 2026-08-31T20:2xZ («да»)
Полный путь реджекта, для истории:
симптом «DayTrend пуст» -> замер лога devops (ветка 2: `Got 0 interaction rows`, функция исполняется,
очереди есть, исключений нет) -> причина по коду (`ToString("dd/MM/yyyy")` без `InvariantCulture`;
`/` в .NET-формате подменяется разделителем культуры; `he-IL`/`ru-RU` дают точку) -> правка `ab20897`
(3 строки + 2 `using`) -> сборка на машине оператора -> ручной выкат только шелла на 234 ->
гейт в ивритской локали: график полон, `Last updated: 23:07:37`.
**Первый реджект дня, доведённый от симптома до подтверждённого исправления.**
status: ✅ CLOSED

Снятые по дороге ложные следы (чтобы не всплыли повторно):
- «формат даты — ложный след» (мой, 15:5xZ) — снят: маски совпадали, культура нет.
- «миграция функций DayTrend не применена на 5433» — опровергнута, функция исполняется.
- «у BU нет очередей / семья PR234-BU-01» — опровергнута, `Queues=[...]` в логе непуст.
- «`UnionId = -1` — сигнал» (по гриду 78) — опровергнут третьей точкой данных.
Уроки в §B: (1) маска формата — не значение; (2) поведение выводить из тела скрипта, а не из имени
флага (`-SkipRTM` не мешает остановке службы); (3) число/sha из документа предшественника — не пин.


## AGRID-FILTER-STUCK — причина найдена ЧТЕНИЕМ, без единого замера (🔴 OPEN)
> coordinator-0831, 2026-08-31T20:3xZ. Ранее вёл это как `AGRID-EMPTY-VS-QGRID`, переименовываю:
> расхождения между гридами нет, есть залипший фильтр.

**Симптом:** `Agent Grid Support` пуст, счётчик страниц `/ 0`, при этом в соседнем `Queue Grid`
по очереди `תמיכה` стоит `logged In = 2`. Читалось как «агенты есть в системе, но грид их не видит».

**ЧТО НА САМОМ ДЕЛЕ.** Виджет имеет ТРИ разные пустые ветки, и они означают разное
(`AgentGridWidget.razor`):
| ветка | строка | текст на экране | смысл |
|---|---|---|---|
| грид не настроен | `:29` | `GridId == 0` | конфигурация |
| данных нет | `:53-58` | `Widget_NoAgents` + иконка людей | зал пуст |
| **все строки отфильтрованы** | `:106-118` | **`Widget_NoMatchingAgents` + кнопка `Clear filters`** | **данные ЕСТЬ** |

На экране я видел **третью**: «No agents match filters» и кнопку «Clear filters». Эта ветка
достижима ТОЛЬКО при `_rows.Count > 0` — иначе рендер уходит во вторую и до таблицы не доходит.
**Значит агенты приходят в виджет, и их скрывает сохранённый фильтр по колонке.**
Фильтры персистентны: `:364-368` `LoadWidgetStateAsync()` при первом рендере восстанавливает
`_columnFilters` из сохранённого состояния виджета. То есть фильтр, поставленный когда-то однажды,
переживает перезагрузку страницы, рестарт службы и выкат.

**Это не дефект данных и не дефект движка.** `logged In = 2` в Queue Grid и пустой Agent Grid
непротиворечивы: первый считает по очереди, второй показывает то, что прошло фильтр.
Моя формулировка «агенты есть, а грид их не видит» была неверна по механизму — снимаю.

**Открытый вопрос — что именно за фильтр и откуда.** Если его никто не ставил руками, это дефект:
состояние сохраняется само и не сообщает о себе. Индикатор активного фильтра в шапке колонки есть
(`:94` `bi-funnel-fill` против `bi-funnel`), но он мелкий и на тёмной теме почти не читается —
пользователь видит «пустой грид», а не «включён фильтр».

**Проверка ценой одного клика (оператору):** нажать `Clear filters` в этом виджете.
Агенты появились — подтверждено, дальше вопрос «кто поставил фильтр и почему он молчит».
Не появились — моя ветка неверна, идём в данные.
Сам не нажимаю: это изменение сохранённого состояния виджета на экране оператора. status: 🔴 OPEN


## QGRID-LOGGEDIN-DUP — «logged In = 2» при пустом зале: метрика устаревшая и движок на ней падает (🔴 OPEN)
> coordinator-0831, 2026-08-31T20:5xZ. Поднято фактом оператора: «сейчас нет подключённых агентов».
> Разобрано чтением каталога метрик и сопоставлением с уже зафиксированными ошибками движка.

**Факт оператора:** подключённых агентов сейчас нет. **Факт с экрана:** `Queue Grid`, очередь
`תמיכה`, колонка `logged In` = **2**, виджет помечен `Live`. Соседний `Agent State Distribution`
на том же экране показывает `agents 0`. Два виджета одного экрана противоречат друг другу.

**ЧТО НАШЛОСЬ В КАТАЛОГЕ МЕТРИК** (`docs/metrics-catalog.json`, запись `QueueNumberOfLoggedAgents`):
- `"status": "duplicate"`, `"displayName": "Logged In Agents (duplicate)"`;
- `"duplicateOf": "QueueLoginDataNumLoggedUsers"`, и в таблице дубликатов (`:24-27`) канонической
  названа именно она;
- `"comparison": "Use QueueLoginDataNumLoggedUsers as the canonical metric."`;
- и главное по смыслу: **«Counts agents of the Business Unit currently logged in»** плюс
  «the engine ignores DataType for status counters».
  То есть это счётчик **по бизнес-юниту, а не по очереди**. В строке очереди он в принципе не может
  быть числом «залогинено в ЭТОЙ очереди» — он одинаков для всех строк грида по построению.

**СМЫКАНИЕ С УЖЕ ИЗВЕСТНОЙ ОШИБКОЙ.** В хендофе зафиксировано с прошлого захода:
`KeyNotFoundException 'QueueNumberOfLoggedAgents'` (`Engine.cs:671`) — **125 раз**, unions
**74/75/76/78**. Это ТА ЖЕ метрика. Движок на ней бросает исключение, значит значение по ней не
обновляется; на экране остаётся то, что легло раньше. Отсюда `2` при пустом зале — **не «двое
залогинены», а «последнее удавшееся значение, которое никто не перезаписал»**.

**Гипотеза владельца — конфигурация экрана, а не движок:** в виджет выбрана deprecated-метрика,
у которой в каталоге прямым текстом написана каноническая замена. Правка — замена метрики в колонке.
**Не вердикт:** сначала нужно подтвердить, что исключение по этой метрике идёт СЕЙЧАС, а не только
в старом заходе. Запрос devops (читающий, вместе с уже висящим грепом).

**Класс дефекта, который стоит назвать отдельно:** виджет с меткой `Live` показывает число, которое
не обновляется, и ничем не отличает «свежий 0» от «застрявшей 2». Молчаливое устаревание на живом
дешборде опаснее пустого виджета: пустой виден, застрявший — нет. status: 🔴 OPEN


## CATALOG-UNSHIPPED — `metrics-catalog.json` живёт на сервере, но не поставляется сборкой (🔴 OPEN)
Поднято devops-0831 при разборе остаточных файлов после ручного выката.
Файл `docs\metrics-catalog.json`, 319 КБ, дата **14 июля**, присутствует в живом каталоге шелла на 234
и ОТСУТСТВУЕТ в сборке `ab20897`. Следствия: при чистой установке каталога не будет вовсе; сейчас он
на два месяца старше кода, который его читает.
**Задевает мой же сегодняшний вывод:** рассуждение про `QueueNumberOfLoggedAgents` (`status: duplicate`)
я построил на РЕПОЗИТОРНОЙ копии. Серверная может быть другой. Запросил `SHA256` серверного файла;
до сверки вывод по метрике держу как гипотезу, не как факт.
Класс: **артефакт, который продукт читает в рантайме, но не везёт с собой** — родственник дефектов
инсталлятора (машинный артефакт едет как продуктовая константа), только зеркальный: продуктовый
артефакт НЕ едет вовсе. status: 🔴 OPEN

## §B-УРОК (coordinator-0831, 2026-08-31): ноль из непроверенного источника
devops отказался засчитать `TOTAL matches: 0` как ответ, потому что (а) лог движка не писан с 29.08,
(б) каталог `C:\Logs\RTMView` был пропущен фильтром `*.txt`. Формулировка для §B:
**отрицательный результат действителен только вместе с доказательством, что источник живой СЕЙЧАС.**
Иначе «не нашлось» неотличимо от «не искали», и закрывает вопрос ложно.


### CATALOG-UNSHIPPED — сверка выполнена, риск по моему выводу СНЯТ
`SHA256` серверного и репозиторного `metrics-catalog.json` равны побайтно:
`8DE3A0981973F593A448A694E40F6D0C4FE08464F234F38D075510CB72FFF1CD`, 319549 b.
Мой вывод по `QueueNumberOfLoggedAgents` построен на том же файле, что читает сервер — пересборка
не нужна. В силе остаётся только непоставляемость файла сборкой. status: 🔴 OPEN (сужен)

### QGRID-LOGGEDIN-DUP — третье независимое указание на ту же метрику
devops-0831: в логах шелла 27 строк вида `Detected column types: … QueueNumberOfLoggedAgents=text …`,
тогда как соседние очередные метрики `=number`. Каталог объявляет `"valueType": "number"`.
Итого три независимых указания на один идентификатор: (1) `status: duplicate` + названная каноническая
замена, (2) историческое `KeyNotFoundException` (`Engine.cs:671`, 125 раз, unions 74/75/76/78),
(3) тип на проводе расходится с типом в каталоге.
**Владелец НЕ пришпилен:** все три — про метрику, ни одно не объясняет, почему на экране `2` при
пустом зале. Ждём греп в `C:\RTMView\RTM\Logs\RTM.log` — путь к логам движка найден только сейчас.


### QGRID-LOGGEDIN-DUP — моя ветка «застрявшее значение» НЕ ПОДТВЕРДИЛАСЬ. Снимаю.
Замер devops-0831 в `C:\RTMView\RTM\Logs\RTM.log` (23:35 по часам сервера):
`KeyNotFound` по `QueueNumberOfLoggedAgents` — **994 вчера / 0 сегодня**. Числа вчерашних совпадений
метрики и вчерашних `KeyNotFound` равны до единицы, то есть исключение прекратилось.
**Моя связка «`2` на экране = застрявшее значение падающей метрики» не подтверждается — снимаю её.**

devops справедливо сузил и обратный вывод: на УСПЕШНОМ вычислении метрика не логируется вовсе,
поэтому ноль совместим и с «перестала падать», и с «перестала запрашиваться». Различаю его НЕ логом
движка, а фактом из логов шелла того же дня: **27 строк `Detected column types: …
QueueNumberOfLoggedAgents=text …` за сегодня** — значит шелл метрику СЕГОДНЯ запрашивает и получает.
Следовательно верна первая ветка: **метрика жива, `2` — значение, которое движок отдаёт сейчас.**

**Куда это двигает предмет.** Вопрос перестаёт быть «почему не обновляется» и становится
**«что движок считает этой метрикой при пустом зале»**. Остаются в силе два факта из каталога:
она считает агентов БИЗНЕС-ЮНИТА, а не очереди (значит в строке очереди вводит в заблуждение
by design), и она `status: duplicate` с названной канонической заменой
`QueueLoginDataNumLoggedUsers`. Плюс расхождение типов: на проводе `text`, в каталоге `number`.
Владелец — движок либо конфигурация экрана; **НЕ пришпилен**, следующий шаг требует сравнения
`QueueNumberOfLoggedAgents` против канонической метрики на одном и том же зале. status: 🔴 OPEN

## ENGINE-ERRORS-1719 — контрольная величина, которую нельзя оставлять внутри контрольной строки
devops-0831, тот же проход: **1719 строк ERROR/FATAL в логе движка за неполные сутки** (31.08).
Не разбирал, вердикта нет ни у него, ни у меня. Поднимаю отдельным предметом: полторы тысячи ошибок
в сутки на тестовом сервере, читающем прод, — это фон, в котором любой новый дефект неразличим.
Разбор — отдельный заход, не сегодняшний. status: 🔴 OPEN


## ⭐ QGRID-78-RTS — МЕХАНИЗМ НАЙДЕН ЧТЕНИЕМ. Гипотеза с проверкой в одну выборку.
> coordinator-0831, 2026-09-01T00:0xZ. Источник: `SaveQueueGridRtsCommand.cs` целиком + числа
> замера devops от 15:35Z. Ни одного нового обращения к серверу.

**Что показал замер:** грид 78 — движок держит **1 строку / 0 колонок / 12 ячеек, все непустые**;
конфиг виджета знает **4 строки × 12 колонок = 48** идентификаторов ячеек; пересечение **0**.

**Что это за одна строка.** `Step 3` (`:96-105`) создаёт ЗАГОЛОВОЧНУЮ строку с `RowNumber = 1` и
`UnionId = -1`. Замер devops дал `UnionId = -1` — **это она и есть**. Уцелела ровно шапка.

**Что это за 12 непустых ячеек при НУЛЕ колонок.** `Step 4` (`:118-133`) кладёт заголовочные ячейки
с `CellType = "Text"` и `Value = имя колонки`. Двенадцать — ровно столько колонок в конфиге.
**Ячейки без колонок = осиротевшие заголовочные ячейки прежней 12-колоночной раскладки.**

**КАК ЭТО ПОЛУЧИЛОСЬ — три удаления в одном сохранении:**
| шаг | строки | что делает | результат на 78 |
|---|---|---|---|
| `Step 2` | `:71-78` | удаляет колонки, которых нет во ВХОДЯЩЕМ списке | колонок стало **0** |
| `Step 5` | `:135-152` | удаляет строки, которых нет во входящем списке (кроме шапки) | строк стало **1** |
| `Step 4` | `:107-115` | удаляет осиротевшие заголовочные ячейки — **но только те, что перечислены в `ExistingHeaderCellIds`** | ячейки **НЕ удалены**, осталось 12 |

**Все три согласуются с ОДНИМ событием: сохранение виджета пришло с ПУСТЫМИ списками
`Columns` и `Rows` и пустым `ExistingHeaderCellIds`.** Пустой список читается обработчиком не как
«нечего менять», а как «удалить всё» — это `Except`-семантика без единой защиты от пустого входа.
Третий словарь тоже пришёл пустым, поэтому чистка шапки не сработала и ячейки осиротели.
Ни одна ветка не проверяет, что входящая раскладка непуста; ни одна не логирует массовое удаление.

**Откуда пустые списки.** Известно с прошлого захода: `ScreenEditorPage.razor:3017 -> :3030 -> :5041`
— `SaveLayout` отправляет ВСЕ виджеты экрана разом, а `ScreenFullscreenPage:315-325` глушит ошибку
пустым `catch {}`. Виджет, чей конфиг на момент сохранения ещё не загрузился, уезжает пустым и
стирает свою регистрацию. Это НЕ доказано — это следующий шаг.

### ПРОВЕРКА — одна выборка, читающая, решает всё
Взять `Value` двенадцати уцелевших ячеек грида 78.
**Если это ИМЕНА КОЛОНОК** (`Waiting`, `Wait Time`, `Answered`, `logged In`, `Available`, `Incoming`…)
— механизм подтверждён окончательно: уцелела шапка, погибли колонки и данные.
**Если там числа или пусто** — моя ветка неверна, и это не осиротевшая шапка.
Отрицательный контроль есть даром: у исправного грида 29 те же ячейки должны читаться так же,
но при 6 живых колонках.

**Правка (после подтверждения) — защита от пустого входа в обработчике:** отказ выполнять удаление
колонок/строк, если входящий список пуст, а в базе записи есть; плюс запись в лог факта массового
удаления. Это чинит класс, а не случай.
⛔ Виджет 78 по-прежнему НЕ пересохранять. status: 🔴 OPEN, механизм найден


### QGRID-78-RTS — половина моей гипотезы СНЯТА devops-0831 (2026-09-01T05:2xZ)
Колонки грида 78 **живы** и висят под другим `GridId`. Значит **удаления не было — была
переадресация**, и моя формулировка «пустой вход стирает всё» не объясняет ЭТОТ случай.
**Снимаю её как объяснение 78** (как отдельный класс риска в обработчике она остаётся, но это другой
предмет и другая правка — благословлять правку по неверному механизму нельзя).
**Что из моей ветки устояло и подтверждено:** уцелевшая строка — заголовочная (`RowNumber=1`,
`UnionId=-1`), а 12 непустых ячеек при нуле колонок — осиротевшие заголовочные ячейки с ИМЕНАМИ
колонок. Механизм сиротства верен, причина — нет.
**Новая рабочая ветка:** `Step 1` (`:54-58`) пересоздаёт грид, когда `GridId` пуст или не существует
(`InsertQueueGridAsync`), колонки уходят в НОВЫЙ грид, а конфиг виджета остаётся указывать на старый
номер. Проверка — один `SELECT` по двенадцати `ColumnId`, предикат зафиксирован до прогона.
Побочный след, НЕ трактуется до ответа: номера колонок идут двумя партиями (632-639 и 649-652).

## PR234-VIEWEDIT-01 — экран в режимах view и edit выглядит по-разному; в edit правый край обрезан
- **Заявлен:** оператором 2026-09-05. Экран `01a04c39-caac-7107-8d59-d40fb48a94fa`
  («בזק - ניהול משמרת פרטי»), сервер `platform.insightense.com:8444`.
- **Проверено координатором лично** (ЧП п.4), оба режима, одна вкладка, одно окно, подряд:
  - **view** (`/screens/{id}`): содержимое вписано целиком, ничего не обрезано. Полоса виджетов
    занимает ~590..1470 px, крайний правый Data Slot («נציגים מחוברים») виден полностью.
  - **edit** (`/screens/{id}/edit`): слева пустое поле разметки в клетку (~10..530 px), содержимое
    сдвинуто и **обрезано по правому краю** — крайний правый Data Slot («נציגים מחוברים») срезан,
    его значение видно частично. Присутствуют горизонтальная и вертикальная полосы прокрутки холста.
- **Данные в обоих режимах ОДИНАКОВЫЕ** (те же 5 строк Queue Grid, те же значения, тот же пустой
  Agent grid) — расхождение чисто в раскладке, а не в содержимом.
- **Контекст, который может быть или не быть причастен — НЕ предикат:** экран правосторонний (иврит,
  RTL); в продукте есть переключатель масштаба просмотра (`viewerScale`, «Actual size 1:1»), заведённый
  в PR234-1c. Совпадает ли обрезка с этим механизмом — НЕ ПРОВЕРЕНО, версий не строю.
- **Класс НЕ ОПРЕДЕЛЁН.** Разбор требует роли shell/frontend (код раскладки редактора), она не поднята.
- **Закрывается ТОЛЬКО словом оператора.**
- **Статус:** OPEN.
