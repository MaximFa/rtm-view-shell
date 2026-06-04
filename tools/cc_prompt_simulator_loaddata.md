# CC Task: Simulator — /LoadData + DB-driven agent MetricIds per UnionId

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
For every `M` file: `tail -3 <path>`. Restore truncated via `git show HEAD:<path> > <path>`.

---

## Problem

The simulator's `GenerateAgentDataAsync` uses a hardcoded metric dictionary.
It has no `/LoadData` endpoint. Therefore:

1. When a new column is added to an Agent Grid widget, `RtmConfigurationApiHook`
   calls `GET {url}/LoadData` — the simulator returns 404.
2. Even if the widget reconnects (via `_lastColumnsKey` fix), the next push still
   does NOT contain the new MetricId because it's not in the hardcoded dict.
3. New column shows "–" forever.

The real RTM Server (after our `ForceRefreshMetrics` fix) behaves as follows:
after `/LoadData`, the next `updateUserGrid` push includes all configured MetricIds
for that union. The simulator must match this.

## Goal

1. `DbMetricService` — add `GetConfiguredMetricsForUnionAsync(int unionId)`:
   reads `RTSUserGrid_Column` + `RTSGrid_Metric` for the union's configured MetricIds.
   Add `InvalidateCaches()` to force re-read on next call.

2. `RtmSimulatorHub.GenerateAgentDataAsync` — after building the hardcoded dict,
   fetch configured MetricIds from DB for this union and ADD any missing ones
   (with `MetricDataGenerator.GenerateValue`). Result: every push contains all
   configured MetricIds, including newly added ones.

3. `Program.cs` — add `GET /LoadData` endpoint: calls `InvalidateCaches()`,
   returns HTTP 200. This makes `/LoadData` work identically to the real RTM Server.

---

## File 1: `tools/SignalRSimulator/Services/DbMetricService.cs`

### Change 1a — Add union metric cache fields and `InvalidateCaches()`

Find:
```csharp
    private List<MetricDefinition>? _cachedMetrics;
    private DateTime _cacheTime = DateTime.MinValue;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);
```

Replace with:
```csharp
    private List<MetricDefinition>? _cachedMetrics;
    private DateTime _cacheTime = DateTime.MinValue;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    // Per-union configured metric cache (cleared on /LoadData)
    private readonly Dictionary<int, List<MetricDefinition>> _unionMetricCache = new();

    /// <summary>
    /// Clears all in-memory caches. Called by /LoadData endpoint so the next
    /// generation cycle re-reads fresh config (including newly added columns).
    /// </summary>
    public void InvalidateCaches()
    {
        _cachedMetrics = null;
        _cacheTime = DateTime.MinValue;
        lock (_unionMetricCache) { _unionMetricCache.Clear(); }
    }
```

### Change 1b — Add `GetConfiguredMetricsForUnionAsync` + interface method

Find the interface declaration:
```csharp
public interface IDbMetricService
{
    Task<List<MetricDefinition>> GetAllMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetAgentMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetQueueMetricsAsync(CancellationToken ct = default);
    Task<List<GridRowInfo>> GetRowsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<MetricDefinition>> GetMetricsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default);
}
```

Replace with:
```csharp
public interface IDbMetricService
{
    Task<List<MetricDefinition>> GetAllMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetAgentMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetQueueMetricsAsync(CancellationToken ct = default);
    Task<List<GridRowInfo>> GetRowsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<MetricDefinition>> GetMetricsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default);
    /// <summary>Returns MetricDefinitions configured in RTSUserGrid_Column for the given UnionId.</summary>
    Task<List<MetricDefinition>> GetConfiguredMetricsForUnionAsync(int unionId, CancellationToken ct = default);
    void InvalidateCaches();
}
```

### Change 1c — Add `GetConfiguredMetricsForUnionAsync` implementation

Find:
```csharp
    public async Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default)
```

Insert BEFORE it:
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

---

## File 2: `tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs`

### Change 2 — After building hardcoded agent row dict, add DB-configured metrics

Find the hardcoded dict return statement inside `GenerateAgentDataAsync`:
```csharp
                    return new Dictionary<string, string>
                    {
```

The entire `return new Dictionary<string, string> { ... };` block ends with `};`.
After the closing `};` of each agent row dict but BEFORE `}).ToList();`, the dict
is immediately used in the `agentRows = agents.Select((userId, idx) => { ... }).ToList()`.

Instead, restructure so we CAN enrich each row. Find the lambda that returns the dict:

```csharp
                var agentRows = agents.Select((userId, idx) =>
                {
```

Replace the ENTIRE `agentRows` select block (from `var agentRows = agents.Select` up to
and including `}).ToList();`) with:

