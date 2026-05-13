using Npgsql;
using SignalRSimulator.Models;

namespace SignalRSimulator.Services;

public interface IDbMetricService
{
    Task<List<MetricDefinition>> GetAllMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetAgentMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetQueueMetricsAsync(CancellationToken ct = default);
}

public class DbMetricService : IDbMetricService
{
    private readonly string _connectionString;
    private readonly ILogger<DbMetricService> _logger;
    private List<MetricDefinition>? _cachedMetrics;
    private DateTime _cacheTime = DateTime.MinValue;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public DbMetricService(IConfiguration configuration, ILogger<DbMetricService> logger)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not found");
        _logger = logger;
    }

    public async Task<List<MetricDefinition>> GetAllMetricsAsync(CancellationToken ct = default)
    {
        if (_cachedMetrics != null && DateTime.UtcNow - _cacheTime < CacheDuration)
            return _cachedMetrics;

        var metrics = new List<MetricDefinition>();

        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        const string sql = @"
            SELECT ""MetricId"", ""Description"", ""DataType"", ""MetricFormat"", ""DefaultValue""
            FROM rtsgrid_metric
            ORDER BY ""MetricId""";

        await using var cmd = new NpgsqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync(ct);

        while (await reader.ReadAsync(ct))
        {
            metrics.Add(new MetricDefinition(
                MetricId: reader.GetString(0),
                Description: reader.IsDBNull(1) ? null : reader.GetString(1),
                DataType: reader.GetString(2),
                MetricFormat: reader.IsDBNull(3) ? null : reader.GetString(3),
                DefaultValue: reader.IsDBNull(4) ? null : reader.GetString(4)
            ));
        }

        _logger.LogInformation("Loaded {Count} metrics from database", metrics.Count);
        _cachedMetrics = metrics;
        _cacheTime = DateTime.UtcNow;

        return metrics;
    }

    public async Task<List<MetricDefinition>> GetAgentMetricsAsync(CancellationToken ct = default)
    {
        var all = await GetAllMetricsAsync(ct);
        return all.Where(m =>
            m.Description?.StartsWith("Agent", StringComparison.OrdinalIgnoreCase) == true &&
            !m.Description.StartsWith("Agent Group", StringComparison.OrdinalIgnoreCase)
        ).ToList();
    }

    public async Task<List<MetricDefinition>> GetQueueMetricsAsync(CancellationToken ct = default)
    {
        var all = await GetAllMetricsAsync(ct);
        return all.Where(m =>
            m.Description?.StartsWith("QM", StringComparison.OrdinalIgnoreCase) == true ||
            m.Description?.StartsWith("Agent Group", StringComparison.OrdinalIgnoreCase) == true
        ).ToList();
    }
}
