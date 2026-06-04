# CC Task: Actualize widgets and simulator for real RTM SignalR protocol

## MANDATORY RULES (CLAUDE.md §0 — read before touching any file)

**§0.3 — Edit tool is BANNED in this repo. Python-only atomic writes:**
```python
with open(path, "r", encoding="utf-8") as f: text = f.read()
# ... str.replace / insertions ...
with open(path, "w", encoding="utf-8") as f: f.write(text)
```
After EVERY write — no exceptions:
```bash
tail -3 <path> && wc -l <path>
```
If truncated: `git show HEAD:<path> > <path>` and retry.

**§0.5 — Before every git commit:**
```bash
bash tools/pre-commit-check.sh   # must exit 0
```

**§0.4 — If git index.lock blocks commit:**
```bash
cp .git/index /tmp/cc-idx && GIT_INDEX_FILE=/tmp/cc-idx git add <files> && \
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "..." && cp /tmp/cc-idx .git/index
```

---

## Context

Blazor Server widgets currently connect to a local simulator at simulator-specific URLs
(`/hubs/queue-grid?gridId=N`). The goal is to switch them to the **real RTM SignalR server**
that runs on the CC platform.

Real RTM server source is in `RTM/RTM/` — **read-only reference, do not modify**.

---

## RTM Server Protocol (from source analysis)

### Connection
- **Hub URL**: `{SignalRConnectionUrl}/signalr` (single hub, no query string)
- **Serialization**: Newtonsoft.Json with `DefaultContractResolver` (PascalCase)
- After connecting, client **must** invoke `init(gridId)` to subscribe to a group
  - Queue / DataSlot grids: `init("42")` — numeric string
  - Agent grids: `init("u5")` — `"u"` + UnionId as string
- On reconnect: invoke `init()` again

### Server → Client pushes

**`updateGridData`** — delta updates for Queue / DataSlot grids  
Payload: `ICollection<CellData>` (array of objects)  
```json
[{"CellId": 123, "Value": "42", "Value2": "raw_value", "Grid": {"GridId": 42}}, ...]
```
Timer cells: `Value` starts with `+`, e.g. `"+01:23:45"` = elapsed time.
Strip the `+` prefix to get the display string. Never show `+` to the user.

**`updateUserGrid`** — full/delta agent list for Agent grids  
3 arguments: `(DateTime timestamp, int unionId, RTUsersResult result)`  
RTUsersResult serializes as:
```json
{"Data": [{"USERID":"u1","AgentLoginName":"John Smith","CurStatus":"AVAILABLE",...}, ...], "Count": 2}
```
Each agent dict: flat key-value pairs where keys = MetricId strings (match `AgentGridColumnDef.MetricId`).
Always-present keys: `"USERID"` (agent identifier), `"AgentLoginName"`.

**`removeUser`** — remove agents from grid  
2 arguments: `(int unionId, List<agentDict> users)`  
Same flat dict format as above. Identify agents to remove by `"USERID"` key.

---

## WidgetConfig fields (defined in ScreenEditorPage.razor `public class WidgetConfig`)

```
GridId: int?            — RTSGrid_Grid.GridId (Queue Grid) → pass as gridId.ToString() to init()
DataSlotGridId: int?    — RTSGrid_Grid.GridId (Data Slot)  → pass as DataSlotGridId.ToString()
DataSlotCellId: int?    — The single RTSGrid_Cell.CellId for Data Slot
RtsUserGridId: int?     — UnionId for Agent Grid → pass as $"u{RtsUserGridId}" to init()

QueueGridRows: List<QueueGridRowDef>
  QueueGridRowDef.Id: string              — internal GUID key
  QueueGridRowDef.CellIds: Dictionary<string, int?>  — key=QueueGridColumnDef.Id, value=CellId

QueueGridColumnDefs: List<QueueGridColumnDef>
  QueueGridColumnDef.Id: string           — matches QueueGridRowDef.CellIds key
  QueueGridColumnDef.MetricId: string     — metric name
  QueueGridColumnDef.ValueType: string?   — "Time" | "Number" | "String"
```

