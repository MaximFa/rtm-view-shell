# CC Task: Fix time metric detection — MetricFormat-based detection for Number+Time

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only + os.fsync().
After every write: `sync && tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.
§0.6 PD-007 — Re-sync all committed files from HEAD as final step.

---

## ANALYSIS (Cowork pre-checked — do NOT re-investigate)

### Symptom
WAIT TIME column in QueueGrid shows plain integers (40, 97, 99) instead of MM:SS ticker format.

### Root cause
`GenerateNumberValue()` checks only `DataType == "Time"`.
In RTM database, wait-time metrics typically have:
- `ValueType = "Number"` (stored as integer seconds) → correct, hits GenerateNumberValue
- `DataType = "Integer"` (NOT "Time") — the DataType describes storage type, not display type
- `MetricFormat = "mm:ss"` or `"hh:mm:ss"` — this is the actual display hint

The fix only checks DataType=="Time" and misses the common case DataType="Integer" + MetricFormat="mm:ss".

### Solution
1. Diagnose: query DB for actual DataType + MetricFormat of queue grid metrics
2. Fix: in `GenerateNumberValue`, also check MetricFormat for time format indicators (`:`-containing format like "mm:ss", "hh:mm:ss")

---

## Step 1 — Integrity check

```bash
cd "$(git rev-parse --show-toplevel)"
for f in \
  "tools/SignalRSimulator/Generators/MetricDataGenerator.cs" \
  "tools/SignalRSimulator/Services/DbMetricService.cs"; do
  wt=$(wc -l < "$f"); hd=$(git show HEAD:"$f" | wc -l)
  [ "$wt" -eq "$hd" ] && echo "OK  WT=$wt  $f" || echo "TRUNCATED WT=$wt HEAD=$hd  $f"
