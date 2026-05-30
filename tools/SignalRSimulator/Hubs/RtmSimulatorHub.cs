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
    private static readonly string[] AgentStates = ["AVAILABLE", "ONPHONE", "BREAK", "PAPERWORK", "TRAINING"];
    private static readonly string[] AgentStateGroups = ["Available", "OnPhone", "Break", "Paperwork", "Training"];
    private static readonly string[] TelStates = ["Idle", "OnCall", "Ringing", "Wrap"];
    private static readonly string[] InteractionTypes = ["Voice", "Chat", "Email", ""];
    private static readonly string[] Campaigns = ["Sales Q1", "Support", "Retention", ""];
    private static readonly string[] AgentNames = ["Alice Smith", "Bob Jones", "Carol White", "Dave Brown", "Eve Davis",
        "Frank Miller", "Grace Lee", "Henry Wilson", "Ivy Chen", "Jack Taylor"];

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
                            row[m.MetricId] = MetricDataGenerator.GenerateValue(m);
                    }

                    return row;
                }).ToList();

                var result = new RtmUsersResult { Data = agentRows, Count = agentRows.Count };
                await _hubContext.Clients.Group(gridId)
                    .SendAsync("updateUserGrid", DateTime.Now, unionId, result, ct);

                _logger.LogDebug("Sent updateUserGrid to {GridId}: {Count} agents with {MetricCount} metrics each",
                    gridId, agentRows.Count, agentRows.FirstOrDefault()?.Count ?? 0);
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
