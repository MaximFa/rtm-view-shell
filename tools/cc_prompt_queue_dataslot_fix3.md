# CC Task: Queue column sync + DataSlot reconnect on Save + simulator cache fix

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -5 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## THREE FIXES

### Fix A — Simulator: cellInfos re-fetch after column added
In `GenerateQueueDataAsync`, `cellInfos ??= ...` caches cells forever.
After `/LoadData` the DB cache clears but the local variable stays — new columns never appear.
Fix: remove `??=`, always re-fetch each iteration.

### Fix B — QueueGridWidget: reconnect when columns change
When a column is added: Config.QueueGridColumnDefs changes, `_cellMap` needs to be rebuilt,
and the widget must reconnect so the simulator re-fetches cells.
Pattern: same `_lastColumnsKey` approach used in AgentGridWidget (cc_prompt_agent_column_sync).

### Fix C — DataSlotWidget: reconnect when _rtsGridId changes after Save
`OnParametersSet()` (sync) calls `ApplyConfig()` which updates `_rtsGridId`,
but never triggers reconnect. After first Save the widget gets a real `_rtsGridId`
but stays subscribed to nothing (initial connect was skipped because `GridId > 0`
but `_rtsGridId` was 0 at that time → ConnectAsync returned immediately).
Fix: change to `OnParametersSetAsync`, track `_prevRtsGridId`, reconnect on change.

---

## STEP 1 — Integrity check

```bash
cd "$(git rev-parse --show-toplevel)"
for f in \
  "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs" \
  "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"; do
    echo "$f: $(wc -l < "$f") lines, last: $(tail -1 "$f")"
done
```
Restore any truncated file from HEAD before proceeding.

---

## STEP 2 — Fix A: Simulator cellInfos

Write `/tmp/fix_sim_cache.py`:

```python
path = "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Remove ??= so cells are re-fetched every iteration (picks up new columns after /LoadData)
text = text.replace(
    "                cellInfos ??= await _db.GetCellsForGridAsync(numericGridId, ct);",
    "                cellInfos = await _db.GetCellsForGridAsync(numericGridId, ct);"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

```bash
python3 /tmp/fix_sim_cache.py
tail -5 tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
wc -l tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
grep -n "cellInfos" tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
# Must show: cellInfos = await (no ??=)
```

---

## STEP 3 — Fix B: QueueGridWidget column sync

Write `/tmp/fix_queue_sync.py`:

```python
path = "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add _lastColumnsKey field after _previousGridId
text = text.replace(
    "    private int _previousGridId;",
    "    private int _previousGridId;\n    private string _lastColumnsKey = \"\";  // Detects column additions"
)

# 2. Replace OnParametersSetAsync — add column change detection
old_params = (
    "    protected override async Task OnParametersSetAsync()\n"
    "    {\n"
    "        ApplyConfig();\n"
    "\n"
    "        if (GridId != 0 && _previousGridId == 0 && _hub is null)\n"
    "        {\n"
    "            _previousGridId = GridId;\n"
    "            await ConnectAsync();\n"
    "        }\n"
    "        _previousGridId = GridId;\n"
    "    }"
)
new_params = (
    "    protected override async Task OnParametersSetAsync()\n"
    "    {\n"
    "        ApplyConfig();\n"
    "\n"
    "        // Initial connect\n"
    "        if (GridId != 0 && _previousGridId == 0 && _hub is null)\n"
    "        {\n"
    "            _previousGridId = GridId;\n"
    "            await ConnectAsync();\n"
    "        }\n"
    "        _previousGridId = GridId;\n"
    "\n"
    "        // Reconnect when columns change (new column added -> new CellIds in Config)\n"
    "        var newColumnsKey = string.Join(\",\", (_columnDefs ?? []).Select(c => c.Id));\n"
    "        if (_lastColumnsKey != \"\" && newColumnsKey != _lastColumnsKey && _hub is not null)\n"
    "        {\n"
    "            Logger.LogInformation(\"QueueGrid: columns changed ({Old} -> {New}), reconnecting\",\n"
    "                _lastColumnsKey, newColumnsKey);\n"
    "            _lastColumnsKey = newColumnsKey;\n"
    "            await ReconnectAsync();\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            _lastColumnsKey = newColumnsKey;\n"
    "        }\n"
    "    }"
)

if old_params in text:
    text = text.replace(old_params, new_params)
    print("OnParametersSetAsync replaced")
