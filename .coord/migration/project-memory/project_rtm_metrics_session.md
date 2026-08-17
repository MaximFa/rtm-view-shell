---
name: rtm-metrics-session
description: "RTM Metrics session 2026-06-05 — каталог метрик (этап 1) ЗАВЕРШЁН, миграция 004 применена (886dfe0+2e72606), остался push"
metadata: 
  node_type: memory
  type: project
  originSessionId: a99d80cd-95be-4f9c-96c7-a5fd1d3036d2
---

Сессия "RTM Metrics" (2026-06-05). Этап 1 каталога метрик ЗАВЕРШЁН, чистка БД ПРИМЕНЕНА.

**Deliverables (verified):**
- `docs/RTM_Shell_Metrics_Overview.md` v1.1 — каталог 202→198 метрик: семейства+матрицы, дубли, ISO 18295-1 Annex A маппинг
- `docs/metrics-catalog.json` — машиночитаемый компаньон (family/channel/thresholdSec/similarMetrics/status, cleanupApplied)
- `db/migrations/20260605_004_metrics_dedup.sql` — ПРИМЕНЕНА (db: 886dfe0, web: 2e72606); после CC-прогона почищена от UPDATE по несуществующей колонке RTSGrid_Column.MetricId (привязка метрик только в RTSGrid_Cell.Value!)
- `tools/cc_prompt_metrics_dedup.md` — выполнен

**Результат чистки (проверено по HEAD):** 198 метрик; удалены QueueNumAcceptedCallbacks, QueueNumOnCallAgents, QueueNumberOfLoggedAgents (дубли — Union.cs игнорирует DataType в статус-счётчиках), QueuePctAnsweredCalls60secIncLast30min (Calc сломан: InQueueDateTime unresolved → Eval throws). Фиксы: InboundCallsOnly без Intercom; SLA80 без пробела в [ref]; 11 Description; DataType TrainingUsers. Shell: DatabaseInitializer + ASD widget (QueueNumOnCallAgents→UsersSumOnCall).

**Конвенции каталога:** "Interactions" = chat+email; Online=вкл. ожидающие, Completed=исключая; Inc=знаменатель incoming (Service Level), Ans=знаменатель answered.

**⚠ Mount gotcha:** git status может показывать M при контенте == HEAD (stale stat-cache, index не перезаписывается). Проверять через `git hash-object <f>` vs `git rev-parse HEAD:<f>`, не верить status. Cowork cache write-back добавляет padding-строку пробелов в конец файлов после CC-коммитов — лечится restore из HEAD.

**Скилл `.claude/skills/rtm-metrics-expert/rtm-metrics-expert.md` v1.1 (444 строки)** — зарегистрирован в CLAUDE.md §30.3. Содержит: engine ground truths, полный инвентарь MetricFunctions (35 Data + 50 Agent cases, verified по switch), полный справочник 9 полей, инфраструктурный pipeline §12 (Roslyn-компиляция фильтров, TransformQuery + string-literal gotcha, calc loop 2s, SignalR delivery, T/B-таймеры шлют "+timestamp" — тикает клиент, failure-matrix). Факт: RTSGrid_GetAllMetrics читает только 7 колонок — ValueType/MetricType движок не видит (Shell-only).

**Новый дефект (найден при инвентаре, НЕ исправлен):** `MonAgentCurrentLoginTimeStamp` мёртв — в каталоге функция `CurLoginTimeStamp`, в движке case `CurLoginTimestamp` (case-sensitive switch). Фикс: UPDATE MetricFunction → 'CurLoginTimestamp' в следующей миграции. Занесён в Overview §5 + catalog.json (defect-candidate).

**ЭТАП 2 — дизайн зафиксирован (2026-06-06):**
- Архитектура каталога: **ВСЁ В БД** (EF Code-First), не JSON-источник. metrics-catalog.json понижается до производного экспорта/ретайра; Overview.md остаётся как человеческий док.
- На `RtsGridMetric` добавляются **12 колонок каталога**: редакторские (DisplayName, ShortDescription, LongDescription, Comparison, StandardKpi, StandardRef), таксономия (CatalogCategory, Family, Channel, ThresholdSec — ХРАНИТЬ, не вычислять), lifecycle (CatalogStatus default active, CatalogNotes — только Superadmin). SimilarMetrics не хранить (вычисляем = та же Family). Все nullable.
- Сидинг колонок ОДИН раз из docs/metrics-catalog.json (198 карточек готовы).
- Визард/Viewer читают БД через EF. Fallback Viewer: LongDescription→ShortDescription→Description.
- **MetricId новых метрик = UUIDv7 БЕЗ ДЕФИСОВ (Guid "N", 32 hex).** Причина: Calc-движок (Union.cs:1305) делает `calc1.Replace("-"," - ")` после извлечения ключей → дефисный UUID в `[ref]` ломается. Dashless обязателен. Legacy-198 НЕ переименовываем (прописаны в RTSGrid_Cell.Value/Calc/ConfigJson) → каталог смешанный (литерные + UUID).
- Страница Metrics: при ADD MetricId генерится автоматом (UUIDv7 dashless), не вводится руками; пользователь заполняет DisplayName+таксономию+описания.
- Линтер: правило no-dash/no-dot ОСТАВИТЬ — оно теперь и охраняет от Calc-дефис-бага.
- **СЛЕДУЮЩИЙ ЭТАП после D3: hot-reload метрик без рестарта RTM** (сейчас LoadData/Engine.cs:145 читает метрики только при старте). Дизайнить всё исходя из этого — не завязывать на рестарт/редеплой.
- Скилл rtm-metrics-expert §4: конвенции именования переписать (PascalCase/family-naming = legacy; новые = UUID).

