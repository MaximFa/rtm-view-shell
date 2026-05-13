using Microsoft.AspNetCore.SignalR;
using SignalRSimulator.Generators;
using SignalRSimulator.Models;

namespace SignalRSimulator.Hubs;

public class QueueGridHub : Hub
{
    private static readonly Dictionary<int, CancellationTokenSource> _activeGrids = new();
    private static readonly Dictionary<int, HashSet<string>> _gridConnections = new();
    private static readonly Dictionary<int, List<RowConfig>> _gridRowConfigs = new();
    private static readonly object _lock = new();
    private readonly IHubContext<QueueGridHub> _hubContext;
    private readonly ILogger<QueueGridHub> _logger;
    private readonly QueueDataGenerator _dataGenerator;

    public QueueGridHub(
        IHubContext<QueueGridHub> hubContext,
        ILogger<QueueGridHub> logger,
        QueueDataGenerator dataGenerator)
    {
        _hubContext = hubContext;
        _logger = logger;
        _dataGenerator = dataGenerator;
    }

    public override async Task OnConnectedAsync()
    {
        var httpContext = Context.GetHttpContext();
        var gridIdStr = httpContext?.Request.Query["gridId"].FirstOrDefault();

        _logger.LogInformation("QueueGrid client connecting. GridId from query: {GridId}", gridIdStr);

        if (string.IsNullOrEmpty(gridIdStr) || !int.TryParse(gridIdStr, out var gridId))
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

        _logger.LogInformation("QueueGrid client {ConnectionId} connected to grid {GridId}", Context.ConnectionId, gridId);

        StartDataGeneration(gridId);

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items.TryGetValue("GridId", out var gridIdObj) && gridIdObj is int gridId)
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

            _logger.LogInformation("QueueGrid client {ConnectionId} disconnected from grid {GridId}", Context.ConnectionId, gridId);
        }

        await base.OnDisconnectedAsync(exception);
    }

    public async Task UpdateRowConfig(int gridId, List<RowConfig> rowConfigs)
    {
        _logger.LogInformation("QueueGrid {GridId} updating row config with {Count} rows", gridId, rowConfigs.Count);

        lock (_lock)
        {
            _gridRowConfigs[gridId] = rowConfigs;
        }

        QueueDataGenerator.UpdateConfig(gridId, rowConfigs);

        var update = await _dataGenerator.GenerateAsync(gridId, rowConfigs);
        await _hubContext.Clients.Group($"grid:{gridId}").SendAsync("QueueGridUpdate", update);
    }

    public async Task SubscribeToGrid(int gridId)
    {
        _logger.LogInformation("QueueGrid client {ConnectionId} subscribing to grid {GridId}", Context.ConnectionId, gridId);

        if (Context.Items.TryGetValue("GridId", out var oldGridIdObj) && oldGridIdObj is int oldGridId && oldGridId != gridId)
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

    private void StartDataGeneration(int gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.ContainsKey(gridId))
                return;

            var cts = new CancellationTokenSource();
            _activeGrids[gridId] = cts;

            _logger.LogInformation("Starting queue data generation for grid {GridId}", gridId);

            _ = GenerateDataAsync(gridId, cts.Token);
        }
    }

    private void StopDataGeneration(int gridId)
    {
        lock (_lock)
        {
            if (_activeGrids.TryGetValue(gridId, out var cts))
            {
                _logger.LogInformation("Stopping queue data generation for grid {GridId}", gridId);
                cts.Cancel();
                _activeGrids.Remove(gridId);
            }
        }
    }

    private async Task GenerateDataAsync(int gridId, CancellationToken ct)
    {
        await Task.Delay(500, ct);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                List<RowConfig>? rowConfigs;
                lock (_lock)
                {
                    _gridRowConfigs.TryGetValue(gridId, out rowConfigs);
                }

                var update = await _dataGenerator.GenerateAsync(gridId, rowConfigs, ct);

                await _hubContext.Clients.Group($"grid:{gridId}")
                    .SendAsync("QueueGridUpdate", update, ct);

                _logger.LogDebug("Sent queue update to grid {GridId}: {RowCount} rows", gridId, update.Rows.Count);

                await Task.Delay(5000, ct);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating queue data for grid {GridId}", gridId);
                await Task.Delay(5000, ct);
            }
        }
    }
}
