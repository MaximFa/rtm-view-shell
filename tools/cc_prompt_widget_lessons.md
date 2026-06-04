# CC Task: Add QueueGrid implementation lessons to widget-creator skill + fix OnParametersSetAsync

## Part 1: Fix remaining OnParametersSetAsync subscribe cycling

### File: src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor

`OnParametersSetAsync` still calls `ConnectAsync()`. This runs during SSR pre-render,
causing subscribe→grace timer→30s→connection drop cycle.

Find the initial-connect block in OnParametersSetAsync (approx line 358):
```csharp
        // Initial connect
        if (GridId != 0 && _previousGridId == 0 && _gridHandler is null)
        {
            _previousGridId = GridId;
            await ConnectAsync();
        }
```

Remove the ConnectAsync call — leave only the _previousGridId tracking:
```csharp
        // Track GridId changes (initial connect is handled in OnAfterRenderAsync)
        if (GridId != 0 && _previousGridId == 0)
        {
            _previousGridId = GridId;
        }
```

After this change, the ONLY place that subscribes is OnAfterRenderAsync(firstRender),
which does NOT run during SSR pre-rendering.

---

## Part 2: Add lessons to widget-creator skill

Read the current skill file:
  D:\Claude\Projects\RTM View Shell\.claude\skills\widget-creator\widget-creator.md

Append a new section at the END of the file (before the last line if there is one,
otherwise just append):

```markdown

---

## §24. QueueGrid / DataGrid relay — critical implementation lessons (2026-06-03)

These lessons were discovered during production debugging of the QueueGrid widget.

### §24.1 Newtonsoft SignalR protocol: NEVER use On<JsonElement>

When the HubConnection uses `AddNewtonsoftJsonProtocol`, do NOT register
`On<System.Text.Json.JsonElement>`. Newtonsoft cannot deserialize to this type.
The handler SILENTLY NEVER FIRES. All incoming messages are dropped with no error.

**Correct:**
```csharp
conn.On<JToken>("updateGridData", cells => HandleAsync(cells));

// In handler:
if (cells is not JArray arr) { LogWarning(...); return; }
foreach (var item in arr)
{
    var cellId = item["CellId"]?.Value<int>() ?? continue;
    var value  = item["Value"]?.Value<string>() ?? "";
}
```

**Wrong (silent drop):**
```csharp
conn.On<JsonElement>("updateGridData", cells => HandleAsync(cells)); // NEVER!
```

### §24.2 Blazor SSR pre-render: subscribe only in OnAfterRenderAsync

`OnInitializedAsync` and `OnParametersSetAsync` run during BOTH SSR pre-rendering
AND the interactive circuit. During SSR, the component disposes immediately after
HTML generation, causing rapid subscribe→unsubscribe (milliseconds), which creates
a grace timer that fires 30 seconds later and disconnects the relay.

**Correct (.NET 8):** Subscribe ONLY in `OnAfterRenderAsync(bool firstRender)`.
This lifecycle method is NOT called during SSR pre-rendering.

```csharp
protected override async Task OnInitializedAsync()
{
    ApplyConfig();
    // NO ConnectAsync here - it runs during SSR pre-render too
}

protected override async Task OnParametersSetAsync()
{
    ApplyConfig();
    // Track parameter changes but NO ConnectAsync call
    if (GridId != 0 && _previousGridId == 0)
        _previousGridId = GridId;
    _previousGridId = GridId;
    // Reconnect on column change is ok here — _gridHandler is not null guard prevents SSR call
}

protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender)
    {
        await ConnectAsync();           // Only runs in interactive mode
        if (!_stateLoaded) { ... }
    }
}
```

Also add guard in ConnectAsync to prevent double-subscribe:
```csharp
private async Task ConnectAsync()
{
    if (_rtsGridId == 0) return;
    if (_gridHandler is not null) return;  // already subscribed
    ...
}
```

### §24.3 GridId in dashboard_widgets must come from RTSGrid_Grid

When saving a QueueGrid widget, the `dashboard_widgets.GridId` field must store
the `RTSGrid_Grid.GridId` value (the real grid ID from RTM Service), NOT the
auto-increment PK of the `dashboard_widgets` table.

After calling `SaveQueueGridRtsCommand` and getting `queueGridId`:
```csharp
queueGridId = rtsResult.GridId;  // from RTSGrid_Grid
preassignedGridId = queueGridId;  // sync to dashboard_widgets.GridId
```

Without this sync, the widget config stores CellIds from a non-existent grid,
and RTM Service pushes CellIds that never match the widget's _cellMap.

### §24.4 UnitOfWork must save ALL DbContexts

If the project has multiple DbContexts (e.g., `AppDbContext` + `BackendEmulationDbContext`),
the `UnitOfWork.SaveChangesAsync()` must call `SaveChangesAsync()` on ALL of them.

```csharp
public async Task<int> SaveChangesAsync(CancellationToken ct = default)
{
    var result = await db.SaveChangesAsync(ct);
    await beDb.SaveChangesAsync(ct);  // Don't forget secondary contexts!
    return result;
}
```

Without this, writes to secondary contexts silently succeed at the application layer
but never reach the database.
```

---

## Part 3: Add lessons to widget-planner skill

Read the current skill file:
  D:\Claude\Projects\RTM View Shell\.claude\skills\widget-planner\widget-planner.md

Append a new section at the END:

