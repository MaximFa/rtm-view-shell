# CC Task: Fix Queue/DataSlot — ValueType generation + connection guard

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -5 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## TWO BUGS TO FIX

### Bug A — Queue Grid shows 0s
`GenerateFakeValue()` in `RtmSimulatorHub.cs` only handles `"Integer"/"Time"/"Percent"`.
Real DB has types like `"Long"`, `"String"`, `"Double"` → falls through to `defaultValue ?? "0"`.
`MetricDataGenerator.GenerateValue()` already exists and handles `ValueType` correctly,
but `GetCellsForGridAsync` doesn't fetch `ValueType` and `RtmCellInfo` doesn't store it.

### Bug B — DataSlot shows "--"
Guard: `if (_rtsGridId == 0 && GridId == 0)` — too permissive.
When `_rtsGridId == 0` but `GridId = 5` (dashboard PK), widget connects with
wrong `init("5")` → simulator finds no cells → no data.

---

## STEP 1 — Verify file integrity

```bash
cd "$(git rev-parse --show-toplevel)"
for f in \\
  "tools/SignalRSimulator/Models/GridModels.cs" \\
  "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs" \\
  "tools/SignalRSimulator/Services/DbMetricService.cs" \\
  "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor" \\
  "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"; do
    last=$(tail -1 "$f")
    lines=$(wc -l < "$f")
    echo "$f: $lines lines, last='$last'"
done
```
If any simulator file is truncated — restore from HEAD: `git show HEAD:"$f" > "$f"`

---

## STEP 2 — Fix GridModels.cs: add ValueType to RtmCellInfo

Write a Python script to `/tmp/fix_models.py`:

```python
path = "tools/SignalRSimulator/Models/GridModels.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    'public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue);',
    'public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue, string ValueType = "Number");'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run: `python3 /tmp/fix_models.py && tail -5 tools/SignalRSimulator/Models/GridModels.cs && wc -l tools/SignalRSimulator/Models/GridModels.cs`

Verify: `grep "RtmCellInfo" tools/SignalRSimulator/Models/GridModels.cs` — must show `ValueType` parameter.

---

## STEP 3 — Fix DbMetricService.cs: add ValueType to SQL

Write `/tmp/fix_dbservice.py`:

```python
path = "tools/SignalRSimulator/Services/DbMetricService.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Extend SELECT to include ValueType
text = text.replace(
    'SELECT c.\"CellId\", c.\"Value\" AS MetricId, m.\"DataType\", m.\"DefaultValue\"\n',
    'SELECT c.\"CellId\", c.\"Value\" AS MetricId, m.\"DataType\", m.\"DefaultValue\",\n'
         '                   COALESCE(m.\"ValueType\", \'Number\') AS \"ValueType\"\n'
)

