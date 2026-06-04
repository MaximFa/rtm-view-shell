# CC Task: Real RTM Server Integration

## MANDATORY RULES (CLAUDE.md §0)

**§0.3 — Edit tool BANNED. Python atomic writes only:**
```python
with open(path, "r", encoding="utf-8") as f: text = f.read()
# ... modify ...
with open(path, "w", encoding="utf-8") as f: f.write(text)
```
After EVERY write: `tail -3 <path> && wc -l <path>`.  
Truncated → `git show HEAD:<path> > <path>` + retry.

**§0.5 — Before every commit:** `bash tools/pre-commit-check.sh` (must exit 0)

**§0.4 — git index.lock workaround:**
```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add <files>
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "..."
cp /tmp/cc-idx .git/index
```

---

## Goal

Wire the project to the real RTM SignalR Server. Three changes:

1. **`RtmConfigurationApiHook`** — after any widget config save, calls `GET /LoadData` on RTM Server
   so it re-reads the updated RTSGrid_* tables from DB without restarting.
2. **`GetCellMapForGridAsync`** + MediatR query — lets widgets resolve CellId → MetricId.
3. **`AgentStateDistributionWidget`** — switch from old simulator hub
   (`/hubs/queue-grid?gridId=...` + `QueueGridUpdate`) to real RTM protocol
   (`/signalr` + `updateGridData`), exactly as QueueGridWidget and DataSlotWidget already do.

---

## Background

### RTM Server HTTP API (Program.cs)
```
GET /LoadData            — full reload of all RTSGrid_* tables from DB (no restart)
GET /UpdateCell?...      — hot-update single cell (v2 optimization, not used now)
```

### RTM SignalR hub (`/signalr`)
- Client calls `init(gridId)` after connecting (string arg, e.g. "42")
- Server pushes `updateGridData` → `ICollection<CellData>` — Newtonsoft PascalCase serialization
  `{ CellId: int, Value: string, Value2: string, Grid: int }`

### Key facts
- `TenantSettings.SignalRConnectionUrl` = RTM Server base URL (already used by widgets).
  Hook uses same URL: `GET {SignalRConnectionUrl}/LoadData`
- `RTSGrid_Cell.Value` = MetricId (e.g. "QueueLoginDataNumLoggedUsers").
  This is what the widget needs to decode CellId → label for chart rendering.
- Calling `/LoadData` after every RTM-related config save is correct for v1.
  RTM picks up all RTSGrid_* changes in one shot.

---

## Part 1 — GetCellMapForGridAsync

### 1a. `src/CcDashboard.Application/Interfaces/IRtsRepository.cs`

Add at the end of the Queue Grid section (before closing brace):

```csharp
    /// <summary>CellId → MetricId map for all cells in a queue grid (RTSGrid_Cell.Value).</summary>
    Task<Dictionary<int, string>> GetCellMapForGridAsync(int gridId, CancellationToken ct = default);
```

### 1b. `src/CcDashboard.Infrastructure/Persistence/Repositories/RtsRepository.cs`

Add before the final closing brace of the class:

```csharp
    public async Task<Dictionary<int, string>> GetCellMapForGridAsync(int gridId, CancellationToken ct = default)
    {
        var result = new Dictionary<int, string>();
        var conn = (NpgsqlConnection)db.Database.GetDbConnection();
        var wasOpen = conn.State == System.Data.ConnectionState.Open;
        if (!wasOpen) await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT c.""CellId"", c.""Value""
                FROM ""RTSGrid_Cell"" c
                JOIN ""RTSGrid_Row"" r ON r.""RowId"" = c.""RowId""
                WHERE r.""GridId"" = @gridId
                  AND c.""Value"" IS NOT NULL AND c.""Value"" <> ''";
            cmd.Parameters.AddWithValue("gridId", gridId);
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
                result[reader.GetInt32(0)] = reader.GetString(1);
        }
        finally
        {
            if (!wasOpen) await conn.CloseAsync();
        }
        return result;
    }
```

### 1c. New file: `src/CcDashboard.Application/Queries/Widgets/GetRtsGridCellMapQuery.cs`

```csharp
using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Widgets;

public record GetRtsGridCellMapQuery(int GridId) : IRequest<Dictionary<int, string>>;

public class GetRtsGridCellMapQueryHandler(IRtsRepository rts)
    : IRequestHandler<GetRtsGridCellMapQuery, Dictionary<int, string>>
{
    public Task<Dictionary<int, string>> Handle(GetRtsGridCellMapQuery q, CancellationToken ct)
        => rts.GetCellMapForGridAsync(q.GridId, ct);
}
```

---

## Part 2 — RtmConfigurationApiHook