```csharp
                // Load DB-configured MetricIds for this union (cached; cleared on /LoadData)
                List<MetricDefinition> dbMetrics;
                try { dbMetrics = await _db.GetConfiguredMetricsForUnionAsync(unionId, ct); }
                catch { dbMetrics = new List<MetricDefinition>(); }

                var agentRows = agents.Select((userId, idx) =>
                {
                    var stateIdx = rng.Next(AgentStates.Length);
                    var statusGroupCode = AgentStates[stateIdx];
                    var agentState = AgentStateGroups[stateIdx];
                    var telState = TelStates[rng.Next(TelStates.Length)];
                    var interactionType = InteractionTypes[rng.Next(InteractionTypes.Length)];
                    var campaign = Campaigns[rng.Next(Campaigns.Length)];
                    var agentName = AgentNames[idx % AgentNames.Length];

                    var statusDuration = TimeSpan.FromSeconds(rng.Next(0, 3600));
                    var loginDuration = TimeSpan.FromHours(rng.Next(1, 8));
                    var availDuration = TimeSpan.FromMinutes(rng.Next(10, 180));
                    var breakDuration = TimeSpan.FromMinutes(rng.Next(0, 60));
                    var talkDuration = TimeSpan.FromMinutes(rng.Next(30, 240));
                    var holdDuration = TimeSpan.FromMinutes(rng.Next(0, 30));
                    var wrapDuration = TimeSpan.FromMinutes(rng.Next(5, 45));
                    var paperworkDuration = TimeSpan.FromMinutes(rng.Next(0, 30));
                    var trainingDuration = TimeSpan.FromMinutes(rng.Next(0, 60));
                    var avgInboundDuration = TimeSpan.FromSeconds(rng.Next(60, 600));
                    var avgOutboundDuration = TimeSpan.FromSeconds(rng.Next(30, 300));

                    var inboundCalls = rng.Next(5, 80);
                    var outboundCalls = rng.Next(0, 40);
                    var inboundCompleted = rng.Next(3, inboundCalls);
                    var outboundCompleted = rng.Next(0, Math.Max(1, outboundCalls));
                    var transfers = rng.Next(0, 10);
                    var conferences = rng.Next(0, 5);
                    var talkPct = rng.Next(30, 80);
                    var occupancy = rng.Next(50, 100);
                    var adherence = rng.Next(75, 100);

                    var row = new Dictionary<string, string>
                    {
                        ["USERID"] = userId,
                        ["AgentLoginName"] = agentName,
                        ["AgentName"] = agentName,
                        ["MonAgentUserId"] = userId,
                        ["MonAgentStation"] = $"STA{1000 + idx}",
                        ["MonAgentExtension"] = $"{3000 + idx}",
                        ["MonAgentState"] = agentState,
                        ["MonAgentStateDesc"] = agentState,
                        ["AgentState"] = agentState,
                        ["CurStatus"] = agentState,
                        ["StatusGroup"] = statusGroupCode,
                        ["CurStatusGroup"] = statusGroupCode,
                        ["MonAgentStateDuration"] = $"+{statusDuration:hh\\:mm\\:ss}",
                        ["AgentStateDuration"] = $"+{statusDuration:hh\\:mm\\:ss}",
                        ["CurStatusDuration"] = $"+{statusDuration:hh\\:mm\\:ss}",
                        ["MonAgentTelState"] = telState,
                        ["MonInteractionType"] = interactionType,
                        ["MonActiveCampaign"] = campaign,
                        ["MonAgentCallerNumber"] = rng.Next(2) == 0 ? "" : $"+1-555-{rng.Next(1000, 9999)}",
                        ["MonAgentCalledNumber"] = rng.Next(2) == 0 ? "" : $"+1-555-{rng.Next(1000, 9999)}",
                        ["MonAgentCurrentLoginDuration"] = $"+{loginDuration:hh\\:mm\\:ss}",
                        ["MonAgentAvailableDuration"] = $"+{availDuration:hh\\:mm\\:ss}",
                        ["MonAgentBreakDuration"] = $"+{breakDuration:hh\\:mm\\:ss}",
                        ["MonAgentTalkDuration"] = $"+{talkDuration:hh\\:mm\\:ss}",
                        ["MonAgentHoldDuration"] = $"+{holdDuration:hh\\:mm\\:ss}",
                        ["MonAgentWrapDuration"] = $"+{wrapDuration:hh\\:mm\\:ss}",
                        ["MonAgentPaperworkDuration"] = $"+{paperworkDuration:hh\\:mm\\:ss}",
                        ["MonAgentTrainingDuration"] = $"+{trainingDuration:hh\\:mm\\:ss}",
                        ["MonAgentNotReadyDuration"] = $"+{breakDuration + paperworkDuration:hh\\:mm\\:ss}",
                        ["MonAgentIdleDuration"] = $"+{TimeSpan.FromMinutes(rng.Next(0, 20)):hh\\:mm\\:ss}",
                        ["MonAgentAverageInboundCallDuration"] = $"+{avgInboundDuration:mm\\:ss}",
                        ["MonAgentAverageOutboundCallDuration"] = $"+{avgOutboundDuration:mm\\:ss}",
                        ["MonAgentAverageWrapDuration"] = $"+{TimeSpan.FromSeconds(rng.Next(10, 120)):mm\\:ss}",
                        ["MonAgentAverageHoldDuration"] = $"+{TimeSpan.FromSeconds(rng.Next(5, 60)):mm\\:ss}",
                        ["MonAgentNumberOfInboundCalls"] = inboundCalls.ToString(),
                        ["MonAgentNumberOfInboundCallsOnly"] = inboundCalls.ToString(),
                        ["MonAgentNumMakeCallsInCompleted"] = inboundCompleted.ToString(),
                        ["MonAgentNumberOfOutboundCalls"] = outboundCalls.ToString(),
                        ["MonAgentNumMakeCallsOutCompleted"] = outboundCompleted.ToString(),
                        ["MonAgentNumberOfTransfers"] = transfers.ToString(),
                        ["MonAgentNumberOfConferences"] = conferences.ToString(),
                        ["MonAgentNumberOfCallbacks"] = rng.Next(0, 10).ToString(),
                        ["MonAgentNumberOfChats"] = rng.Next(0, 20).ToString(),
                        ["MonAgentNumberOfEmails"] = rng.Next(0, 15).ToString(),
                        ["MonAgentTalkDurationPct"] = $"{talkPct}%",
                        ["AgentOccupancy"] = $"{occupancy}%",
                        ["AgentAdherence"] = $"{adherence}%",
                        ["MonAgentUtilization"] = $"{rng.Next(60, 95)}%",
                        ["MonAgentAvailablePct"] = $"{rng.Next(20, 60)}%",
                        ["MonAgentBreakPct"] = $"{rng.Next(5, 20)}%",
                        ["MonAgentCurrentQueue"] = rng.Next(2) == 0 ? "" : $"Queue_{rng.Next(1, 5)}",
                        ["MonAgentCurrentSkill"] = rng.Next(2) == 0 ? "" : $"Skill_{rng.Next(1, 10)}",
                        ["MonAgentSkillLevel"] = rng.Next(1, 11).ToString(),
                        ["MonAgentWrapReason"] = rng.Next(3) == 0 ? "Follow-up" : "",
                        ["MonAgentScheduledState"] = AgentStateGroups[rng.Next(AgentStateGroups.Length)],
                        ["MonAgentScheduleVariance"] = $"{rng.Next(-30, 30)}m",
                    };

                    // Add any DB-configured MetricIds not already in the hardcoded set.
                    // This makes newly added columns appear immediately after /LoadData.
                    foreach (var m in dbMetrics)
                    {
                        if (!row.ContainsKey(m.MetricId))
                            row[m.MetricId] = Generators.MetricDataGenerator.GenerateValue(m);
                    }

                    return row;
                }).ToList();
```

