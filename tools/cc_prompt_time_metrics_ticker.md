# CC Task: Time ticker in QueueGrid + DataSlot fix + MetricFormat propagation

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only. After every write: `tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## ANALYSIS (Cowork pre-checked — do NOT re-investigate)

### Four bugs to fix:

**Bug 1 — GenerateNumberValue ignores DataType=="Time"**
`MetricDataGenerator.GenerateNumberValue()` (line ~70):
- "QM - Current Max Wait Time" has `ValueType="Number"` (int seconds in DB), `DataType="Time"` (display hint)
- `GenerateTimeValue()` only fires when `ValueType == "Time"` — not here
- Result: `_rng.Next(0,200).ToString()` → plain integer, not `+MM:SS`
- Fix: add `DataType=="Time"` branch at top of `GenerateNumberValue`

**Bug 2 — SQL doesn't fetch MetricFormat**
`DbMetricService.GetCellsForGridAsync` SQL omits `m."MetricFormat"`.
`RtmCellInfo` record has no `MetricFormat` field.
`RtmSimulatorHub.GenerateQueueDataAsync` passes `null` as MetricFormat → `GenerateTimeValue` always defaults to short format.
Fix: add `m."MetricFormat"` to SQL + RtmCellInfo + pass through.

**Bug 3 — DataSlot always empty: RowNumber > 1 filter excludes DataSlot row**
SQL in `GetCellsForGridAsync`:
```sql
WHERE r."GridId" = @gridId AND c."CellType" = 'Data' AND r."RowNumber" > 1
```
- Queue Grid: header row is RowNumber=1 + CellType='Header'. Data rows are RowNumber=2+, CellType='Data'.
- DataSlot: only row is RowNumber=1, CellType='Data'.
- Result: DataSlot's only data cell is excluded by `RowNumber > 1`.
- The `CellType='Data'` filter already handles the Queue Grid header row correctly.
- Fix: remove `AND r."RowNumber" > 1` — `CellType='Data'` is sufficient.

**Bug 4 — QueueGridWidget strips '+' but doesn't tick**
`updateGridData` handler strips `+` prefix and stores static string.
No PeriodicTimer → time values update only every 5s (push interval), no live counter.
Fix: add `TimerAnchors` to `QueueRowData`, `PeriodicTimer`, `StartTickLoopAsync`, `GetCellDisplay` — identical pattern to AgentGridWidget.

### Truncated working tree files (restore FIRST before any changes):
```
src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor   WT=512  HEAD=533  TRUNCATED
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor  WT=1291 HEAD=1319 TRUNCATED
```
After restoration: DataSlotWidget is done (no changes needed). QueueGridWidget needs ticker changes.

---

## Step 1 — Restore truncated files from HEAD

```bash
cd "$(git rev-parse --show-toplevel)"
for f in \
  "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"; do
    git show HEAD:"$f" > "$f"
    echo "Restored: $f ($(wc -l < "$f") lines)"
    tail -2 "$f"
    echo "---"
done
```

Expected line counts: DataSlotWidget=533, QueueGridWidget=1319.
Both must end with `}` on final line. If not — STOP and report.
After restoration `git status` must show these two files as clean (no M).

---

## Step 2 — Fix RtmCellInfo: add MetricFormat (GridModels.cs)

Path: `tools/SignalRSimulator/Models/GridModels.cs`
Current line 41:
```
public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue, string ValueType = "Number");
```

Python script `/tmp/fix_gridmodels.py`:
```python
path = "tools/SignalRSimulator/Models/GridModels.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = 'public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue, string ValueType = "Number");'
new = 'public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue, string ValueType = "Number", string? MetricFormat = null);'

assert old in text, "RtmCellInfo pattern not found"
text = text.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run + verify:
```bash
python3 /tmp/fix_gridmodels.py && tail -3 tools/SignalRSimulator/Models/GridModels.cs && wc -l tools/SignalRSimulator/Models/GridModels.cs
```

Expected: last line is `}`, line count increases by 0 (same lines, just longer line 41).

---

## Step 3 — Fix SQL + reader: add MetricFormat, remove RowNumber>1 (DbMetricService.cs)

