# CC Task: Wire widgets to IRtmRelayService (Шаг 7 плана CC-003)

## MANDATORY RULES (CLAUDE.md §0)

**§0.3 — Edit tool BANNED. Python atomic writes only:**
```python
with open(path, "r", encoding="utf-8") as f: text = f.read()
# ... str.replace / insertions ...
with open(path, "w", encoding="utf-8") as f:
    f.write(text); f.flush(); os.fsync(f.fileno())
```
After EVERY write — no exceptions:
```bash
sync && tail -3 <path> && wc -l <path>
```
If truncated: `git show HEAD:<path> > <path>` and retry.

**§0.5 — Before every git commit:**
```bash
bash tools/pre-commit-check.sh   # must exit 0
```

---

## §0 — SESSION-RESUME INTEGRITY CHECK (run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -1
git status --short
```
For every `M` file: `tail -3 <path>` — if truncated, restore: `git show HEAD:<path> > <path>`

---

## Goal

Complete **Step 7** of the RTM Relay plan (CLAUDE.md §34): switch the four widget
components from direct `HubConnectionBuilder` connections to the server-side
`IRtmRelayService`. This activates the single-port browser model — browser only
uses port 443, RTM server is never directly reachable from the browser.

**Widgets to migrate:**
1. `QueueGridWidget.razor` — grid subscription, multi-BU (one GridId, multiple rows)
2. `DataSlotWidget.razor` — grid subscription
3. `AgentStateDistributionWidget.razor` — grid subscription
4. `AgentGridWidget.razor` — union subscription

---

## Architecture recap

`IRtmRelayService` (Application/Interfaces/IRtmRelayService.cs):
```csharp
Task SubscribeGridAsync(Guid tenantId, int gridId,
    Func<IReadOnlyList<GridCellUpdate>, Task> handler, CancellationToken ct = default);
Task UnsubscribeGridAsync(Guid tenantId, int gridId,
    Func<IReadOnlyList<GridCellUpdate>, Task> handler);

Task SubscribeUnionAsync(Guid tenantId, int unionId,
    Func<UnionStateChange, Task> handler, CancellationToken ct = default);
Task UnsubscribeUnionAsync(Guid tenantId, int unionId,
    Func<UnionStateChange, Task> handler);
```

`GridCellUpdate` = `record GridCellUpdate(int CellId, string Value)` — same shape as
current `RtmCellData`. Direct replacement in existing cell-map lookup.

`UnionStateChange` = discriminated union:
- `InitialSnapshot(IReadOnlyDictionary<string,AgentSnapshot> Agents, TimeSpan ServerTimeOffset)`
  — delivered immediately on subscribe if relay already has data
- `AgentsUpserted(IReadOnlyList<AgentSnapshot> Agents)` — replaces `updateUserGrid`
- `AgentsRemoved(IReadOnlyList<string> AgentLoginNames)` — replaces `removeUser`

`AgentSnapshot` = `record AgentSnapshot(string AgentLoginName, IReadOnlyDictionary<string,CellValue> Fields, DateTime ReceivedAt)`

`CellValue.Raw` = the raw string value, same as what current `ApplyMetricValue` receives.
Timer prefix `+` is preserved in `Raw` (relay does not strip it).

TenantId: get from `settings.TenantId` after `Mediator.Send(new GetTenantSettingsQuery())`.

---

## IMPORTANT: QueueGrid — one subscription regardless of BU count

QueueGrid can show data for **multiple Business Units** (multiple rows, each with its own
`BusinessUnitId`). All BU rows belong to the **same single RTSGrid_Grid** (one `_rtsGridId`).
All BU cell data arrives in one `updateGridData` push, decoded by the existing `_cellMap`.

**→ ONE `SubscribeGridAsync` call per QueueGrid widget. Never subscribe per BU.**

---

## Changes — File 1: QueueGridWidget.razor (1387 lines)

### 1a. Remove SignalR using, add Rtm using

Find (line 3):
```razor
@using Microsoft.AspNetCore.SignalR.Client
```
Replace with:
```razor
@using CcDashboard.Domain.Domain.Rtm
@using CcDashboard.Application.Interfaces
```

### 1b. Add inject after existing injects (after line 10)

Find:
```razor
@inject IJSRuntime JS
```
Replace with:
```razor
@inject IJSRuntime JS
@inject IRtmRelayService RtmRelay
```

### 1c. Replace private fields block

Find:
```csharp
    private HubConnection? _hub;
