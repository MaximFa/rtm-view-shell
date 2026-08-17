---
name: rtm-prod-tests2-session
description: "Итоги сессии RTM Prod Tests2 (2026-06-05) — DataSlot, Connection race, Calc metrics, skills"
metadata:
  type: project
  updated: 2026-06-05
---

## Сессия: RTM Prod Tests2 — 2026-06-05

### Ветка: v2 | Последний коммит: origin/v2 актуален

---

## Что сделано и исправлено

### DataSlot — три бага подряд, все закрыты

**Bug 1 — BU не сохранялся (UnionId=NULL):**
`SelectBusinessUnit()` обновляла только `ConfigBusinessUnit` (string), но не `ConfigDataSlotBusinessUnitId` (int?).
Фикс: добавить `ConfigDataSlotBusinessUnitId = bu?.BusinessUnitId;` в `SelectBusinessUnit`.

**Bug 2 — GridId в dashboard_widgets ≠ RTSGrid_Grid.GridId:**
`preassignedGridId` не устанавливался после DataSlot RTS save → DB генерировал случайный ID.
Фикс: `preassignedGridId = _dataSlotGridId;` после `_dataSlotGridId = rtsResult.GridId;`.
(Аналог Bug из §24.3 widget-creator — то же для DataSlot)

**Bug 3 — BU восстановление при открытии:**
При редактировании существующего DataSlot `ConfigBusinessUnit` и `BuSearchText` не восстанавливались.
Фикс: инициализировать из `widget.Config.DataSlotBusinessUnitId` при загрузке.

### "Connection failed" при 2+ Grid виджетах на дашборде

**Причина (из лога):** `GetTenantSettingsQuery` вызывался одновременно из нескольких виджетов → concurrent DbContext.
- НЕ проблема CancellationToken (как думали изначально)
- НЕ проблема RTM подключения (init+refreshCells оба завершались успешно)

**Фикс 1 — TenantSettingsRepository:**
`GetByTenantAsync` → `IDbContextFactory<AppDbContext>` (свежий context per call).
`UpsertAsync` остаётся на scoped db (транзакции).

**Фикс 2 — RtmRelayService (дополнительный):**
Все шаги подключения используют `CancellationToken.None`:
- `GetHubUrlAsync(tenantId, CancellationToken.None)`
- `state.Lock.WaitAsync(CancellationToken.None)`
- `conn.StartAsync(CancellationToken.None)`
- `GridInitAsync(..., CancellationToken.None)`
- `refreshCells` — void метод → `SendAsync` вместо `InvokeAsync<string>`

### Calc метрики показывали 0.0%

**Причина:** опечатка в MetricId — `QueueNumAbandonefCalls` ("ef") но формулы используют `[QueueNumAbandonedCalls]` ("ed").
**Фикс:** добавлены alias-метрики `QueueNumAbandonedCalls` и `QueueNumAbandonedCallbacks` в DB.
После перезапуска RTM → DataSlot показывает 100.0% ✅

### refreshCells сбрасывал таймер при рефреше страницы

**Причина:** `_allCellsData` кэширует processed elapsed `"+00:00:10"`, а `refreshCells` пытается ParseExact как datetime → FAIL → `"&nbsp;"`.
**Фикс:** `refreshCells` в Engine.cs читает `cellValue.Value.Value2` (оригинальный `+datetime`) вместо `Value` (processed elapsed).

### Header Font Size

Добавлен в конфигуратор AgentGrid, QueueGrid, DataSlot:
- Rename "Font Size" → "Table Font Size"
- Новый дропдаун "Header Font Size"
- `GetTheadCellStyle()` применяет `_headerFontSize` напрямую к `<th>` (не `<thead>`)

### AgentStateGroup процентные метрики

Добавлены через DB migration:
- `MonAgentAvailableDurationPct`, `MonAgentBreakDurationPct`, `MonAgentPaperworkDurationPct`, `MonAgentTrainingDurationPct`

### Skills — автозагрузка в каждой сессии

- §32 CLAUDE.md: **Step 0** — читать widget-planner + widget-creator перед всем остальным
- §40 CLAUDE.md: правило для Cowork И CC
- Каждый CC промпт начинается с блока `## Mandatory — read before starting`

---

## Pending на завтра

- [ ] Протестировать Connection failed фикс (TenantSettingsRepository + CancellationToken.None)
- [ ] DayTrend метрики — несоответствие Incoming vs Answered (данные обнулились в 00:00, отложено)
- [ ] refreshCells timer fix — проверить что таймер ожидания не сбрасывается после рефреша
- [ ] Resize widgets со всех сторон — CC промпт написан (`cc_prompt_resize_drag_improvements.md`), не применялся
- [ ] Double-click Save fix — CC промпт написан (`cc_prompt_fix_config_save_doubleclick.md`), не проверен

## Состояние кода

- Ветка: `v2`, все изменения на `origin/v2`
- DB: экспортирован, alias-метрики закоммичены
- UnitOfWork: `beDb.SaveChangesAsync()` удалён (только AppDbContext)
