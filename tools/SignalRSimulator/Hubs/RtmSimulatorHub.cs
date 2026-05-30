using Microsoft.AspNetCore.SignalR;
using SignalRSimulator.Generators;
using SignalRSimulator.Models;
using SignalRSimulator.Services;

namespace SignalRSimulator.Hubs;

/// <summary>
/// Simulates the real RTM SignalR hub at /signalr.
/// Client calls init(gridId) after connecting:
///   - Queue/DataSlot grids: gridId = "42" (numeric string)
///   - Agent grids:          gridId = "u5" (u + UnionId)
/// </summary>
public class RtmSimulatorHub : Hub
{
    // gridId → CTS for the generation loop
    private static readonly Dictionary<string, CancellationTokenSource> _activeGrids = new();
    // gridId → connectionIds
    private static readonly Dictionary<string, HashSet<string>> _gridConnections = new();
    private static readonly object _lock = new();

    private readonly IHubContext<RtmSimulatorHub> _hubContext;
    private readonly ILogger<RtmSimulatorHub> _logger;
    private readonly IDbMetricService _db;
    private readonly QueueDataGenerator _queueGen;
    private readonly AgentDataGenerator _agentGen;

    public RtmSimulatorHub(
        IHubContext<RtmSimulatorHub> hubContext,
        ILogger<RtmSimulatorHub> logger,
        IDbMetricService db,
        QueueDataGenerator queueGen,
        AgentDataGenerator agentGen)
    {
        _hubContext = hubContext;
        _logger = logger;
        _db = db;
        _queueGen = queueGen;
        _agentGen = agentGen;
    }

    // Matches RTM server signature — returns DateTime
    public DateTime init(string gridId)
    {
        _logger.LogInformation("init({GridId}) from {ConnectionId}", gridId, Context.ConnectionId);
        _ = SubscribeAsync(gridId);
        return DateTime.Now;
    }

    private async Task SubscribeAsync(string gridId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, gridId);
        lock (_lock)
        {
            if (!_gridConnections.ContainsKey(gridId))
                _gridConnections[gridId] = new HashSet<string>();
            _gridConnections[gridId].Add(Context.ConnectionId);
        }
        Context.Items["GridId"] = gridId;
        StartGeneration(gridId);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items.TryGetValue("GridId", out var g) && g is string gridId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, gridId);
            lock (_lock)
            {
                if (_gridConnections.TryGetValue(gridId, out var conns))
                {
                    conns.Remove(Context.ConnectionId);
                    if (conns.Count == 0)
                    {
                        _gridConnections.Remove(gridId);
                        StopGeneration(gridId);
                    }
                }
            }
        }
        await base.OnDisconnectedAsync(exception);
    }

    private void StartGeneration(string gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.ContainsKey(gridId)) return;
            var cts = new CancellationTokenSource();
            _activeGrids[gridId] = cts;
            if (gridId.StartsWith('u'))
                _ = GenerateAgentDataAsync(gridId, cts.Token);
            else
                _ = GenerateQueueDataAsync(gridId, cts.Token);
        }
    }

    private void StopGeneration(string gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.TryGetValue(gridId, out var cts))
            {
                cts.Cancel();
                _activeGrids.Remove(gridId);
            }
        }
    }

    // --- Queue / DataSlot generation ---
    private async Task GenerateQueueDataAsync(string gridId, CancellationToken ct)
    {
        if (!int.TryParse(gridId, out var numericGridId)) return;
        await Task.Delay(300, ct);

        List<RtmCellInfo>? cellInfos = null;

        while (!ct.IsCancellationRequested)
        {
            try
            {
                cellInfos ??= await _db.GetCellsForGridAsync(numericGridId, ct);

                if (cellInfos.Count == 0)
                {
                    _logger.LogWarning("No cells found for grid {GridId}", numericGridId);
                    await Task.Delay(10000, ct);
                    continue;
                }

                var cells = cellInfos.Select(ci => new RtmCellData
                {
                    CellId = ci.CellId,
                    Value  = GenerateFakeValue(ci.DataType, ci.DefaultValue),
                    Value2 = "",
                    Grid   = new RtmGridRef { GridId = numericGridId }
                }).ToList();

                await _hubContext.Clients.Group(gridId)
                    .SendAsync("updateGridData", cells, ct);

                _logger.LogDebug("Sent updateGridData to grid {GridId}: {Count} cells", gridId, cells.Count);
                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Queue generation error for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }

    // --- Agent grid generation ---
    private static readonly string[] AgentStatuses = ["AVAILABLE", "ONPHONE", "BREAK", "PAPERWORK", "TRAINING"];
    private static readonly string[] AgentNames = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Davis"];

    private async Task GenerateAgentDataAsync(string gridId, CancellationToken ct)
    {
        if (!int.TryParse(gridId[1..], out var unionId)) return;
        await Task.Delay(300, ct);

        // Stable agent list per unionId
        var agents = Enumerable.Range(1, 5).Select(i => $"agent{unionId}_{i:D2}").ToList();
        var rng = new Random(unionId);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var agentRows = agents.Select((userId, idx) =>
                {
                    var status = AgentStatuses[rng.Next(AgentStatuses.Length)];
                    var elapsed = TimeSpan.FromSeconds(rng.Next(0, 3600));
                    return new Dictionary<string, string>
                    {
                        ["USERID"]          = userId,
                        ["AgentLoginName"]  = AgentNames[idx % AgentNames.Length],
                        ["CurStatus"]       = status,
                        ["CurStatusTitle"]  = status,
                        ["CurStatusGroup"]  = status == "ONPHONE" ? "OnPhone" : "NotOnPhone",
                        // Timer value — '+' prefix means running elapsed timer
                        ["CurStatusDuration"] = $"+{elapsed:hh\\:mm\\:ss}",
                        ["CurLoginDuration"]  = $"+{(elapsed + TimeSpan.FromMinutes(30)):hh\\:mm\\:ss}",
                        ["Station"]         = $"STA{1000 + idx}",
                    };
                }).ToList();

                var result = new RtmUsersResult { Data = agentRows, Count = agentRows.Count };
                await _hubContext.Clients.Group(gridId)
                    .SendAsync("updateUserGrid", DateTime.Now, unionId, result, ct);

                _logger.LogDebug("Sent updateUserGrid to {GridId}: {Count} agents", gridId, agentRows.Count);
                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Agent generation error for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }

    private static readonly Random _valueRng = new();

    private static string GenerateFakeValue(string dataType, string? defaultValue)
    {
        return dataType switch
        {
            "Integer" => _valueRng.Next(0, 200).ToString(),
            "Time"    => TimeSpan.FromSeconds(_valueRng.Next(0, 3600)).ToString(@"mm\:ss"),
            "Percent" => $"{_valueRng.Next(0, 100)}%",
            _         => defaultValue ?? "0"
        };
    }
}