```
Replace with:
```csharp
    private Guid _tenantId;
    private Func<IReadOnlyList<GridCellUpdate>, Task>? _gridHandler;
```

### 1d. Update the ConnectAsync guard (change `_hub is null` to `_gridHandler is null`)

Find:
```csharp
        if (GridId != 0 && _previousGridId == 0 && _hub is null)
```
Replace with:
```csharp
        if (GridId != 0 && _previousGridId == 0 && _gridHandler is null)
```

Find:
```csharp
        if (_lastColumnsKey != "" && newColumnsKey != _lastColumnsKey && _hub is not null)
```
Replace with:
```csharp
        if (_lastColumnsKey != "" && newColumnsKey != _lastColumnsKey && _gridHandler is not null)
```

### 1e. Replace ConnectAsync body

Find the entire `private async Task ConnectAsync()` method (from `private async Task ConnectAsync()` to the closing `}` of the catch block, approximately lines 429–514).

Identify the exact span by looking for:
```csharp
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
```
...down to the end of the try/catch.

Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
        {
            Logger.LogWarning("QueueGridWidget: Config.GridId not set, skipping connection");
            return;
        }

        _connectionState = ConnectionState.Connecting;
        Logger.LogInformation("QueueGridWidget: Subscribing to GridId {GridId}", _rtsGridId);

        try
        {
            if (_tenantId == Guid.Empty)
            {
                var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
                _tenantId = settings!.TenantId;
            }

            _gridHandler = async updates =>
            {
                var isFirstData = _rows.All(r => r.Metrics.Count == 0);
                foreach (var cell in updates)
                {
                    if (!_cellMap.TryGetValue(cell.CellId, out var mapping)) continue;
                    var (rowDefId, metricId) = mapping;
                    var row = _rows.FirstOrDefault(r => r.RowId == rowDefId);
                    if (row is null) continue;
                    ApplyMetricValue(row, metricId, cell.Value ?? "");
                }
                if (isFirstData) DetectColumnDataTypes();
                await InvokeAsync(StateHasChanged);
            };

            await RtmRelay.SubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler, _cts.Token);
            _connectionState = ConnectionState.Connected;
            _ = StartTickLoopAsync();
            Logger.LogInformation("QueueGridWidget: subscribed to GridId {GridId}", _rtsGridId);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "QueueGridWidget: Failed to subscribe. Error: {Message}", ex.Message);
            _connectionState = ConnectionState.Failed;
        }
    }
```

### 1f. Replace ReconnectAsync body

Find `private async Task ReconnectAsync()` and its body (the block that disposes `_hub` and calls `ConnectAsync`). Replace with:
```csharp
    private async Task ReconnectAsync()
    {
        if (_gridHandler != null && _rtsGridId > 0 && _tenantId != Guid.Empty)
        {
            await RtmRelay.UnsubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler);
            _gridHandler = null;
        }

        _rows = _rowDefs.Select(r => new QueueRowData
        {
            RowId = r.Id,
            QueueName = r.QueueName ?? r.BusinessUnitName ?? ""
        }).ToList();

        await ConnectAsync();
    }
```

### 1g. Replace DisposeAsync hub disposal

Find in `DisposeAsync`:
```csharp
                await _hub.DisposeAsync();
```
(there may be try/catch around it — replace the whole hub-related block)

Find the `_hub` disposal block in `DisposeAsync`. Replace with:
```csharp
            if (_gridHandler != null && _rtsGridId > 0 && _tenantId != Guid.Empty)
            {
                try { await RtmRelay.UnsubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler); } catch { }
                _gridHandler = null;
            }
```

---

## Changes — File 2: DataSlotWidget.razor (533 lines)

### 2a. Remove SignalR using, add Rtm using (line 2)

Find:
```razor
@using Microsoft.AspNetCore.SignalR.Client
```
Replace with:
```razor
@using CcDashboard.Domain.Domain.Rtm
@using CcDashboard.Application.Interfaces
```

### 2b. Add inject

Find:
```razor
@inject ISender Mediator
```
Replace with:
```razor
@inject ISender Mediator
@inject IRtmRelayService RtmRelay
```

### 2c. Replace private fields

Find:
```csharp
    private HubConnection? _hub;
```
Replace with:
```csharp
    private Guid _tenantId;
    private Func<IReadOnlyList<GridCellUpdate>, Task>? _gridHandler;
```

### 2d. Replace ConnectAsync body