CellId → (RowDefId, MetricId) reverse map for Queue Grid (build in ApplyConfig):
```csharp
_cellMap = new Dictionary<int, (string RowDefId, string MetricId)>();
foreach (var row in _rowDefs)
    foreach (var col in _columnDefs)
        if (row.CellIds.TryGetValue(col.Id, out var cid) && cid.HasValue)
            _cellMap[cid.Value] = (row.Id, col.MetricId);
```

---

## Changes Required

### Change 1 — `src/CcDashboard.Web/CcDashboard.Web.csproj`

Add one NuGet package (same version family as existing SignalR packages):
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson" Version="8.0.16" />
```

Run `dotnet restore src/CcDashboard.Web` after.

---

### Change 2 — `src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor`

Widget uses `Config.DataSlotGridId` as the gridId and `Config.DataSlotCellId` to find its cell.

**In `@code` section:**

1. Remove local records `GridRowData` and `GridUpdate`.

2. Add:
```csharp
private record RtmCellData(int CellId, string Value, string Value2);
```

3. Replace `ConnectAsync()` body (keep the method signature and try/catch wrapper):
   - URL: `var fullUrl = $"{simulatorUrl}/signalr";` (no query string)
   - Builder: add `.AddNewtonsoftJsonProtocol()` after `.WithUrl(fullUrl)` in the chain
   - Remove: `_hub.On<GridUpdate>("QueueGridUpdate", OnQueueGridUpdate);`
   - Add: `_hub.On<List<RtmCellData>>("updateGridData", OnUpdateGridData);`
   - After `await _hub.StartAsync(_cts.Token)`:
     replace `await _hub.InvokeAsync("SubscribeToGrid", GridId, _cts.Token)`
     with    `await _hub.InvokeAsync("init", GridId.ToString(), _cts.Token)`
   - In `_hub.Reconnected` handler: add `await _hub.InvokeAsync("init", GridId.ToString())`
     (before or instead of existing Reconnected body, which just sets state)

4. Replace `OnQueueGridUpdate(GridUpdate update)` with:
```csharp
private void OnUpdateGridData(List<RtmCellData> cells)
{
    // Find the cell we're displaying
    string? rawValue = null;

    if (Config?.DataSlotCellId is int targetCellId && targetCellId > 0)
    {
        var cell = cells.FirstOrDefault(c => c.CellId == targetCellId);
        rawValue = cell?.Value;
    }
    else if (cells.Count > 0)
    {
        // Fallback: first cell in update (backward compat / unconfigured widget)
        rawValue = cells[0].Value;
    }

    if (rawValue is null) return;

    // Timer cells: strip '+' prefix, e.g. "+01:23:45" → "01:23:45"
    var value = rawValue.StartsWith('+') ? rawValue[1..] : rawValue;

    // --- paste the existing value-processing block from OnQueueGridUpdate ---
    // (parse time/numeric, set _currentValue, _displayValue, _isTimeFormat,
    //  CalculateDelta(), ApplyThresholds(), InvokeAsync(StateHasChanged))
}
```
The existing processing block (time parse → numeric parse → else) stays exactly as it is;
only the way `value` is obtained changes.

Note: DataSlot widget uses `Config.DataSlotGridId` (not `Config.GridId`) for the gridId.
Check the current `ConnectAsync()` — it reads `GridId` from the component parameter.
The component parameter `[Parameter] public int GridId { get; set; }` is set by the parent
to `Config.DataSlotGridId`. No change needed to how GridId is passed — only how it is used
in the hub call (`GridId.ToString()` instead of `SubscribeToGrid`).

---

### Change 3 — `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`

**In `@code` section:**

1. Remove local records `GridRowData` and `GridUpdate` if present.

2. Add:
```csharp
private record RtmCellData(int CellId, string Value, string Value2);
private Dictionary<int, (string RowDefId, string MetricId)> _cellMap = new();
```

3. At the end of `ApplyConfig()`, after populating `_rowDefs` and `_columnDefs`, add:
```csharp
// Build CellId → (RowDefId, MetricId) reverse map
_cellMap = new Dictionary<int, (string RowDefId, string MetricId)>();
foreach (var row in _rowDefs)
    foreach (var col in _columnDefs)
        if (row.CellIds.TryGetValue(col.Id, out var cid) && cid.HasValue)
            _cellMap[cid.Value] = (row.Id, col.MetricId);
