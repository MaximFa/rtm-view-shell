# CC Task: Fix SSR pre-render subscribe cycling in AgentGrid, DataSlot, AgentStateDistribution

## Problem
Same SSR pre-render bug as QueueGridWidget (fixed in commit b45618b).
OnInitializedAsync and OnParametersSetAsync run during SSR pre-render →
widget subscribes → component immediately disposed → grace timer → 30s → connection drop.

Fix pattern (same for all widgets):
1. Remove ConnectAsync() from OnInitializedAsync (keep other setup code)
2. Remove initial ConnectAsync() from OnParametersSetAsync (keep reconnect-on-change logic)
3. Add ConnectAsync() to OnAfterRenderAsync(firstRender) — does NOT run during SSR
4. Add `if (_handler is not null) return;` guard in ConnectAsync to prevent double-subscribe

---

## Widget 1: AgentGridWidget.razor

### Change 1a — OnInitializedAsync: remove ConnectAsync call

Find:
```csharp
    protected override async Task OnInitializedAsync()
    {
        ApplyConfig();
        await ConnectAsync();
    }
```

Replace with:
```csharp
    protected override async Task OnInitializedAsync()
    {
        ApplyConfig();
        // ConnectAsync moved to OnAfterRenderAsync — does not run during SSR pre-render
    }
```

### Change 1b — OnParametersSetAsync: remove initial ConnectAsync call

Find:
```csharp
        if (GridId != 0 && _previousGridId == 0 && _unionHandler is null)
        {
            _previousGridId = GridId;
            await ConnectAsync();
        }
```

Replace with:
```csharp
        if (GridId != 0 && _previousGridId == 0)
        {
            _previousGridId = GridId;
            // Initial connect handled in OnAfterRenderAsync(firstRender)
        }
```

### Change 1c — OnAfterRenderAsync: add ConnectAsync call

Find:
```csharp
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            _ = StartTickLoopAsync();
            if (GridId != 0 && !_stateLoaded)
            {
                _stateLoaded = true;
                await LoadWidgetStateAsync();
                StateHasChanged();
            }
        }
    }
```

Replace with:
```csharp
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            await ConnectAsync();
            _ = StartTickLoopAsync();
            if (GridId != 0 && !_stateLoaded)
            {
                _stateLoaded = true;
                await LoadWidgetStateAsync();
                StateHasChanged();
            }
        }
    }
```

### Change 1d — ConnectAsync: add double-subscribe guard

Find the start of ConnectAsync (the check at the top):
```csharp
    private async Task ConnectAsync()
    {
        if (GridId == 0)
        {
            Logger.LogWarning("AgentGridWidget: GridId is 0, skipping connection");
            return;
        }
```

Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (GridId == 0)
        {
            Logger.LogWarning("AgentGridWidget: GridId is 0, skipping connection");
            return;
        }
        if (_unionHandler is not null)
        {
            Logger.LogDebug("AgentGridWidget: already subscribed to union {UnionId}, skipping duplicate ConnectAsync", _rtsGridId > 0 ? _rtsGridId : GridId);
            return;
        }
```

---

## Widget 2: DataSlotWidget.razor

### Change 2a — OnInitializedAsync: remove ConnectAsync call

Find:
```csharp
    protected override async Task OnInitializedAsync()
    {
        ApplyConfig();
        if (GridId > 0)
        {
            await ConnectAsync();
        }
        else
        {
            _connectionState = ConnectionState.Connected;
        }
    }
```

Replace with:
```csharp
    protected override async Task OnInitializedAsync()
    {
        ApplyConfig();
        // ConnectAsync moved to OnAfterRenderAsync — does not run during SSR pre-render
    }
```

### Change 2b — OnParametersSetAsync: guard reconnect with _gridHandler check

Find:
```csharp
    protected override async Task OnParametersSetAsync()
    {
        ApplyConfig();
        // Reconnect when DataSlotGridId becomes available (e.g. first Save after widget placed)
        if (_rtsGridId > 0 && _rtsGridId != _prevRtsGridId)
        {
            _prevRtsGridId = _rtsGridId;
            await ReconnectAsync();
        }
        else
        {
            _prevRtsGridId = _rtsGridId;
        }
    }
