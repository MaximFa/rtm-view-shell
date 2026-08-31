# .coord/backlog.md — coordinator backlog (durable, survives context-refresh)
> Next coordinator: read this + .coord/specialization.md at session start.

---
## [CRITICAL] Надёжность канала доставки сообщений сессия↔координатор
**Заведено:** 2026-06-07T15:26Z (оператор) — приоритет: КРИТИЧНЫЙ.

**Проблема:** сообщения на шине (.coord/ inbox, journal, вердикты сессий) **теряются при
кросс-view чтении** (mount async-drop, L-SC-04) → координатор не получает → переделывает уже
сделанную работу (двойная работа) → оператор вынужден вручную релеить сообщения между сессиями.

**Симптомы (наблюдённые):**
- 2026-06-07: полный flow-вердикт devops по NGC_CreateSupergroup (стр 384) НЕ дошёл до координатора —
  пришёл только короткий `> handled`-однострочник. Координатор независимо перепроверил grep'ом
  то же самое → потраченное время. Оператор вручную скопировал полный текст.
- Множественные L-SC-04 дропы строк journal/inbox в течение сессии (восстанавливались вручную из git).

**Почему критично:** подрывает весь протокол §42. Координация держится на том, что сообщение,
записанное сессией, БУДЕТ прочитано адресатом. Сейчас это не гарантировано → дубли + ручной релей.

**Что исследовать / спроектировать:**
- Root-cause mount async cross-view drop (L-SC-04): когда именно теряется, детерминирован ли.
- Надёжный механизм доставки. Кандидаты:
  - git-backed message log (коммитим сообщения — git = истина, как journal↔git reconciliation L-SC-18);
  - read-receipt handshake (адресат пишет ACK прочтения, отправитель ждёт; как append-ACKS L-SC-19, который УЖЕ решил один кейс);
  - sequence-numbers + gap-detection (адресат видит пропуск номера → запрашивает повтор);
  - single-writer append + read-back verification отправителем (записал → перечитал из свежего view → подтвердил).
- Обобщить успешные паттерны: append-ACKS (L-SC-19) и journal↔git reconciliation (L-SC-18) уже работают —
  возможно, ВСЕ направленные сообщения должны идти через git-backed или ACK-handshake канал, а не «голый» inbox-append.

**Связь:** L-SC-04, L-SC-10, L-SC-18, L-SC-19; протокол §42; кандидат в hardening на joint-сессии по специализации (.coord/specialization.md).

**Дома фикса (когда решим):** session-coord skill (новый раздел про reliable delivery) + CLAUDE.md §42.
---
## [BACKLOG] Специализация сессий → 9 роль-скиллов
См. .coord/specialization.md (заведено 2026-06-07T15:26Z). Следующая крупная joint-сессия coordinator+оператор.

### Под-случай (2026-06-07T19:33Z): неоднозначность адреса инбокса координатора
Сессии пишут координатору в **`.coord/inbox/coordinator.md`** (общий), а координатор-сессия имеет
свой `.coord/inbox/coordinator-0606.md`. devops-2 положил release-composition proposal в `coordinator.md`,
координатор сначала искал в `coordinator-0606.md` → «сообщение не дошло» (на деле дошло, не туда смотрели).
**Фикс-кандидат:** единый канонический адрес инбокса координатора (фиксированное имя, не slug-зависимое),
прописать в session-coord skill; координатор ВСЕГДА читает оба + reconcile. Часть [CRITICAL] выше.

---
## RELEASE-1 (server45 PG17) — GREEN 2026-06-07T22:06Z. Post-release backlog (owners)
Verified: B=0 (14 RTM-write PROCEDURE, RTM-SEC-002), _005 history metrics(count=2), _008 BU-scope UNAVAILABLE=t,
ledger _002/_003, Shell up, RTM restarted, RTM log clean (no 42809/42883), DayTrend renders.

**[devops] HIGH — корректность (любой будущий деплой иначе ловит B=1):**
- Влить sig-agnostic DROP SetChatMessage (staging/fix_setchatmessage_server45.sql: DROP any FUNCTION via pg_proc
  loop) в db/functions/02_rtsdata_functions.sql. На server45 functions/02 с фикс-14-arg sig дал DROP no-op →
  CREATE PROCEDURE clash → ON_ERROR_STOP halt (B=1), чинилось вручную. Durable fix обязателен.

**[devops] orchestrator hardening:**
- Shell-preserve ДОЛЖЕН включать plain appsettings.json (server45 использует его, не .Production.json → publish
  затёр, спас P3a binary-backup). 
- AUTO-rollback при падении фазы; clean RESUME (не ре-бэкапить новые бинарники при повторном прогоне).

**[devops] comparator (Compare-ToBaseline):**
- Fix false probes (_005, _20260604_001 показали MISSING ложно); itemize dim-A; ledger-backfill для pre-ledger миграций.

**[devops] regen db/schema.sql (Export-All из post-fix dev DB) + verify db/baseline.sql** — для корректных FRESH-инсталляций (A=254 drift = staleness).

**[devops] cleanup:** удалить 2 мёртвых createSupergroup overload (lines 350+373/384) или укрепить caller стр 384 на GetScalar.

**[metrics]:**
- fix _004_metrics_dedup: убрать 4 невалидные строки `UPDATE "RTSGrid_Column" SET "MetricId"` (у RTSGrid_Column нет
  MetricId; ref = RTSGrid_Cell."Value"). После — миграция applyable.
- 6 лишних метрик на server45 (QueueNumAbandonef* typos + 4) — триаж dedup/keep.
- configurator + MetricWizard dark-mode (см. routing ниже).

**[frontend/metrics] dark-mode на configurators + MetricWizard:** бинарники aae7efa включают 536415b (dark-mode
parity) → должно быть. Сначала hard-refresh (CSS cache app.css?v, §29.1). Если остаётся → coverage gap в 536415b,
чинит metrics (держит MetricsPage/MetricWizard) или frontend-сессия (anthropic-skills:frontend-design). НЕ блокер.

**Deploy commits к пушу:** f707627 (orchestrator) + 373ffd6 (BOM) + 788e2fe (preserve) + staging/
fix_setchatmessage_server45.sql (untracked, влить в functions/02).

---
## [POST-234] Self-describing deploy-state (devops + Lab) — заведено 2026-06-08 (операторский GO)
**Операционно (devops, ПОСЛЕ релиза 234):**
- Оркестратор Apply-*Upgrade.ps1: AUTO-write binary-version manifest на УСПЕШНЫЙ деплой (commit hash Shell/RTM + PG-версия + ts) -> C:\RTMView-Ops\SERVER.md / applied\_ledger.txt. Пишет КОД, не человек (E-009).
- READ-before-upgrade: оркестратор читает db_patch_history (§38a) + manifest -> вычисляет to-apply дельту БЕЗ полного Compare. Compare остаётся пост-деплой ВЕРИФИКАТОРОМ (B=0), не открывателем.
- Источник правды: per-server (db_patch_history самопишущийся + auto-manifest). Центральный реестр = опциональный КЭШ, не доверять для apply.
- Дом доков: CLAUDE.md §43 (ops-layout) + §38a.
**Метод (Lab):** self-describing deploy-state = кандидат в ПЕРВЫЕ отчуждаемые компоненты продукта #1. Бьёт в центральную ставку. Evidence E-010.
**Связь:** E-010, §43, §38a, 234-инцидент (db_patch_history отсутствовал -> археология). НЕ начинать до релиза 234.

---
## [FUTURE-FEATURE] AI-виджет RTM — заведено 2026-06-08 (оператор)
**Идея:** виджет берёт данные из RealTime/БД -> Claude API -> инсайты.
**Порядок (решено):** Concept 2 ПЕРВЫМ — кнопка на Agent Grid: анализ текущего расклада -> рекомендация старшему смены (bounded, pull, чистый data-контракт, демоабельно). Concept 1 ВТОРЫМ — чат по КЦ-данным (нужен tool-use слой доступа к RTM-БД, выше риск галлюцинаций/стоимость).
**Гейты дизайна (не детали):**
 - Курация контекста: инсайт не лучше поданного контекста (домен -> в промпт, не в модель).
 - Заземление/анти-галлюцинация (E-002/E-005 как продуктовый инвариант): каждая рекомендация цитирует фактические цифры; РЕШАЕТ человек, не AI.
 - «Что такое хорошая рекомендация» = дыра #1 (need-fitness): валидатор = старший смены, метрика исхода.
 - ИБ/приватность (§8-14): что данных КЦ покидает периметр, анонимизация, tenant data-protection — ГЕЙТ.
 - Архитектура: первый виджет с ЛОГИКОЙ (пересекает границу shell-vs-widget-library, §18).
