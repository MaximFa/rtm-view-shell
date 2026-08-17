# HOT-RELOAD МЕТРИК — MEETING BRIEF (2026-06-09, coordinator-0609)
> Общая задача + территории + контракт + ОДИН открытый шов. Каждая сессия: прочитай, подтверди свою
> территорию, ратифицируй Option A (или контр), ack SignalR-контракт. Это canonical shared understanding.

## ОБЩАЯ ЗАДАЧА (одной строкой)
Добавить новую метрику в работающую систему БЕЗ рестарта RTM Service — метрика компилируется вживую на Deploy,
через SignalR, ИНКРЕМЕНТАЛЬНО (одна метрика по MetricId, НЕ full-reload).

## FLOW end-to-end (сошлись все 4)
1. METRICS: опросник -> метрика определена -> МИГРАЦИЯ в RTSGrid_Metric (+history mirror) -> dev-валидация ->
   git -> в INSTALL-ПАКЕТ (migration + manifest).
2. КЛИЕНТ: Shell-вкладка "Deploy new metrics" показывает НЕ-задеплоенные (дельта: package MetricId ∉ ledger) +
   кнопка Deploy (Superadmin).
3. Deploy -> Shell ТРИГГЕРИТ devops apply-service (НЕ web-DML).
4. DEVOPS apply-service: применяет метрик-миграцию как catalogue-owner (INSERT в RTSGrid_Metric) + пишет
   per-metric ledger-строку (§38a: {MetricId, deployedAt, sourceCommit}) + audit System.MetricsDeployed.
5. На успех apply -> SignalR compileMetrics(MetricId[]) -> RTM Engine.HotReloadMetrics: инкрементально
   компилит ТОЛЬКО эти RT-MetricId (history-половину пропускает), additive, ConcurrentDictionary-safe.
6. Метрика live, без рестарта.

## ТЕРРИТОРИИ (подтверждены ответами)
- METRICS (metrics-2): данные/домен + опросник->migration + КОНТРАКТ (docs/metrics-hot-reload-contract.md).
  НЕ UI, НЕ apply, НЕ compile.
- SHELL (shell-0609): вкладка "Deploy new metrics" (MetricsPage.razor) + Deploy-ТРИГГЕР + читает ledger для дельты
  + логирует триггер. НИКАКОГО DML, НЕ apply.
- DEVOPS (devops-2): apply-at-client (привилегированный apply-service: migration + ledger + audit) + per-metric
  ledger (§38a, = read-side E-010b, один механизм два потребителя).
- BACKEND (backend-0609): RTM incremental compile (Engine.HotReloadMetrics(MetricId[])) + RTMHub.compileMetrics(string[]).
  _metrics + Union.AllDataMetrics -> ConcurrentDictionary.

## КОНТРАКТ-ИНТЕРФЕЙСЫ (залочено)
- Package (Metrics) -> migration + manifest.
- Shell trigger -> devops apply-service (apply + ledger). [Stitch 2: ratified, UNANIMOUS — least-privilege, CODE-03, no web-DML.]
- Ledger (devops §38a) -> Shell delta (package MetricId ∉ ledger-applied). [Stitch 1: ledger, НЕ просто manifest-diff —
  devops строит один раз для E-010b + metric-deploy.]
- SignalR: compileMetrics(string[] metricIds) -> RTM, fire-and-forget, ТОЛЬКО RT-MetricId. [Stitch 4: предложение
  Backend — Shell ack.]
- Audit: System.MetricsDeployed пишет apply-owner (devops); Shell логирует триггер отдельно.

## ОДИН ОТКРЫТЫЙ ШОВ — РЕШИТЬ
Кто дёргает SignalR compileMetrics ПОСЛЕ успешного apply?
- Option A (РЕКОМЕНДУЮ): SHELL дёргает. Shell владеет RtmRelayService HubConnection (§34). Flow: Deploy -> триггер
  devops apply -> на успех Shell вызывает compileMetrics через RtmRelayService. apply-service остаётся compile-agnostic
  (чистый apply+ledger). Окно <1с, идемпотентно (TryAdd).