```

Replace with:
```csharp
    protected override async Task OnParametersSetAsync()
    {
        ApplyConfig();
        // Reconnect when GridId changes on a live connection.
        // Guard: _gridHandler is not null ensures we only reconnect after initial connect (OnAfterRenderAsync).
        if (_gridHandler is not null && _rtsGridId > 0 && _rtsGridId != _prevRtsGridId)
        {
            _prevRtsGridId = _rtsGridId;
            await ReconnectAsync();
        }
        else
        {
            _prevRtsGridId = _rtsGridId;
        }
    }
```

### Change 2c — add OnAfterRenderAsync with ConnectAsync

DataSlotWidget has no OnAfterRenderAsync. Find the OnParametersSetAsync method end
(the closing brace of OnParametersSetAsync) and add after it:

After the full `OnParametersSetAsync` method, insert:
```csharp

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
            await ConnectAsync();
    }
```

### Change 2d — ConnectAsync: add double-subscribe guard

Find:
```csharp
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
            return;

        _connectionState = ConnectionState.Connecting;
```

Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
            return;
        if (_gridHandler is not null)
        {
            Logger.LogDebug("DataSlotWidget: already subscribed to grid {GridId}, skipping duplicate ConnectAsync", _rtsGridId);
            return;
        }

        _connectionState = ConnectionState.Connecting;
```

---

## Widget 3: AgentStateDistributionWidget.razor

### Change 3a — OnInitializedAsync: remove ConnectAsync call, keep LoadDefinitionsAsync

Find:
```csharp
    protected override async Task OnInitializedAsync()
    {
        await LoadDefinitionsAsync();
        ApplyConfig();
        if (RtsGridId > 0 && _businessUnitId > 0)
        {
            await ConnectAsync();
        }
    }
```

Replace with:
```csharp
    protected override async Task OnInitializedAsync()
    {
        await LoadDefinitionsAsync();
        ApplyConfig();
        // ConnectAsync moved to OnAfterRenderAsync — does not run during SSR pre-render
    }
```

### Change 3b — OnParametersSetAsync: remove initial ConnectAsync, keep reconnect-on-change

Find:
```csharp
        // First connection
        if (currentGridId != 0 && _previousGridId == 0 && _gridHandler is null && _businessUnitId > 0)
        {
            _previousGridId = currentGridId;
            await ConnectAsync();
        }
        // Grid changed (mode switch) — reconnect to new grid
        else if (currentGridId != 0 && currentGridId != _previousGridId && _businessUnitId > 0)
        {
            _previousGridId = currentGridId;
            _chartRendered = false;
            await ReconnectAsync();
        }
```

Replace with:
```csharp
        // Initial connect is handled in OnAfterRenderAsync(firstRender) to avoid SSR pre-render cycling.
        // Track GridId for reconnect detection.
        if (currentGridId != 0 && _previousGridId == 0)
        {
            _previousGridId = currentGridId;
        }
        // Grid changed (mode switch) — reconnect only if already connected
        else if (_gridHandler is not null && currentGridId != 0 && currentGridId != _previousGridId && _businessUnitId > 0)
        {
            _previousGridId = currentGridId;
            _chartRendered = false;
            await ReconnectAsync();
        }
```

### Change 3c — OnAfterRenderAsync: add ConnectAsync call

Find:
```csharp
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (_connectionState == ConnectionState.Connected && _cellValues.Count > 0 && !_chartRendered)
        {
            _chartRendered = true;
            await RenderChartAsync();
        }
    }
```

Replace with:
```csharp
    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
            await ConnectAsync();

        if (_connectionState == ConnectionState.Connected && _cellValues.Count > 0 && !_chartRendered)
        {
            _chartRendered = true;
            await RenderChartAsync();
        }
    }
```

### Change 3d — ConnectAsync: add double-subscribe guard

