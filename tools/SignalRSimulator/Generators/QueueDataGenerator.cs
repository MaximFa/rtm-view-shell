using SignalRSimulator.Models;
using SignalRSimulator.Services;

namespace SignalRSimulator.Generators;

public class QueueDataGenerator
{
    private readonly IDbMetricService _metricService;
    private readonly ILogger<QueueDataGenerator> _logger;
    private static readonly Random _rng = new();
    private static readonly Dictionary<int, List<RowConfig>> _gridConfigs = new();

    public QueueDataGenerator(IDbMetricService metricService, ILogger<QueueDataGenerator> logger)
    {
        _metricService = metricService;
        _logger = logger;
    }

    public async Task<GridUpdate> GenerateAsync(int gridId, List<RowConfig>? rowConfigs = null, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var rows = new List<GridRowData>();

        var metrics = await _metricService.GetQueueMetricsAsync(ct);

        if (metrics.Count == 0)
        {
            _logger.LogWarning("No Queue metrics found in database");
            return new GridUpdate(gridId, now, rows);
        }

        _logger.LogDebug("Generating data for {Count} Queue metrics", metrics.Count);

        var configs = rowConfigs ?? _gridConfigs.GetValueOrDefault(gridId);

        if (configs is { Count: > 0 })
        {
            foreach (var config in configs)
            {
                var metricValues = MetricDataGenerator.GenerateMetrics(metrics);
                rows.Add(new GridRowData(
                    RowId: config.RowId,
                    Metrics: metricValues
                ));
            }
        }
        else
        {
            var count = _rng.Next(3, 8);
            for (int i = 0; i < count; i++)
            {
                var metricValues = MetricDataGenerator.GenerateMetrics(metrics);
                rows.Add(new GridRowData(
                    RowId: $"Q{gridId:D2}{i:D2}",
                    Metrics: metricValues
                ));
            }
        }

        return new GridUpdate(gridId, now, rows);
    }

    public static void UpdateConfig(int gridId, List<RowConfig> configs)
    {
        _gridConfigs[gridId] = configs;
    }
}

public class RowConfig
{
    public string RowId { get; set; } = "";
    public int RowIndex { get; set; }
    public string? DisplayName { get; set; }
}
