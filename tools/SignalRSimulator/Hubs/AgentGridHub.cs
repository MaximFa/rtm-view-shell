using Microsoft.AspNetCore.SignalR;
using SignalRSimulator.Generators;
using SignalRSimulator.Models;

namespace SignalRSimulator.Hubs;

public class AgentGridHub : Hub
{
    private static readonly Dictionary<Guid, CancellationTokenSource> _activeGrids = new();
    private static readonly Dictionary<Guid, HashSet<string>> _gridConnections = new();
    private static readonly object _lock = new();
    private readonly IHubContext<AgentGridHub> _hubContext;
    private readonly ILogger<AgentGridHub> _logger;

    public AgentGridHub(IHubContext<AgentGridHub> hubContext, ILogger<AgentGridHub> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var httpContext = Context.GetHttpContext();
        var gridIdStr = httpContext?.Request.Query["gridId"].FirstOrDefault();

        _logger.LogInformation("Client connecting. GridId from query: {GridId}", gridIdStr);

        if (string.IsNullOrEmpty(gridIdStr) || !Guid.TryParse(gridIdStr, out var gridId))
        {
            _logger.LogWarning("Connection rejected: invalid or missing gridId");
            Context.Abort();
            return;
        }

        Context.Items["GridId"] = gridId;
        await Groups.AddToGroupAsync(Context.ConnectionId, $"grid:{gridId}");

        lock (_lock)
        {
            if (!_gridConnections.ContainsKey(gridId))
                _gridConnections[gridId] = new HashSet<string>();
            _gridConnections[gridId].Add(Context.ConnectionId);
        }

        _logger.LogInformation("Client {ConnectionId} connected to grid {GridId}", Context.ConnectionId, gridId);

        StartDataGeneration(gridId);

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items.TryGetValue("GridId", out var gridIdObj) && gridIdObj is Guid gridId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"grid:{gridId}");

            lock (_lock)
            {
                if (_gridConnections.TryGetValue(gridId, out var connections))
                {
                    connections.Remove(Context.ConnectionId);
                    if (connections.Count == 0)
                    {
                        _gridConnections.Remove(gridId);
                        StopDataGeneration(gridId);
                    }
                }
            }

            _logger.LogInformation("Client {ConnectionId} disconnected from grid {GridId}", Context.ConnectionId, gridId);
        }

        await base.OnDisconnectedAsync(exception);
    }

    public async Task SubscribeToGrid(Guid gridId)
    {
        _logger.LogInformation("Client {ConnectionId} subscribing to grid {GridId}", Context.ConnectionId, gridId);

        if (Context.Items.TryGetValue("GridId", out var oldGridIdObj) && oldGridIdObj is Guid oldGridId && oldGridId != gridId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"grid:{oldGridId}");
        }

        Context.Items["GridId"] = gridId;
        await Groups.AddToGroupAsync(Context.ConnectionId, $"grid:{gridId}");

        lock (_lock)
        {
            if (!_gridConnections.ContainsKey(gridId))
                _gridConnections[gridId] = new HashSet<string>();
            _gridConnections[gridId].Add(Context.ConnectionId);
        }

        StartDataGeneration(gridId);
    }

    public async Task UnsubscribeFromGrid(Guid gridId)
    {
        _logger.LogInformation("Client {ConnectionId} unsubscribing from grid {GridId}", Context.ConnectionId, gridId);

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"grid:{gridId}");

        lock (_lock)
        {
            if (_gridConnections.TryGetValue(gridId, out var connections))
            {
                connections.Remove(Context.ConnectionId);
                if (connections.Count == 0)
                {
                    _gridConnections.Remove(gridId);
                    StopDataGeneration(gridId);
                }
            }
        }
    }

    private void StartDataGeneration(Guid gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.ContainsKey(gridId))
                return;

            var cts = new CancellationTokenSource();
            _activeGrids[gridId] = cts;

            _logger.LogInformation("Starting data generation for grid {GridId}", gridId);

            _ = GenerateDataAsync(gridId, cts.Token);
        }
    }

    private void StopDataGeneration(Guid gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.TryGetValue(gridId, out var cts))
            {
                _logger.LogInformation("Stopping data generation for grid {GridId}", gridId);
                cts.Cancel();
                _activeGrids.Remove(gridId);
            }
        }
    }

    private async Task GenerateDataAsync(Guid gridId, CancellationToken ct)
    {
        await Task.Delay(500, ct);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var update = AgentDataGenerator.Generate(gridId);

                await _hubContext.Clients.Group($"grid:{gridId}")
                    .SendAsync("AgentGridUpdate", update, ct);

                _logger.LogDebug("Sent update to grid {GridId}: {AgentCount} agents", gridId, update.Agents.Count);

                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating data for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }
}