Find:
```csharp
    private async Task ConnectAsync()
    {
        if (RtsGridId == 0 || _businessUnitId == 0)
        {
            Logger.LogWarning("AgentStateDistributionWidget: RtsGridId or BusinessUnitId is 0, skipping connection");
            return;
        }

        _connectionState = ConnectionState.Connecting;
```

Replace with:
```csharp
    private async Task ConnectAsync()
    {
        if (RtsGridId == 0 || _businessUnitId == 0)
        {
            Logger.LogWarning("AgentStateDistributionWidget: RtsGridId or BusinessUnitId is 0, skipping connection");
            return;
        }
        if (_gridHandler is not null)
        {
            Logger.LogDebug("AgentStateDistributionWidget: already subscribed to grid {GridId}, skipping duplicate ConnectAsync", RtsGridId);
            return;
        }

        _connectionState = ConnectionState.Connecting;
```

---

## Build and commit

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj -c Release
```

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor
```

```bash
git add src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor
git commit -m "fix: SSR pre-render subscribe cycling in AgentGrid, DataSlot, AgentStateDistribution

Same fix as QueueGridWidget (commit b45618b):
- Remove ConnectAsync from OnInitializedAsync and OnParametersSetAsync initial-connect
- Add ConnectAsync to OnAfterRenderAsync(firstRender) — not called during SSR
- Add _handler is not null guard to prevent double-subscribe
"
```

```bash
for f in src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

---

## Widget 4: RtmRelayService.cs — BuildUnionConnection JToken fix

Same bug as updateGridData (fixed in cc_prompt_jtoken_fix.md).
BuildUnionConnection uses AddNewtonsoftJsonProtocol but registers On<JsonElement>,
so updateUserGrid and removeUser handlers SILENTLY NEVER FIRE.

### Change 4a — BuildUnionConnection: On<JsonElement> → On<JToken>

Find:
```csharp
        // Server sends: (DateTime d, int unionId, object res) — JsonElement accepts any JSON shape.
        conn.On<JsonElement, JsonElement, JsonElement>("updateUserGrid",
            (d, _, res) => HandleUpdateAsync(state, key, res));

        // Server sends: (int unionId, array users) — JsonElement accepts any JSON shape.
        conn.On<JsonElement, JsonElement>("removeUser",
            (_, users) => HandleRemoveAsync(state, key, users));
```

Replace with:
```csharp
        // Using On<JToken> — Newtonsoft protocol cannot deserialize to System.Text.Json.JsonElement.
        conn.On<JToken, JToken, JToken>("updateUserGrid",
            (d, _, res) => HandleUpdateAsync(state, key, res));

        conn.On<JToken, JToken>("removeUser",
            (_, users) => HandleRemoveAsync(state, key, users));
```

### Change 4b — HandleUpdateAsync: JsonElement → JToken

Find entire method:
```csharp
    private async Task HandleUpdateAsync(UnionState state, (Guid TenantId, int UnionId) key, JsonElement res)
    {
        if (!res.TryGetProperty("Data", out var dataEl) ||
            dataEl.ValueKind != JsonValueKind.Array)
            return;

        var upserted = new List<AgentSnapshot>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in dataEl.EnumerateArray())
            {
                if (!item.TryGetProperty("AgentLoginName", out var nameEl)) continue;
                var agentLoginName = nameEl.GetString();
                if (agentLoginName == null) continue;

                var fields = new Dictionary<string, CellValue>();
                foreach (var prop in item.EnumerateObject())
                {
                    fields[prop.Name] = prop.Value.ValueKind == JsonValueKind.String
                        ? CellValue.Parse(prop.Value.GetString())
                        : CellValue.Parse(prop.Value.ToString());
                }

                var snapshot = new AgentSnapshot(agentLoginName, fields, DateTime.UtcNow);
                state.Snapshot[agentLoginName] = snapshot;
                upserted.Add(snapshot);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogDebug(
            "RtmRelayService: updateUserGrid tenant {TenantId} union {UnionId}, {Count} agents upserted",
            key.TenantId, key.UnionId, upserted.Count);

        if (upserted.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsUpserted(upserted));
    }