Find the entire `private async Task ConnectAsync()` method. Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
        {
            Logger.LogWarning("DataSlotWidget: GridId not set, skipping connection");
            return;
        }

        _connectionState = ConnectionState.Connecting;

        try
        {
            if (_tenantId == Guid.Empty)
            {
                var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
                _tenantId = settings!.TenantId;
            }

            _gridHandler = async updates =>
            {
                foreach (var cell in updates)
                {
                    if (cell.CellId == _rtsMetricCellId)
                        await OnUpdateGridData(new List<RtmCellData> { new() { CellId = cell.CellId, Value = cell.Value } });
                }
            };

            await RtmRelay.SubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler, _cts.Token);
            _connectionState = ConnectionState.Connected;
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "DataSlotWidget: Failed to subscribe. Error: {Message}", ex.Message);
            _connectionState = ConnectionState.Failed;
        }
    }
```

**NOTE:** If `DataSlotWidget` currently has its own `OnUpdateGridData(List<RtmCellData>)` method
or inline handler — keep that logic unchanged and just route `GridCellUpdate` into it.
Alternatively, if the handler is inline in `ConnectAsync`, extract it as follows:

The existing `_hub.On<List<RtmCellData>>("updateGridData", OnUpdateGridData)` handler
is `OnUpdateGridData`. Reroute `GridCellUpdate` items into it:

```csharp
            _gridHandler = async updates =>
            {
                var cells = updates.Select(u => new RtmCellData { CellId = u.CellId, Value = u.Value }).ToList();
                await OnUpdateGridData(cells);
            };
```

If `RtmCellData` is not accessible from the widget (it may be in a different namespace),
instead inline the logic directly — copy the body of `OnUpdateGridData` into the lambda.

**Read the actual `OnUpdateGridData` / inline handler in the current file before implementing,
and keep the logic 100% identical — only the data source changes.**

### 2e. Replace ReconnectAsync

Find `private async Task ReconnectAsync()`. Replace with:
```csharp
    private async Task ReconnectAsync()
    {
        if (_gridHandler != null && _rtsGridId > 0 && _tenantId != Guid.Empty)
        {
            await RtmRelay.UnsubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler);
            _gridHandler = null;
        }
        await ConnectAsync();
    }
```

### 2f. Replace DisposeAsync hub block

Find and replace `_hub` disposal in `DisposeAsync` with:
```csharp
            if (_gridHandler != null && _rtsGridId > 0 && _tenantId != Guid.Empty)
            {
                try { await RtmRelay.UnsubscribeGridAsync(_tenantId, _rtsGridId, _gridHandler); } catch { }
                _gridHandler = null;
            }
```

---

## Changes — File 3: AgentStateDistributionWidget.razor (624 lines)

Same pattern as DataSlot/QueueGrid (grid subscription).

### 3a–3b. Same using/inject changes as above

Remove `@using Microsoft.AspNetCore.SignalR.Client`, add:
```razor
@using CcDashboard.Domain.Domain.Rtm
@using CcDashboard.Application.Interfaces
@inject IRtmRelayService RtmRelay
```

### 3c. Replace field

Find:
```csharp
    private HubConnection? _hub;
```
Replace with:
```csharp
    private Guid _tenantId;
    private Func<IReadOnlyList<GridCellUpdate>, Task>? _gridHandler;
```

### 3d. Update guard (same as QueueGrid pattern)

Find:
```csharp
        if (currentGridId != 0 && _previousGridId == 0 && _hub is null && _businessUnitId > 0)
```
Replace with:
```csharp
        if (currentGridId != 0 && _previousGridId == 0 && _gridHandler is null && _businessUnitId > 0)
