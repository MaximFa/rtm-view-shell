---
name: project-frontend-session
description: "RTM Frontend session state — pending tasks from ToDo.txt, working tree status, next steps"
metadata:
  type: project
  originSessionId: c8672a34-e93b-4b0f-a438-c5c8e11dd5c5
---

## Сессия RTM Frontend — 2026-06-01

**Ветка:** `v2`, HEAD `1838685` (CC-003 docs, 2026-05-31)

**Что сделано в этой сессии:**
- Восстановлено рабочее дерево из HEAD: 16 усечённых файлов (Cowork cache write-back PD-007)
  Восстановлены: Program.cs, AppConfig.cs, BusinessUnitData.cs, DBMng.cs, IDInteraction.cs,
  RealtimeData.cs, UserManager.cs, appsettings.json, все SQL-файлы, .csproj файлы

**Pending задачи (из `ToDo.txt` в C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\):**

| # | Задача | Статус | Примечания |
|---|---|---|---|
| 1 | Валидация обязательных полей в конфигураторе | ⏳ Pending | Блокировать Save если MetricId/GridId не выбраны |
| 2 | Warning в DataSlot когда расхождение с таргетом > X | ⏳ Pending | `_isWorseThanTarget` есть, нужен порог + UI |
| 3 | Доделать DataSlot | ⏳ Pending | Нужно уточнить у Max что именно не готово |
| 4 | Импортировать дату | ⏳ Pending | Нужно уточнить смысл у Max |

**Состояние DataSlot (из кода):**
- Target, TargetMode (less/greater), TargetLabel — ✅ реализованы
- Thresholds (цветовые пороги) — ✅ реализованы
- Delta-стрелка (_showDelta, _deltaIcon, _deltaText) — ✅ реализована
- `_isWorseThanTarget` — вычисляется, но нет отдельного warning-порога
- **Отсутствует:** поле "warn if |delta| > X" в конфигураторе

**Следующий шаг:**
Уточнить у Max:
1. Что именно не готово в DataSlot ("доделать")
2. Что значит "импортировать дату"
Затем: написать CC-промпт на валидацию конфигуратора (п.1) — наиболее критично для UX.

**How to apply:** При возобновлении сессии — прочитать этот файл, задать уточняющие вопросы
по п.3 и п.4, затем приступать к CC-промптам в указанном порядке.