# 2. Add 5th column read in the constructor
text = text.replace(
    "                DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3)\n            ));",
    "                DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3),\n                ValueType: reader.IsDBNull(4) ? \"Number\" : reader.GetString(4)\n            ));"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run and verify:
```bash
python3 /tmp/fix_dbservice.py
tail -5 tools/SignalRSimulator/Services/DbMetricService.cs
wc -l tools/SignalRSimulator/Services/DbMetricService.cs
grep -n "ValueType\|GetString(4)" tools/SignalRSimulator/Services/DbMetricService.cs
```

**IMPORTANT**: The SQL replacement may be tricky due to escaped quotes. If the replacement fails
(grep shows no match), use a direct Python read-and-rewrite approach:
Read the file, find the `GetCellsForGridAsync` method, manually locate the SELECT statement
and the cells.Add() constructor, insert the 5th column in both places.

---

## STEP 4 — Fix RtmSimulatorHub.cs: use MetricDataGenerator.GenerateValue()

Write `/tmp/fix_hub.py`:

```python
path = "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add using if missing
if "using SignalRSimulator.Generators;" not in text:
    text = "using SignalRSimulator.Generators;\n" + text

# 2. Replace GenerateFakeValue call with MetricDataGenerator.GenerateValue()
text = text.replace(
    '                    Value  = GenerateFakeValue(ci.DataType, ci.DefaultValue),',
    '                    Value  = MetricDataGenerator.GenerateValue(\n'
    '                                 new MetricDefinition(ci.MetricId, null, ci.DataType, null, ci.DefaultValue, ci.ValueType)),'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Run and verify:
```bash
python3 /tmp/fix_hub.py
tail -5 tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
wc -l tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
grep -n "MetricDataGenerator\|GenerateFakeValue" tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
# MetricDataGenerator.GenerateValue must appear in the loop
# GenerateFakeValue must appear ONLY in its definition (line 303+) — NOT in GenerateQueueDataAsync
```

---

## STEP 5 — Fix QueueGridWidget.razor: strict guard + direct _rtsGridId

Write `/tmp/fix_queue.py`:

```python
path = "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Strict guard — skip entirely if _rtsGridId == 0
text = text.replace(
    'if (_rtsGridId == 0 && GridId == 0)',
    'if (_rtsGridId == 0)'
)
text = text.replace(
    '"QueueGridWidget: no RTS GridId configured, skipping connection"',
    '"QueueGridWidget: Config.GridId not set — not configured, skipping"'
)

# Direct _rtsGridId in init() — remove fallback
text = text.replace(
    'await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);',
    'await _hub.InvokeAsync("init", _rtsGridId.ToString(), _cts.Token);'
)
text = text.replace(
    'await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());',
    'await _hub.InvokeAsync("init", _rtsGridId.ToString());'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Verify:
```bash
python3 /tmp/fix_queue.py
tail -5 src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
grep -n "_rtsGridId == 0\|init.*_rtsGridId" src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
```

---

## STEP 6 — Fix DataSlotWidget.razor: strict guard + direct _rtsGridId

Write `/tmp/fix_dataslot.py`:

```python
path = "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    'if (_rtsGridId == 0 && GridId == 0)',
    'if (_rtsGridId == 0)'
)
text = text.replace(
    '"DataSlotWidget: no RTS GridId configured, skipping connection"',
    '"DataSlotWidget: Config.DataSlotGridId not set — not configured, skipping"'
)
text = text.replace(
    'await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString(), _cts.Token);',
    'await _hub.InvokeAsync("init", _rtsGridId.ToString(), _cts.Token);'
)
text = text.replace(
    'await _hub.InvokeAsync("init", (_rtsGridId > 0 ? _rtsGridId : GridId).ToString());',
    'await _hub.InvokeAsync("init", _rtsGridId.ToString());'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
print("Done")
```

Verify:
```bash
python3 /tmp/fix_dataslot.py
tail -5 src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
wc -l src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
grep -n "_rtsGridId == 0\|init.*_rtsGridId" src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```

---

## STEP 7 — Pre-commit check (§0.5)

```bash
bash tools/pre-commit-check.sh \\
    tools/SignalRSimulator/Models/GridModels.cs \\
    tools/SignalRSimulator/Services/DbMetricService.cs \\
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \\
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \\
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
```
Exit code must be 0. If 1 — restore from HEAD and retry.

---

## STEP 8 — Commit

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \\
    tools/SignalRSimulator/Models/GridModels.cs \\
    tools/SignalRSimulator/Services/DbMetricService.cs \\
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \\
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \\
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator+widgets): ValueType-driven generation for Queue/DataSlot; strict RTS GridId guard"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4).

---

## STEP 9 — Post-commit integrity (§0.6)

```bash
git status --short
git diff HEAD -- \\
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \\
    tools/SignalRSimulator/Services/DbMetricService.cs \\
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \\
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor
# Expected: empty
git log --oneline -3
```

---

## STEP 10 — Instruct user

```
Fixes committed. Next steps:
1. Rebuild + restart simulator:
   cd tools/SignalRSimulator && dotnet build && dotnet run
2. Reload the dashboard page.
3. If DataSlot still shows "--": open widget settings → click Save
   (forces re-save of Config.DataSlotGridId).
```
