# CC Task: Simulator — drive value generation from RTSGrid_Metric.ValueType

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

## Goal

`RTSGrid_Metric` has a `ValueType` column (`"String"` | `"Time"` | `"Number"`) that
explicitly declares each metric's semantic type. Currently the simulator ignores it
and uses fragile description-string heuristics instead.

Replace the heuristic approach with `ValueType`-driven generation:
- `"Time"`   → `"+" + HH:MM:SS` or `"+" + MM:SS` ('+' = live timer in AgentGridWidget)
- `"Number"` → integer or percent based on `DataType` / `MetricFormat`
- `"String"` → keep existing description heuristics for names, states, phone numbers, etc.

Three files change. Apply in order: GridModels → DbMetricService → MetricDataGenerator.

---

## File 1: `tools/SignalRSimulator/Models/GridModels.cs`

### Change 1 — add ValueType to MetricDefinition

Find:
```csharp
public record MetricDefinition(
    string MetricId,
    string? Description,
    string DataType,       // Integer, Time, Percent, String
    string? MetricFormat,  // N0, mm:ss, P0, P1
    string? DefaultValue
);
```

Replace with:
```csharp
public record MetricDefinition(
    string MetricId,
    string? Description,
    string DataType,       // Integer, Time, Percent, String  (format hint)
    string? MetricFormat,  // N0, mm:ss, P0, P1
    string? DefaultValue,
    string ValueType = "String"   // String | Time | Number  (semantic type from RTSGrid_Metric)
);
```

---

## File 2: `tools/SignalRSimulator/Services/DbMetricService.cs`

### Change 2a — add ValueType to GetAllMetricsAsync SELECT (column index 5)

Find:
```csharp
        const string sql = @"
            SELECT ""MetricId"", ""Description"", ""DataType"", ""MetricFormat"", ""DefaultValue""
            FROM ""RTSGrid_Metric""
            ORDER BY ""MetricId""";
```

Replace with:
```csharp
        const string sql = @"
            SELECT ""MetricId"", ""Description"", ""DataType"", ""MetricFormat"", ""DefaultValue"", ""ValueType""
            FROM ""RTSGrid_Metric""
            ORDER BY ""MetricId""";
```

### Change 2b — read ValueType in GetAllMetricsAsync MetricDefinition constructor

Find:
```csharp
            metrics.Add(new MetricDefinition(
                MetricId: reader.GetString(0),
                Description: reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType: reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4)
            ));
```

Replace with:
```csharp
            metrics.Add(new MetricDefinition(
                MetricId: reader.GetString(0),
                Description: reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType: reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4),
                ValueType: reader.IsDBNull(5) ? "String" : reader.GetString(5)
            ));
```

### Change 2c — add ValueType to GetConfiguredMetricsForUnionAsync SELECT

Find:
```csharp
        const string sql = @"
            SELECT DISTINCT
                c.""MetricId"",
                COALESCE(m.""Description"", c.""MetricId"") AS ""Description"",
                COALESCE(m.""DataType"", 'String')          AS ""DataType"",
                m.""MetricFormat"",
                m.""DefaultValue""
            FROM ""RTSUserGrid_Column"" c
            JOIN ""RTSUserGrid_ColumnsSet"" cs ON cs.""ColumnsSetId"" = c.""ColumnsSetId""
            JOIN ""RTSUserGrid_Grid""      g  ON g.""ColumnsSetId""  = cs.""ColumnsSetId""
            LEFT JOIN ""RTSGrid_Metric""   m  ON m.""MetricId""      = c.""MetricId""
            WHERE g.""GridId"" = @gridId
              AND c.""MetricId"" IS NOT NULL
              AND c.""MetricId"" <> ''";
```

Replace with:
```csharp
        const string sql = @"
            SELECT DISTINCT
                c.""MetricId"",
                COALESCE(m.""Description"", c.""MetricId"") AS ""Description"",
                COALESCE(m.""DataType"", 'String')          AS ""DataType"",
                m.""MetricFormat"",
                m.""DefaultValue"",
                COALESCE(m.""ValueType"", 'String')         AS ""ValueType""
            FROM ""RTSUserGrid_Column"" c
            JOIN ""RTSUserGrid_ColumnsSet"" cs ON cs.""ColumnsSetId"" = c.""ColumnsSetId""
            JOIN ""RTSUserGrid_Grid""      g  ON g.""ColumnsSetId""  = cs.""ColumnsSetId""
            LEFT JOIN ""RTSGrid_Metric""   m  ON m.""MetricId""      = c.""MetricId""
            WHERE g.""GridId"" = @gridId
              AND c.""MetricId"" IS NOT NULL
              AND c.""MetricId"" <> ''";
```

