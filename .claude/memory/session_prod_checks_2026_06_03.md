---
name: session-prod-checks-2026-06-03
description: "Прод-тестирование виджетов после деплоя relay: результаты, баги, открытые вопросы"
metadata:
  type: project
  updated: 2026-06-03
---

## Статус деплоя (все задеплоены)

| Коммит | Что |
|---|---|
| `b45618b` | QueueGrid: ConnectAsync → OnAfterRenderAsync |
| `591c537` | JToken fix для updateGridData (grid) |
| `584bc77` | Убрать ConnectAsync из OnParametersSetAsync QueueGrid |
| `a0e0f59` | SSR fix AgentGrid/DataSlot/AgentStateDistribution + union JToken (updateUserGrid/removeUser) |
| `1f314e3` | AgentGrid: UnionId = BusinessUnit.Id (не RtsUserGridId) |
| `(pending)` | RefCount fix: Unsubscribe только если handler найден — СБИЛДИТЬ И ЗАДЕПЛОИТЬ |

## Результаты проверки

### ✅ Queue Grid
- **Данные идут**: AVAILABLE, LOGGED IN обновляются корректно
- **Проблема**: WAITING/WAIT TIME/ANSWERED/INCOMING всегда 0
  - **Root cause**: тестовые звонки идут `workgroup=Everyone` (Union 56), не в конкретные очереди
  - Queue Grid мониторит BU 74/78/76/58/77 — звонки до них не доходят
  - Нужно проверить в Dialer: можно ли выбрать целевую очередь при создании звонка
- **Стабильность**: иногда теряет данные через ~30с — refcount fix должен помочь

### ✅ Agent Grid
- **Данные идут**: агенты видны, состояния обновляются
- **Проблема 1**: TALK% показывает сырой float (0.572299...) вместо форматированного
  - Нужно разобраться с форматированием метрики MonAgentTalkDurationPct в виджете
- **Проблема 2**: DURATION показывает "16:00" у оффлайн агентов — возможно нормально

### ⏳ DataSlot, AgentStateDistribution
- Не проверялись в проде (SSR fix задеплоен)

## Открытые задачи

1. **Задеплоить refcount fix** (`cc_prompt_refcount_fix.md`) — собрать и установить
2. **Dialer routing check** — может ли Dialer направить звонок в конкретную очередь (не Everyone)
3. **TALK% форматирование** — MonAgentTalkDurationPct возвращает float, виджет показывает сырое число
4. **Queue Grid stability** — после refcount fix проверить не пропадают ли данные при действиях
5. **DataSlot + AgentStateDistribution** — протестировать в проде

## Архитектурные факты (§36)

- BU = Union (одно и то же)
- Звонки в этой установке идут в workgroup=Everyone (Union 56)
- Специфичные BU (74=לפני_רכישה, 78=הרכבות) = группы агентов, не маршрутизационные очереди
- AVAILABLE/LOGGED IN работает через агентские статусы → работает корректно
- WAITING/ANSWERED → нужны звонки в конкретные workgroups

## Следующая сессия: "продолжаем проверки в проде"

1. Убедиться что refcount fix задеплоен
2. Проверить стабильность Queue Grid (открыть конфиг, сдвинуть виджет — должны остаться данные)
3. Разобраться с Dialer routing для тестирования WAITING метрик
4. Проверить форматирование TALK% в Agent Grid
5. Протестировать DataSlot и AgentStateDistribution