**Cross-ref (Lab):** кандидат-СУБЪЕКТ для протокола informed-GO + dogfood (AI-инсайт-фича, построенная AI-процессом). Легитимно по правилу изоляции: реальная RTM-нужда + помеченный DESIGNED-эксперимент.
**Метод-решение (зафиксировано):** informed-GO протокол fork-1 = АГЕНТ играет не-автора первым (верхняя граница-стресс, он-тезисный тест #1); человек — второй якорь. fork-2 (субъект) — ОТКРЫТ (widget greenfield vs существующий кусок с известным незаписанным инвариантом).

---
## [FEATURE + PROTOCOL-SUBJECT] Agent Grid — управление статусом + Logout — заведено 2026-06-09 (требование)
**Требование (не AI-фантазия):** double-click агента в Agent Grid -> модалка: накопленная статистика
(донат распределения времени по Status Group + основные KPI по ISO 18295), дропдаун статусов, кнопка Logout.
**Почему лучший ПЕРВЫЙ субъект informed-GO протокола:** requirement-driven (реальная нужда, не изобретена
ради теста) -> чисто по правилу изоляции; ограничен; богат незаписанными инвариантами (killer-поверхность).
**Незаписанные инварианты (killer-тест опросника):**
 - PROPAGATION: logout/смена статуса = реальная команда в CC-платформу (Finesse/UCCE), не UI+БД. Shell —
   view-container (write-path out of scope §1) -> НУЖНА новая write-способность + обработка успех/отказ.
 - AUTHZ по скоупу: только агенты в скоупе супервайзера (queues/BU/supergroup, [PG-04], Application Layer).
 - AUDIT: новые события Agent.LoggedOut / Agent.StatusChanged (§16 их ещё нет).
 - STALENESS (E-005): действовать по ТЕКУЩЕМУ состоянию, не по снимку модалки.
 - Status Group = Agent State Definitions (§ tenant_agent_state_groups); дропдаун = валидные target-статусы;
   ISO-KPI = какие + окно (логин/смена/сегодня).
**Решение Метода:** кандидат-СУБЪЕКТ для informed-GO (fork-2). Реальная нужда + помеченный DESIGNED-эксперимент = легитимно по изоляции. Превосходит AI-виджет как первый прогон (тот — «его идея», этот — внешнее требование).
**Build:** целиком в A (как и AI-виджет). Связь: §15 permission, §16 audit, §29.6 IConfigurationApiHook, Agent State Definitions.


---
## [TASK — Backend] Hot-reload компиляция метрик (без рестарта RTM) — заведено 2026-06-09 (оператор)
**Требование:** добавление новой метрики должно проходить БЕЗ рестарта RTM Service — новая метрика
компилируется НА ЛЕТУ (hot-reload в рантайме).
**Сейчас:** метрики грузятся/компилируются в память на старте RTM (LoadData; RTSGrid_GetDataCells →
union.Metrics → RTSGrid_Metric, §36) → добавление = рестарт.
**Owner:** RTM Backend (роль #1 RTM Server). Skills: program-architector + signalr-expert +
rtm-service-expert + rtm-metrics-expert.
**Плоскости дизайна:** (1) что именно держит привязку к рестарту (компиляция выражения/MetricParameter →
in-memory реестр); (2) триггер reload — SignalR Shell→RTM / DB LISTEN-NOTIFY / polling (signalr-expert
взвесит); (3) безопасная пересборка in-memory реестра в рантайме (конкурентность, не уронить активные
union/cells); (4) границы изменений RTM↔Shell↔DB; (5) инварианты: tenant-скоуп, RTM-SEC-002 (PROCEDURE),
не сломать midnight/grid-flow.
**Порядок:** Backend освежается по архитектуре/dataflow → архитектурный анализ+дизайн → coordinator §4 →
CC-имплементация. Claims на RTM согласовать с daytrend-2/Widget (Engine.cs занят) через .coord/queue.md.

## [ROSTER] Команда специалистов (формируется, 2026-06-09 оператор) — маппинг на specialization.md 9 ролей
1. Backend (RTM Server, роль #1) — backend-0609 (поднимается). Skills: program-architector, signalr-expert, rtm-service-expert.
2. Shell (роль #4 + UX-UI) — shell-0609 ACTIVE.
3. Metrics (роль #2) — metrics-2-0607 (on-hold, resume). Skills: rtm-metrics-expert.
4. Devops — devops-2-0607 ACTIVE.
+ Widget — мигрирует из DayTrend = daytrend-2-0607 (re-designate Widget specialist). Skills: widget-planner/creator.
+ Test (QA, роль ?) — test-5-0607 (on-hold, resume). Skills: qa-expert.


---
## [PROTOCOL FIX — CRITICAL] Security = обязательный ACK в релиз-гейте — заведено 2026-06-09 (оператор)
**Упущение:** push-барьеры #1/#2 (hot-reload фича -> origin 24122c2) прошли БЕЗ Security ACK. Кворум собирался
только с реализующих сессий. §44 требует mandatory Security ack before release — гейт отсутствовал в §42.7-кворуме.
**Фикс:** Security — ОБЯЗАТЕЛЬНЫЙ слот кворума ЛЮБОГО release/deploy-барьера (не только prod). Ни push-на-деплой,
ни deploy не идут без Security ACK. Дом правила: session-coord §42.7 + CLAUDE.md §44. Security ведёт выделенная
сессия (app-cyber-security-expert + security-review skill) ИЛИ запуск security-review над changeset.
**Сейчас (этот feature):** Security-review над 24122c2 + e17d898/9db8ffd ДО любого деплоя. Surface: Roslyn runtime-
compile (RCE!), ApplyService write-path (§1), token, Deploy AuthZ/audit, tenant-scope, migration-apply.
**Method-эвиденс:** аппарат пропустил критический гейт -> security-review должен быть ВХОДНЫМ гейтом impl/deploy, не пост-фактум.


---
## [ROSTER] Security = СТОЯЧАЯ роль (одна из 9), не разовая — заведено 2026-06-09 (оператор)
Security — ПОСТОЯННАЯ специалист-сессия (slug security-0609), стоячий release-gate keeper. Мандат = security-review
ЛЮБОГО изменения/добавления/фичи/фикса перед release/deploy (НЕ привязан к hot-reload). Обязательный ACK в КАЖДОМ
deploy/release-барьере (§42.7 + §44). Идеально — ревьюит каждую фичу/изменение по мере постройки (входной гейт), и на
барьере (выходной гейт). REVIEW-ONLY: не правит код, findings -> owning-сессиям через координатора §4.
Skills: app-cyber-security-expert + security-review. Это закрывает упущение «фича уехала без Security».
ПЕРВАЯ задача (immediate): hot-reload changeset (24122c2 + e17d898/9db8ffd) — блокирует деплой 234.
Команда теперь 7 стоячих: Backend, Shell, Metrics, Devops, Widget(DayTrend), Test, +Security. (+Lab = Method-трек, отдельно.)


---
## [TOOLING BUG] coord_check_claims.py ловит module-keywords из КОММЕНТАРИЕВ на modules:/files: строках — 2026-06-09
field("modules") не срезает `# comment` -> слово "web" в комментарии shell-0609 дало ЛОЖНЫЙ module-claim web ->
ложный конфликт на devops ApplyService/Program.cs. Workaround: держать module-keywords вне комментариев. Реальный фикс:
strip `#...` в parse() перед re.findall. Низкий приоритет, но коварно (ложные блокировки claim-чека).


---
## [FAST-FOLLOW — Security compensating] hot-reload F-1/F-3 реальные фиксы — заведено 2026-06-10 (оператор: компенсаторы)
234-деплой идёт с КОМПЕНСИРУЮЩИМИ контролями (Security accept + documented boundary). Реальные фиксы = fast-follow,
ОБЯЗАТЕЛЬНЫ до prod-at-scale:
 - F-1 (RCE): grammar-allowlist-валидатор метрик (parse Parameter, allowlist полей/операторов/типов литералов,
   reject всё прочее — НЕ char-regex+keyword-blocklist, тот обходится string-concat). Код-набросок: tools/
   cc_prompt_rtm_security_f1f3.md (whitelist-версия = НЕ достаточна, переписать на AST/grammar). Owner: backend.
 - F-3 (hub authz): bearer-token на RTMHub.OnConnectedAsync (FixedTimeEquals) + shell RtmRelayService Bearer-header +
   devops провижн RTM:HubToken/RtmHub:Token. Код-набросок РТМ-стороны уже в том же промпте (готов, применим). Owner: backend+shell+devops.
КОМПЕНСАТОРЫ на 234 (documented boundary, до fast-follow): F-1 = Superadmin-only + DBA-curated пакеты; F-3 = verified
firewall-изоляция hub-порта (devops верифицирует). Документировать в docs/security-review-hotreload-0609.md (Security).


---
## [ARCH DECISION] Метрики = вендор-контролируемые продукт-константы — 2026-06-09 (оператор)
Метрики — ВШИТЫЕ в продукт КОНСТАНТЫ. Канонический список = сорс вендора (репо); версии продукта несут
неизменяемый список. Add/delete метрики = ВЕНДОР-инициируемый процесс (сначала на сорсе вендора -> в версию ->
для клиентов точечный деплой). Клиент: MetricsPage = READ-ONLY ПОЛНОСТЬЮ (вкл. описание/локализацию); ЛЮБОЕ изменение метрики (Parameter/Format/
Function/DisplayName/Description/локализация) -> ТОЛЬКО через vendor-деплой. Никаких client-side create/edit/delete/
translation. Deploy-механизм/пакет ДОЛЖЕН нести и локализацию (не только Parameter). Дом доков: CLAUDE.md §18/метрики (обновить).
=> F-1 RCE закрывается архитектурно (нет client input-пути), не валидатором и не «доверяем Superadmin».

## [EPIC — iteration 2+] Деплой-удаление метрик + ОБЯЗАТЕЛЬНАЯ замена — 2026-06-09 (оператор)
Расширить деплой-механизм на УДАЛЕНИЕ метрик (сейчас только add). КЛЮЧЕВОЕ (оператор): процесс замены — РЕЗУЛЬТАТ
СЕССИИ METRICS. Удаление НИКОГДА не «голое»: при задаче удаления Metrics ОБЯЗАНА выдать ЗАМЕНУ:
 - создать новую заменяющую метрику, ЛИБО
 - указать одну из СУЩЕСТВУЮЩИХ метрик как замену.
=> deletion-пакет несёт mapping {deletedMetricId -> replacementMetricId} (авторство Metrics, опросник).
Деплой применяет: delete метрику + RE-POINT клиентского usage (dashboards/dashboard_widgets/конфиги виджетов,
ссылающиеся на deletedMetricId) на replacementMetricId -> экраны клиента НЕ ломаются (у каждого удаления есть замена).
Usage-validation = найти где deletedMetricId используется; замена закрывает разрыв.
Многосессионное: Metrics (контракт delete+replacement, опросник-логика «выдать замену») + Shell (Deploy UI показывает
delete+replacement) + Backend (RTM убрать метрику из реестра) + Devops (apply delete + re-point). Отдельный design-раунд.
НЕ блокирует iter-1 (infra-only). Owner: координировать после iter-1 GREEN.

## [FF — Security nit] ApplyService runs LocalSystem (over-priv vs DEPLOY-01) -> dedicated low-priv service account. 2026-06-10.

## [FF — true DB-level read-only metrics] B': мигрировать seeding (DatabaseInitializer RTSGrid_Metric INSERT) на privileged/superuser-init, ЗАТЕМ REVOKE INSERT/UPD/DEL on RTSGrid_Metric FROM ccdashboard_user. После Shell read-only фикса metrics-admin write убран -> остаётся только seeding (узко). Даёт DB-level гарантию read-only. + RV-2: убрать мёртвые repo Update/Delete(RtsGridMetric) (без caller'а после b7b20e4). Post-234. 2026-06-10.


---
## [ROSTER COMPLETE] Команда из 7 стоячих специалистов собрана — 2026-06-10 (оператор)
Полный ростер Cowork-A (все стоячие специалисты, не разовые сессии):
 1. Backend (RTM Server #1)        = backend-0609   — Engine/RTM/data-flow/SQL. re-init clean 2026-06-10.
 2. Shell (Shell+UI/UX #4)         = shell-0609     — админ-портал, configurator, theming, RTL, security UI.
 3. Metrics (#2)                   = metrics-3-0609 — каталог метрик, опросник->migration, контракт, lifecycle.
 4. Devops                         = devops-2-0607  — деплой-оркестратор, пакеты, БД-роли, apply-service.
 5. Widget (RTM Widget)            = daytrend-2-0607 (РЕФРЕШ из DayTrend 2026-06-10) — widget data-logic (Grid/DataSlot/
                                     AgentGrid/DayTrend), теперь ПОЛНОЦЕННЫЙ Widget-специалист, не только DayTrend.
 6. Test (QA)                      = test-5-0607 (on-hold) — acceptance/QA, integration/security тесты.
 7. Security (release-gate keeper) = security-0609  — обязательный ACK в каждом deploy/release-барьере.
8a. DBA (#5) = ПОДНИМАЕТСЯ отдельно (оператор 2026-06-10) — реальный пробел: БД трогают devops/backend/metrics,
    дрейф ловили там (RV-2 dead-code, baseline staleness, REVOKE-нюансы, §33.8 kind). DBA = единый владелец/контроль DB.
    UX-UI (#3) = НЕ отдельно, остаётся свёрнут в Shell (оператор 2026-06-10). Итого продукт-ростер = 8 (7 + DBA).
(+ Lab = lab-0609, Method-трек на ветке lab, ОТДЕЛЬНО от продукт-ростера.)
NB: Widget = daytrend-2-0607 сохраняет slug (inbox = daytrend-2-0607.md, без миграции); на след. ходу обновит
session-файл session:RTM Widget / role:widget. Engine.cs передан backend (takeover §42.2) — Widget держит
widget-specific файлы (Handlers/Queries/Widgets/*), не RTM Engine.

## [PROTOCOL FIX] handled-marker only by RECIPIENT — 2026-06-10. Coordinator must NOT append `> handled by coordinator-XXXX` to directives it SENDS — recipients skip `> handled` blocks -> miss directives ('no new messages', Shell 08:00). The `> handled <UTC> by <slug>` is written by the RECIPIENT (its own slug) AFTER processing. Sender ends blocks with a plain signature or nothing. Candidate session-coord §11 clarification.


---
## [PROTOCOL — Lab/Coord] Auto inbox-check lifecycle hook — заведено 2026-06-10 (оператор)
**Цель (оператор):** ускорить кросс-сессийные коммуникации и снять с оператора необходимость вручную триггерить
`коорд: входящие` — сессии сами подхватывают инбокс.
**Ограничение (зафиксировано):** сессии Cowork = отдельные окна, фонового демона НЕТ. Сессия действует только в свой ход.
Поэтому «после любого ответа все сессии автоматом» буквально невозможно — переформулировано в turn-start + completion hook.
**Согласованный безопасный дизайн (НЕ «всё автоматом» — избегает раздувания контекста и перебивания активного таска):**
 1. TURN-START PEEK (дёшево): в начале каждого хода сессия проверяет, есть ли новое в её инбоксе после последнего
    `> handled` маркера. Лёгкая проверка (есть/нет N), не полная обработка.
 2. IDLE → авто-разбор: если новое есть И сессия простаивает между тасками → обрабатывает сразу (коорд: входящие семантика).
 3. MID-TASK → НЕ перебивать: если сессия в активном таске — не лезет, держит «N pending».
 4. COMPLETION HOOK: по завершении активного таска сессия в конце ответа сама спрашивает «разобрать входящие? (N новых)».
    Это ядро ценности (убирает «забыл триггернуть»), почти бесплатно и безрисково.
**Куда вписать:** CLAUDE.md §42 (session lifecycle, §42.8 таблица) + дубль-норма в скилл session-coord §8/§10
(чтобы каждая сессия подхватывала при инициации/каждый ход).
**Открытый выбор оператора при имплементации:** строгий вариант (авто-разбор и mid-task тоже) vs безопасный (выше, mid-task defer).
**Статус:** PROPOSAL, не начинать без явного GO оператора (протокол-изменение на ВСЕ сессии). НЕ во время sales/234-hold.
**Связь:** §42.8 lifecycle, session-coord skill, handled-marker convention (recipient-marks, §coordinator_handoff PROTOCOL FIXES).


---
## [PROTOCOL — Coord/Docs] Codify doc-governance into CLAUDE.md + session-coord — заведено 2026-06-11 (оператор, remark #5)
**Что:** doc-governance сейчас живёт в docs/bi/README.md + памяти техрайтера. Quorum/barrier-enforcement + release-ID +
doc-sync triage gate — это проектное правило на ВСЕ сессии, должно быть в **CLAUDE.md §42.7** (+ §44 cross-Cowork) и
дублём-нормой в скилл **session-coord §8/§10**, не в README одного домена.
**Содержимое для кодификации (согласовано 2026-06-11):**
 - techwriter = mandatory doc-sync gate в кворуме КАЖДОГО барьера (как Security для ИБ / DBA для БД).
 - Product Release ID = `RTM-REL-YYYY.MM[.patch]` (product release train, НЕ git-hash; коорд назначает, writer запрашивает);
   ревиз-таблица доков + колонка "Shipped-with (commit/barrier)" заполняется постфактум.
 - Doc-sync = IMPACT TRIAGE: no-impact -> instant READY; minor/internal -> READY + doc-debt ticket; doc-blocking
   (user-facing/schema/API/install-upgrade/security) -> HOLD до approved/. Writer указывает конкретные changed/added/
   deleted блоки и маппит на doc-секции; коорд-review = соответствие change->doc + cross-fact, НЕ редактура.
 - Folder layout approved/{doc,pdf}+editing/, both .docx+.pdf, mandatory in-doc revision-history table.
**Статус:** PROPOSAL, НЕ сегодня (протокол-изменение на все сессии; sales/234-hold). Делать вместе с
[Auto inbox-check lifecycle hook] (оба — CLAUDE.md §42 + session-coord, один заход при возврате к разработке).
**Связь:** §42.7 quorum, §44, session-coord §8/§10, docs/bi/README.md, handled-marker convention.

- [2026-06-12T09:36Z] HYGIENE (CC/native only — Cowork can't unlink, L-SC-02): (a) clear stale .git/index.lock (0-byte, 05:11; commits currently work around it via temp-index §0.4); (b) clear dba-0610 STALE db-module claim in its session file (HB 06-10, dormant) — coord_check_claims reads session-file claims not queue GRANT, so the dormant db-claim causes FALSE conflicts for future db/ work (flagged by devops-2-0607 09:35). Needs operator §42.2 confirm. Bundle into a small CC hygiene task or fold into devops's next run.

- [2026-06-12T10:49Z] DEPLOY-HARDENING (from 45 incident, owner devops): (a) BOM gate in tools/pre-commit-check.sh — every *.ps1 must start EF BB BF (Python writes drop BOM unless utf-8-sig; §35); (b) build_45 must verify package migrations/ count == repo db/migrations/*.sql; (c) NGC_CreateSupergroup sig/prokind-agnostic DROP in db/functions/01; (d) §43 PG-version matrix corrected (45=PG15.x). (a)-(d) consolidated in tools/cc_prompt_fix45_deploy_v2 (devops drafting -> §4). COORD LESSON: verify PG version from server auto-detect, not §43; package-verify must check BOM not just grep content.

- [2026-06-12T11:10Z] DOCS (techwriter, post-45-deploy): (a) native-CC archive-move — git mv superseded doc versions -> docs/archive/ (list in techwriter 11:25); (b) MASS-MIGRATION of all published docs to Data Connector template (Batch1 text/table: TZ v1.6/SAD/Security Overview/Stakeholder/Metrics Overview/Backup=A-06; Batch2 screenshot-heavy: A-02 14 shots, B-02 41 shots). Operator-decided 2026-06-12. Coordinator drafts archive-move CC prompt after deploy settles; migration batches sequence after A-01/A-07/B-01.
- [2026-06-12T11:10Z] ROSTER: Security (security-0609) REAPED by curator 11:02 — re-spin a fresh Security incarnation before the next push barrier; it must security-review the unpushed changeset (8 commits) + ACK (§44 mandatory gate).

- [2026-06-12T12:39Z] BUILD_45 GAPS (devops, post-deploy): (a) emit INSTALL.txt (-PgVersion 15 + 4 migrations + DG-1..4 + Compare); (b) bake STEP-0 ExecutionPolicy bypass + Unblock-File into INSTALL.txt (operator standing directive — mark-of-the-web on unpacked .ps1); (c) build-verify gate must assert INSTALL.txt present+non-empty (a6fd360 shipped with NO INSTALL.txt, slipped the gate). Codify STEP-0 in CLAUDE.md §35/§24.

- [2026-06-12T12:49Z] [DEPLOY-HARDENING — rollback safety-net degrades on re-run] (owner devops, design→§4; operator-confirmed). Apply-Server45Upgrade.ps1 backs up at the START of EVERY run; AutoRollback restores from the CURRENT run's backup. So a re-run AFTER a prior run damaged the DB dumps the ALREADY-DAMAGED DB (Phase 2, $backupFile is timestamped so the original file survives on disk but the script auto-restores the CURRENT run's = the damaged one) → "rollback into the corpse". Binaries (Phase 3a) are resume-guarded BUT on resume $BinaryBackupDir points at the skipped current-ts dir → auto binary-restore can't find it either. NET: re-running the orchestrator silently degrades the automatic rollback point (a contributing cause of the unstable 45 recovery, on top of the PG17-tainted backup). FIX options: (1) resume-guard the DB backup (skip re-dump if a prior-run backup marker exists — like binaries); OR (2) AutoRollback targets the EARLIEST/original backup for this deploy-attempt-chain, not the current run's; (3) fix the binary-backup pointer on resume so rollback finds the original dir. Pick + design → coordinator §4 → impl. Source: operator analysis 2026-06-12, verified in HEAD deploy/Apply-Server45Upgrade.ps1 (Phase 2 line 312/129-138; Phase 3a line 338-343).

- [2026-06-12T13:59Z] [SECURITY — RTM] .git/config origin URL embeds the GitHub PAT in PLAINTEXT (https://<token>@github.com/MaximFa/rtm-view-shell.git) — violates §13/§25 secrets-in-plaintext. FIX: rotate the PAT (it's been exposed in session context) + move auth to a git credential helper / Windows Credential Manager (remove token from URL). Owner: operator/devops. Surfaced during AD git-setup consult 2026-06-12.

- [2026-06-13T08:18:58Z] [DB — §33.8 latent routine-kind] (owner dba, fold into midnight-clear re-enable). `RTSData_MidnightClear` is defined CREATE OR REPLACE FUNCTION (db/functions/02_rtsdata_functions.sql:318) but invoked via DBAdapter.ExecuteNonQuery=CALL (DBMng.cs:466) -> 42809 'wrong object type' WHEN run. Currently DORMANT — caller `_dbMng.midnightClear()` is commented out (Engine.cs:957; consistent with RTM-SEC-001 "do not run until tenant-scope fix deployed"). FIX when midnight-clear is re-enabled: convert to PROCEDURE with sig-agnostic DROP ROUTINE/pg_proc-based DROP per §33.8/E-016. NOT a current blocker. (NGC_CreateSupergroup kind/baseline-staleness already tracked: lines ~65, 277c.)

- [2026-06-13T08:25Z] [DEPLOY/REBUILD RUNBOOK HARDENING — from 45 live rebuild, owner devops+dba, fold into cc_prompt_rebuild45_db + build_45 + CLAUDE.md §43] Gotchas hit live (devops 19:30-21:00): (1) `Web.exe migrate` MUST run from C:\RTMView\Shell (CWD=content root, else appsettings null-conn crash); (2) on a PRODUCTION Shell, beDb BackendEmulation migrate is SKIPPED (ADR-007, env-gated) -> the 3 RTM columns (CatalogCategory/DisplayName/StatusGroup) NOT created -> run migrate with ASPNETCORE_ENVIRONMENT=Testing (Production conn preserved, dev RTS seed skipped) to create them; (3) migrate seed crashes SeedSuperadminAsync 'Tenant not resolved' (CLI no tenant pipeline) — IGNORE (all 3 MigrateAsync run before it; superadmin from data/01_system) -> BACKEND follow-up: TenantContext fallback for migrate/seed CLI context; (4) PGCLIENTENCODING=UTF8 for data/02_metrics+05_translations+migrations (Windows console WIN1252 -> 0x9d/0x90 errors on Cyrillic); (5) data/* seed as postgres (SET session_replication_role = superuser-only); (6) +_002 before _010 (ledger table dependency). My §4'd rebuild runbook did NOT have (1)-(2)-(4)-(5) — devops discovered live; MUST fold into the runbook before the next fresh install.
- [2026-06-13T08:25Z] [FEATURE GAP — metric_deploy_log baseline backfill, owner Metrics+DBA, §4] Fresh install/rebuild shows ALL catalog metrics as 'Undeployed' (undeployed = catalog − metric_deploy_log; ledger empty after rebuild; nothing backfills it). RTM compiles the baseline at startup = they're live -> misleading. FIX: backfill metric_deploy_log from RTSGrid_Metric on install (migration 20260613_011, INSERT...SELECT MetricId, now(), 'baseline' ON CONFLICT DO NOTHING, self-record §38a) + clarify metrics-hot-reload-contract fresh-install semantics. Interim on 45 = the same INSERT...SELECT (operator). Open semantic for Metrics: backfill all-catalog vs grid-referenced only.

- [2026-06-13T09:46Z] [RELEASE-BLOCKER — 45 functions/schema drift] db/functions/*.sql diverge from schema.sql/C# -> 42703/42883 cascade (CreatedDatetime column + arities on NGC_GetOrCreateQueue/AgentGroup, NGC_CreateSupergroupAgentgroupMapping, RTSData_get, NGC_CreateBusinessUnit). Push barrier HELD. Resolution: determine authoritative source (DBA+backend) — beware regen-from-stale-schema.sql reverting recent db/functions fixes (a6fd360 FIX C); prefer Export-All from a known-good dev DB to regen BOTH schema.sql + functions. Then devops regen -> repackage -> re-apply 45 -> §4. ROOT: functions must be sourced from the same authoritative dump as schema, not drifting hand-maintained db/functions/ files (my rebuild runbook used the stale ones).

## [POST-MORTEM — PD-008: server-45 deploy cascade vs clean 234] — 2026-06-13T10:35Z (operator: разбор + lessons + proactive anti-staleness)
**INCIDENT:** 45 ran the SAME package as 234 PLUS the backported firefight fixes (should have been SMOOTHER) — yet surfaced a long
cascade (PG-version mismatch -> tainted backup -> failed rollback -> flapping DB -> forced clean rebuild -> 42883/42703 functions).
234 (also an in-place upgrade of an existing server) went almost clean. NOT a 'fresh-vs-renovation' difference (both in-place).

**ROOT CAUSES (corrected, verified):**
1. DOC STALE: CLAUDE.md §43 said '45=PG17'; the server is **PG15.5**. We ran -PgVersion 17 -> PG17-client backup incompatible
   with 15.5 -> rollback couldn't restore -> DB damaged. (234's PG15 was documented correctly -> no cascade.) Single trigger.
2. FORCED REBUILD: from (1) -> tainted/flapping DB -> we did a clean DROP+CREATE rebuild on 45. 234 was NEVER rebuilt.
3. DB-CONTENT STALE + masked: the clean rebuild WIPED the accumulated-correct function overloads that had lived in the DB, leaving
   only what db/functions/*.sql define — and those files had **drifted/aged** (3-param instead of 5; stale CreatedDatetime INSERT;
   RTSData_get arity-1). On 234 (no rebuild) CREATE-OR-REPLACE re-apply kept the historic-correct overloads -> no error. So 45
    EXPOSED long-existing staleness that live servers had MASKED. schema.sql itself was also flagged stale (A=254 drift).
4. Different starting DB state (45 NGC_Queues lacked CreatedDatetime; 234 had it).

**HEADLINE CONCERN (operator):** our REFERENCE-TRUTH artifacts rotted undetected — (a) deploy docs (§43 PG matrix) wrong; (b)
db/functions/*.sql drifted from real schema; (c) schema.sql stale. Live servers masked (b)/(c) until a rebuild forced the truth.

**LESSONS:** L-DEPLOY-01 verify PG version from the SERVER (auto-detect), never from the doc. L-DEPLOY-02 a clean DB rebuild
exposes stale reference artifacts that live servers mask — treat rebuild as a truth-test. L-DEPLOY-03 hand-maintained db/functions/
drift silently; they must be GENERATED from the authoritative dump, not hand-edited. (Coordinator self-lesson: my rebuild runbook
sourced functions from the stale files — propagated the rot.)

**PROACTIVE PREVENTION (owners; the anti-staleness program):**
 P1 [dba+devops] FRESHNESS-AUDIT cadence: regularly + BEFORE every release, regenerate db/schema.sql + db/functions/* + the
    PG-version matrix from a KNOWN-GOOD dev DB (Export-All). Candidate: scheduled task. = the only way to catch masked staleness.
 P2 [devops] PG-version from the server: deploy pre-flight auto-detects PG, cross-checks §43, FAILS/flags on mismatch.
 P3 [devops+dba] DRIFT-GATE before EVERY deploy: extend Compare-ToBaseline to catch function-vs-schema-vs-C#-caller drift
    (arity/kind/columns), run as a MANDATORY pre-deploy gate (not only post-deploy verifier).
 P4 [dba] SINGLE SOURCE for functions: generate db/functions/* from the authoritative dev-DB dump (same source as schema.sql);
    stop hand-editing drifting files. (Today's dba regen is step 1.)
 P5 [techwriter+coord] DOC-FRESHNESS: deploy/ops doc facts (§43 etc.) verified against the running system at release; doc-sync gate.
 P6 [devops/dba] REBUILD RULE: don't DROP+CREATE a live DB unless forced; if forced, source schema+functions+data from ONE fresh
    known-good dump (not EF-migrate + stale files mixed).
**Status:** recorded for formal разбор. Curator to harvest L-DEPLOY-01..03 into discipline-lessons; devops/dba to scope P1-P6.

- [2026-06-13T11:27Z] [PD-008 REFINEMENT + P3 BROUGHT FORWARD] 45 re-apply failed 02:335 — schema.sql's RTSData_GetInteractions body referenced CustomCallData1..20 (table has single "CustomCallData"); regen copied it. AUTHORITY MODEL refined: schema.sql authoritative for SIGNATURES (arity/kind), NOT for BODY correctness — body authority = real EF table columns + RTM-read contract. ACTION: PD-008 P3 (function-refs-vs-table-columns drift-gate) brought FORWARD as a one-time systematic scan of 01+02 BEFORE the next re-apply (dba), backend confirms read contract. Whack-a-mole avoided by scanning all, fixing once. Codify P3 as a permanent pre-deploy gate after.

- [2026-06-13T11:37Z] [PD-008 REFINEMENT #2 + coord error owned] 45 02:335: my 11:27 'strip CustomCallData1..20 (legacy body)' was WRONG — caught by dba review-gate + backend contract. 1..20 are CANONICAL (schema.sql table DDL + RTM Call.cs + SetInteraction write-21); RTM reads getters POSITIONALLY (column ORDER is a hard contract; never drop/reorder mid-list — strip would corrupt RemoteAddress/UserId/flags/ts/ServerId). ROOT = 45 TABLE drifted (un-migrated, missing the 20 cols), function body 3db705d CORRECT. AUTHORITY MODEL refined: a column-mismatch is EITHER stale-body (fix fn) OR stale-table (migrate table) — the drift-gate scan + RTM read/WRITE contract disambiguates DIRECTION; default is NOT to strip. FIX = 45 table migration (ALTER ADD COLUMN to baseline), co-authored dba+backend, applied devops; functions unchanged. P3 drift-gate must classify direction, not just detect.

- [2026-06-13T13:25Z] [DEPLOY-HARDENING — B2 PowerShell -c quote-strip] Orchestrator B2 SignalRConnectionUrl UPDATE: source L841 correctly quoted `WHERE "TenantId"`, but `& psql -c $updateSql` (L847) STRIPS embedded " at the native-arg boundary -> psql gets unquoted `WHERE TenantId` -> 42703 column tenantid. NON-FATAL (relay-URL set via UI). FIX (devops §4): use `psql -f tempfile` or `-v` for B2 (not -c with embedded quotes); scan orchestrator for other `-c "<...quotes...>"` calls. LESSON: quoting SQL identifiers in a PS source string is necessary but insufficient — PowerShell eats embedded " passed to a native exe via -c; use -f/-v for SQL with identifier-quotes.

- [2026-06-13T15:00Z] [DURABLE/anti-staleness — global kind-agnostic DROP-guard sweep in db/functions/01] backend (14:45Z) flagged: the `IF r.prokind='p' THEN DROP PROCEDURE` guard pattern is prokind-only across the WHOLE NGC set, not just the 3 mapping routines — any future stray CREATE FUNCTION would survive re-apply (the 42883 root-cause class). Compare [B] currently flags ONLY the 3 (others are procedure-only on 45, so preventive not active). Durable fix (post-45, dba): branch guard on prokind ('f'->DROP FUNCTION, 'p'->DROP PROCEDURE) globally in 01. NOT in the hotfix (don't bloat); separate hardening pass. Pairs with PD-008 P4 (generate functions from dev dump).

- [2026-06-13T17:42Z] [DURABLE/ROOT — EF BackendEmulation model ⊇ schema.sql] dba root cause: clean rebuild = `Web.exe migrate` (EF model) + db/functions/, does NOT apply schema.sql -> schema.sql-only columns/constraints/indexes (CustomCallData1..20, CreatedDatetime, MaxDuraction, uq_supergroup_agentgroup) never land on rebuild = the whole 45 drift class. Migrations _011/_012/_013 patch deployed servers; durable fix = EF model authoritative ⊇ schema.sql (A) OR rebuild applies schema.sql (B) OR hybrid (C). Decision routed Shell+backend (+devops/dba). PD-008 P-class, post-45-green. THE unifying root cause of the 45 saga.

- [2026-06-13T18:08Z] [Compare-ToBaseline enhancement package E1-E4, PD-008 P3+] OPERATOR-APPROVED. E1 mandatory PRE-deploy gate (block on runtime-critical drift, audited override). E2 SEMANTIC [A] drill: cross-ref schema objects x db/functions/* body deps (ON CONFLICT->unique exists, getter SELECT col-list + INSERT/UPDATE targets exist) -> RUNTIME-CRITICAL subsection separate from cosmetic staleness (automates the manual column[P3] + ON-CONFLICT gap-finders). E3 5th dimension IDENTITY sequence-sync (currval vs MAX(id)) -> catches 23505-class. E4 tie to EF-model⊇schema.sql (then [A]->~0). devops owns script (E1/E3), dba owns SQL/semantics (E2/E3), curator norm+AD parity. Draft->§4. Post-45 deploy-hardening. WHY: 45 showed Compare surfaced most drift ([B]=3; missing constraint+cols inside [A]'s 328) but post-deploy + under-triaged + blind to sequences.


## 2026-06-18T13:11Z | operator+Маяк | Multi-tenant custom FQDN + wildcard SSL per server
- Tenant resolution is SUBDOMAIN-based (slug.<domain>, §5 ARCH-03; §24 DEPLOY-07 wildcard cert). Domain owned: insightens.com.
- Need per-server: wildcard A record `*.insightens.com -> <server public IP>` + ONE wildcard cert `*.insightens.com` (covers all tenant subdomains; NOT per-tenant cert, NOT EV — EV cannot wildcard).
- DV wildcard sufficient (encryption == OV/EV). Options: (a) FREE Let's Encrypt wildcard via win-acme (DNS-01, auto-renew 90d, needs EuroDNS DNS-API or manual TXT); (b) paid Sectigo Instant DV + Wildcard ~EUR65/yr (1y, manual yearly renew).
- PRODUCTIZE later: how a tenant registers its FQDN, cert automation, and the case of tenants bringing their OWN custom domain (wildcard won't cover -> per-domain ACME / win-acme-per-domain).
- IMMEDIATE (today, 234): pick cert + point DNS + bind IIS 443 (operator + Маяк, ad-hoc).

## 2026-06-18T13:11Z | operator+Маяк | Curator-sync norm-candidates (3, queued; journaled in Mayak/observation-journal.md)
- N1 build/compile-verify gate: 'build 0 err' must cite a real dotnet build; object-store marker-verify != compile-verify != product-verify.
- N2 pre-push hash-sweep = ALL tracked-M (not only claimed paths); restore PD-007 truncations from HEAD before push.
- N3 write-discipline in §A (agnostic): .coord/+mount files via Python+os.fsync ONLY, never Edit; sessions write peers' inboxes directly; NEVER relay bus-writes through another session (esp. Маяк). + META: behavioural rules live in §A cardinal layer (read every init), not buried in long docs (ignored) — same class as coordinator route-not-execute drift.
- [2026-06-24T07:50:11Z] **v3 → v2-backend (trunk) integration merge** — DEFERRED (operator 2026-06-23, "позже"). v3 (Historical Reports, RTM-REL-2026.06, origin/v3=db9d18e) is pushed; v2-backend trunk lacks the reports. Maintenance v1 builds on v2-backend independently (no reports dep). When scheduled: merge origin/v3 -> v2-backend, resolve, security/QA gate, push. Owner: coordinator (captain). Priority: after Maintenance v1 / when operator calls it.

- [ ] **Migrate RTM View Shell repository to a PAID account** (git hosting) — infra/ops; owner: devops/operator. Added 2026-07-02T08:11:14Z (operator).


## 2026-07-12T23:21Z — §35 BOM cleanup (standing, non-blocking) — route per owner AFTER 140 install
Non-ASCII NO-BOM PS1 that would FAIL PS 5.1 if run (devops sweep, cb6f069):
- devops: db/tools/Regen-Schema.ps1, devops/tools/Install-RTMView.ps1
- rtm: RTM/deployment/Backup-RTMDb.ps1, RTM/deployment/Restore-RTMDb.ps1
- coord-route (unowned): scripts/Install-CcDashboard.ps1, scripts/Update-CcDashboard.ps1, staging/run_migration_004.ps1
(ascii-ok NO-BOM PS1 = cosmetic, PS5.1 fine, skip.)


## 2026-07-13T01:58Z | INSTALL CHANGESET (consolidated) — DEFERRED by operator (more pressing post-install issues first)
Full spec: `.coord/install_changeset_spec.md`. Not dispatched yet — batch when we return to install hardening.
Owners/changes: (1) backend seed FIXED platform-UUID 019e03e9-60dd-72da-bd01-648ffdb2b433 + Name-key + Seed:PlatformTenantSlug; (2) devops Install -TenantSlug; (3) devops RTM appsettings TenantId baked=019e03e9 (+ -RTMTenantId); (4) dba/db verify ALL db/data tenant-scoped rows (NGC_Site IL first) = 019e03e9; (5) devops DEFECT A pw fail-fast. Plus C/D/E/SEC shakedown findings TBD in-batch vs follow-up. Root: seed random UUID != db/data NGC_Site 019e03e9 != RTM 019e03e9 -> RTM queue/group data no-join.
Open Qs pending operator: Q1 re-provision 140 clean vs hand-align; Q2 C/D/E/SEC in-batch?; Q3 confirm 019e03e9 permanent standard.
STATUS: backend/devops/shell tenant/slug tasks HELD (not cancelled — folded into this batch).


## 2026-07-13T02:04Z | INSTALL CHANGESET — ADD item 6: provision TenantSettings.SignalRConnectionUrl
Post-install defect (140): BU Edit → Queues picker empty + Blazor "unhandled error" because `TenantSettings.SignalRConnectionUrl` for the platform tenant was UNSET. Operator set it manually → resolved.
CHANGE [devops/backend]: install must SET the platform tenant's `SignalRConnectionUrl` (RTM relay hub URL, per-server — e.g. derived from -RTMPort / an explicit `-SignalRUrl` param) so it is populated on fresh install, not hand-entered. Either seed default (backend, if a sane per-server default exists) OR inject at install (devops -SignalRUrl → tenant_settings). Decide owner when batched.
Ref: §6.2 SignalRConnectionUrl, §34 RTM relay. Folds into the consolidated install changeset (`.coord/install_changeset_spec.md`).


## 2026-07-13T03:37Z | Defect F/G/H (140 Shell restart crash) + DECISION B scope=1+2
- F: Update-RTMView -SkipShell bounced RTMViewShell -> won't restart (Shell down on 140).
- G (root): SeedPlatformTenantAsync hardcodes find-by-slug="platform" (DatabaseInitializer.cs:119/126). Operator renamed platform tenant 019f58ea slug platform->nayax (FQDN). Restart seed can't find slug=platform -> creates DUP tenant 019f5978 (empty) -> SeedSuperadminAsync -> admin absent -> CreateAsync 'admin' -> GLOBAL UserNameIndex dup (23505) -> Program.Main crash.
- H (schema, §6.2): identity.users unique index is GLOBAL UserNameIndex (NormalizedUserName only), not per-tenant (NormalizedUserName,TenantId)+(NormalizedEmail,TenantId).
- DECISION (operator): Option **B** (proper, rebuild), scope **1+2 ONLY**: (1) G = find-by-Name="Platform" + slug from Seed:PlatformTenantSlug (existing cc_prompt_platform_tenant_slug.md, un-HELD); (2) H = new EF migration per-tenant user index. Rebuild Shell + redeploy 140 (migration applied). Items 3-5 (fixed-UUID 019e03e9 default / Install -TenantSlug+baked RTM TenantId+SignalR auto / DEFECT A pw fail-fast) STAY in HELD install-changeset.
- 140 redeploy config detail: Seed:PlatformTenantSlug MUST = "nayax" (else G re-syncs slug->platform). Delete spurious 019f5978 (operator). Redeploy for B = NOT binary-only (H migration) -> Update-RTMView with migration, dba review.
- RTMService = Running (cf18c8b); NGC_Queues seal BLOCKED behind Shell up.


## 2026-07-13T10:03Z | BACKLOG (operator: "все перечисленное пока в беклог")
- Defect I: FIXED, PENDING operator CONFIRM (constitution — not closed on my inference). Save (setval) + QueueGrid zeros visually verified.
- STEP 2 (dba): baseline setval in db/data/03_rtsgrid.sql + NGC data + Provision/Restore — permanent save-23505 fix for fresh installs (140 one-time patched).
- Push v3 (cf18c8b + a261840 + f486e4c): deployed + 140 sanity GREEN, UNPUSHED — awaits operator go + quorum barrier (Sec/DBA/QA/TW).
- install-changeset 3-5 (fixed-UUID 019e03e9 / Install -TenantSlug+baked RTM TenantId+SignalR auto / DEFECT A pw fail-fast) — HELD.
- Update-RTMView drift-gate path bug (Compare-ToBaseline resolved at C:\Temp\db\tools\ not <pkg>\db\tools\) — WARN-skip, harmless.
NEW PRIORITY: client metric gap analysis (metrics specialist) → operator picks additions → baseline + UI-deploy mockup.

## 2026-07-14T10:52Z | BACKLOG (security-track): log4net 2.0.15 moderate CVE (NU1902) in RTM.Adapter.Common (§CODE-07, non-blocking) — route to security for upgrade.

## 2026-07-14T15:16Z | Defect D CONFIRMED on 140: Shell Serilog relative path -> System32. Operator hand-patched 140 (absolute path). Permanent code fix (base-dir-relative) routed to shell (batch w/ pagination).
- [dba] RTSData_getUsersStatuses TZ-guard — DEFERRED (2026-07-16). Arity-2 currently `WHERE OnDate=p_on_date`, WORKS, never had ::interval bug. JUSTIFICATION NEEDED before any convert: does agent user-status inflate on RTM restart the way cumulative interaction counts do? (statuses are point-in-time, not cumulative). Do NOT convert a working function without this. SOURCE: db/functions/02_rtsdata_functions.sql arity-2 getUsersStatuses.

## [PROTOCOL — QUESTION TO THE OPERATOR] Разобрать режим ЧП: вынести работающее в стандарт, фикцию отпустить — заведено 2026-08-17 (куратор, оператор согласен по существу, отложено)

**Статус: НЕ на этом этапе.** Оператор согласен с существом, но на развилке кросс-аккаунтинга режим не трогаем.
Запись заведена, чтобы вопрос не потерялся и чтобы следующий куратор не «прибрался» тут по своей инициативе.

**Факт (оператор, 2026-08-17):** режима ЧП фактически УЖЕ НЕТ. Он объявлен 2026-06-25 и держится намеренно,
потому что дисциплинирует: после периода разнобоя ролей (включая координатора) с катастрофическими
последствиями для продукта ЧП субъективно подняло строгость у каждой роли. Оператор сам считает это
методологически неверным.

**Проблема (куратор):** дисциплина привязана к ЛОЖНОМУ ФАКТУ, а не к нормам. Всё, что реально работает —
не срезать углы; ни одного решения мимо координатора; координатор лично визуально проверяет каждое закрытие;
проверка на реальных прод-данных — упаковано ВНУТРЬ режима со сроком «снять по команде оператора».
Значит при вскрытии фикции отвалится не строка про ЧП, а весь пакет разом. Дисциплина, держащаяся на сроке
годности, живёт до первого вопроса «а он ещё действует?».

**Предлагаемый ход (когда дойдут руки, НЕ сейчас):** не снимать ЧП, а вынести из него в
`role-skill-standard.md` то, что действительно работает, как бессрочные нормы; после этого ЧП можно
отпустить, ничего не потеряв. Разбор — по пунктам, каждый отдельно: что становится нормой, что было
временной мерой, что просто перестраховка.

**Где сидит сейчас:** `§A CORE` семи ролей из девяти (backend, bi, coordinator, dba, devops, shell, test) —
проверено 2026-08-17 через object store. Каждая сессия читает его при КАЖДОМ ините.

**ВОПРОС К ОПЕРАТОРУ (открыт):** когда разбирать — и разбирать ли вообще, или оставить как есть, приняв
хрупкость сознательно?

- [devops-0625 2026-08-29T07:16:00Z] Compare-ToBaseline.ps1 DEFECT: `-BaselineDir` leaves `$ScriptDir` unset (assigned only in else-branch L60) -> L196 dot-source RtmSchemaDump.ps1 null-Path throw. Workaround: run without -BaselineDir. Fix: derive $ScriptDir unconditionally. Part of install-changeset epic (with grant `\$` here-string + 01_init_db role-pw reset + PascalCase naming).


## [DEPLOY — РЕШЕНИЕ ОПЕРАТОРА] 234 converge @d1982de С ПЕРЕНОСОМ данных, ДО разбора багов — 2026-08-29

**Решение (оператор):** «сначала апгрейдим, потом смотрим баги, возможно часть из них уже закрыта
актуальной версией». Вариант (а): авторить процедуру переноса -> полноценный converge -> затем баги.

**Почему наивный converge был заблокирован (гейт §DB-INTAKE-01, devops-0625, read-only):**
234 стоит на `20260624093015_AddReportEntities` (**2026-06-24**), а НЕ на июльском converge — весь
июльский цикл уезжал на 140. До `d1982de` не хватает трёх App-миграций:
`DropAppOwnedBackendTables`, `PerTenantUserNameIndex`, `WfmTenantSettings`.
Первая каскадом сносит 26 app-owned таблиц с БОЕВЫМИ данными клиента. `schema.sql` DDL-only, данные не
вернёт. Пути восстановления NGC из репо НЕТ (`db/data` сеет только Site + метрики + определения гридов).
140 прошёл эти миграции на ПУСТОЙ БД (`Install-RTMView -FreshDb`) => **проверенного пути переноса у нас
не было ни разу.**

**Расслоение 26 таблиц (пины на код, дерево `d1982de`):**
- ДВИЖОК ОТСТРОИТ: Queues 61, AgentGroups 43, Supergroup 41, SupergroupAgentgroup 39, UserAgentgroup 566,
  Interaction 119052, UserStatus 25938 (`getOrCreate*` в `BusinessUnitData.cs`/`Engine.cs`, `DBMng.cs`).
- ДУАЛ (скелет движок, СОДЕРЖАНИЕ человек): `NGC_BusinessUnit` 59 — движок делает `id=id`, имена даёт
  человек (`ConfigurationCommands.cs:108`); `NGC_BusinessUnitQueueClassification` 61 — движок ставит ALL,
  состав курирует человек (`:129`).
- ЧЕЛОВЕК СОБРАЛ, автопути НЕТ: `NGC_BusinessUnitSupergroup` 36 (единственный писатель
  `ConfigurationCommands.cs:142`; улика была SG=41 vs BUSG=36 + инцидент «DE - Accounting/Support без
  супергрупп» 2026-07-22); RTSGrid Grid/Row/Column/Cell 32/62/77/338 (`SaveQueueGridRtsCommand.cs`);
  RTSUserGrid 14/2/2.
- ВОССТАНОВИМОЕ: Site 3, Metric 208, MetricTranslation 402, db_patch_history 14, metric_deploy_log 204.

**ФАКТ, ОПРОВЕРГШИЙ ОБЩЕЕ ДОПУЩЕНИЕ:** `MidnightClear` (`02_rtsdata_functions.sql:262-263`) чистит
ТОЛЬКО `RTSData_Interaction` и `RTSData_UserStatus`. **`RTSData_UserStatusLog` (202 917 строк) не
чистится никогда** — накопительная история для `fn_daytrend` и BU-резолвера. И оператор, и координатор
считали все RTSData суточным транзиентом; опровергнуто чтением кода.

**Объём переноса (решение координатора, вето за оператором):** человеческий конфиг ~700 строк +
`RTSData_UserStatusLog` целиком.

**Дефект, найденный попутно (в install-changeset):** `Compare-ToBaseline.ps1` присваивает `$ScriptDir`
только в else-ветке (L60) -> с `-BaselineDir` он null -> dot-source `RtmSchemaDump.ps1` (L196) падает.
Обход: запуск без `-BaselineDir`.

**Пред-существующий дрейф 234 — НЕ чиним в этот перенос, фиксируем как известное:** metric
`QueueNumberOfCompletedIncomingCalls` MISSING + 6 лишних (вкл. опечатку `QueueNumAbandonefCalls`);
routines 46 missing / 115 extra (baseline позади сервера, §33-профиль); constraint naming PascalCase;
2 наших лишних WFM-индекса. `align.sql` НЕ применяем — §38.5, стейл-baseline ломает рабочий сервер.
⚠ Отсутствующая метрика — первый кандидат в причину, если при разборе багов всплывёт «виджет пустой».

**Статус:** процедура переноса — у devops-0625 на авторстве, ко мне на §4. Обязательна РЕПЕТИЦИЯ на
восстановленном `rtmviewdb_20260829_1129.dump` на DEV до касания 234 (§A local-validation).
234 нетронут; бэкап парой (`dump` 19.03 MB + `C:\RTMView\Backup\20260829_1129`) цел;
пакет `29082026.1119.zip` (BUILD=0, unit 283/0, tip==d1982de) годен.


## [DEFECT — db/tools] Provision-FreshDb resync НЕ покрывает GENERATED ALWAYS AS IDENTITY — кандидат в первопричину инцидента 45 — 2026-08-29

**Находка devops-0829 в репетиции converge-234 (экспериментальная, не рассуждение).**
Блок resync последовательностей в `Provision-FreshDb.ps1` (step 7) отбирает последовательности через
`pg_depend` с `deptype='a'` (owned-by, классический `serial`). У колонок `GENERATED ALWAYS AS IDENTITY`
зависимость имеет `deptype='i'` — **они в выборку не попадают, и блок проходит вхолостую.** После прогона
`pg_sequence_last_value` у них NULL -> первый insert приложения даёт `23505 duplicate key`.

**Почему это важнее самого дефекта:** это кандидат в ПЕРВОПРИЧИНУ инцидента сервера 45
(`role-devops §B` 2026-06-07 «23505 IDENTITY seq», PD-008 P6 IDENTITY-resync). Тогда искали ошибку в
процедуре и добавили ручной шаг; если гипотеза верна — сломан был штатный инструмент, а ручной шаг лечил
симптом. Гипотеза НЕ подтверждена операторским словом и в реестр реджектов не заносится.

**Статус:** правка `db/tools/**` — территория devops, заведена как самостоятельное изменение ПОСЛЕ конверджа.
В процедуре `cc_prompt_converge234_transfer.md` используется собственный resync по `deptype='i'`, не
полагающийся на дефектный блок.

## [РЕПЕТИЦИЯ converge-234 — что она поймала] 2026-08-29

Прогон Phase R на восстановленной копии 234 (DEV) остановил три вещи, каждая из которых на 234 сработала бы
после дропа топологии:
1. **Структурный дрейф.** Дамп 234 несёт ИЮНЬСКУЮ структуру `NGC_Queues` / `NGC_AgentGroups` с колонкой
   `CreatedDatetime`; целевая `v3:db/schema.sql` определяет их как (Id, TenantId, ExternalId, Name, IsActive).
   `pg_restore --data-only` не отображает колонки — всё-или-ничего на таблицу -> 0 из 61 и 0 из 43 строк.
   На 234: топология снесена, BU и маппинги залиты, очереди и агент-группы пусты, движок ещё не поднят.
   Решение координатора: `CreatedDatetime` теряем осознанно (продукт её не читает), потеря НАЗЫВАЕТСЯ в
   артефакте; перед RELOAD обязателен структурный диф ВСЕХ 17 таблиц (обратный случай — колонок в дампе
   МЕНЬШЕ — проходит тихо и даёт зелёный счётчик при пустых полях).
2. **Дефект инструмента** — см. пункт выше.
3. **`RTSGrid_Cell.MetricId` не существует** (`v3:db/schema.sql`: CellId, RowId, ColumnId, ColNumber, UnionId,
   StyleId, CellType, Value, Tooltip, OnClick, ThresholdSetId, NewRowId, OldRowId). «Проверка висячих
   MetricId» упала бы ошибкой запроса, а не вердиктом. Ссылка на метрику живёт в `RTSUserGrid_Column.MetricId`;
   в ячейке метрика — текстом в `"Value"`. Тем же классом были испорчены проверки 2b:
   `BUQueueClass.QueueId` -> `NGC_Queues."ExternalId"` (varchar), имя BU — `"BusinessUnitName"`, не `"Name"`.
   **Класс:** предикат сочинён по правдоподобию вместо чтения схемы. Пробу написал предшественник,
   координатор принял её на §4, devops протащил — промах коллективный, старшая доля на §4-гейте.
   Норма впредь: каждый предикат VERIFY несёт пин на строку схемы, откуда взято имя колонки; нет пина —
   предикат не готов.

**Вывод для протокола:** локальная валидация на копии боевой БД (§A) окупилась в первом же прогоне. Ни одна
из трёх находок не была видна ни в object-store, ни в Compare-отчёте, ни на ревью текста процедуры.


## [DEPLOY — РЕШЕНИЕ ОПЕРАТОРА] 234 переводится под PostgreSQL 18 — 2026-08-30

**Решение (оператор, дословно):** «переводим 234 под PG18».

**Что вскрылось и заставило пересмотреть план.** Боевой PostgreSQL на 234 — **15.5** (порт 5432), при том
что `CLAUDE.md:370` утверждает «PostgreSQL 18 (production)» — **дефект документации, опровергнут сервером**.
Репетиция converge шла на PG **18**. Дамп 234 снят новым `pg_dump`, его преамбула несёт `transaction_timeout`
(GUC от 17+); `psql` с `ON_ERROR_STOP=1` оборвал бы шаг `schema.sql` **ПОСЛЕ дропа 26 таблиц**.
Промах координатора, названный им самим: **репетиция была принята без вопроса о версии СУБД на цели**, при
том что §A требует среду, идентичную проду, а версия СУБД — первый параметр этой идентичности.

**Открытие, изменившее план:** PostgreSQL **18.4 уже установлен и работает на 234**, порт 5433,
`listen_addresses='*'`, инстанс ПУСТОЙ (только postgres/template0/template1, роли `ccdashboard_user` нет).

**Принятый путь.** Конвердж целиком выполняется на инстансе 18.4: создать роль и БД, восстановить туда
закреплённый дамп, прогнать всю процедуру, и лишь в конце переключить обе `appsettings` с `Port=5432` на
`5433` и перезапустить наши службы.
Почему это лучше «починить процедуру под 15»:
- боевая БД на 15.5 **не изменяется вообще** — дропа 26 таблиц на живых данных нет;
- конвердж идёт на **той версии, которую репетиция фактически валидировала** (несовпадение версий
  разворачивается в нашу пользу);
- окно простоя сжимается с «весь конвердж» до «переключить порт и перезапустить»;
- откат = «вернуть `Port=5432` и перезапустить» при целой живой базе — **сильнее пары дампа**, которая
  остаётся сверх этого.

**Предусловия, объявленные координатором ОБЯЗАТЕЛЬНЫМИ до первого изменения на 234** (решение оператора
одобрило ПУТЬ, а не отмену проверок): точные `version()` трёх инстансов · **происхождение пустого инстанса 18**
(неустановленное = СТОП; прецедент `rtmviewdb_prodstg`) · **поимённый список всего, что ходит в `rtmviewdb`
на 5432** · `pg_hba.conf` 18 · роль с тем же паролем · расширения.

**Главный риск ИМЕННО ЭТОГО пути:** после переключения наши службы работают на 5433, а всё, что осталось на
5432 (легаси, Soma, задания обслуживания, **бэкапы**), продолжит использовать СТАРУЮ базу и разойдётся
**молча, без ошибок**. Молчаливое расхождение хуже падения.
**Второй:** окно отката ограничено во времени — с момента переключения базы расходятся; «вернуть порт»
через час теряет всё, записанное на 18. Граница должна быть названа числом в процедуре.
**Старую базу на 5432 не удалять и не останавливать** — она путь отката; её судьба — отдельное решение
оператора позже.

**Статус:** devops-0829 авторит **Rev 12** процедуры под новый путь, на §4 координатора. Всё ранее
благословлённое (§STRUCT-DIFF, слой functions/data, RELOAD с колоночной копией, IDENTITY-resync,
целостность против базовой линии источника, шаг со слагами, проба а/б, §FEED-READY) сохраняется.
`rtmviewdb_src` на PG15 больше не нужен — сносится.


## [ПОПРАВКА КЛАССИФИКАЦИИ — важно для всех ролей] 234 — ТЕСТОВЫЙ сервер, не боевой — 2026-08-30

**Факт от оператора 2026-08-30:** «234 — это не боевой сервер, это тестовый сервер, подключённый к
продакшн-среде, он только читает». Директива: **«сокращаем количество подходов»**.

**Почему это стоит записать, а не просто учесть.** Артефакты проекта описывают 234 как прод: заголовок
процедуры — `CONVERGE DEPLOY to 234 (nayax prod-parity)`; хендофы называют его прод-зеркалом; реестр
реджектов ведёт раздел `Batch: Prod 234 — RELEASE (dashboards) version`. Из этих формулировок роль,
поднятая с нуля, добросовестно выводит «боевой» — что и произошло: координатор выстроил процедуру
конверджа с тринадцатью гейтами и СТОПом на каждом, аргументируя «потерей клиентских данных на бою».
**Класс:** термин в артефактах («prod-parity», «prod-mirror») описывал СХОЖЕСТЬ СРЕДЫ, а читался как
СТАТУС СИСТЕМЫ. Цена — десятки тактов оператора за один день.

**Действующая классификация 234:**
- статус: **тестовый**; подключён к продакшн-среде **на чтение**;
- потеря данных на нём = неудобство (NGC-композицию собирали руками), **не инцидент**;
- ⛔ **но legacy RTM / RTM.Twilio / Garnet не трогаются НИ ПРИ КАКИХ условиях** — через них 234 связан с
  продакшн-средой, и перезапуск отсюда дотянется до прода. Тестовый статус здесь ничего не смягчает.

**Как это меняет процедуру converge (координатор, 2026-08-30):** тринадцать гейтов схлопнуты в **три
захода** — подготовка на 5433 / перенос / переключение, по одному докладу на заход. СТОП к координатору
остаётся только по трём поводам: (1) требуется тронуть legacy/Twilio/Garnet/5432; (2) числа не сошлись с
эталоном или базовой линией источника; (3) не установлено происхождение инстанса 18.
Проверки (§STRUCT-DIFF, RELOAD со счётом, IDENTITY-resync, целостность против базовой линии, слаги,
проба а/б) **сохраняются, но смысл их сместился**: они защищают не данные, а **достоверность разбора багов,
который идёт сразу после конверджа**. Испорченный перенос выдаст оператору наши собственные повреждения
под видом продуктовых багов — это дороже, чем сам перенос.

**К исправлению (координатор, своя территория):** формулировки «prod» вокруг 234 в `CLAUDE.md`,
в заголовке процедуры и в разделе реестра реджектов — привести к «тестовый, подключён к проду на чтение»,
чтобы следующая роль не выводила статус из слова.