```

Replace with:
```csharp
    private async Task HandleUpdateAsync(UnionState state, (Guid TenantId, int UnionId) key, JToken res)
    {
        if (res is not JObject resObj) return;
        if (resObj["Data"] is not JArray dataArray) return;

        var upserted = new List<AgentSnapshot>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in dataArray)
            {
                if (item is not JObject itemObj) continue;
                var agentLoginName = itemObj["AgentLoginName"]?.Value<string>();
                if (agentLoginName == null) continue;

                var fields = new Dictionary<string, CellValue>();
                foreach (var prop in itemObj.Properties())
                {
                    fields[prop.Name] = CellValue.Parse(
                        prop.Value.Type == JTokenType.String
                            ? prop.Value.Value<string>()
                            : prop.Value.ToString());
                }

                var snapshot = new AgentSnapshot(agentLoginName, fields, DateTime.UtcNow);
                state.Snapshot[agentLoginName] = snapshot;
                upserted.Add(snapshot);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogDebug(
            "RtmRelayService: updateUserGrid tenant {TenantId} union {UnionId}, {Count} agents upserted",
            key.TenantId, key.UnionId, upserted.Count);

        if (upserted.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsUpserted(upserted));
    }
```

### Change 4c — HandleRemoveAsync: JsonElement → JToken

Find entire method:
```csharp
    private async Task HandleRemoveAsync(UnionState state, (Guid TenantId, int UnionId) key, JsonElement users)
    {
        if (users.ValueKind != JsonValueKind.Array) return;

        var removed = new List<string>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            if (!state.HasLoggedRemovePayload)
            {
                _logger.LogInformation(
                    "RtmRelayService: removeUser first payload tenant {TenantId} union {UnionId} — raw: {Raw}",
                    key.TenantId, key.UnionId, users.GetRawText());
                state.HasLoggedRemovePayload = true;
            }

            foreach (var userEl in users.EnumerateArray())
            {
                if (!userEl.TryGetProperty("name", out var nameEl)) continue;
                var name = nameEl.GetString();
                if (name == null) continue;

                if (state.Snapshot.Remove(name))
                    removed.Add(name);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogDebug(
            "RtmRelayService: removeUser tenant {TenantId} union {UnionId}, {Count} agents removed",
            key.TenantId, key.UnionId, removed.Count);

        if (removed.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsRemoved(removed));
    }
```

Replace with:
```csharp
    private async Task HandleRemoveAsync(UnionState state, (Guid TenantId, int UnionId) key, JToken users)
    {
        if (users is not JArray usersArray) return;

        var removed = new List<string>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            if (!state.HasLoggedRemovePayload)
            {
                _logger.LogInformation(
                    "RtmRelayService: removeUser first payload tenant {TenantId} union {UnionId} — raw: {Raw}",
                    key.TenantId, key.UnionId, users.ToString());
                state.HasLoggedRemovePayload = true;
            }

            foreach (var userToken in usersArray)
            {
                if (userToken is not JObject userObj) continue;
                var name = userObj["name"]?.Value<string>();
                if (name == null) continue;

                if (state.Snapshot.Remove(name))
                    removed.Add(name);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogDebug(
            "RtmRelayService: removeUser tenant {TenantId} union {UnionId}, {Count} agents removed",
            key.TenantId, key.UnionId, removed.Count);

        if (removed.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsRemoved(removed));
    }
```

### Update commit message

Change the commit -m to:
```
git commit -m "fix: SSR pre-render cycling in AgentGrid/DataSlot/AgentStateDistribution + union JToken fix

Widget SSR fix (same as QueueGridWidget b45618b):
- ConnectAsync moved to OnAfterRenderAsync(firstRender) in all 3 widgets
- _handler is not null guard added to prevent double-subscribe

RtmRelayService union JToken fix (same as grid fix):
- BuildUnionConnection: On<JsonElement> → On<JToken> (Newtonsoft silent-drop fix)
- HandleUpdateAsync: JsonElement → JToken parsing
- HandleRemoveAsync: JsonElement → JToken parsing
"
```

Also add RtmRelayService.cs to the git add and re-sync blocks:
```bash
git add src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
```

And re-sync:
```bash
for f in src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
