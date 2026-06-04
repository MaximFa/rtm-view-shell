# CC Task: Fix updateGridData handler — JsonElement → JToken (Newtonsoft)

## Root Cause
RtmRelayService.BuildGridConnection registers:
  conn.On<JsonElement>("updateGridData", ...)

RTM Service uses AddNewtonsoftJsonProtocol + DefaultContractResolver (PascalCase).
Shell also uses AddNewtonsoftJsonProtocol.

Problem: Newtonsoft CANNOT deserialize to System.Text.Json.JsonElement — it's a foreign type.
Result: the handler SILENTLY NEVER FIRES. All updateGridData messages are dropped.

The fix: use Newtonsoft.Json.Linq.JToken (which Newtonsoft handles natively).

## File to modify
src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

### Change 1: BuildGridConnection — On<JsonElement> → On<JToken>

Find (around line 516):
```csharp
        // Using On<JsonElement> matches the DNN function(cells) single-array-arg signature.
        conn.On<JsonElement>("updateGridData",
            cells => HandleGridUpdateAsync(state, key, cells));
```

Replace with:
```csharp
        // Using On<JToken> — Newtonsoft protocol cannot deserialize to System.Text.Json.JsonElement.
        // JToken is the correct type when AddNewtonsoftJsonProtocol is active.
        conn.On<JToken>("updateGridData",
            cells => HandleGridUpdateAsync(state, key, cells));
```

### Change 2: HandleGridUpdateAsync signature + body — JsonElement → JToken

Find method signature (around line 629):
```csharp
    private async Task HandleGridUpdateAsync(GridState state, (Guid TenantId, int GridId) key, JsonElement cells)
    {
        if (cells.ValueKind != JsonValueKind.Array)
        {
            _logger.LogWarning(
                "RtmRelayService: updateGridData tenant {TenantId} grid {GridId} — unexpected payload kind {Kind}",
                key.TenantId, key.GridId, cells.ValueKind);
            return;
        }

        var updates = new List<GridCellUpdate>();
        List<Func<IReadOnlyList<GridCellUpdate>, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in cells.EnumerateArray())
            {
                if (!item.TryGetProperty("CellId", out var cellIdEl)) continue;
                if (!item.TryGetProperty("Value", out var valueEl)) continue;
                var cellId = cellIdEl.GetInt32();
                var value = valueEl.GetString() ?? "";
                state.CellSnapshot[cellId] = value;
                updates.Add(new GridCellUpdate(cellId, value));
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogInformation(
            "RtmRelayService: updateGridData grid {GridId}: {Count} cells, {HandlerCount} handlers",
            key.GridId, updates.Count, handlers.Count);

        if (updates.Count > 0)
            await FanOutGridAsync(handlers, updates);
    }
```

Replace with:
```csharp
    private async Task HandleGridUpdateAsync(GridState state, (Guid TenantId, int GridId) key, JToken cells)
    {
        if (cells is not JArray cellsArray)
        {
            _logger.LogWarning(
                "RtmRelayService: updateGridData tenant {TenantId} grid {GridId} — unexpected payload type {Type}",
                key.TenantId, key.GridId, cells?.Type.ToString() ?? "null");
            return;
        }

        var updates = new List<GridCellUpdate>();
        List<Func<IReadOnlyList<GridCellUpdate>, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in cellsArray)
            {
                var cellIdToken = item["CellId"];
                var valueToken = item["Value"];
                if (cellIdToken == null || valueToken == null) continue;
                var cellId = cellIdToken.Value<int>();
                var value = valueToken.Value<string>() ?? "";
                state.CellSnapshot[cellId] = value;
                updates.Add(new GridCellUpdate(cellId, value));
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogInformation(
            "RtmRelayService: updateGridData grid {GridId}: {Count} cells, {HandlerCount} handlers",
            key.GridId, updates.Count, handlers.Count);

        if (updates.Count > 0)
            await FanOutGridAsync(handlers, updates);
    }
```

## Verify usings at top of RtmRelayService.cs
Make sure these using statements exist:
- `using Newtonsoft.Json.Linq;`  ← needed for JToken, JArray
- `using Newtonsoft.Json.Serialization;` ← already there

If `using Newtonsoft.Json.Linq;` is missing, add it.

## Build & commit

```bash
dotnet build src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj
```

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# only if exit 0:
git add src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
git commit -m "fix: updateGridData handler JsonElement→JToken (Newtonsoft compat)

Newtonsoft.Json protocol cannot deserialize to System.Text.Json.JsonElement.
On<JsonElement> handler silently never fires — all updateGridData messages dropped.
Fix: use On<JToken> + JArray parsing which Newtonsoft handles natively.
"
```

```bash
for f in src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Expected result after deploy
Shell log should now show:
  RtmRelayService: updateGridData grid 29: N cells, M handlers
And widget should display real values instead of "-".