### Change 2d — read ValueType in GetConfiguredMetricsForUnionAsync constructor

Find:
```csharp
            result.Add(new MetricDefinition(
                MetricId:     reader.GetString(0),
                Description:  reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType:     reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4)
            ));
```

Replace with:
```csharp
            result.Add(new MetricDefinition(
                MetricId:     reader.GetString(0),
                Description:  reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType:     reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4),
                ValueType:    reader.IsDBNull(5) ? "String" : reader.GetString(5)
            ));
```

---

## File 3: `tools/SignalRSimulator/Generators/MetricDataGenerator.cs`

### Change 3 — rewrite GenerateValue() to use ValueType; keep string heuristics as GenerateStringValue()

Replace the ENTIRE content of `MetricDataGenerator.cs` with:

```csharp
using SignalRSimulator.Models;

namespace SignalRSimulator.Generators;

public static class MetricDataGenerator
{
    private static readonly Random _rng = new();

    private static readonly string[] AgentNames = {
        "John Smith", "Maria Garcia", "David Lee", "Anna Kowalski", "Michael Brown",
        "Sarah Johnson", "James Wilson", "Emma Davis", "Robert Miller", "Lisa Anderson",
        "William Taylor", "Jennifer Martinez", "Daniel Thompson", "Michelle White", "Christopher Harris",
        "Amanda Clark", "Matthew Lewis", "Jessica Robinson", "Andrew Walker", "Stephanie Hall",
        "Joshua Allen", "Nicole Young", "Ryan King", "Megan Wright", "Justin Scott",
        "Ashley Green", "Brandon Adams", "Brittany Baker", "Tyler Nelson", "Samantha Hill"
    };

    private static readonly string[] StatusNames = {
        "Available", "On Call", "Break", "Paperwork", "Wrap Up", "Unavailable", "Meeting", "Training"
    };

    private static readonly string[] StatusGroups = {
        "Available", "On Call", "Break", "Paperwork", "Wrap Up", "Unavailable"
    };

    private static readonly string[] InteractionTypes = {
        "Inbound Call", "Outbound Call", "Chat", "Email", "Callback"
    };

    private static readonly string[] QueueNames = {
        "Sales", "Support", "Billing", "Technical", "General", "VIP", "Complaints"
    };

    /// <summary>
    /// Generate a fake value for the given metric.
    /// Dispatches on ValueType (from RTSGrid_Metric.ValueType):
    ///   "Time"   → "+HH:MM:SS" or "+MM:SS"  ('+' prefix = live timer in AgentGridWidget)
    ///   "Number" → integer or percent based on DataType / MetricFormat
    ///   "String" → description-heuristic text (names, states, IDs, etc.)
    /// </summary>
    public static string GenerateValue(MetricDefinition metric)
    {
        return (metric.ValueType ?? "String") switch
        {
            "Time"   => GenerateTimeValue(metric),
            "Number" => GenerateNumberValue(metric),
            _        => GenerateStringValue(metric)
        };
    }

    public static Dictionary<string, string> GenerateMetrics(IEnumerable<MetricDefinition> metrics)
        => metrics.ToDictionary(m => m.MetricId, m => GenerateValue(m));

    // ── Time ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// All Time metrics get the '+' prefix so AgentGridWidget creates a TimerAnchor
    /// and increments the value every second via its PeriodicTimer.
    /// Format choice: MetricFormat containing "hh" → long (HH:MM:SS), else short (MM:SS).
    /// </summary>
    private static string GenerateTimeValue(MetricDefinition metric)
    {
        var isLong = metric.MetricFormat?.Contains("hh", StringComparison.OrdinalIgnoreCase) == true
                     || metric.DataType?.Equals("Time", StringComparison.OrdinalIgnoreCase) == true;
        return "+" + (isLong ? GenerateLongTime() : GenerateShortTime());
    }

    // ── Number ───────────────────────────────────────────────────────────────

    private static string GenerateNumberValue(MetricDefinition metric)
    {
        // Percent: DataType == "Percent" OR MetricFormat contains '%'
        if (metric.DataType?.Equals("Percent", StringComparison.OrdinalIgnoreCase) == true
            || metric.MetricFormat?.Contains('%') == true)
            return GeneratePercent(metric.MetricFormat);

        // Default integer
        return _rng.Next(0, 200).ToString();
    }

    // ── String ───────────────────────────────────────────────────────────────

    private static string GenerateStringValue(MetricDefinition metric)
    {
        var desc = metric.Description ?? "";
        var metricId = metric.MetricId;

        if (desc.Contains("Login Name"))
            return AgentNames[_rng.Next(AgentNames.Length)];

        if (desc.Contains("User ID") || desc.Contains("Station ID") || desc.Contains("Extension ID"))
            return _rng.Next(1000, 9999).ToString();

        if (desc.Contains("Interction ID") || desc.Contains("Interaction ID"))
            return $"INT-{_rng.Next(100000, 999999)}";

        if (desc.Contains("Phone Number"))
            return $"+1-{_rng.Next(200, 999)}-{_rng.Next(100, 999)}-{_rng.Next(1000, 9999)}";

        if (desc.Contains("Queue Name"))
            return QueueNames[_rng.Next(QueueNames.Length)];

        if (desc.Contains("Interaction State") && !desc.Contains("Duration"))
            return StatusNames[_rng.Next(StatusNames.Length)];

        if (desc.Contains("Interaction Type"))
            return InteractionTypes[_rng.Next(InteractionTypes.Length)];

        if (desc.Contains("Current Satatus") || (desc.Contains("Current Status") && !desc.Contains("Duration") && !desc.Contains("Group")))
            return StatusNames[_rng.Next(StatusNames.Length)];

        if (desc.Contains("Status Group") && !desc.Contains("Duration"))
            return StatusGroups[_rng.Next(StatusGroups.Length)];

        if (desc.Contains("Today Login") || desc.Contains("Change -ID"))
            return _rng.Next(0, 2) == 0 ? "" : AgentNames[_rng.Next(AgentNames.Length)];

        if (desc.Contains("Time Stamp") || desc.Contains("TimeStamp"))
            return GenerateTimestamp();

        // Fallback: return a small number as text
        return _rng.Next(0, 100).ToString();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    public static string GenerateShortTime()
    {
        var seconds = _rng.Next(0, 1800);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    public static string GenerateLongTime()
    {
        var seconds = _rng.Next(0, 32400);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{(int)ts.TotalHours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    private static string GeneratePercent(string? format)
    {
        var value = _rng.Next(60, 100) + _rng.NextDouble();
        if (format?.Contains("##0.00%") == true) return $"{value:F2}%";
        if (format?.Contains("##0.0%") == true)  return $"{value:F1}%";
        return $"{(int)value}%";
    }

    private static string GenerateTimestamp()
    {
        var now = DateTime.Now;
        var offset = TimeSpan.FromMinutes(_rng.Next(0, 480));
        return (now - offset).ToString("HH:mm:ss");
    }
}
```

