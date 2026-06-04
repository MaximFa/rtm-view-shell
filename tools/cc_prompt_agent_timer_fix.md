# CC Task: AgentGridWidget — local timer counting for CurStatusDuration cells

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
# Expected: ~1370 lines
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

RTM Server pushes `updateUserGrid` every ~3–4 seconds.
Timer cells (`CurStatusDuration`, etc.) arrive with a `+HH:MM:SS` prefix.
Currently `StripTimerPrefix` just removes `+` and stores `"01:23:45"`.
Result: the displayed time jumps/flickers on every server push instead of counting smoothly.

## Goal

Parse the `+HH:MM:SS` value into `(baseSecs, receivedAt)` per-agent per-metric.
Run a 1-second local `PeriodicTimer` that increments and re-renders timer cells.
Server pushes still act as the authoritative resync (reset the anchor).
Non-timer cells (`CurStatus`, `USERID`, etc.) are unaffected.

---

## File: `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

### Change 1 — Add `TimerAnchors` to `AgentRowData`

Find:
```csharp
    private class AgentRowData
    {
        public string RowId { get; set; } = "";
        public Dictionary<string, string> Metrics { get; set; } = new();
    }
```

Replace with:
```csharp
    private class AgentRowData
    {
        public string RowId { get; set; } = "";
        public Dictionary<string, string> Metrics { get; set; } = new();
        // Timer cells: metricId → (base seconds at server push, time of that push)
        public Dictionary<string, (int BaseSecs, DateTime StartedAt)> TimerAnchors { get; set; } = new();
    }
```

---

### Change 2 — Add private field for the tick timer

Find:
```csharp
    private CancellationTokenSource _cts = new();
```

Add after it:
```csharp
    private PeriodicTimer? _tickTimer;
```

---

### Change 3 — Replace `StripTimerPrefix` calls in `updateUserGrid` handler

Find:
```csharp
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
                            Metrics = agentDict.ToDictionary(kv => kv.Key, kv => StripTimerPrefix(kv.Value))
                        });
                    }
```

Replace with:
```csharp
                    var now = DateTime.UtcNow;
                    if (existing is not null)
                    {
                        foreach (var kv in agentDict)
                            ApplyMetricValue(existing, kv.Key, kv.Value, now);
                    }
                    else
                    {
                        var row = new AgentRowData { RowId = userId };
                        foreach (var kv in agentDict)
                            ApplyMetricValue(row, kv.Key, kv.Value, now);
                        _rows.Add(row);
                    }
```

---

### Change 4 — Replace `StripTimerPrefix` definition with `ApplyMetricValue` + helpers

Find:
```csharp
    private static string StripTimerPrefix(string value)
        => value?.StartsWith('+') == true ? value[1..] : value ?? "";
```

Replace with:
```csharp
    /// <summary>
    /// Applies a raw metric value from the server to an agent row.
    /// Values prefixed with '+' are timers: stored as a (baseSecs, startedAt) anchor
    /// for smooth local counting. Non-timer values go straight into Metrics.
    /// </summary>
    private static void ApplyMetricValue(AgentRowData row, string metricId, string rawValue, DateTime receivedAt)
    {
        if (rawValue?.StartsWith('+') == true)
        {
            var secs = ParseTimeToSeconds(rawValue[1..]);
            row.TimerAnchors[metricId] = (secs, receivedAt);
            // Also keep Metrics in sync for sort/filter fallback
            row.Metrics[metricId] = rawValue[1..];
        }
        else
        {
            row.Metrics[metricId] = rawValue ?? "";
            row.TimerAnchors.Remove(metricId); // no longer a timer
        }
    }

    private static int ParseTimeToSeconds(string time)
    {
        var parts = time.Split(':');
        return parts.Length switch
        {
            2 when int.TryParse(parts[0], out var m) && int.TryParse(parts[1], out var s)
                => m * 60 + s,
            3 when int.TryParse(parts[0], out var h) && int.TryParse(parts[1], out var m) && int.TryParse(parts[2], out var s)
                => h * 3600 + m * 60 + s,
            _ => 0
        };
    }

    private static string FormatSeconds(int totalSecs)
    {
        if (totalSecs < 0) totalSecs = 0;
        var h = totalSecs / 3600;
        var m = (totalSecs % 3600) / 60;
        var s = totalSecs % 60;
        return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
    }
```

---

### Change 5 — Add `GetCellDisplay` helper

Add near `GetMetricValue`:

```csharp
    /// <summary>
    /// Returns the display value for a cell. For timer cells, computes live elapsed time
    /// from the anchor instead of reading the static stored value.
    /// </summary>
    private string GetCellDisplay(AgentRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        return GetMetricValue(row.Metrics, metricId);
    }
```

---

### Change 6 — Update Razor template to use `GetCellDisplay`

Find in the `@foreach (var colDef in _columnDefs)` block:
```csharp
                                    var cellValue = GetMetricValue(row.Metrics, colDef.MetricId);
```

Replace with:
```csharp
                                    var cellValue = GetCellDisplay(row, colDef.MetricId);
```

---

### Change 7 — Add 1-second tick loop

Add near `ConnectAsync`:

```csharp
    private async Task StartTickLoopAsync()
    {
        _tickTimer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        try
        {
            while (await _tickTimer.WaitForNextTickAsync(_cts.Token))
            {
                if (_rows.Any(r => r.TimerAnchors.Count > 0))
                    await InvokeAsync(StateHasChanged);
            }
        }
        catch (OperationCanceledException) { }
        finally
        {
            _tickTimer?.Dispose();
            _tickTimer = null;
        }
    }
```

---

### Change 8 — Start tick loop on first render

Find:
```csharp
    public async ValueTask DisposeAsync()
```

Insert BEFORE it:

```csharp
    protected override Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
            _ = StartTickLoopAsync();
        return base.OnAfterRenderAsync(firstRender);
    }

```

---

### Change 9 — Dispose tick timer in `DisposeAsync`

Find:
```csharp
    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
```

Replace with:
```csharp
    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        _tickTimer?.Dispose();
```

---

## Verification

```bash
# Build
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj 2>&1 | tail -5

# StripTimerPrefix must be gone
grep "StripTimerPrefix" src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: (empty)

# All new symbols present
grep -n "ApplyMetricValue\|FormatSeconds\|GetCellDisplay\|StartTickLoopAsync\|TimerAnchors\|ParseTimeToSeconds" \
    src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: all 6 names found

# Template uses GetCellDisplay
grep "GetCellDisplay" src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: 1+ lines

# File ends properly
tail -5 src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
wc -l  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Expected: ends with }  and  ~1390 lines (was 1370 + ~20 new lines)
```

---

## Commit

```bash
# MANDATORY
bash tools/pre-commit-check.sh
# After exit 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(agent-grid): local timer counting — PeriodicTimer 1s tick, TimerAnchors per agent"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
