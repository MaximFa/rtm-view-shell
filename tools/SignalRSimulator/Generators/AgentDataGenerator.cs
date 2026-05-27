using SignalRSimulator.Models;
using SignalRSimulator.Services;

namespace SignalRSimulator.Generators;

public class AgentDataGenerator
{
    private readonly IDbMetricService _metricService;
    private readonly ILogger<AgentDataGenerator> _logger;

    public AgentDataGenerator(IDbMetricService metricService, ILogger<AgentDataGenerator> logger)
    {
        _metricService = metricService;
        _logger = logger;
    }

    public async Task<GridUpdate> GenerateAsync(int gridId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var rows = new List<GridRowData>();

        var metrics = await _metricService.GetAgentMetricsAsync(ct);

        if (metrics.Count == 0)
        {
            _logger.LogWarning("No Agent metrics found in database");
            return new GridUpdate(gridId, now, rows);
        }

        _logger.LogDebug("Generating data for {Count} Agent metrics", metrics.Count);

        for (int i = 1; i <= 30; i++)
        {
            var agentId = $"A{i:D3}";
            var metricValues = MetricDataGenerator.GenerateMetrics(metrics);

            rows.Add(new GridRowData(
                RowId: agentId,
                UnionId: null,
                Metrics: metricValues
            ));
        }

        return new GridUpdate(gridId, now, rows);
    }
}
