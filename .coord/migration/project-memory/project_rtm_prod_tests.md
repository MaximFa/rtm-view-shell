---
name: rtm-prod-tests-2026-06-03-04
description: "Итоги production-тестирования на сервере 45 — баги QueueGrid, DB модуль, Restore-All, seeder fix"
metadata: 
  node_type: memory
  type: project
  updated: 2026-06-04
  originSessionId: 55a4a4b1-4cfa-4d77-b623-05606942a31c
---

## Контекст

Сессия "RTM Prod Tests" — тестирование на тестовом сервере 45.
Сервер: Windows Server, IIS, PostgreSQL 18, Memurai (Redis).
Рабочая ветка: `v2`. CLAUDE.md: TZ v2.1.

---

## Что было сделано и исправлено

### QueueGrid — два root-cause бага (полностью исправлены)

**Bug 1 — RTSGrid_GetDataCells INNER JOIN с пустой таблицей:**
`RTSGrid_TemplateCell` всегда пустая (legacy MSSQL таблица). INNER JOIN давал 0 строк
→ RTM Engine не регистрировал ни одной ячейки → `updateGridData` не посылался никогда.
Фикс: убрали JOIN, используем `c."CellType" = 'Data'`. Также удалили `RtsGridTemplateCell`
из Shell (`RtsEntities.cs`, `BackendEmulationDbContext.cs`).

**Bug 2 — ClassificationId не установлен в "ALL":**
RTM Engine вызывает `union.addWorkgroup(QueueId)` ТОЛЬКО когда `ClassificationId == "ALL"`.
Shell сохранял записи без этого поля → Union.Queues пустой → при звонке создавался
дублирующий BusinessUnit вместо маршрутизации в Union 56 → ячейки в Grid 31 не обновлялись.
Фикс: `ClassificationId = "ALL"` добавлен в `ConfigurationCommands.cs` + `DatabaseInitializer.cs`
+ EF миграция UPDATE для существующих строк.

### Прочие UI-фиксы (все закоммичены)
- Время MM:SS, HH только при появлении часов (AgentGrid, QueueGrid, DataSlot)
- Процент из `metric.Format` (RTM передаёт уже отформатированное значение) — фильтр учитывает
- Фильтр по конфигурации AgentGrid — починен
- Индикатор активных фильтров перенесён в заголовок виджета (AgentGrid, QueueGrid)
- Dropdown clipping в модалах конфигуратора (position: fixed + MouseEventArgs)
- &nbsp; из RTM рендерится как пустая ячейка
- Reset строк QueueGrid при смене DarkMode

### DB модуль создан (db/)

Структура:
```
db/
  schema.sql          — pg_dump --schema-only (полный DDL)
  functions/          — SQL функции (перенесены из RTM/sql/pgsql/)
  data/
    01_system.sql     — Platform tenant, superadmin, EF migration history
    02_metrics.sql    — RTSGrid_Metric (196 строк)
    03_rtsgrid.sql    — RTSGrid/RTSUserGrid определения
    04_catalog.sql    — widget_catalog, NGC_Site (SiteId='IL')
  setup/01_init_db.sql
  tools/
    Export-All.ps1    — export DB → git после любого изменения БД
    Restore-All.ps1   — DROP + пересоздание БД из git
    Create-FreshDb.ps1
```

**Export-All** использовать после любого изменения БД:
```powershell
powershell -File db\tools\Export-All.ps1 -Password "!@#qweASDzxc" -CommitMessage "..."
```

**Restore-All** для чистого старта:
```powershell
powershell -File db\tools\Restore-All.ps1 -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc" -DropAndRecreate
```

### Seeder fix (DatabaseInitializer.cs)

**Проблема:** После `Restore-All` в `NGC_Site` есть `SiteId='IL'` (RTM default из baseline).
Seeder видел "есть хоть один сайт" → пропускал SITE001/SITE002 → FK violation при создании
NGC_BusinessUnit → app crash.

**Фикс (коммит 44d6ccb):**
```csharp
// Было:
AnyAsync(s => s.TenantId == tenant.Id)
// Стало:
AnyAsync(s => s.TenantId == tenant.Id && s.SiteId == "SITE001")
```
Также `SeedDevRtsInteractionsAsync` обёрнут в try-catch.

**Важно:** `SeedSampleCcEntitiesAsync` запускается безусловно во ВСЕХ окружениях (не только dev).

### CLAUDE.md обновлён до TZ v2.1

Добавлено:
- §29.8 — production gotchas (launchSettings.json, SeedSampleCcEntitiesAsync, NGC_Site='IL')
- §39.6 — four-way commit (rtm, web, db, docs)
- PostgreSQL 18 во всех упоминаниях

---

## Состояние на конец сессии

- **Пуш в процессе** (CC выполнял `cc_prompt_push.md` в момент закрытия сессии)
- Все фиксы закоммичены, ветка v2
- CLAUDE.md TZ v2.1, `db/` модуль полный, Restore-All + dotnet run работает

### Возможные pending задачи

- Убедиться что пуш завершился: `git log --oneline -5` и `git status`
- Продолжить тестирование виджетов на сервере 45
- Проверить DataSlot виджет (упоминался как "доделать DataSlot")
- Проверить AgentGrid новые колонки (cc_prompt_fix_agentgrid_new_column.md — статус неизвестен)

---

## Ключевые правила из этой сессии

- `dotnet run` с `launchSettings.json` → всегда Development. Для Production: `--no-launch-profile`
- `SeedSampleCcEntitiesAsync` = безусловный, идемпотентный
- `NGC_Site SiteId='IL'` = RTM default, ОБЯЗАТЕЛЕН в baseline
- `ClassificationId = "ALL"` = обязателен во всех NGC_BusinessUnitQueueClassification записях
- PostgreSQL версия на сервере = **18**