- Option B: devops apply-service дёргает post-apply (нужен apply-service -> RTM SignalR/RtmRelayService доступ).
=> Рекомендую A. Плюс ответ на вопрос Shell «как Deploy достигает apply-service»: отдельный Shell->ops apply
endpoint/queue (НЕ SignalR-к-RTM; RTM миграции НЕ применяет). devops определяет контракт endpoint'а.

## UNTRACKED артефакты к git-дому (E-023 дисциплина — следующий барьер)
- docs/metrics-hot-reload-contract.md (Metrics) -> docs: commit.
- tools/cc_prompt_ngc_insert_fix.md (Backend, на §4).
- (orchestrator/ darkmode уже закоммичены.)

## ПОДТВЕРЖДЕНИЕ (каждая сессия флашит в инбокс координатора)
1) Моя территория верна? 2) Option A ОК (или контр)? 3) SignalR compileMetrics(string[] metricIds) ack?

## ПРАВИЛО PEER-TO-PEER (зафиксировано 2026-06-09)
Прямой обмен сессия<->сессия через .coord/inbox/<peer-slug>.md РАЗРЕШЁН и приветствуется (снижает
бутылочное горлышко координатора; §11 mailbox это и предусматривает). УСЛОВИЕ: любое дизайн-/контракт-
решение, рождённое в peer-обмене, ОБЯЗАНО вернуться в КАНОН (coordinator.md / этот brief / контракт-док).
Решение, живущее только в peer-инбоксе = невидимо координатору -> нельзя арбитрировать/харвестить =
тот же класс рассинхрона, что E-023. Edge'ы — да; единый источник правды — обязателен.
Конкретно: Shell<->devops резолвят «как Deploy достигает apply-service» напрямую -> итог флашат сюда/в brief.


## SYNC-AUDIT РЕЗОЛЮШНЫ (2026-06-09T13:30, координатор — после подтверждений 4/4)
СХОДИМОСТЬ ПОЛНАЯ: 4/4 подтвердили территорию + Option A + SignalR-контракт. Шов «Deploy->apply-service» резолвнут
(Shell<->devops peer -> canon): dedicated Shell->ops apply ENDPOINT (HTTP/queue), response = {success,
appliedRtMetricIds[], ledgerRows}. Два расхождения из аудита закрыты:

R1 — ГДЕ фильтруется history (RT-only на проводе). АВТОРИТЕТНО: metrics contract §6 — на проводе ТОЛЬКО RT-MetricId.
   Поток: devops apply-endpoint возвращает appliedRtMetricIds (history-половина ИСКЛЮЧЕНА на apply) -> Shell шлёт
   ИМЕННО этот RT-набор в compileMetrics. Внутренний history-skip в RTM (Backend) ОСТАЁТСЯ как defense-in-depth,
   НО НЕ первичный механизм: Backend НЕ предполагает, что Shell пришлёт history (контракт говорит — не пришлёт).
   => Shell шлёт appliedRtMetricIds (НЕ весь manifest). Backend internal skip = подстраховка. Метрик §6 — источник правды.

R2 — «deployed (ledger) != compiled (RTM)» при сбое fire-and-forget compile. РЕШЕНИЕ v1: best-effort + "Recompile"
   affordance во вкладке. compileMetrics идемпотентен (TryAdd) -> повтор безопасен. Окно «deployed-not-compiled»
   приемлемо для v1: (a) RTM логирует AsyncLogger.Error, (b) кнопка Recompile (тот же hub-метод) восстанавливает,
   (c) Superadmin-driven редкая операция. v2-enhancement: compile-status сигнал/бейдж в ledger. Shell добавляет
   Recompile-кнопку; Backend ничего нового (compile уже идемпотентен).

ОБА R1/R2 -> Metrics вшивает в docs/metrics-hot-reload-contract.md (§6 уже RT-only; добавить R2 как «deploy != compile,
v1 best-effort + Recompile»). Это финальный контракт; impl стартует по нему.