**Готовые промпты (свободные пути, ждут запуска):** tools/cc_prompt_lint_coverage.md (но при «всё в БД» coverage-гейт не нужен — пересмотреть), tools/cc_prompt_metric_change.md (процедура add/edit/delete — обновить под UUID+БД).

**ЭТАП 3 — ВЫПОЛНЕНО (2026-06-06):**
- D3a (commits 7703903 web + 1237811 db + adeebca docs): 12 колонок каталога на RtsGridMetric (в BackendEmulationDbContext! миграция в Migrations/BackendEmulation/, НЕ App), EF-миграция, бэкфилл 198/198 из metrics-catalog.json, линтер на новые колонки. Все nullable.
- D3b (deb1d00 web + 63babe6 test): DTO/query/command +12 полей; ADD генерит MetricId=Uuid.NewSequential().ToString("N") (UUIDv7 dashless, клиентский id игнор); MetricsPage редактирует карточку; 6 тестов (regex ^[0-9a-f]{32}$).
- ВИЗАРД W1-W3 — LIVE-проверен оператором, работает:
  - W1 (9429f02): MetricWizard.razor+css (Components/Shared) — поиск, чипы категорий, 3 фасета (Family/Channel/Threshold), карточка, draggable, dark-mode; MetricCatalogFilter.cs (чистый, исключает duplicate/deprecated, IsDefect) + 24 unit-теста; L-34 локализация 3 resx. Читает GetRtsGridMetricsQuery.
  - W2 (200664a + z-index fix 1898c88): пилот Queue Grid column picker → MetricWizard MetricTypeFilter=Data. ⚠ BUG: визард рендерился ЗА конфигуратором (z-index 1050 < .editor-modal 10001); фикс → .metric-wizard-overlay z-index 10050. .editor-modal=10001, backdrop=10000 (app.css ~2515-2525).
  - W3 (a773665): раскатка на DataSlot (Data) + Agent Grid columns (Agent). DayTrend (multi-metric set) + ASD (auto status-group) ИСКЛЮЧЕНЫ — другая модель выбора, отдельный дизайн.
- Тулинг закоммичен (b006e6e): cc_prompt_* промпты + metric_longdesc_catalogtype.tsv.

**ОЧЕРЕДЬ (ждут GO оператора, серийно на моём bottleneck — DatabaseInitializer/schema/baseline + ScreenEditorPage):**
1. UNAVAILABLE-seed _006 (мой)
2. Эпик P1 — NGC_UserAgentgroup DB-юнит (Domain entity + BackendEmulation EF-миграция + NGC_Set/Delete/GetUserAgentgroup SP §33 TenantId + schema/data/baseline + DatabaseInitializer seed + Export-All). Я единственный владелец; daytrend владеет P2 (RTM Engine/DBMng) + P3 (fn+DayTrend); порядок P1→P2→P3. P1 требует GO оператора до написания CC-промпта → §4 координатора. См. [[project_agent_bu_membership]].
3. L1 — локализация каталога: таблица RtsGridMetricTranslation (MetricId+Locale), локали ru-RU + he-IL (en-US база/fallback), переводим DisplayName/ShortDescription/LongDescription/Comparison; MetricId/Family/Channel/CatalogCategory/StandardKpi/StandardRef = каноничный английский; сидим первичный машинный перевод, потом редактируется на странице Metrics; GetRtsGridMetricsQuery делает coalesce по CurrentUICulture.

**Бэклог:** фикс CurLoginTimeStamp (→CurLoginTimestamp); docx-экспорт Overview; Dark-Mode parity всех конфигураторов (ОТДЕЛЬНАЯ дизайн-сессия оператора, не моя); hot-reload метрик без рестарта RTM.

**Координация:** сессия metrics-0605, протокол .coord/ (session-coord skill v1.4+). ScreenEditorPage.razor — самый контендный файл, держать эксклюзивно и освобождать сразу после коммита. Координатор coordinator-0606.