```

4. In `ConnectAsync()`:
   - URL: `var fullUrl = $"{simulatorUrl}/signalr";`
   - Add `.AddNewtonsoftJsonProtocol()` in builder chain
   - Replace `_hub.On<GridUpdate>("QueueGridUpdate", async update => { ... })` with:
     ```csharp
     _hub.On<List<RtmCellData>>("updateGridData", async cells =>
     {
         var isFirstData = _rows.All(r => r.Metrics.Count == 0);
         foreach (var cell in cells)
         {
             if (!_cellMap.TryGetValue(cell.CellId, out var mapping)) continue;
             var (rowDefId, metricId) = mapping;
             var row = _rows.FirstOrDefault(r => r.RowId == rowDefId);
             if (row is null) continue;
             // Strip '+' timer prefix
             row.Metrics[metricId] = cell.Value?.StartsWith('+') == true
                 ? cell.Value[1..] : cell.Value ?? "";
         }
         if (isFirstData) DetectColumnDataTypes();
         await InvokeAsync(StateHasChanged);
     });
     ```
   - After `await _hub.StartAsync(_cts.Token)`:
     replace `await SendRowConfig()`
     with    `await _hub.InvokeAsync("init", GridId.ToString(), _cts.Token)`
   - In `_hub.Reconnected` handler:
     replace `await SendRowConfig()`
     with    `await _hub.InvokeAsync("init", GridId.ToString())`

5. Delete the `SendRowConfig()` method entirely.

6. In `ReconnectAsync()`: remove any `await SendRowConfig()` call if present.

---

### Change 4 — `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

Agent Grid uses `Config.RtsUserGridId` (the UnionId) as `GridId` parameter.
`init()` call uses `$"u{GridId}"`.

**In `@code` section:**

1. Add nested class (before or after existing inner classes):
```csharp
private class RtmUsersResult
{
    [Newtonsoft.Json.JsonProperty("Data")]
    public List<Dictionary<string, string>>? Data { get; set; }
    [Newtonsoft.Json.JsonProperty("Count")]
    public int Count { get; set; }
}
```

2. In `ConnectAsync()`:
   - URL: `var fullUrl = $"{simulatorUrl}/signalr";`
   - Add `.AddNewtonsoftJsonProtocol()` in builder chain
   - Remove: `_hub.On<GridUpdate>("AgentGridUpdate", async update => { ... })`
   - Add:
     ```csharp
     _hub.On<DateTime, int, RtmUsersResult>("updateUserGrid", async (ts, unionId, result) =>
     {
         if (result.Data is null) return;
         var isFirstData = _rows.Count == 0;
         foreach (var agentDict in result.Data)
         {
             var userId = agentDict.GetValueOrDefault("USERID")
                          ?? agentDict.GetValueOrDefault("AgentLoginName") ?? "";
             if (string.IsNullOrEmpty(userId)) continue;
             var existing = _rows.FirstOrDefault(r => r.RowId == userId);
             if (existing is not null)
             {
                 foreach (var kv in agentDict)
                     existing.Metrics[kv.Key] = StripTimerPrefix(kv.Value);
             }
             else
             {
                 _rows.Add(new AgentRowData
                 {
                     RowId = userId,
                     Metrics = agentDict.ToDictionary(
                         kv => kv.Key,
                         kv => StripTimerPrefix(kv.Value))
                 });
             }
         }
         if (isFirstData) DetectColumnDataTypes();
         await InvokeAsync(StateHasChanged);
     });

     _hub.On<int, List<Dictionary<string, string>>>("removeUser", async (unionId, users) =>
     {
         foreach (var agentDict in users)
         {
             var userId = agentDict.GetValueOrDefault("USERID")
                          ?? agentDict.GetValueOrDefault("AgentLoginName") ?? "";
             _rows.RemoveAll(r => r.RowId == userId);
         }
         await InvokeAsync(StateHasChanged);
     });
     ```
   - After `await _hub.StartAsync(_cts.Token)`:
     replace any `SubscribeToGrid` or similar call
     with    `await _hub.InvokeAsync("init", $"u{GridId}", _cts.Token)`
   - In `_hub.Reconnected` handler: add `await _hub.InvokeAsync("init", $"u{GridId}")`