done
```

If any TRUNCATED — restore: `git show HEAD:"$f" > "$f"` before proceeding.

---

## Step 2 — Diagnose: query DB for queue metric types

Get the connection string from appsettings, then query RTSGrid_Metric for all queue metrics:

```bash
cd "$(git rev-parse --show-toplevel)"
# Read connection string from simulator config
CONN=$(python3 -c "
import json
with open('tools/SignalRSimulator/appsettings.json') as f:
    cfg = json.load(f)
print(cfg.get('ConnectionStrings', {}).get('RtsDatabase', ''))
")
echo "Connection: $CONN"
```

Then run a diagnostic SQL query via psql:
```bash
python3 - << 'PYEOF'
import json, subprocess

with open("tools/SignalRSimulator/appsettings.json") as f:
    cfg = json.load(f)

conn_str = cfg.get("ConnectionStrings", {}).get("RtsDatabase", "")
# Parse: Host=...;Database=...;Username=...;Password=...
parts = dict(kv.split("=", 1) for kv in conn_str.split(";") if "=" in kv)
host = parts.get("Host", parts.get("Server", "localhost"))
db   = parts.get("Database", "")
user = parts.get("Username", parts.get("User Id", "postgres"))
pwd  = parts.get("Password", "")
port = parts.get("Port", "5432")

sql = """
SELECT m."MetricId", m."DataType", m."ValueType", m."MetricFormat", m."DefaultValue"
FROM "RTSGrid_Metric" m
WHERE m."DataType" IS NOT NULL OR m."MetricFormat" IS NOT NULL
ORDER BY m."MetricId"
LIMIT 30;
"""

env = {"PGPASSWORD": pwd}
import os; env.update(os.environ)
result = subprocess.run(
    ["psql", "-h", host, "-p", port, "-U", user, "-d", db, "-c", sql],
    capture_output=True, text=True, env=env
)
print(result.stdout or result.stderr)
PYEOF
```

**Read the output carefully.** Look for MetricIds related to wait time (containing "Wait", "WAIT", "Time", "TIME").
Note down their actual `DataType` and `MetricFormat` values.

---

## Step 3 — Fix GenerateNumberValue: MetricFormat-based time FORMAT (no ticker)

Path: `tools/SignalRSimulator/Generators/MetricDataGenerator.cs`

### Key design rule (confirmed by project owner):
- `ValueType = "Time"` → `+MM:SS` (live ticker, handled by GenerateTimeValue — DO NOT CHANGE)
- `ValueType = "Number"` + `MetricFormat contains ':'` → `MM:SS` (formatted snapshot, NO `+` prefix)
- `ValueType = "Number"` no time format → integer

The `+` prefix is ONLY for ValueType="Time" metrics (elapsed timers like agent state duration).
Wait-time metrics (ValueType="Number", MetricFormat="mm:ss") are snapshots — display as MM:SS
but DO NOT add `+` (no live ticker between pushes).

Python script `/tmp/fix_gen_metricformat.py`:

```python
import os
path = "tools/SignalRSimulator/Generators/MetricDataGenerator.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = '''    private static string GenerateNumberValue(MetricDefinition metric)
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

new = '''    private static string GenerateNumberValue(MetricDefinition metric)
    {
        // Time-formatted snapshot: MetricFormat contains ':' (e.g. "mm:ss", "hh:mm:ss")
        // ValueType="Number" means this is a snapshot value — NO '+' prefix (not a live ticker)
        // Only ValueType="Time" gets '+' (handled in GenerateTimeValue)
        if (metric.MetricFormat != null && metric.MetricFormat.Contains(':'))
        {
            var isLong = metric.MetricFormat.Contains("hh", StringComparison.OrdinalIgnoreCase);
            return isLong ? GenerateLongTime() : GenerateShortTime();
        }
        // DataType=="Time" fallback when MetricFormat is null — also snapshot, no '+'
        if (metric.DataType?.Equals("Time", StringComparison.OrdinalIgnoreCase) == true)
            return GenerateShortTime();
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
    f.flush()
    os.fsync(f.fileno())
print("Done")
```

Run + verify:
```bash
python3 /tmp/fix_gen_metricformat.py && sync && \
tail -5 tools/SignalRSimulator/Generators/MetricDataGenerator.cs && \
wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

Expected: last line is `}`, line count = 167 (was 161, +6 lines).

Verify no `+` prefix for Number path:
```bash
grep -A3 "MetricFormat.*Contains.*':'" tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

Expected: the return statement does NOT start with `"+"`.

---

## Step 4 — Pre-commit check

```bash
cd "$(git rev-parse --show-toplevel)"
bash tools/pre-commit-check.sh tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

If exit code 1 — DO NOT COMMIT.

---

## Step 5 — Commit

Only after pre-commit check exits 0:

```bash
cd "$(git rev-parse --show-toplevel)"
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/SignalRSimulator/Generators/MetricDataGenerator.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(sim): detect time metrics by MetricFormat ':' in GenerateNumberValue (handles Integer+mm:ss pattern)"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4).

---

## Step 6 — Post-commit integrity (CLAUDE.md §0.6)

```bash
git status --short | grep -E "^M tools/SignalRSimulator/Generators"
# Expected: no output

git diff HEAD -- tools/SignalRSimulator/Generators/MetricDataGenerator.cs
# Expected: empty
```

---

## Step 7 — Re-sync from HEAD (CLAUDE.md §0.6 PD-007)

```bash
cd "$(git rev-parse --show-toplevel)"
git show HEAD:"tools/SignalRSimulator/Generators/MetricDataGenerator.cs" > "tools/SignalRSimulator/Generators/MetricDataGenerator.cs"
sync
wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
# Must match HEAD
```

---

## Expected result after fix

For a wait-time metric with `ValueType="Number"`, `DataType="Integer"`, `MetricFormat="mm:ss"`:
- Before: `GenerateNumberValue` returned "137" (plain integer)
- After: `GenerateNumberValue` detects `MetricFormat.Contains(':')` → returns "02:17" (formatted, NO ticker)

QueueGrid will receive "02:17" (no `+`), display as static time string, update every 5s from simulator push.

For agent state duration with `ValueType="Time"`:
- `GenerateTimeValue` returns "+02:17" (with `+` — live ticker, ticks every second) — UNCHANGED
