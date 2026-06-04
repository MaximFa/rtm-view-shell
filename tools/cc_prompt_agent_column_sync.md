# CC Task: AgentGridWidget — reconnect on column set change

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.
§0.4 — git index.lock workaround if needed.

---

## §0 — SESSION-RESUME INTEGRITY CHECK (run first, before any code changes)

### Step 0a — Fix .git/config null bytes (known issue on this mount)

```bash
python3 -c "
with open('.git/config', 'rb') as f: data = f.read()
if b'\x00' in data:
    with open('.git/config', 'wb') as f: f.write(data.replace(b'\x00', b''))
    print('Fixed null bytes in .git/config')
else:
    print('git/config OK')
"
git log --oneline -1   # must succeed after fix
```

### Step 0b — Detect and restore truncated files

```bash
git status --short
```

For **every `M` file** in the output, run:
```bash
tail -3 <path>
```

**Truncated endings** (last line is mid-word/mid-expression) — examples of BAD endings:
```
var fgColor = !strin
var state = System.Text.Json.JsonSerializer.Deserialize<Wid
segments.Add(new { label = "Tra
```

**Good endings**: `}`, `})`, `});`, `}` on its own line.

If any file is truncated, restore from HEAD:
```bash
git show HEAD:<path> > <path>
tail -3 <path>    # verify restored correctly
wc -l <path>      # compare with expected count from git show | wc -l
```

**IMPORTANT:** `git checkout HEAD -- <path>` fails on this mount.
Use `git show HEAD:<path> > <path>` only.

**Check the target file specifically, even if git status shows it clean:**
```bash
tail -3 src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: ends with three lines:   _cts.Dispose();  /  }  /  }
wc -l src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: ~1390 lines (after prior timer fix)
```

If truncated → restore before doing anything else:
```bash
git show HEAD:src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
    > src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
tail -3 src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
wc -l  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
```

Only proceed to the changes below once the file ends properly.

---

## Problem

When a user adds a new column to the Agent Grid widget config, the widget's `_columnDefs`
is updated via `ApplyConfig()` inside `OnParametersSetAsync`. However:

1. `OnParametersSetAsync` only calls `ConnectAsync()` on the **very first** render
   (guard: `_previousGridId == 0 && _hub is null`).
2. Subsequent parameter changes (e.g. column added) call `ApplyConfig()` and update
   `_columnDefs`, but the hub connection is NOT restarted.
3. RTM Server has been notified via `/LoadData` (via `RtmConfigurationApiHook`) and now
   pushes data including the new MetricId, but the rows already in `_rows` are updated
   incrementally — `DetectColumnDataTypes()` is only called when `isFirstData` is true
   (i.e., `_rows.Count == 0`).
4. Result: new column appears in the header but shows "–" forever, AND column type detection
   (`DataType`) is not run for the new column, so timer/status formatting is wrong.

## Goal

When `OnParametersSetAsync` detects that the column set (set of MetricIds) has changed
AND the hub is already connected, call `ReconnectAsync()`.

`ReconnectAsync()` already:
- Disposes the old hub
- Clears `_rows` (so `isFirstData` = true on first push)
- Calls `ConnectAsync()` fresh

This ensures:
- RTM sends a fresh `updateUserGrid` push with all current MetricIds
- `DetectColumnDataTypes()` is called naturally (via `isFirstData = true`)
- Stale agent rows are cleared

**Note:** this fix is the widget-side complement to `cc_prompt_rtm_integration.md`
(RTM-side fix). Both must be applied for full correctness.

---

## File: `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

### Change 1 — Add `_lastColumnsKey` field

Find:
```csharp
    private int _previousGridId;
```

Replace with:
```csharp
    private int _previousGridId;
    private string _lastColumnsKey = "";
```

---

### Change 2 — Update `OnParametersSetAsync` to detect column set change

Find:
```csharp
    protected override async Task OnParametersSetAsync()
    {
        ApplyConfig();

        if (GridId != 0 && _previousGridId == 0 && _hub is null)
        {
            _previousGridId = GridId;
            await ConnectAsync();
        }
        _previousGridId = GridId;
    }
```

Replace with:
```csharp
    protected override async Task OnParametersSetAsync()
    {
        var prevColumnsKey = _lastColumnsKey;
        ApplyConfig();
        _lastColumnsKey = string.Join(",", _columnDefs.Select(c => c.MetricId));

        if (GridId != 0 && _previousGridId == 0 && _hub is null)
        {
            _previousGridId = GridId;
            await ConnectAsync();
        }
        else if (_hub?.State == HubConnectionState.Connected
                 && _lastColumnsKey != prevColumnsKey
                 && prevColumnsKey.Length > 0)
        {
            // Column set changed on a live connection — reconnect so RTM pushes
            // fresh data for all current MetricIds and DetectColumnDataTypes() runs.
            Logger.LogInformation(
                "AgentGrid {GridId}: column set changed, reconnecting. Old={Old} New={New}",
                GridId, prevColumnsKey, _lastColumnsKey);
            await ReconnectAsync();
        }

        _previousGridId = GridId;
    }
```

---

## Verification

```bash
# Build
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj 2>&1 | tail -5

# New field present
grep -n "_lastColumnsKey" src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: 3 lines (declaration, prevColumnsKey assignment, _lastColumnsKey =)

# Guard conditions present
grep -n "prevColumnsKey\|_lastColumnsKey != prevColumnsKey\|column set changed" \
    src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: all found

# File ends properly
tail -5 src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
wc -l  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: ends with }  and  ~1397 lines (was ~1390 + ~7 new lines)
```

---

## Commit

```bash
# MANDATORY
bash tools/pre-commit-check.sh
# After exit 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(agent-grid): reconnect on column set change — fresh DetectColumnDataTypes"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
