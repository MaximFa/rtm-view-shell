# CC Task: Fix QueueGrid pre-render subscribe cycling + add relay diagnostics

## Context
Production Queue Grid widget shows "-" for all cells.
Root cause: `ConnectAsync()` is called in `OnInitializedAsync`, which runs during
BOTH Blazor SSR pre-rendering AND the interactive circuit.

Timeline observed in logs:
- 23:48:43.094: widget subscribes (SSR pre-render phase)
- 23:48:43.096: subscribe completes, RefCount=1
- 23:48:43.100: component DISPOSED (SSR cleanup) → unsubscribe → RefCount=0 → grace timer!

The grace timer then fires after 30s, disconnects relay. Interactive circuit widget
subscribes into a dead connection, no data.

Secondary issue: `HandleGridUpdateAsync` in RtmRelayService uses `LogDebug` for
all key events, but Serilog file sink isn't picking up Debug level. Need INF logs.

## Files to modify

### 1. src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor

**Change: add pre-render guard + double-subscribe guard at TOP of `ConnectAsync()`**

Current code (around line 436):
```
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
        {
            Logger.LogWarning("QueueGridWidget: Config.GridId not set, skipping connection");
            return;
        }

        _connectionState = ConnectionState.Connecting;
        Logger.LogInformation("QueueGridWidget: Subscribing to GridId {GridId}", _rtsGridId);
```

Replace with:
```
    private async Task ConnectAsync()
    {
        if (_rtsGridId == 0)
        {
            Logger.LogWarning("QueueGridWidget: Config.GridId not set, skipping connection");
            return;
        }

        // Guard: do NOT subscribe during Blazor SSR pre-rendering.
        // OnInitializedAsync runs in BOTH SSR (no circuit) and interactive mode.
        // In SSR the component disposes immediately after HTML render, causing
        // rapid subscribe→unsubscribe (4ms gap) that kills the relay grace timer.
        if (!RendererInfo.IsInteractive)
        {
            Logger.LogDebug("QueueGridWidget: skipping ConnectAsync during pre-render (not interactive)");
            return;
        }

        // Guard: prevent double-subscribe (OnInitializedAsync + OnParametersSetAsync both call ConnectAsync)
        if (_gridHandler is not null)
        {
            Logger.LogDebug("QueueGridWidget: already subscribed to GridId {GridId}, skipping duplicate ConnectAsync", _rtsGridId);
            return;
        }

        _connectionState = ConnectionState.Connecting;
        Logger.LogInformation("QueueGridWidget: Subscribing to GridId {GridId}", _rtsGridId);
```

### 2. src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

**Change A: SubscribeGridAsync — add INF log when snapshot delivered to late subscriber**

Find this block (around line 458):
```
            else if (state.CellSnapshot.Count > 0)
            {
                // Late subscriber: deliver current cell values immediately
                var snapshot = state.CellSnapshot
                    .Select(kvp => new GridCellUpdate(kvp.Key, kvp.Value))
                    .ToList();
                await handler(snapshot);
            }
```

Replace with:
```
            else if (state.CellSnapshot.Count > 0)
            {
                // Late subscriber: deliver current cell values immediately
                var snapshot = state.CellSnapshot
                    .Select(kvp => new GridCellUpdate(kvp.Key, kvp.Value))
                    .ToList();
                _logger.LogInformation(
                    "RtmRelayService: delivering snapshot of {Count} cells to late subscriber for grid {GridId}",
                    snapshot.Count, gridId);
                await handler(snapshot);
            }
```

**Change B: HandleGridUpdateAsync — promote LogDebug to LogInformation, add handler count**

Find this block (around line 656):
```
        _logger.LogDebug(
            "RtmRelayService: updateGridData tenant {TenantId} grid {GridId}, {Count} cells updated",
            key.TenantId, key.GridId, updates.Count);
```

Replace with:
```
        _logger.LogInformation(
            "RtmRelayService: updateGridData grid {GridId}: {Count} cells, {HandlerCount} handlers",
            key.GridId, updates.Count, handlers.Count);
```

## Verification steps

After making changes:

1. Build:
```
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj -c Release
```

2. Check that no new compilation errors exist.

3. Verify no truncation:
```bash
tail -3 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
tail -3 src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
```

4. Commit:
```bash
# MANDATORY pre-commit check
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Only if exit code 0:
git add src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
git commit -m "fix: QueueGrid pre-render subscribe cycling + INF relay diagnostics

- Add RendererInfo.IsInteractive guard in ConnectAsync to prevent
  subscription during Blazor SSR pre-rendering phase. Without this guard,
  OnInitializedAsync subscribes during SSR, then the component immediately
  disposes (SSR cleanup), causing rapid subscribe→unsubscribe (4ms gap)
  that puts relay into grace timer state.
- Add _gridHandler != null guard to prevent double-subscribe from
  both OnInitializedAsync and OnParametersSetAsync.
- Promote HandleGridUpdateAsync LogDebug → LogInformation (visible in logs).
- Add INF log when snapshot delivered to late subscriber.
"
```

5. Post-commit re-sync:
```bash
for f in src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
          src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Expected result after deploy to prod

Shell log should show:
- NO more rapid subscribe/unsubscribe cycling
- "RtmRelayService: updateGridData grid 29: N cells, M handlers" when RTM pushes
- "delivering snapshot of N cells to late subscriber for grid 29" when widget connects late
- Widget shows actual values (not "-")