else:
    print("ERROR: old_params not found — check exact whitespace in the file")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

```bash
python3 /tmp/fix_queue_sync.py
tail -5 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
grep -n "_lastColumnsKey\|newColumnsKey" src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Must show field + 4 usages in OnParametersSetAsync
```

If the replacement fails (prints ERROR): read the exact OnParametersSetAsync block from the file
and adjust the `old_params` string to match precisely.

---

## STEP 4 — Fix C: DataSlotWidget reconnect on Save

Write `/tmp/fix_dataslot_reconnect.py`:

```python
path = "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add _prevRtsGridId field after _rtsGridId
text = text.replace(
    '    private int _rtsGridId;  // RTSGrid_Grid.GridId \u2014 set from Config.DataSlotGridId',
    '    private int _rtsGridId;  // RTSGrid_Grid.GridId \u2014 set from Config.DataSlotGridId\n    private int _prevRtsGridId;'
)

# 2. Replace sync OnParametersSet with async OnParametersSetAsync
old_params = (
    "    protected override void OnParametersSet()\n"
    "    {\n"
    "        ApplyConfig();\n"
    "    }"
)
new_params = (
    "    protected override async Task OnParametersSetAsync()\n"
    "    {\n"
    "        ApplyConfig();\n"
    "        // Reconnect when DataSlotGridId becomes available (e.g. first Save after widget placed)\n"
    "        if (_rtsGridId > 0 && _rtsGridId != _prevRtsGridId)\n"
    "        {\n"
    "            Logger.LogInformation(\"DataSlotWidget: _rtsGridId changed ({Prev} -> {Curr}), reconnecting\",\n"
    "                _prevRtsGridId, _rtsGridId);\n"
    "            _prevRtsGridId = _rtsGridId;\n"
    "            await ReconnectAsync();\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            _prevRtsGridId = _rtsGridId;\n"
    "        }\n"
    "    }"
)

if old_params in text:
    text = text.replace(old_params, new_params)
    print("OnParametersSet replaced")
else:
    print("ERROR: old_params not found — check exact whitespace")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

```bash
python3 /tmp/fix_dataslot_reconnect.py
tail -5 src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
grep -n "_prevRtsGridId\|OnParametersSetAsync" src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
# Must show: field + async OnParametersSetAsync with reconnect logic
```

Also verify `ReconnectAsync` in DataSlotWidget disposes old hub before reconnecting.
Read it: if it just calls `ConnectAsync()` without disposing `_hub`, add dispose:

```python
path = "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add hub disposal to ReconnectAsync if missing
old_reconnect = (
    "    private async Task ReconnectAsync()\n"
    "    {\n"
    "        _connectionState = ConnectionState.Connecting;\n"
    "        StateHasChanged();\n"
    "        await ConnectAsync();\n"
    "        StateHasChanged();\n"
    "    }"
)
new_reconnect = (
    "    private async Task ReconnectAsync()\n"
    "    {\n"
    "        if (_hub != null) { try { await _hub.DisposeAsync(); } catch { } _hub = null; }\n"
    "        _connectionState = ConnectionState.Connecting;\n"
    "        StateHasChanged();\n"
    "        await ConnectAsync();\n"
    "        StateHasChanged();\n"
    "    }"
)
if old_reconnect in text:
    text = text.replace(old_reconnect, new_reconnect)
    print("ReconnectAsync updated")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
else:
    print("ReconnectAsync already has dispose or has different body — check manually")
```

---

## STEP 5 — Pre-commit check

```bash
bash tools/pre-commit-check.sh \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```
Exit code must be 0.

---

## STEP 6 — Commit

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(widgets+sim): Queue column sync on add; DataSlot reconnect on Save; simulator cellInfos re-fetch"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
If HEAD.lock blocks — commit-tree workaround (CLAUDE.md §0.4).

---

## STEP 7 — Post-commit integrity

```bash
git status --short
git diff HEAD -- \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
# Expected: empty
git log --oneline -3
```

---

## STEP 8 — Instruct user

```
Committed. Next:
1. Rebuild + restart simulator: cd tools/SignalRSimulator && dotnet build && dotnet run
2. Rebuild + restart web app: dotnet build src/CcDashboard.Web && dotnet run --project src/CcDashboard.Web
3. Open dashboard — DataSlot should now connect on first Save.
4. Add a column to Queue Grid — new column data should appear within 5 seconds.
```