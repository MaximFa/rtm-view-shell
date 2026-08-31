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
