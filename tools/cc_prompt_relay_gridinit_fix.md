# Fix: RtmRelayService GridInitAsync — JsonElement → string

**Session name:** RTM — Relay GridInit Fix
**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

---

## §0 — Session-resume integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

---

## Проблема

В `GridInitAsync` (строка ~532) `init` и `refreshCells` вызываются с возвратом `<JsonElement>`.
RTM Service возвращает datetime-строку. С `AddNewtonsoftJsonProtocol` Newtonsoft не может
десериализовать строку в `System.Text.Json.JsonElement` — конфликт двух JSON-библиотек.

**Ошибка в логах:**
```
HubException: Error converting value "2026-06-02T12:24:19..." to type 'System.Text.Json.JsonElement'
```

Такая же ситуация была решена для `InitUnionAsync` — там уже используется `<string>`.

---

## Исправление

В файле `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`
найти метод `GridInitAsync` и заменить оба вызова:

**Было:**
```csharp
private async Task GridInitAsync(GridState state, int gridId, CancellationToken ct)
{
    await state.Connection!.InvokeAsync<JsonElement>("init", gridId.ToString(), ct);
    await state.Connection!.InvokeAsync<JsonElement>("refreshCells", gridId.ToString(), ct);
    _logger.LogInformation("RtmRelayService: init+refreshCells complete for grid {GridId}", gridId);
}
```

**Стало:**
```csharp
private async Task GridInitAsync(GridState state, int gridId, CancellationToken ct)
{
    await state.Connection!.InvokeAsync<string>("init", gridId.ToString(), ct);
    await state.Connection!.InvokeAsync<string>("refreshCells", gridId.ToString(), ct);
    _logger.LogInformation("RtmRelayService: init+refreshCells complete for grid {GridId}", gridId);
}
```

**Также проверить** `ReconnectGridWithBackoffAsync` — если `GridInitAsync` бросает исключение,
соединение было уже создано и запущено но не закрыто. Добавить dispose в catch:

Найти в `ReconnectGridWithBackoffAsync` блок catch:
```csharp
catch (Exception ex)
{
    state.IsDisposing = false;
    _logger.LogWarning(ex, ...);
    ...
}
```

Заменить на:
```csharp
catch (Exception ex)
{
    // Dispose connection that was started but failed init
    if (state.Connection != null)
    {
        try { await state.Connection.DisposeAsync(); } catch { }
        state.Connection = null;
    }
    state.IsDisposing = false;
    _logger.LogWarning(ex, ...);
    ...
}
```

---

## Запись через Python (EDIT TOOL BANNED)

```python
import os
path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\RtmRelay\RtmRelayService.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix 1: GridInitAsync return type
text = text.replace(
    'await state.Connection!.InvokeAsync<JsonElement>("init", gridId.ToString(), ct);\n\n        // refreshCells causes the server to push updateGridData with all current values.\n        await state.Connection!.InvokeAsync<JsonElement>("refreshCells", gridId.ToString(), ct);',
    'await state.Connection!.InvokeAsync<string>("init", gridId.ToString(), ct);\n\n        // refreshCells causes the server to push updateGridData with all current values.\n        await state.Connection!.InvokeAsync<string>("refreshCells", gridId.ToString(), ct);'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
```

После записи:
```bash
sync && tail -3 src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
grep -n "InvokeAsync" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | grep -i "grid\|init\|refresh"
```

Ожидаемый результат: оба вызова возвращают `<string>`, не `<JsonElement>`.

---

## Build check

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
```

0 errors.

---

## MANDATORY pre-commit check

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
```

---

## Git commit

```bash
git add src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

git commit -m "fix(relay): GridInitAsync InvokeAsync<JsonElement> -> <string>

RTM Service returns datetime string from init/refreshCells.
With AddNewtonsoftJsonProtocol, Newtonsoft cannot deserialize
a raw string into System.Text.Json.JsonElement — type conflict.
Fix matches InitUnionAsync pattern which already uses <string>.

Fixes: HubException: Error converting value datetime to JsonElement"
```

---

## MANDATORY post-commit + re-sync

```bash
git status --short
git show HEAD:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | grep -A3 "GridInitAsync"

git show HEAD:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs > src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
sync
echo "Re-synced RtmRelayService.cs ($(wc -l < src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs) lines)"
```
