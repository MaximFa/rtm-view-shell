# Fix: QueueGrid dashboard_widgets.GridId не синхронизирован с RTSGrid_Grid.GridId

**Session name:** RTM — QueueGrid GridId Fix
**File:** `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`

---

## §0 — Session-resume integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

---

## Проблема

В `SaveWidgetConfig()` для QueueGrid виджетов:
- `queueGridId = rtsResult.GridId` → например 28 (RTSGrid_Grid.GridId)
- Но `preassignedGridId` остаётся `null`
- `SaveDashboardWidgetCommand(..., preassignedGridId=null)` → PostgreSQL генерирует авто-число (87)
- `dashboard_widgets.GridId = 87` ≠ `RTSGrid_Grid.GridId = 28`

Для AgentGrid это работает правильно: `preassignedGridId = rtsUserGridId`.
QueueGrid не синхронизирован.

---

## Исправление

Файл: `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`

Найти строку ~4059:
```csharp
                queueGridId = rtsResult.GridId;
                headerRowId = rtsResult.HeaderRowId;
```

Добавить одну строку после `queueGridId = rtsResult.GridId`:
```csharp
                queueGridId = rtsResult.GridId;
                preassignedGridId = queueGridId;  // Sync dashboard_widgets.GridId with RTSGrid_Grid.GridId
                headerRowId = rtsResult.HeaderRowId;
```

---

## Запись через Python (EDIT TOOL BANNED)

```python
import os
path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = "                queueGridId = rtsResult.GridId;\n                headerRowId = rtsResult.HeaderRowId;"
new = "                queueGridId = rtsResult.GridId;\n                preassignedGridId = queueGridId;  // Sync dashboard_widgets.GridId with RTSGrid_Grid.GridId\n                headerRowId = rtsResult.HeaderRowId;"

if old not in text:
    print("ERROR: pattern not found")
    exit(1)

text = text.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print("Done")
```

После записи — проверка:
```bash
sync
grep -n "preassignedGridId = queueGridId" "src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor"
# Expected: one match around line 4060
```

---

## Build check

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
```

0 errors.

---

## MANDATORY pre-commit check

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
```

---

## Git commit

```bash
git add src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor

git commit -m "fix(configurator): sync dashboard_widgets.GridId with RTSGrid_Grid.GridId for QueueGrid

QueueGrid was not setting preassignedGridId after SaveQueueGridRtsCommand,
causing dashboard_widgets.GridId to be auto-generated (e.g. 87) instead of
matching the actual RTSGrid_Grid.GridId (e.g. 28).

Fix: set preassignedGridId = queueGridId after RTS save, same pattern as AgentGrid.

Effect: dashboard_widgets.GridId now equals RTSGrid_Grid.GridId for QueueGrid
widgets, and the configurator General tab shows the correct Grid ID."
```

---

## MANDATORY post-commit + re-sync

```bash
git status --short
git show HEAD:src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | grep -A2 "queueGridId = rtsResult.GridId"

git show HEAD:src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor > src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
sync
echo "Re-synced ScreenEditorPage.razor ($(wc -l < src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor) lines)"
```