3. Add helper at the end of `@code`:
```csharp
private static string StripTimerPrefix(string value)
    => value?.StartsWith('+') == true ? value[1..] : value ?? "";
```

4. Remove `GridRowData` and `GridUpdate` types if they exist in this file.

---

### Change 5 — `tools/SignalRSimulator/` — rework to RTM protocol

The simulator must expose a single hub at `/signalr` that speaks the same protocol as the
real RTM server. Keep existing `QueueDataGenerator`, `AgentDataGenerator`, `DbMetricService`
infrastructure — only change the hub layer and data push format.

#### 5a. `tools/SignalRSimulator/SignalRSimulator.csproj`

Add:
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson" Version="8.0.16" />
<PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
```

#### 5b. Add to `IDbMetricService` interface and `DbMetricService` class

New method for fetching CellId-keyed data:
```csharp
// Interface:
Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default);

// Implementation (add to DbMetricService):
public async Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default)
{
    var cells = new List<RtmCellInfo>();
    await using var conn = new NpgsqlConnection(_connectionString);
    await conn.OpenAsync(ct);
    const string sql = @"
        SELECT c.""CellId"", c.""Value"" AS MetricId, m.""DataType"", m.""DefaultValue""
        FROM ""RTSGrid_Cell"" c
        JOIN ""RTSGrid_Row"" r ON c.""RowId"" = r.""RowId""
        LEFT JOIN ""RTSGrid_Metric"" m ON c.""Value"" = m.""MetricId""
        WHERE r.""GridId"" = @gridId AND c.""CellType"" = 'Data' AND r.""RowNumber"" > 1
        ORDER BY r.""RowNumber"", c.""CellId""";
    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("gridId", gridId);
    await using var reader = await cmd.ExecuteReaderAsync(ct);
    while (await reader.ReadAsync(ct))
    {
        cells.Add(new RtmCellInfo(
            CellId: reader.GetInt32(0),
            MetricId: reader.IsDBNull(1) ? "" : reader.GetString(1),
            DataType: reader.IsDBNull(2) ? "String" : reader.GetString(2),
            DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3)
        ));
    }
    return cells;
}
```

Add model to `Models/GridModels.cs` (or a new `Models/RtmModels.cs`):
```csharp
public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue);

// For simulator pushes (PascalCase to match real RTM server)
public class RtmCellData
{
    public int CellId { get; set; }
    public string Value { get; set; } = "";
    public string Value2 { get; set; } = "";
    public RtmGridRef Grid { get; set; } = new();
}

public class RtmGridRef { public int GridId { get; set; } }

public class RtmUsersResult
{
    public List<Dictionary<string, string>> Data { get; set; } = new();
    public int Count { get; set; }
}
```

#### 5c. New file: `tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs`

Create a hub that replaces QueueGridHub + AgentGridHub:

```csharp
using Microsoft.AspNetCore.SignalR;
using SignalRSimulator.Generators;
using SignalRSimulator.Models;
using SignalRSimulator.Services;

namespace SignalRSimulator.Hubs;

/// <summary>
/// Simulates the real RTM SignalR hub at /signalr.
/// Client calls init(gridId) after connecting:
///   - Queue/DataSlot grids: gridId = "42" (numeric string)
///   - Agent grids:          gridId = "u5" (u + UnionId)
/// </summary>
public class RtmSimulatorHub : Hub
{
    // gridId → CTS for the generation loop
    private static readonly Dictionary<string, CancellationTokenSource> _activeGrids = new();
    // gridId → connectionIds
    private static readonly Dictionary<string, HashSet<string>> _gridConnections = new();
    private static readonly object _lock = new();

    private readonly IHubContext<RtmSimulatorHub> _hubContext;
    private readonly ILogger<RtmSimulatorHub> _logger;
    private readonly IDbMetricService _db;
    private readonly QueueDataGenerator _queueGen;
    private readonly AgentDataGenerator _agentGen;

    public RtmSimulatorHub(
        IHubContext<RtmSimulatorHub> hubContext,
        ILogger<RtmSimulatorHub> logger,
        IDbMetricService db,
        QueueDataGenerator queueGen,
        AgentDataGenerator agentGen)
    {
        _hubContext = hubContext;
        _logger = logger;
        _db = db;
        _queueGen = queueGen;
        _agentGen = agentGen;
    }

    // Matches RTM server signature — returns DateTime
    public DateTime init(string gridId)
    {
        _logger.LogInformation("init({GridId}) from {ConnectionId}", gridId, Context.ConnectionId);
        _ = SubscribeAsync(gridId);
        return DateTime.Now;
    }

    private async Task SubscribeAsync(string gridId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, gridId);
        lock (_lock)
        {
            if (!_gridConnections.ContainsKey(gridId))
                _gridConnections[gridId] = new HashSet<string>();
            _gridConnections[gridId].Add(Context.ConnectionId);
        }
        Context.Items["GridId"] = gridId;
        StartGeneration(gridId);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items.TryGetValue("GridId", out var g) && g is string gridId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, gridId);
            lock (_lock)
            {
                if (_gridConnections.TryGetValue(gridId, out var conns))
                {
                    conns.Remove(Context.ConnectionId);
                    if (conns.Count == 0)
                    {
                        _gridConnections.Remove(gridId);
                        StopGeneration(gridId);
                    }
                }
            }
        }
        await base.OnDisconnectedAsync(exception);
    }

    private void StartGeneration(string gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.ContainsKey(gridId)) return;
            var cts = new CancellationTokenSource();
            _activeGrids[gridId] = cts;
            if (gridId.StartsWith('u'))
                _ = GenerateAgentDataAsync(gridId, cts.Token);
            else
                _ = GenerateQueueDataAsync(gridId, cts.Token);
        }
    }

    private void StopGeneration(string gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.TryGetValue(gridId, out var cts))
            {
                cts.Cancel();
                _activeGrids.Remove(gridId);
            }
        }
    }

    // --- Queue / DataSlot generation ---
    private async Task GenerateQueueDataAsync(string gridId, CancellationToken ct)
    {
        if (!int.TryParse(gridId, out var numericGridId)) return;
        await Task.Delay(300, ct);

        List<RtmCellInfo>? cellInfos = null;

        while (!ct.IsCancellationRequested)
        {
            try
            {
                cellInfos ??= await _db.GetCellsForGridAsync(numericGridId, ct);

                if (cellInfos.Count == 0)
                {
                    _logger.LogWarning("No cells found for grid {GridId}", numericGridId);
                    await Task.Delay(10000, ct);
                    continue;
                }

                var cells = cellInfos.Select(ci => new RtmCellData
                {
                    CellId = ci.CellId,
                    Value  = GenerateFakeValue(ci.DataType, ci.DefaultValue),
                    Value2 = "",
                    Grid   = new RtmGridRef { GridId = numericGridId }
                }).ToList();

                await _hubContext.Clients.Group(gridId)
                    .SendAsync("updateGridData", cells, ct);

                _logger.LogDebug("Sent updateGridData to grid {GridId}: {Count} cells", gridId, cells.Count);
                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Queue generation error for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }

    // --- Agent grid generation ---
    private static readonly string[] AgentStatuses = ["AVAILABLE", "ONPHONE", "BREAK", "PAPERWORK", "TRAINING"];
    private static readonly string[] AgentNames = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Davis"];

    private async Task GenerateAgentDataAsync(string gridId, CancellationToken ct)
    {
        if (!int.TryParse(gridId[1..], out var unionId)) return;
        await Task.Delay(300, ct);

        // Stable agent list per unionId
        var agents = Enumerable.Range(1, 5).Select(i => $"agent{unionId}_{i:D2}").ToList();
        var rng = new Random(unionId);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var agentRows = agents.Select((userId, idx) =>
                {
                    var status = AgentStatuses[rng.Next(AgentStatuses.Length)];
                    var elapsed = TimeSpan.FromSeconds(rng.Next(0, 3600));
                    return new Dictionary<string, string>
                    {
                        ["USERID"]          = userId,
                        ["AgentLoginName"]  = AgentNames[idx % AgentNames.Length],
                        ["CurStatus"]       = status,
                        ["CurStatusTitle"]  = status,
                        ["CurStatusGroup"]  = status == "ONPHONE" ? "OnPhone" : "NotOnPhone",
                        // Timer value — '+' prefix means running elapsed timer
                        ["CurStatusDuration"] = $"+{elapsed:hh\\:mm\\:ss}",
                        ["CurLoginDuration"]  = $"+{elapsed + TimeSpan.FromMinutes(30):hh\\:mm\\:ss}",
                        ["Station"]         = $"STA{1000 + idx}",
                    };
                }).ToList();

                var result = new RtmUsersResult { Data = agentRows, Count = agentRows.Count };
                await _hubContext.Clients.Group(gridId)
                    .SendAsync("updateUserGrid", DateTime.Now, unionId, result, ct);

                _logger.LogDebug("Sent updateUserGrid to {GridId}: {Count} agents", gridId, agentRows.Count);
                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Agent generation error for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }

    private static readonly Random _valueRng = new();

    private static string GenerateFakeValue(string dataType, string? defaultValue)
    {
        return dataType switch
        {
            "Integer" => _valueRng.Next(0, 200).ToString(),
            "Time"    => TimeSpan.FromSeconds(_valueRng.Next(0, 3600)).ToString(@"mm\:ss"),
            "Percent" => $"{_valueRng.Next(0, 100)}%",
            _         => defaultValue ?? "0"
        };
    }
}
```

#### 5d. Update `tools/SignalRSimulator/Program.cs`

Replace:
```csharp
builder.Services.AddSignalR();
```
with:
```csharp
builder.Services.AddSignalR()
    .AddNewtonsoftJsonProtocol(options =>
    {
        options.PayloadSerializerSettings.ContractResolver =
            new Newtonsoft.Json.Serialization.DefaultContractResolver();
    });
```

Remove the two old hub mappings:
```csharp
app.MapHub<AgentGridHub>("/hubs/agent-grid");
app.MapHub<QueueGridHub>("/hubs/queue-grid");
```

Add:
```csharp
app.MapHub<RtmSimulatorHub>("/signalr");
```

Update the root GET response text to reflect the new endpoint.

Old hubs `QueueGridHub.cs` and `AgentGridHub.cs` can remain as-is (they won't be mapped).
Old `Models/GridModels.cs` keep as-is (generators still use it internally). 

---

## Verification

After all changes:

```bash
# 1. Restore packages
dotnet restore CcDashboard.sln
dotnet restore tools/SignalRSimulator/SignalRSimulator.csproj

# 2. Build widgets project
dotnet build src/CcDashboard.Web --no-restore 2>&1 | tail -5

# 3. Build simulator
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj --no-restore 2>&1 | tail -5
```

Both must report `Build succeeded. 0 Error(s)`.

Also verify by grep:
```bash
# All three widgets must use /signalr and .AddNewtonsoftJsonProtocol
grep -n "AddNewtonsoftJsonProtocol\|/signalr\|InvokeAsync.*init" \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor

# No old simulator-specific push names should remain
grep -rn "QueueGridUpdate\|AgentGridUpdate\|SubscribeToGrid\|UpdateRowConfig" \
  src/CcDashboard.Web/Components/Widgets/
```

Both greps must produce the expected output (init calls present, old method names absent).

---

## Commit

```bash
bash tools/pre-commit-check.sh   # must exit 0
```

Then commit with:
```
feat: actualize widgets and simulator for real RTM SignalR protocol

- CcDashboard.Web: add Newtonsoft SignalR protocol package
- DataSlotWidget: connect to /signalr, init(gridId), handle updateGridData by CellId
- QueueGridWidget: connect to /signalr, init(gridId), CellId→metric reverse map
- AgentGridWidget: connect to /signalr, init("u{UnionId}"), handle updateUserGrid/removeUser
- SignalRSimulator: new RtmSimulatorHub at /signalr matching real RTM protocol
- Timer prefix '+' stripped in all widgets before display
```