---

## Verification

```bash
# Build
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj 2>&1 | tail -5

# ValueType in model
grep -n "ValueType" tools/SignalRSimulator/Models/GridModels.cs
# Expected: 1 line with ValueType = "String"

# ValueType in both SQL queries
grep -n "ValueType" tools/SignalRSimulator/Services/DbMetricService.cs
# Expected: 4+ lines (2 SELECT, 2 reader)

# GenerateValue uses ValueType switch
grep -n "ValueType\|GenerateTimeValue\|GenerateNumberValue\|GenerateStringValue" tools/SignalRSimulator/Generators/MetricDataGenerator.cs
# Expected: 4+ lines

# Files end properly
tail -3 tools/SignalRSimulator/Models/GridModels.cs
tail -3 tools/SignalRSimulator/Services/DbMetricService.cs
tail -3 tools/SignalRSimulator/Generators/MetricDataGenerator.cs
wc -l tools/SignalRSimulator/Models/GridModels.cs
wc -l tools/SignalRSimulator/Services/DbMetricService.cs
wc -l tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
    tools/SignalRSimulator/Models/GridModels.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    tools/SignalRSimulator/Models/GridModels.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator): drive value generation from RTSGrid_Metric.ValueType — Time gets '+' prefix, Number gets int/percent, String keeps text heuristics"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