**Note:** The lambda is now `async`-free — the DB call is hoisted BEFORE the `.Select(...)`.
The lambda returns `Dictionary<string, string>` (not a Task), which is correct.
Make sure to add `using SignalRSimulator.Generators;` at the top of the file if not present.

---

## File 3: `tools/SignalRSimulator/Program.cs`

### Change 3 — Add `/LoadData` endpoint

Find:
```csharp
app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr\nClient calls init(gridId) after connecting:\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nMetrics are loaded from database.");
```

Replace with:
```csharp
app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr\nClient calls init(gridId) after connecting:\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nMetrics are loaded from database.");

// Matches real RTM Server endpoint — called by RtmConfigurationApiHook after config changes.
// Invalidates the metric cache so the next push includes newly configured MetricIds.
app.MapGet("/LoadData", (IDbMetricService db, ILogger<Program> logger) =>
{
    db.InvalidateCaches();
    logger.LogInformation("[Simulator] /LoadData called — metric cache cleared");
    return Results.Ok("LoadData OK");
});
```

---

## Verification

```bash
# Build
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj 2>&1 | tail -10

# Interface has new method
grep -n "GetConfiguredMetricsForUnionAsync\|InvalidateCaches" tools/SignalRSimulator/Services/DbMetricService.cs
# Expected: 4+ lines (interface + implementation)

# Hub uses DB metrics
grep -n "GetConfiguredMetricsForUnionAsync\|dbMetrics" tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
# Expected: 2+ lines

# /LoadData endpoint present
grep -n "LoadData\|InvalidateCaches" tools/SignalRSimulator/Program.cs
# Expected: 2+ lines

# Files end properly
tail -3 tools/SignalRSimulator/Services/DbMetricService.cs
tail -3 tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs
tail -3 tools/SignalRSimulator/Program.cs
```

---

## Commit

```bash
bash tools/pre-commit-check.sh
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    tools/SignalRSimulator/Program.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator): /LoadData endpoint + DB-driven agent MetricIds per union — new columns appear immediately"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