Path: `tools/SignalRSimulator/Services/DbMetricService.cs`

Python script `/tmp/fix_dbmetric.py`:
```python
path = "tools/SignalRSimulator/Services/DbMetricService.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Change 1: SQL — add MetricFormat column, remove RowNumber > 1 filter
old_sql = '''        const string sql = @"
            SELECT c.""CellId"", c.""Value"" AS MetricId, m.""DataType"", m.""DefaultValue"",
                   COALESCE(m.""ValueType"", 'Number') AS ""ValueType""
            FROM ""RTSGrid_Cell"" c
            JOIN ""RTSGrid_Row"" r ON c.""RowId"" = r.""RowId""
            LEFT JOIN ""RTSGrid_Metric"" m ON c.""Value"" = m.""MetricId""
            WHERE r.""GridId"" = @gridId AND c.""CellType"" = 'Data' AND r.""RowNumber"" > 1
            ORDER BY r.""RowNumber"", c.""CellId""";'''

new_sql = '''        const string sql = @"
            SELECT c.""CellId"", c.""Value"" AS MetricId, m.""DataType"", m.""DefaultValue"",
                   COALESCE(m.""ValueType"", 'Number') AS ""ValueType"",
                   m.""MetricFormat""
            FROM ""RTSGrid_Cell"" c
            JOIN ""RTSGrid_Row"" r ON c.""RowId"" = r.""RowId""
            LEFT JOIN ""RTSGrid_Metric"" m ON c.""Value"" = m.""MetricId""
            WHERE r.""GridId"" = @gridId AND c.""CellType"" = 'Data'
            ORDER BY r.""RowNumber"", c.""CellId""";'''

assert old_sql in text, "SQL pattern not found"
text = text.replace(old_sql, new_sql)

# Change 2: reader — add MetricFormat at index 5
old_reader = '''            cells.Add(new RtmCellInfo(
                CellId: reader.GetInt32(0),
                MetricId: reader.IsDBNull(1) ? "" : reader.GetString(1),
                DataType: reader.IsDBNull(2) ? "String" : reader.GetString(2),
                DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3),
                ValueType: reader.IsDBNull(4) ? "Number" : reader.GetString(4)
            ));'''

new_reader = '''            cells.Add(new RtmCellInfo(
                CellId: reader.GetInt32(0),
                MetricId: reader.IsDBNull(1) ? "" : reader.GetString(1),
                DataType: reader.IsDBNull(2) ? "String" : reader.GetString(2),
                DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3),
                ValueType: reader.IsDBNull(4) ? "Number" : reader.GetString(4),
                MetricFormat: reader.IsDBNull(5) ? null : reader.GetString(5)
            ));'''

assert old_reader in text, "Reader pattern not found"
text = text.replace(old_reader, new_reader)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run + verify:
```bash
python3 /tmp/fix_dbmetric.py && tail -5 tools/SignalRSimulator/Services/DbMetricService.cs && wc -l tools/SignalRSimulator/Services/DbMetricService.cs
```

Expected: last line is `}`, line count increases by ~2 (new MetricFormat line in SQL + reader).

---

## Step 4 — Fix GenerateNumberValue: add DataType==Time branch (MetricDataGenerator.cs)

Path: `tools/SignalRSimulator/Generators/MetricDataGenerator.cs`

Python script `/tmp/fix_generator.py`:
```python
path = "tools/SignalRSimulator/Generators/MetricDataGenerator.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = '''    private static string GenerateNumberValue(MetricDefinition metric)
    {
        // Percent: DataType == "Percent" OR MetricFormat contains '%'
        if (metric.DataType?.Equals("Percent", StringComparison.OrdinalIgnoreCase) == true
            || metric.MetricFormat?.Contains('%') == true)
            return GeneratePercent(metric.MetricFormat);

        // Default integer
        return _rng.Next(0, 200).ToString();
    }'''

new = '''    private static string GenerateNumberValue(MetricDefinition metric)
    {
        // Time-stored-as-Number (e.g. wait time in seconds) — show as live timer
        if (metric.DataType?.Equals("Time", StringComparison.OrdinalIgnoreCase) == true)
        {
            var isLong = metric.MetricFormat?.Contains("hh", StringComparison.OrdinalIgnoreCase) == true;
            return "+" + (isLong ? GenerateLongTime() : GenerateShortTime());
        }
        // Percent: DataType == "Percent" OR MetricFormat contains '%'
        if (metric.DataType?.Equals("Percent", StringComparison.OrdinalIgnoreCase) == true
            || metric.MetricFormat?.Contains('%') == true)
            return GeneratePercent(metric.MetricFormat);

        // Default integer
        return _rng.Next(0, 200).ToString();
    }'''

assert old in text, "GenerateNumberValue pattern not found"
text = text.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run + verify:
```bash
python3 /tmp/fix_generator.py && tail -3 tools/SignalRSimulator/Generators/MetricDataGenerator.cs && wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

Expected: last line is `}`, line count = 160 (was 155, +5 for Time branch).

---

## Step 5 — Pass MetricFormat to MetricDataGenerator (RtmSimulatorHub.cs)

Path: `tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs`

Python script `/tmp/fix_hub.py`:
```python
path = "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = 'MetricDataGenerator.GenerateValue(new MetricDefinition(ci.MetricId, null, ci.DataType, null, ci.DefaultValue, ci.ValueType))'
new = 'MetricDataGenerator.GenerateValue(new MetricDefinition(ci.MetricId, null, ci.DataType, ci.MetricFormat, ci.DefaultValue, ci.ValueType))'

assert old in text, "MetricDataGenerator.GenerateValue call pattern not found"
text = text.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run + verify:
```bash
python3 /tmp/fix_hub.py && tail -3 tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs && wc -l tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
```

Expected: last line is `}`, line count = 314 (no line count change — same-line replacement).

---

## Step 6 — Add time ticker to QueueGridWidget.razor

Path: `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`
Must be at 1319 lines after Step 1 restore. Verify before proceeding:
```bash
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Must be 1319. If not — re-run Step 1 restore.
```

Python script `/tmp/fix_queuegrid.py` — apply 6 changes sequentially, assert each before replacing:

```python
path = "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# ── Change 1: QueueRowData — add TimerAnchors ─────────────────────────────
old1 = """    private class QueueRowData
    {
        public string RowId { get; set; } = \"\";
        public string QueueName { get; set; } = \"\";
        public Dictionary<string, string> Metrics { get; set; } = new();
    }"""

new1 = """    private class QueueRowData
    {
        public string RowId { get; set; } = \"\";
        public string QueueName { get; set; } = \"\";
        public Dictionary<string, string> Metrics { get; set; } = new();
        public Dictionary<string, (int BaseSecs, DateTime StartedAt)> TimerAnchors { get; set; } = new();
    }"""

assert old1 in text, "FAIL: QueueRowData pattern not found"
text = text.replace(old1, new1)

# ── Change 2: _tickTimer field after _cts ─────────────────────────────────
old2 = "    private CancellationTokenSource _cts = new();"
new2 = "    private CancellationTokenSource _cts = new();\n    private PeriodicTimer? _tickTimer;"

assert old2 in text, "FAIL: _cts field pattern not found"
text = text.replace(old2, new2)

# ── Change 3: updateGridData handler — use ApplyMetricValue ───────────────
old3 = """                    if (row is null) continue;
                    // Strip '+' timer prefix
                    row.Metrics[metricId] = cell.Value?.StartsWith('+') == true
                        ? cell.Value[1..] : cell.Value ?? \"\";"""

new3 = """                    if (row is null) continue;
                    ApplyMetricValue(row, metricId, cell.Value ?? \"\");"""

assert old3 in text, "FAIL: updateGridData row.Metrics assignment pattern not found"
text = text.replace(old3, new3)

# ── Change 4: Start tick loop after init ──────────────────────────────────
old4 = """            await _hub.InvokeAsync("init", _rtsGridId.ToString(), _cts.Token);

            Logger.LogInformation("Connected to QueueGrid simulator for GridId {GridId}", GridId);"""

new4 = """            await _hub.InvokeAsync("init", _rtsGridId.ToString(), _cts.Token);
            _ = StartTickLoopAsync();

            Logger.LogInformation("Connected to QueueGrid simulator for GridId {GridId}", GridId);"""

assert old4 in text, "FAIL: init + LogInformation pattern not found"
text = text.replace(old4, new4)

# ── Change 5: Display template — GetCellDisplay ───────────────────────────
old5 = "                                var cellValue = GetMetricValue(row.Metrics, colDef.MetricId);"
new5 = "                                var cellValue = GetCellDisplay(row, colDef.MetricId);"

assert old5 in text, "FAIL: cellValue GetMetricValue pattern not found"
text = text.replace(old5, new5)

# ── Change 6: Add helper methods + modify DisposeAsync ────────────────────
old6 = """    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        if (_hub != null)
        {
            try
            {
                await _hub.DisposeAsync();
            }
            catch (Exception ex)
            {
                Logger.LogDebug(ex, "Error disposing hub connection");
            }
        }
        _cts.Dispose();
    }
}"""

new6 = """    private static void ApplyMetricValue(QueueRowData row, string metricId, string rawValue)
    {
        if (rawValue.StartsWith('+'))
        {
            var secs = ParseTimeToSeconds(rawValue[1..]);
            row.TimerAnchors[metricId] = (secs, DateTime.UtcNow);
            row.Metrics[metricId] = rawValue[1..];
        }
        else
        {
            row.Metrics[metricId] = rawValue;
            row.TimerAnchors.Remove(metricId);
        }
    }

    private string GetCellDisplay(QueueRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        return GetMetricValue(row.Metrics, metricId);
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

    public async ValueTask DisposeAsync()
    {
        _cts.Cancel();
        _tickTimer?.Dispose();
        if (_hub != null)
        {
            try
            {
                await _hub.DisposeAsync();
            }
            catch (Exception ex)
            {
                Logger.LogDebug(ex, "Error disposing hub connection");
            }
        }
        _cts.Dispose();
    }
}"""

assert old6 in text, "FAIL: DisposeAsync pattern not found"
text = text.replace(old6, new6)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("All 6 changes applied successfully")
```

Run + verify:
```bash
python3 /tmp/fix_queuegrid.py && \
tail -5 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor && \
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
```

Expected: last 2 lines are `    }` then `}`, line count ≈ 1369 (1319 + ~50 new lines).

---

## Step 7 — Pre-commit check (MANDATORY)

```bash
cd "$(git rev-parse --show-toplevel)"
bash tools/pre-commit-check.sh \
    tools/SignalRSimulator/Models/GridModels.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
```

**If exit code 1 — DO NOT COMMIT.** Identify the truncated file, restore from HEAD, re-apply the Python script for that file only, re-run pre-commit-check.

---

## Step 8 — Commit

Only after pre-commit check exits 0:

```bash
cd "$(git rev-parse --show-toplevel)"
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    tools/SignalRSimulator/Models/GridModels.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat(widgets+sim): QueueGrid time ticker; DataSlot RowNumber fix; MetricFormat propagation; Number+Time DataType fix"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4).

---

## Step 9 — Post-commit integrity (CLAUDE.md §0.6)

```bash
git status --short
# Expected: only ?? (untracked) files remain; no M files for the 5 committed files

git diff HEAD -- \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Expected: empty output

git show HEAD:tools/SignalRSimulator/Generators/MetricDataGenerator.cs | wc -l
wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
# Both must match
```

---

## Summary of changes

| File | Change |
|------|--------|
| `GridModels.cs` | `RtmCellInfo` gets `string? MetricFormat = null` parameter |
| `DbMetricService.cs` | SQL adds `m."MetricFormat"` (col 6); removes `RowNumber > 1` filter; reader adds index 5 |
| `MetricDataGenerator.cs` | `GenerateNumberValue` handles `DataType=="Time"` → returns `"+MM:SS"` |
| `RtmSimulatorHub.cs` | `MetricDataGenerator.GenerateValue` call passes `ci.MetricFormat` (was `null`) |
| `QueueGridWidget.razor` | `TimerAnchors` on rows; `PeriodicTimer`; `ApplyMetricValue`; `GetCellDisplay`; `StartTickLoopAsync` |