```

### 3e. Replace ConnectAsync body

Find the entire `ConnectAsync()` method. Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (RtsGridId == 0 || _businessUnitId == 0)
        {
            Logger.LogWarning("AgentStateDistributionWidget: RtsGridId or BusinessUnitId is 0, skipping connection");
            return;
        }

        Logger.LogInformation("AgentStateDistributionWidget: Subscribing to GridId {GridId}", RtsGridId);
        _connectionState = ConnectionState.Connecting;

        try
        {
            // Load CellId → MetricId map so GridCellUpdate items can be decoded
            _cellIdToMetric = await Mediator.Send(new GetRtsGridCellMapQuery(RtsGridId), _cts.Token);
            Logger.LogInformation("AgentStateDistributionWidget: loaded {Count} cells for grid {GridId}",
                _cellIdToMetric.Count, RtsGridId);

            if (_tenantId == Guid.Empty)
            {
                var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
                _tenantId = settings!.TenantId;
            }

            _gridHandler = async updates =>
            {
                // Route to existing updateGridData handler logic (keep logic identical)
                var cells = updates
                    .Select(u => new RtmCellData { CellId = u.CellId, Value = u.Value })
                    .ToList();
                await HandleGridDataAsync(cells);
            };

            await RtmRelay.SubscribeGridAsync(_tenantId, RtsGridId, _gridHandler, _cts.Token);
            _connectionState = ConnectionState.Connected;
            Logger.LogInformation("AgentStateDistributionWidget: subscribed to GridId {GridId}", RtsGridId);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "AgentStateDistributionWidget: Failed to subscribe. Error: {Message}", ex.Message);
            _connectionState = ConnectionState.Failed;
        }
    }
```

Extract the existing `_hub.On<List<RtmCellData>>("updateGridData", ...)` handler body into
a private method `HandleGridDataAsync(List<RtmCellData> cells)`.

**Read actual handler body in current file, keep logic 100% identical.**

### 3f. Replace ReconnectAsync + DisposeAsync

Same pattern as QueueGrid: `UnsubscribeGridAsync(_tenantId, RtsGridId, _gridHandler)`.
In `DisposeAsync`, use `RtsGridId` (the property).

---

## Changes — File 4: AgentGridWidget.razor (1459 lines)

AgentGrid uses **union subscription**, not grid subscription.

### 4a–4b. Using/inject changes

Remove `@using Microsoft.AspNetCore.SignalR.Client`, add:
```razor
@using CcDashboard.Domain.Domain.Rtm
@using CcDashboard.Application.Interfaces
@inject IRtmRelayService RtmRelay
```

### 4c. Replace field

Find:
```csharp
    private HubConnection? _hub;
```
Replace with:
```csharp
    private Guid _tenantId;
    private Func<UnionStateChange, Task>? _unionHandler;
```

### 4d. Update guard

Find:
```csharp
        if (GridId != 0 && _previousGridId == 0 && _hub is null)
```
Replace with:
```csharp
        if (GridId != 0 && _previousGridId == 0 && _unionHandler is null)
```

### 4e. Replace ConnectAsync body

Find the entire `ConnectAsync()` method (lines ~488–596). Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (GridId == 0)
        {
            Logger.LogWarning("AgentGridWidget: GridId is 0, skipping connection");
            return;
        }

        _connectionState = ConnectionState.Connecting;
        Logger.LogInformation("AgentGridWidget: Subscribing to union {UnionId}", _rtsGridId > 0 ? _rtsGridId : GridId);

        await Task.Delay(Random.Shared.Next(100, 500), _cts.Token);

        try
        {
            if (_tenantId == Guid.Empty)
            {
                var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
                _tenantId = settings!.TenantId;
            }

            var unionId = _rtsGridId > 0 ? _rtsGridId : GridId;

            _unionHandler = async change =>
            {
                await InvokeAsync(async () =>
                {
                    switch (change)
                    {
                        case UnionStateChange.InitialSnapshot snap:
                            _rows.Clear();
                            var now = DateTime.UtcNow;
                            foreach (var (_, agent) in snap.Agents)
                            {
                                var row = new AgentRowData { RowId = agent.AgentLoginName };
                                foreach (var kv in agent.Fields)
                                    ApplyMetricValue(row, kv.Key, kv.Value.Raw, now);
                                _rows.Add(row);
                            }
                            if (_rows.Count > 0) DetectColumnDataTypes();
                            break;

                        case UnionStateChange.AgentsUpserted upserted:
                            var isFirstData = _rows.Count == 0;
                            var upsertNow = DateTime.UtcNow;
                            foreach (var agent in upserted.Agents)
                            {
                                var existing = _rows.FirstOrDefault(r => r.RowId == agent.AgentLoginName);
                                if (existing is not null)
                                {
                                    foreach (var kv in agent.Fields)
                                        ApplyMetricValue(existing, kv.Key, kv.Value.Raw, upsertNow);
                                }
                                else
                                {
                                    var row = new AgentRowData { RowId = agent.AgentLoginName };
                                    foreach (var kv in agent.Fields)
                                        ApplyMetricValue(row, kv.Key, kv.Value.Raw, upsertNow);
                                    _rows.Add(row);
                                }
                            }
                            if (isFirstData) DetectColumnDataTypes();
                            break;

                        case UnionStateChange.AgentsRemoved removed:
                            foreach (var name in removed.AgentLoginNames)
                                _rows.RemoveAll(r => r.RowId == name);
                            break;
                    }
                    _connectionState = ConnectionState.Connected;
                    StateHasChanged();
                });
            };

            await RtmRelay.SubscribeUnionAsync(_tenantId, unionId, _unionHandler, _cts.Token);
            _connectionState = ConnectionState.Connected;
            Logger.LogInformation("AgentGridWidget: subscribed to union {UnionId}", unionId);
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "AgentGridWidget: Failed to subscribe. Error: {Message}", ex.Message);
            _connectionState = ConnectionState.Failed;
        }
    }