### 2a. New file: `src/CcDashboard.Infrastructure/Services/RtmConfigurationApiHook.cs`

```csharp
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// Calls GET {SignalRConnectionUrl}/LoadData on the RTM SignalR Server after any
/// RTM-related config change, so RTM re-reads all RTSGrid_* tables without restarting.
/// Fails gracefully — save always succeeds even if RTM is unreachable.
/// </summary>
public class RtmConfigurationApiHook(
    AppDbContext db,
    ITenantContext tenantContext,
    IHttpClientFactory httpClientFactory,
    ILogger<RtmConfigurationApiHook> logger) : IConfigurationApiHook
{
    private static readonly HashSet<string> RtmEventTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "QueueGridRts.Saved",  "QueueGridRts.Deleted",
        "AgentGridRts.Saved",  "AgentGridRts.Deleted",
        "DataSlotRts.Saved",   "DataSlotRts.Deleted",
        "BusinessUnit", "Supergroup", "Site", "RtsGridMetric"
    };

    public async Task NotifyAsync(string entityType, object payload, CancellationToken ct = default)
    {
        if (!RtmEventTypes.Contains(entityType))
            return;

        if (!tenantContext.IsResolved)
        {
            logger.LogDebug("[RTM-HOOK] Tenant not resolved, skipping /LoadData for {EntityType}", entityType);
            return;
        }

        string? rtmUrl;
        try
        {
            var settings = await db.TenantSettings
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.TenantId == tenantContext.TenantId, ct);
            rtmUrl = settings?.SignalRConnectionUrl;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "[RTM-HOOK] Failed to read TenantSettings for {EntityType}", entityType);
            return;
        }

        if (string.IsNullOrWhiteSpace(rtmUrl))
        {
            logger.LogDebug("[RTM-HOOK] SignalRConnectionUrl not set for tenant {TenantId}", tenantContext.TenantId);
            return;
        }

        var loadDataUrl = $"{rtmUrl.TrimEnd('/')}/LoadData";
        try
        {
            var client = httpClientFactory.CreateClient("RtmServer");
            var response = await client.GetAsync(loadDataUrl, ct);
            if (response.IsSuccessStatusCode)
                logger.LogInformation("[RTM-HOOK] /LoadData OK ({Status}) for {EntityType}, tenant {TenantId}",
                    (int)response.StatusCode, entityType, tenantContext.TenantId);
            else
                logger.LogWarning("[RTM-HOOK] /LoadData returned {Status} for {EntityType}",
                    (int)response.StatusCode, entityType);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or OperationCanceledException)
        {
            logger.LogWarning(ex,
                "[RTM-HOOK] /LoadData unreachable for {EntityType} — save succeeded, RTM will sync later",
                entityType);
        }
    }
}
```

### 2b. `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs`

Find:
```csharp
        services.AddScoped<IConfigurationApiHook, NoOpConfigurationApiHook>();
```

Replace with:
```csharp
        services.AddScoped<IConfigurationApiHook, RtmConfigurationApiHook>();
        services.AddHttpClient("RtmServer", client =>
        {
            client.Timeout = TimeSpan.FromSeconds(5);
        });
```

---

## Part 3 — AgentStateDistributionWidget RTM protocol

### File: `src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor`

The widget currently uses the old simulator protocol. Replace it with real RTM.

The `_cellValues` dictionary (keyed by MetricId) is already used throughout chart rendering —
only the data ingestion layer changes. No chart code modifications needed.

#### 3a. Add usings at the top (after existing `@using` lines):

```razor
@using CcDashboard.Application.Queries.Widgets
@using Newtonsoft.Json.Serialization
```

#### 3b. Add private field (near `_cellValues`):

```csharp
    private Dictionary<int, string> _cellIdToMetric = new();
```

#### 3c. Replace the hub connection block inside `ConnectHubAsync()`

Find this block (starts at `var settings = await Mediator.Send(new GetTenantSettingsQuery()`):

```csharp
            var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
            var simulatorUrl = settings?.SignalRConnectionUrl ?? "http://localhost:5045";
            var fullUrl = $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";

            Logger.LogInformation("AgentStateDistributionWidget: Connecting to {Url}", fullUrl);

            _hub = new HubConnectionBuilder()
                .WithUrl(fullUrl)
                .WithAutomaticReconnect(new[] {
                    TimeSpan.Zero,
                    TimeSpan.FromSeconds(2),
                    TimeSpan.FromSeconds(5),
                    TimeSpan.FromSeconds(10),
                    TimeSpan.FromSeconds(30)
                })
                .Build();

            _hub.On<GridUpdate>("QueueGridUpdate", async update =>
            {
                var buRow = update.Rows.FirstOrDefault(r => r.UnionId == _businessUnitId);
                if (buRow is not null)
                {
                    _cellValues = buRow.Metrics;
                    await InvokeAsync(async () =>
                    {
                        StateHasChanged();
                        await RenderChartAsync();
                    });
                }
            });
```

