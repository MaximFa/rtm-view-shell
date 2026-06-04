# CC Task: Fix GridId mismatch — QueueGridWidget + DataSlotWidget

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -5 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## ROOT CAUSE

Both QueueGridWidget and DataSlotWidget call `init(GridId.ToString())` where
`GridId` = `PlacedWidget.GridId` = the auto-PK from `dashboard_widgets` table.

The simulator's `GenerateQueueDataAsync` queries `RTSGrid_Cell WHERE r."GridId" = numericGridId`.
The correct GridId for that query is stored in Config, NOT in the passed `GridId` parameter:

| Widget        | Correct RTS GridId field | Current (wrong) |
|---------------|--------------------------|-----------------|
| QueueGrid     | `Config.GridId`          | `GridId` (dashboard_widgets PK) |
| DataSlot      | `Config.DataSlotGridId`  | `GridId` (dashboard_widgets PK) |

This is the same class of bug that was fixed in AgentGridWidget (commit 745c69c):
```csharp
// AgentGridWidget fix (already done):
if (Config.RtsUserGridId is > 0)
    _rtsGridId = Config.RtsUserGridId.Value;
// and in init():
await _hub.InvokeAsync("init", $"u{(_rtsGridId > 0 ? _rtsGridId : GridId)}");
```

---

## STEP 1 — Verify file integrity first

```bash
cd "$(git rev-parse --show-toplevel)"
tail -5 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
tail -5 src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```

