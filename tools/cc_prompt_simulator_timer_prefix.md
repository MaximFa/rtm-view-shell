# CC Task: Simulator — add '+' prefix to duration metrics in MetricDataGenerator

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## §0 — SESSION-RESUME INTEGRITY CHECK

```bash
python3 -c "
with open('.git/config', 'rb') as f: data = f.read()
if b'\x00' in data:
    with open('.git/config', 'wb') as f: f.write(data.replace(b'\x00', b''))
    print('Fixed null bytes')
else:
    print('OK')
"
git log --oneline -1
git status --short
```
For every `M` file: `tail -3 <path>`. Restore truncated: `git show HEAD:<path> > <path>`.

---

## Root Cause

`AgentGridWidget.ApplyMetricValue` decides whether a metric is a live timer by:
```csharp
if (rawValue?.StartsWith('+') == true)
{
    row.TimerAnchors[metricId] = (secs, receivedAt);  // → ticks every second
}
```

The hardcoded metrics in `RtmSimulatorHub` correctly use `+` prefix for all durations:
```csharp
["MonAgentCurrentLoginDuration"] = $"+{loginDuration:hh\\:mm\\:ss}",
["MonAgentAverageInboundCallDuration"] = $"+{avgInboundDuration:mm\\:ss}",
```

But `MetricDataGenerator.GenerateValue()` returns duration/time values **without** `+`:
```csharp
if (desc.Contains("Duration") || desc.Contains("Talk Time"))
    return GenerateShortTime();   // returns "12:34" — treated as plain text by widget
```

Result: DB-configured duration columns (e.g. "Average Handling Duration") show static
text instead of a live ticking timer.

## Goal

In `MetricDataGenerator.GenerateValue()`, prefix all duration/time return values
with `+`, matching the real RTM Server and the hardcoded simulator entries.
`GenerateShortTime()` and `GenerateLongTime()` should keep their current format
(they are also called via `GenerateMetrics` for other purposes) — add the `+`
only at the call sites inside `GenerateValue()`.

---

## File: `tools/SignalRSimulator/Generators/MetricDataGenerator.cs`

### Change — add '+' prefix to duration/time branches in GenerateValue()

Find:
```csharp
        // Cumulative durations - long format HH:MM:SS
        if (desc.Contains("Cumulative") && desc.Contains("Duration"))
            return GenerateLongTime();

        if (desc.Contains("Current Login Duration"))
            return GenerateLongTime();

        // Average/Max/Current durations - short format MM:SS
        if (desc.Contains("Duration") || desc.Contains("Talk Time"))
            return GenerateShortTime();

        // Wait time, Response time - short format MM:SS
        if (desc.Contains("Wait Time") || desc.Contains("Response Time") || desc.Contains("Time to Aband"))
            return GenerateShortTime();
```

Replace with:
```csharp
        // Cumulative durations - long format +HH:MM:SS ('+' = live timer in AgentGridWidget)
        if (desc.Contains("Cumulative") && desc.Contains("Duration"))
            return "+" + GenerateLongTime();

        if (desc.Contains("Current Login Duration"))
            return "+" + GenerateLongTime();

        // Average/Max/Current durations - short format +MM:SS
        if (desc.Contains("Duration") || desc.Contains("Talk Time"))
            return "+" + GenerateShortTime();

        // Wait time, Response time - short format +MM:SS
        if (desc.Contains("Wait Time") || desc.Contains("Response Time") || desc.Contains("Time to Aband"))
            return "+" + GenerateShortTime();
```

---

## Verification

```bash
# Build
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj 2>&1 | tail -5

# + prefix present in duration branches
grep -n '"+" +\|"+"' tools/SignalRSimulator/Generators/MetricDataGenerator.cs
# Expected: 4 lines

# File ends properly
tail -3 tools/SignalRSimulator/Generators/MetricDataGenerator.cs
wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

---

## Commit

```bash
bash tools/pre-commit-check.sh tools/SignalRSimulator/Generators/MetricDataGenerator.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/SignalRSimulator/Generators/MetricDataGenerator.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator): add '+' prefix to duration metrics — AgentGridWidget treats them as live timers"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