Replace with:

```csharp
            // Load CellId → MetricId map so updateGridData pushes can be decoded
            _cellIdToMetric = await Mediator.Send(new GetRtsGridCellMapQuery(RtsGridId), _cts.Token);
            Logger.LogInformation("AgentStateDistributionWidget: loaded {Count} cells for grid {GridId}",
                _cellIdToMetric.Count, RtsGridId);

            var settings = await Mediator.Send(new GetTenantSettingsQuery(), _cts.Token);
            var rtmUrl = settings?.SignalRConnectionUrl ?? "http://localhost:5045";
            var fullUrl = $"{rtmUrl.TrimEnd('/')}/signalr";

            Logger.LogInformation("AgentStateDistributionWidget: Connecting to {Url}", fullUrl);

            _hub = new HubConnectionBuilder()
                .WithUrl(fullUrl)
                .AddNewtonsoftJsonProtocol(o =>
                    o.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
                .WithAutomaticReconnect(new[] {
                    TimeSpan.Zero,
                    TimeSpan.FromSeconds(2),
                    TimeSpan.FromSeconds(5),
                    TimeSpan.FromSeconds(10),
                    TimeSpan.FromSeconds(30)
                })
                .Build();

            _hub.On<List<RtmCellData>>("updateGridData", async cells =>
            {
                var updated = false;
                foreach (var cell in cells)
                {
                    if (_cellIdToMetric.TryGetValue(cell.CellId, out var metricId))
                    {
                        _cellValues[metricId] = cell.Value ?? string.Empty;
                        updated = true;
                    }
                }
                if (updated)
                    await InvokeAsync(async () =>
                    {
                        StateHasChanged();
                        await RenderChartAsync();
                    });
            });
```

#### 3d. Add `init()` call right after `StartAsync`

Find:
```csharp
            await _hub.StartAsync(_cts.Token);
            _connectionState = ConnectionState.Connected;

            Logger.LogInformation("Connected to QueueGrid simulator for RtsGridId {RtsGridId}", RtsGridId);
```

Replace with:
```csharp
            await _hub.StartAsync(_cts.Token);
            await _hub.InvokeAsync("init", RtsGridId.ToString(), _cts.Token);
            _connectionState = ConnectionState.Connected;

            Logger.LogInformation("AgentStateDistributionWidget: connected, init({GridId}) sent", RtsGridId);
```

#### 3e. Replace local record types at the bottom of the file

Find:
```csharp
    private record GridUpdate(int GridId, List<GridRowUpdate> Rows);
    private record GridRowUpdate(string RowId, int? UnionId, Dictionary<string, string> Metrics);
```

Replace with:
```csharp
    private record RtmCellData(int CellId, string Value, string Value2);
```

---

## Verification

```bash
# Build
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj 2>&1 | tail -5

# New files exist
ls -la src/CcDashboard.Application/Queries/Widgets/GetRtsGridCellMapQuery.cs
ls -la src/CcDashboard.Infrastructure/Services/RtmConfigurationApiHook.cs

# NoOp no longer registered
grep "NoOpConfigurationApiHook" src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs
# Expected: (empty)

# Old simulator references removed from widget
grep -n "QueueGridUpdate\|/hubs/queue-grid\|GridRowUpdate" \
    src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor
# Expected: (empty)

# Tail each modified file
tail -5 src/CcDashboard.Application/Interfaces/IRtsRepository.cs
tail -5 src/CcDashboard.Infrastructure/Persistence/Repositories/RtsRepository.cs
tail -5 src/CcDashboard.Infrastructure/Services/RtmConfigurationApiHook.cs
tail -5 src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor
```

Expected: build 0 errors, all files end with `}`.

---

## Commit

```bash
# MANDATORY
bash tools/pre-commit-check.sh
# Only after exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    src/CcDashboard.Application/Interfaces/IRtsRepository.cs \
    src/CcDashboard.Application/Queries/Widgets/GetRtsGridCellMapQuery.cs \
    src/CcDashboard.Infrastructure/Persistence/Repositories/RtsRepository.cs \
    src/CcDashboard.Infrastructure/Services/RtmConfigurationApiHook.cs \
    src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs \
    src/CcDashboard.Web/Components/Widgets/AgentStateDistributionWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m \
    "feat: real RTM Server integration — RtmConfigurationApiHook + AgentStateDistributionWidget RTM protocol"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