```

### 4f. Replace ReconnectAsync

Find `private async Task ReconnectAsync()`. Replace with:
```csharp
    private async Task ReconnectAsync()
    {
        if (_unionHandler != null && _tenantId != Guid.Empty)
        {
            var unionId = _rtsGridId > 0 ? _rtsGridId : GridId;
            await RtmRelay.UnsubscribeUnionAsync(_tenantId, unionId, _unionHandler);
            _unionHandler = null;
        }
        _rows.Clear();
        await ConnectAsync();
    }
```

### 4g. Replace DisposeAsync hub block

Find the `_hub` disposal block in `DisposeAsync`. Replace with:
```csharp
            if (_unionHandler != null && _tenantId != Guid.Empty)
            {
                try
                {
                    var unionId = _rtsGridId > 0 ? _rtsGridId : GridId;
                    await RtmRelay.UnsubscribeUnionAsync(_tenantId, unionId, _unionHandler);
                }
                catch { }
                _unionHandler = null;
            }
```

---

## NuGet cleanup (optional, do after confirming build passes)

`Microsoft.AspNetCore.SignalR.Client` was added to `CcDashboard.Web.csproj` for the widgets.
After migration, if NO other code in `CcDashboard.Web` imports it, it can be removed.
Check first: `grep -r "SignalR.Client\|HubConnectionBuilder" src/CcDashboard.Web/ --include="*.cs" --include="*.razor"`
Remove only if grep returns no matches.

---

## Verification

```bash
# 1. Build
dotnet build src/CcDashboard.Web --no-restore 2>&1 | tail -5
# Expected: Build succeeded. 0 Error(s).

# 2. No HubConnectionBuilder left in widgets
grep -n "HubConnectionBuilder\|_hub\b" \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: no output

# 3. All widgets use RtmRelay
grep -n "RtmRelay\.\(Subscribe\|Unsubscribe\)" \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: 2 lines per widget (Subscribe + Unsubscribe)

# 4. Run tests (no regressions)
dotnet test CcDashboard.sln 2>&1 | tail -5
```

---

## Commit message

```
feat(relay): wire all widgets to IRtmRelayService — single-port browser model complete

- QueueGridWidget: SubscribeGridAsync (one sub regardless of BU count)
- DataSlotWidget: SubscribeGridAsync
- AgentStateDistributionWidget: SubscribeGridAsync
- AgentGridWidget: SubscribeUnionAsync with InitialSnapshot/AgentsUpserted/AgentsRemoved
- Remove HubConnectionBuilder from all four widgets
- Browser no longer opens direct WebSocket to RTM server

Closes: RTM Relay Шаг 7 (CLAUDE.md §34)
```


---

## Part 2 — Fix RtmRelayService (two bugs) + Simulator CORS cleanup

### Bug 1 — GetHubUrlAsync does not append /signalr

`RtmRelayService.GetHubUrlAsync` returns the raw `SignalRConnectionUrl` value, e.g.
`"http://localhost:5045"`. `BuildUnionConnection` and `BuildGridConnection` use this
directly: `.WithUrl(hubUrl)`. But the hub endpoint is at `/signalr`, not at the base URL.

Widgets previously appended the path manually: `$"{simulatorUrl}/signalr"`.
The relay must do the same.

**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

In `GetHubUrlAsync`, before caching and returning the URL, append `/signalr`:

Find (end of method, before return):
```csharp
        // 3. Cache for 5 minutes
        await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
        return url;
