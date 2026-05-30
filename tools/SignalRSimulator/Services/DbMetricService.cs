using Npgsql;
using SignalRSimulator.Models;

namespace SignalRSimulator.Services;

public interface IDbMetricService
{
    Task<List<MetricDefinition>> GetAllMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetAgentMetricsAsync(CancellationToken ct = default);
    Task<List<MetricDefinition>> GetQueueMetricsAsync(CancellationToken ct = default);
    Task<List<GridRowInfo>> GetRowsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<MetricDefinition>> GetMetricsForGridAsync(int gridId, CancellationToken ct = default);
    Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default);
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
            FROM ""RTSGrid_Metric""
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

    public async Task<List<GridRowInfo>> GetRowsForGridAsync(int gridId, CancellationToken ct = default)
    {
        var rows = new List<GridRowInfo>();
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        const string sql = @"
            SELECT ""RowId"", ""UnionId"", ""RowNumber""
            FROM ""RTSGrid_Row""
            WHERE ""GridId"" = @gridId AND ""RowNumber"" > 1
            ORDER BY ""RowNumber""";
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("gridId", gridId);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            rows.Add(new GridRowInfo(
                RowId: reader.GetInt32(0),
                UnionId: reader.IsDBNull(1) ? null : reader.GetInt32(1),
                RowNumber: reader.GetInt32(2)
            ));
        }
        return rows;
    }

    public async Task<List<MetricDefinition>> GetMetricsForGridAsync(int gridId, CancellationToken ct = default)
    {
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        const string sql = @"
            SELECT DISTINCT c.""Value""
            FROM ""RTSGrid_Cell"" c
            JOIN ""RTSGrid_Row"" r ON c.""RowId"" = r.""RowId""
            WHERE r.""GridId"" = @gridId AND c.""CellType"" = 'Data' AND c.""Value"" IS NOT NULL";
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("gridId", gridId);
        var metricIds = new List<string>();
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            metricIds.Add(reader.GetString(0));

        if (metricIds.Count == 0) return new List<MetricDefinition>();

        var all = await GetAllMetricsAsync(ct);
        return all.Where(m => metricIds.Contains(m.MetricId)).ToList();
    }
    public async Task<List<RtmCellInfo>> GetCellsForGridAsync(int gridId, CancellationToken ct = default)
    {
        var cells = new List<RtmCellInfo>();
        await using var conn = new NpgsqlConnection(_connectionString);
        await conn.OpenAsync(ct);
        const string sql = @"
            SELECT c.""CellId"", c.""Value"" AS MetricId, m.""DataType"", m.""DefaultValue""
            FROM ""RTSGrid_Cell"" c
            JOIN ""RTSGrid_Row"" r ON c.""RowId"" = r.""RowId""
            LEFT JOIN ""RTSGrid_Metric"" m ON c.""Value"" = m.""MetricId""
            WHERE r.""GridId"" = @gridId AND c.""CellType"" = 'Data' AND r.""RowNumber"" > 1
            ORDER BY r.""RowNumber"", c.""CellId""";
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("gridId", gridId);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            cells.Add(new RtmCellInfo(
                CellId: reader.GetInt32(0),
                MetricId: reader.IsDBNull(1) ? "" : reader.GetString(1),
                DataType: reader.IsDBNull(2) ? "String" : reader.GetString(2),
                DefaultValue: reader.IsDBNull(3) ? null : reader.GetString(3)
            ));
        }
        return cells;
    }
}
