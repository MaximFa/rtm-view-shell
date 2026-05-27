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

        // Get actual rows with UnionId from DB
        var dbRows = await _metricService.GetRowsForGridAsync(gridId, ct);

        // Get metrics actually used by this grid
        var metrics = await _metricService.GetMetricsForGridAsync(gridId, ct);

        // Fall back to queue metrics if grid-specific lookup returns nothing
        if (metrics.Count == 0)
            metrics = await _metricService.GetQueueMetricsAsync(ct);

        if (metrics.Count == 0)
        {
            _logger.LogWarning("No metrics found for grid {GridId}", gridId);
            return new GridUpdate(gridId, now, rows);
        }

        _logger.LogDebug("Generating data for {Count} metrics, {RowCount} DB rows", metrics.Count, dbRows.Count);

        if (dbRows.Count > 0)
        {
            foreach (var dbRow in dbRows)
            {
                var metricValues = MetricDataGenerator.GenerateMetrics(metrics);
                rows.Add(new GridRowData(
                    RowId: dbRow.RowId.ToString(),
                    UnionId: dbRow.UnionId,
                    Metrics: metricValues
                ));
            }
        }
        else
        {
            // No DB rows — fall back to random generation (no UnionId)
            var configs = rowConfigs ?? _gridConfigs.GetValueOrDefault(gridId);

            if (configs is { Count: > 0 })
            {
                foreach (var config in configs)
                {
                    var metricValues = MetricDataGenerator.GenerateMetrics(metrics);
                    rows.Add(new GridRowData(
                        RowId: config.RowId,
                        UnionId: null,
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
                        UnionId: null,
                        Metrics: metricValues
                    ));
                }
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
