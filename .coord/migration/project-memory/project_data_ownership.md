---
name: RTM View Shell — границы владения данными
description: Кто чем владеет — shell vs backend. 5 категорий таблиц, dev emulation, prod deployment, dual-write pattern. Без этого любая работа с БД ведёт к путанице.
type: project
originSessionId: e7fc5936-9b58-407e-b6f6-f191c0570f6e
---
## Идентичность продукта

RTM View Shell — **двусоставный продукт**:

1. **Vendor-часть** — мы полноценный SaaS-продукт для управления контакт-центром-мониторингом:
   - Tenants (наши клиенты)
   - Users системы отображения (те, кто логинится в наш продукт)
   - Licensing (Purchased licences, User connections — коммерческая модель)
   - Permission Groups и их права
   - Dashboards, Categories (наша группировка экранов)
   - Audit
   - Tenant Settings (политика паролей, appearance, signalr widgets URL)
   - SSO/2FA конфигурация (когда будет реализовано)

2. **UI-прослойка** — мы фасад к внешнему backend'у:
   - Измеряемые сущности контакт-центра (queues, business units, supergroups, agent groups, sites)
   - Метрики (rtsgrid_metric)
   - Adaptation tables для виджетов (RTSGrid_*, RTSUserGrid_*)
   - SignalR endpoint для real-time данных
   - Мы их **не используем** для своей логики — мы транслируем между UI и их БД/API

**Why:** Эта дихотомия фундаментальна — все TZ-решения, ADR, и архитектурные выборы должны явно адресовать, к какой из двух частей относится требование.

**How to apply:** При появлении сущности в обсуждении — первым делом классифицировать: vendor-часть или UI-прослойка. Это определяет, кто владеет миграциями, кто пишет данные, и кто несёт ответственность за изменения схемы.

---

## 5 категорий таблиц (актуально на 2026-05-15)

### Категория 1: Полностью наши
- **Концептуальный владелец:** мы
- **Миграции в проде:** наша EF migration
- **Запись данных:** мы (через нашу UI/API)
- **Чтение:** мы
- **TZ describes:** полный жизненный цикл

**Примеры:** `tenants`, `users`, `permission_groups`, `dashboards`, `dashboard_categories`, `tenant_settings`, `tenant_appearance` (если будет отдельной), `audit.audit_logs`, `pg_business_units`, `pg_queues`, `pg_supergroups`, `pg_agent_groups` (после Skills→AgentGroups rename), `widget_catalog`, `widget_templates`, `sso_configurations`.

### Категория 2: Их данные, мы только читаем
- **Концептуальный владелец:** backend
- **Миграции в проде:** их система
- **Запись данных:** их система
- **Чтение:** мы (как источник ссылочных данных для UI)
- **TZ describes:** integration contract, что читаем