```
Replace with:
```csharp
        // 3. Normalise: ensure URL ends with /signalr (widgets previously appended this manually)
        if (!url.TrimEnd('/').EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
            url = url.TrimEnd('/') + "/signalr";

        // 4. Cache for 5 minutes
        await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
        return url;
```

### Bug 2 — Relay uses System.Text.Json; simulator and real RTM server use Newtonsoft

The simulator (`tools/SignalRSimulator/Program.cs`) registers:
```csharp
builder.Services.AddSignalR().AddNewtonsoftJsonProtocol(...)
```

`RtmRelayService.BuildUnionConnection` and `BuildGridConnection` both end with `.Build()`
without specifying a JSON protocol. The default is System.Text.Json — a protocol mismatch
with both the simulator and the real RTM server.

**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

Add Newtonsoft package reference to the project file if not already present:
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Client.Core" Version="8.*" />
```
(SignalR.Client already includes this transitively — check with
`dotnet list src/CcDashboard.Infrastructure package | grep SignalR` first.)

Add using at top of `RtmRelayService.cs` if not present:
```csharp
using Newtonsoft.Json.Serialization;
```

In `BuildUnionConnection`, find:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```
Replace with:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
            {
                opts.PayloadSerializerSettings.ContractResolver =
                    new DefaultContractResolver(); // PascalCase — matches RTM server
            })
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```

Apply the same replacement to `BuildGridConnection`.

**NuGet:** `Microsoft.AspNetCore.SignalR.Client` already pulls in the Newtonsoft protocol
extension via `Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson`. If the build fails
on `AddNewtonsoftJsonProtocol`, add to `CcDashboard.Infrastructure.csproj`:
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson" Version="8.*" />
```

---

### Simulator — remove CORS (server-to-server, no browser connections)

After relay migration, the simulator is only accessed server-to-server by
`RtmRelayService`. Browsers never connect to the simulator directly.
CORS headers are only relevant for browser requests — remove the configuration.

**File:** `tools/SignalRSimulator/Program.cs`

Find and remove the entire CORS block:
```csharp
// CORS origins loaded from appsettings — CcDashboard.Web URL must be listed
var corsOrigins = builder.Configuration.GetSection("CorsOrigins").Get<string[]>()
    ?? new[] { "http://localhost:5000" };

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(corsOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});
```

Also find and remove:
```csharp
app.UseCors();
```

Update the root GET response text to reflect relay architecture:
Find:
```csharp
app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr\nClient calls init(gridId) after connecting:\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nMetrics are loaded from database.");
```
Replace with:
```csharp
app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr (server-to-server via RtmRelayService)\nProtocol: Newtonsoft JSON (PascalCase)\nClient calls init(gridId):\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nEndpoints:\n  GET /LoadData - invalidate metric cache\nMetrics loaded from database.");
```

**File:** `tools/SignalRSimulator/appsettings.json`

Remove the `CorsOrigins` key:
```json
  "CorsOrigins": [
    "http://localhost:5000",
    "http://localhost:5239"
  ]
```

---

## Updated Verification (full)

```bash
# 1. Build all
dotnet build CcDashboard.sln --no-restore 2>&1 | tail -5
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj --no-restore 2>&1 | tail -5

# 2. No HubConnectionBuilder left in widgets
grep -rn "HubConnectionBuilder" src/CcDashboard.Web/Components/Widgets/

# 3. Relay appends /signalr
grep -n "signalr" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

# 4. Relay uses Newtonsoft
grep -n "AddNewtonsoftJsonProtocol" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Expected: 2 matches (BuildUnionConnection + BuildGridConnection)

# 5. Simulator has no CORS
grep -n "Cors\|cors" tools/SignalRSimulator/Program.cs
# Expected: no output

# 6. Tests
dotnet test CcDashboard.sln 2>&1 | tail -5
```

## Updated commit message

```
feat(relay): complete single-port relay — wire widgets + fix relay bugs + remove sim CORS

Widgets:
- QueueGridWidget, DataSlotWidget, AgentStateDistributionWidget: SubscribeGridAsync
- AgentGridWidget: SubscribeUnionAsync (InitialSnapshot/AgentsUpserted/AgentsRemoved)
- Remove HubConnectionBuilder from all four widgets

RtmRelayService fixes:
- Append /signalr to hub URL (SignalRConnectionUrl stores base URL, not hub path)
- Add AddNewtonsoftJsonProtocol to BuildUnionConnection + BuildGridConnection

Simulator:
- Remove CORS (server-to-server only; browsers never connect directly)
- Remove CorsOrigins from appsettings.json
- Update root endpoint description

Closes: RTM Relay Шаг 7 (CLAUDE.md §34)
```