```markdown

---

## Lesson 11: QueueGrid production checklist (2026-06-03)

Before marking a DataGrid/QueueGrid widget as delivered, verify:

1. **GridId sync**: `dashboard_widgets.GridId` == `RTSGrid_Grid.GridId`
   (NOT the auto-increment PK of dashboard_widgets)

2. **CellMap populated**: After saving, `Config.QueueGridRows[i].CellIds[colId]`
   contains real CellIds from `RTSGrid_GetDataCells(gridId)`.
   If CellIds are null/empty, no data will ever display.

3. **Newtonsoft + JToken**: If relay uses Newtonsoft protocol,
   `On<JsonElement>` silently drops all messages. Use `On<JToken>`.

4. **Blazor lifecycle**: Widget subscribe must be in `OnAfterRenderAsync(firstRender)`
   only. SSR pre-render in `OnInitializedAsync`/`OnParametersSetAsync` causes
   subscribe→dispose cycles that make the relay grace timer kill the connection.

5. **RTM Service LoadData**: Calling `/LoadData` (e.g., after SaveQueueGridRts)
   causes RTM Service to close all SignalR connections. The relay reconnects
   automatically via backoff, but there will be a brief data interruption.
```

---

## Build and commit

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj -c Release
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# also check skill files if they were modified
```

```bash
git add src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  .claude/skills/widget-creator/widget-creator.md \
  .claude/skills/widget-planner/widget-planner.md
git commit -m "fix: remove ConnectAsync from OnParametersSetAsync (SSR pre-render cycling)
docs: add QueueGrid production lessons to widget-creator §24 and widget-planner Lesson 11
"
```

```bash
for f in src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  .claude/skills/widget-creator/widget-creator.md \
  .claude/skills/widget-planner/widget-planner.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

---

## Part 4: Add BU/Union/Queue/Supergroup definitions to CLAUDE.md §36

Append a new section §36 to D:\Claude\Projects\RTM View Shell\CLAUDE.md:

```markdown

---

## 36. Business Unit / Union — определения и маппинги

> КРИТИЧЕСКИ ВАЖНО: не путать понятия. Неправильный UnionId = нет данных.

### §36.1 Терминология

| Термин | Где встречается | Значение |
|--------|----------------|---------|
| **Business Unit (BU)** | Shell UI, Shell DB (`NGC_BusinessUnit`) | Единица организации. Базовый объект конфигурации |
| **Union** | RTM Service код (`UnionList[unionId]`) | Старое название BU; в RTM Service код оперирует UnionId |
| `NGC_BusinessUnit.Id` | Shell DB | Числовой ID BU → используется как UnionId в RTM Service |

**BU = Union. Это одно и то же.**

### §36.2 Два маппинга BU → данные

Каждый BU имеет ДВА независимых маппинга для разных типов данных:

#### Маппинг 1: BU → Queues (метрики очередей)
- Таблица: `NGC_BusinessUnitQueueClassification`
- Связь: `BU.Id` → `NGC_Queues` (очереди)
- Используется для: Queue Grid, Queue Summary, Data Slot (Queue метрики)
- RTM Service UnionId = `NGC_BusinessUnit.Id`
- Метрики типа: `QueueNumIncomingOnlineCalls`, `QueueCurMaxWaitTimeCalls`, etc.

#### Маппинг 2: BU → Supergroups (метрики агентов)
- Таблица: `NGC_BusinessUnitSupergroup`
- Связь: `BU.Id` → `NGC_Supergroup` → агенты
- Используется для: Agent Grid, Agent State Distribution, Data Slot (Agent метрики)
- RTM Service UnionId = `NGC_Supergroup.Id` (НЕ BU.Id!)
- Метрики типа: `QueueLoginDataNumAvailableUsers`, агентские статусы, etc.

### §36.3 Правило выбора UnionId для виджета

```
IF metric type == "Data" (queue metrics):
    UnionId = NGC_BusinessUnit.Id
    subscribe: RtmRelay.SubscribeGridAsync(gridId from RTSGrid_Grid)

IF metric type == "Agent" (agent/status metrics):
    UnionId = NGC_Supergroup.Id  ← НЕ BU.Id!
    subscribe: RtmRelay.SubscribeUnionAsync(unionId = Supergroup.Id)
```

### §36.4 Примеры ID (продакшн)

| BU Name | BU.Id | Queues | Supergroup.Id |
|---------|-------|--------|---------------|
| לפני_רכישה | 74 | Mapped via QueueClassification | Supergroup linked |
| הרכבות | 78 | Mapped via QueueClassification | Supergroup linked |

**Queue Grid виджет**: использует BU.Id (74, 78) → RTSGrid_Grid → данные очередей.
**Agent Grid виджет**: использует Supergroup.Id для BU → данные агентов.

### §36.5 Как получить Supergroup.Id для BU

```sql
-- Найти Supergroup для BU
SELECT b."Name" as BU, b."Id" as BU_Id,
       s."Name" as Supergroup, s."Id" as Supergroup_Id
FROM "NGC_BusinessUnit" b
JOIN "NGC_BusinessUnitSupergroup" bsg ON bsg."BusinessUnitId" = b."Id"
JOIN "NGC_Supergroup" s ON s."Id" = bsg."SupergroupId"
WHERE b."TenantId" = '...'
ORDER BY b."Name";
```

*TZ version: 1.9 | CLAUDE.md last updated: 2026-06-03 (§36 BU/Union definitions)*
```