If either file is truncated (doesn't end with `}`), restore from HEAD:
```bash
git show HEAD:src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor > src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
git show HEAD:src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor   > src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```

---

## STEP 2 — Fix QueueGridWidget.razor

Read the file first. Find the field declarations section (near `private HubConnection? _hub;`).

### Change A — add `_rtsGridId` field
Find the block of private fields. Add after `private HubConnection? _hub;`:
```csharp
private int _rtsGridId;  // RTSGrid_Grid.GridId — used in init(); set from Config.GridId
```

### Change B — set `_rtsGridId` in `ApplyConfig()`
In `ApplyConfig()` (after existing Config assignments), add:
```csharp
if (Config?.GridId is > 0)
    _rtsGridId = Config.GridId.Value;
```

### Change C — update guard in `ConnectAsync()`
Find:
```csharp
if (GridId == 0)
{
    Logger.LogWarning("QueueGridWidget: GridId is 0, skipping connection");
    return;
}
```
Replace with:
```csharp
if (_rtsGridId == 0 && GridId == 0)
{
    Logger.LogWarning("QueueGridWidget: no RTS GridId configured, skipping connection");
    return;
}
```

### Change D — update `init()` calls (there are TWO: one in `Reconnected`, one main call)
Find ALL occurrences of:
```csharp
await _hub.InvokeAsync("init", GridId.ToString());
```
and:
```csharp
await _hub.InvokeAsync("init", GridId.ToString(), _cts.Token);
```
Replace both with (preserving the `_cts.Token` argument where present):
```csharp
await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());
```
and:
```csharp
await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);
```

### Change E — also update the `OnParametersSetAsync` guard
Find:
```csharp
if (GridId != 0 && _previousGridId == 0 && _hub is null)
```
and:
```csharp
_previousGridId = GridId;
```
These can stay as-is (GridId comes from parent, still used for @key).

**Implementation — use Python atomic write:**
```python
path = "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Change A — add _rtsGridId field
text = text.replace(
    "private HubConnection? _hub;",
    "private HubConnection? _hub;\n    private int _rtsGridId;  // RTSGrid_Grid.GridId — set from Config.GridId"
)

# Change B — set in ApplyConfig (add after Config.QueueGridColumnDefs assignment or last Config.xxx line)
# Find the end of Config assignments in ApplyConfig and add the _rtsGridId assignment
# Look for the ShowPagination line which is typically near the end of config reads
text = text.replace(
    "            _showPagination = Config.ShowPagination;",
    "            _showPagination = Config.ShowPagination;\n            if (Config?.GridId is > 0)\n                _rtsGridId = Config.GridId.Value;"
)

# Change C — update guard
text = text.replace(
    'if (GridId == 0)\n        {\n            Logger.LogWarning("QueueGridWidget: GridId is 0, skipping connection");\n            return;\n        }',
    'if (_rtsGridId == 0 && GridId == 0)\n        {\n            Logger.LogWarning("QueueGridWidget: no RTS GridId configured, skipping connection");\n            return;\n        }'
)

# Change D — update init() calls (with token)
text = text.replace(
    "await _hub.InvokeAsync(\"init\", GridId.ToString(), _cts.Token);",
    "await _hub.InvokeAsync(\"init\", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);"
)
# Change D — update init() calls (without token, Reconnected handler)
text = text.replace(
    "await _hub.InvokeAsync(\"init\", GridId.ToString());",
    "await _hub.InvokeAsync(\"init\", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Written")
```

After writing:
```bash
tail -5 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Must end with } and line count must be >= original
```

Verify the changes were actually applied:
```bash
grep -n "_rtsGridId" src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Expected: 4+ matches (_rtsGridId field, ApplyConfig assignment, guard, init calls)
```

---

## STEP 3 — Fix DataSlotWidget.razor

Read the file first. The DataSlot uses `Config.DataSlotGridId` (not `Config.GridId`).

### Change A — add `_rtsGridId` field
Find `private HubConnection? _hub;` and add after:
```csharp
private int _rtsGridId;  // RTSGrid_Grid.GridId — set from Config.DataSlotGridId
```

### Change B — set in `ApplyConfig()`
In `ApplyConfig()`, after the existing Config assignments, add:
```csharp
if (Config?.DataSlotGridId is > 0)
    _rtsGridId = Config.DataSlotGridId.Value;
```

### Change C — add guard at start of `ConnectAsync()`
At the top of `ConnectAsync()`, add:
```csharp
if (_rtsGridId == 0 && GridId == 0)
{
    Logger.LogWarning("DataSlotWidget: no RTS GridId configured, skipping connection");
    return;
}
```

### Change D — update `init()` calls (TWO occurrences)
Replace:
```csharp
await _hub.InvokeAsync("init", GridId.ToString());
```
with:
```csharp
await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());
```
And:
```csharp
await _hub.InvokeAsync("init", GridId.ToString(), _cts.Token);
```
with:
```csharp
await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);
```

**Implementation — Python atomic write:**
```python
path = "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Change A
text = text.replace(
    "private HubConnection? _hub;",
    "private HubConnection? _hub;\n    private int _rtsGridId;  // RTSGrid_Grid.GridId — set from Config.DataSlotGridId"
)

# Change B — after DataSlotCellId assignment or last _xxx = Config.xxx line in ApplyConfig
# _showArrow is typically one of the last assignments
text = text.replace(
    "        _showArrow = Config.DataSlotShowArrow;",
    "        _showArrow = Config.DataSlotShowArrow;\n        if (Config?.DataSlotGridId is > 0)\n            _rtsGridId = Config.DataSlotGridId.Value;"
)

# Change C — add guard after the Task.Delay at start of ConnectAsync
# The method starts with: await Task.Delay(Random.Shared.Next(100, 500), _cts.Token);
text = text.replace(
    "        // Stagger concurrent widget connections — same pattern as QueueGrid\n        await Task.Delay(Random.Shared.Next(100, 500), _cts.Token);",
    "        // Stagger concurrent widget connections — same pattern as QueueGrid\n        await Task.Delay(Random.Shared.Next(100, 500), _cts.Token);\n\n        if (_rtsGridId == 0 && GridId == 0)\n        {\n            Logger.LogWarning(\"DataSlotWidget: no RTS GridId configured, skipping connection\");\n            return;\n        }"
)

# Change D — init calls
text = text.replace(
    "await _hub.InvokeAsync(\"init\", GridId.ToString(), _cts.Token);",
    "await _hub.InvokeAsync(\"init\", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);"
)
text = text.replace(
    "await _hub.InvokeAsync(\"init\", GridId.ToString());",
    "await _hub.InvokeAsync(\"init\", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Written")
```

After writing:
```bash
tail -5 src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
grep -n "_rtsGridId" src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
# Expected: 4+ matches
```

---

## STEP 4 — Pre-commit check

```bash
bash tools/pre-commit-check.sh \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```

Exit code must be 0. If 1 — restore from HEAD and retry.

---

## STEP 5 — Commit

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(widgets): use Config RTS GridId in init() for QueueGrid + DataSlot — same fix as AgentGrid 745c69c"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4).

---

## STEP 6 — Post-commit integrity (CLAUDE.md §0.6)

```bash
git status --short
git diff HEAD -- \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
# Expected: empty

git log --oneline -3
```