**Примеры:** *(на 2026-05-15 — таких "чистых" нет; все сущности backend'а имеют ещё и наш admin UI — см. категорию 3. Эта категория зарезервирована для будущих случаев pure read-only)*

### Категория 3: Их данные, у нас admin UI + чтение для дропдаунов
- **Концептуальный владелец:** backend
- **Миграции в проде:** их система (нас уведомят заблаговременно об изменениях схемы)
- **Запись данных:** мы (через наш admin UI; backend admin'а для этого не имеет)
- **Дополнительно:** **dual write** — каждая запись в БД должна сопровождаться вызовом их API, чтобы backend применил изменения **без рестарта**. Сейчас API-сторона — placeholder/stub (см. `NoOpConfigurationApiHook` в CLAUDE.md §29.6)
- **Чтение:** мы (для дропдаунов/фильтров) — но не используем значения для своей логики, только транслируем
- **TZ describes:** integration contract, что читаем, что пишем, API protocol

**Примеры:**
- `RTSGrid_Metric` (метрики; экран Metrics в меню)
- `NGC_BusinessUnit` (экран Business Units)
- `NGC_Site` (экран Sites)
- `NGC_Supergroup` (экран Super Groups)
- `NGC_SupergroupAgentgroup` (связь Supergroup ↔ Agent Group)
- `NGC_BusinessUnitQueueClassification` (связь BU ↔ Queue)
- `NGC_AgentGroups` (экран Agent Groups; **Skills упразднено — это новое имя**)
- `NGC_Queues` (просмотр Queues)

### Категория 4: Их данные, мы пишем как побочный эффект (adaptation layer)
- **Концептуальный владелец:** backend
- **Миграции в проде:** их система
- **Запись данных:** мы (через MediatR-команды при create/update/delete виджета)
- **Дополнительно:** **dual write** — DB-запись + их API
- **Чтение:** обычно не читаем, кроме `GridId` обратно после создания (handle для SignalR subscription)
- **TZ describes:** adaptation contract, lifecycle hooks (widget create/edit/delete → backend tables write + API notification)

**Примеры:**
- `RTSGrid_Grid`, `RTSGrid_Row`, `RTSGrid_Column`, `RTSGrid_Cell` (для Queue Grid виджетов)
- `RTSUserGrid_Grid`, `RTSUserGrid_Column`, `RTSUserGrid_ColumnsSet` (для Agent Grid виджетов)

### Категория 5: Их endpoint (нет таблицы у нас)
- **Концептуальный владелец:** backend
- **Storage:** на их стороне, у нас нет
- **Доступ:** через SignalR Hub
- **TZ describes:** SignalR contract (`SubscribeToGrid(GridId)` → `ReceiveGridData` события)

**Примеры:**
- SignalR Hub `SubscribeToGrid` / `ReceiveGridData` / `ReceiveQueueGridData`
- URL хранится в Tenant Settings (`SignalRConnectionUrl`) — само поле наше (категория 1)
- **Текущая dev-реализация — это симулятор**, не реальный backend. Точный протокол будет позже.

---

## Production deployment — критические факты

**Одна общая Postgres БД `RTMViewDB`** на одном сервере содержит:
- Наши таблицы (snake_case) — наши миграции
- Их таблицы (PascalCase: `NGC_*`, `RTSGrid_*`, `RTSUserGrid_*`) — **их** миграции

**Два EF DbContext** в одной БД:
- Наш: `__ef_migrations_history` (snake_case)
- Их: `__EFMigrationsHistory` (PascalCase, EF Core legacy default)

**Координация изменений схемы:**
- Если backend меняет дизайн **своих** таблиц — нас уведомляют заблаговременно
- Наши EF-миграции **не должны** создавать backend-таблицы в проде
- В dev мы их **эмулируем** — наши миграции создают их у нас для разработки. Это технический долг (нужен путь, при котором dev seeds backend tables, но prod не пытается их создать)

**Why:** Без этой ясности EF-миграции в проде упадут с конфликтом ("table already exists") или, хуже, перезапишут backend-таблицы.

---

## Naming convention в БД (after 2026-05-15 cleanup)

- **Наши таблицы** — `snake_case` (`tenants`, `dashboards`, `pg_business_units`, и т.д.)
- **Их таблицы** — `PascalCase_With_Underscore` (`NGC_BusinessUnit`, `NGC_Supergroup`, `RTSGrid_Cell`, `RTSUserGrid_Column`, и т.д.)
- В PostgreSQL имена в PascalCase **обязательно в кавычках** в любом raw SQL: `INSERT INTO "RTSGrid_Metric"...`. Без кавычек PostgreSQL приводит к нижнему регистру.

**Сделанные renames (2026-05-15):**
- `rtsgrid_metric` → `RTSGrid_Metric` (commit `03a9355`)
- `ngc_AgentGroups` → `NGC_AgentGroups`, `ngc_queues` → `NGC_Queues` (commit `3445213`)

**Technical debt:**
- `pg_skills` — legacy от Skills→AgentGroups переименования. Должно быть `pg_agent_groups` или удалено.

---

## Open architectural decisions (для ADR)

1. **Dev emulation strategy** — как мы эмулируем backend-таблицы в dev, не создавая конфликта в проде? (Отдельный путь миграций? Conditional `if (env == "Development")` в migration? Sql script вместо EF?)
2. **Dual-write transaction semantics** — что делать, если DB-запись прошла, а API-уведомление backend'а упало? (Saga? Outbox? Retry queue? Compensating action?)
3. **API contract versioning** — как мы реагируем, если backend меняет свой API? (Версионированные эндпоинты? Adapter с конверсией?)
4. **Schema change coordination** — формальный канал для backend-уведомлений об изменении схемы их таблиц.

---

## Антипаттерны

- ❌ **НЕ** добавлять в нашу миграцию `CreateTable` для backend-таблицы (`NGC_*`, `RTSGrid_*`, `RTSUserGrid_*`) без отдельного pattern для dev-only.
- ❌ **НЕ** ссылаться на rtsgrid_metric/NGC_*/RTSGrid_* в raw SQL без кавычек.
- ❌ **НЕ** трактовать наличие EF entity + repository как доказательство, что таблица "наша" — semantically она может быть backend'а, а мы лишь UI-прослойка.
- ❌ **НЕ** забывать про dual-write: запись в backend-таблицу без API-уведомления = backend не применит до рестарта.
