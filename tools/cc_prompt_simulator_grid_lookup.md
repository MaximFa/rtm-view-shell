# CC Task: Simulator — fix GetConfiguredMetricsForUnionAsync SQL (GridId vs UnionId)

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

---

## Root Cause

In `AgentGridWidget.razor`, the hub is called with:
```csharp
await _hub.InvokeAsync("init", $"u{GridId}");
```
where `GridId` is `RTSUserGrid_Grid.GridId` — the **primary key** of the grid row.

In `RtmSimulatorHub.GenerateAgentDataAsync`:
```csharp
if (!int.TryParse(gridId[1..], out var unionId)) return;
// ...
dbMetrics = await _db.GetConfiguredMetricsForUnionAsync(unionId, ct);
```
The variable `unionId` holds the **GridId PK value** (e.g., 42), NOT the
`RTSUserGrid_Grid.UnionId` column (which is the BusinessUnitId — a different value).

In `DbMetricService.GetConfiguredMetricsForUnionAsync`, the SQL is:
```sql
WHERE g."UnionId" = @unionId
```
This compares the BusinessUnit column with the GridId PK → **zero rows returned** →
newly added columns never appear in the simulator push.

## Goal

Fix the WHERE clause to use `GridId` (the PK) instead of `UnionId` (BusinessUnit field).
Rename the parameter from `unionId` to `gridId` for clarity.

---

## File: `tools/SignalRSimulator/Services/DbMetricService.cs`

### Change 1 — Fix method signature and SQL

Find:
```csharp
    public async Task<List<MetricDefinition>> GetConfiguredMetricsForUnionAsync(int unionId, CancellationToken ct = default)
    {
        lock (_unionMetricCache)
        {
            if (_unionMetricCache.TryGetValue(unionId, out var cached))
                return cached;
        }

        var result = new List<MetricDefinition>();
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        // Join RTSUserGrid tables to find MetricIds configured for this UnionId,
        // then join RTSGrid_Metric to get DataType / Description for value generation.
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
            WHERE g.""UnionId"" = @unionId
              AND c.""MetricId"" IS NOT NULL
              AND c.""MetricId"" <> ''";

        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("unionId", unionId);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            result.Add(new MetricDefinition(
                MetricId:     reader.GetString(0),
                Description:  reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType:     reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4)
            ));
        }

        _logger.LogDebug("Loaded {Count} configured metrics for union {UnionId}", result.Count, unionId);

        lock (_unionMetricCache) { _unionMetricCache[unionId] = result; }
        return result;
    }
```

Replace with:
```csharp
    public async Task<List<MetricDefinition>> GetConfiguredMetricsForUnionAsync(int gridId, CancellationToken ct = default)
    {
        lock (_unionMetricCache)
        {
            if (_unionMetricCache.TryGetValue(gridId, out var cached))
                return cached;
        }

        var result = new List<MetricDefinition>();
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        // Join RTSUserGrid tables to find MetricIds configured for this Grid PK.
        // NOTE: the hub receives gridId (PK of RTSUserGrid_Grid), NOT UnionId (BusinessUnit).
        // Widget calls init("u{GridId}") where GridId = RTSUserGrid_Grid.GridId PK.
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

        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("gridId", gridId);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            result.Add(new MetricDefinition(
                MetricId:     reader.GetString(0),
                Description:  reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType:     reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4)
            ));
        }

        _logger.LogDebug("Loaded {Count} configured metrics for grid {GridId}", result.Count, gridId);

        lock (_unionMetricCache) { _unionMetricCache[gridId] = result; }
        return result;
    }
```

### Change 2 — Fix interface to match (parameter name is cosmetic but keep consistent)

Find in the interface:
```csharp
    /// <summary>Returns MetricDefinitions configured in RTSUserGrid_Column for the given UnionId.</summary>
    Task<List<MetricDefinition>> GetConfiguredMetricsForUnionAsync(int unionId, CancellationToken ct = default);
```

Replace with:
```csharp
    /// <summary>
    /// Returns MetricDefinitions configured in RTSUserGrid_Column for the given GridId (PK).
    /// NOTE: gridId here is RTSUserGrid_Grid.GridId (PK), not the UnionId/BusinessUnit column.
    /// </summary>
    Task<List<MetricDefinition>> GetConfiguredMetricsForUnionAsync(int gridId, CancellationToken ct = default);
```

---

## Verification

```bash
# Fixed WHERE clause uses GridId PK
grep -n '"GridId" = @gridId\|"UnionId" = @unionId' tools/SignalRSimulator/Services/DbMetricService.cs
# Expected: one line with GridId, zero lines with UnionId

# Build
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj 2>&1 | tail -5

# File ends properly
tail -3 tools/SignalRSimulator/Services/DbMetricService.cs
wc -l tools/SignalRSimulator/Services/DbMetricService.cs
```

---

## Commit

```bash
bash tools/pre-commit-check.sh tools/SignalRSimulator/Services/DbMetricService.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/SignalRSimulator/Services/DbMetricService.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator): query configured metrics by GridId PK, not UnionId — widget sends u{GridId}"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
