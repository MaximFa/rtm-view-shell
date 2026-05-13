namespace SignalRSimulator.Models;

/// <summary>
/// Metric definition from rtsgrid_metric table
/// </summary>
public record MetricDefinition(
    string MetricId,
    string? Description,
    string DataType,       // Integer, Time, Percent, String
    string? MetricFormat,  // N0, mm:ss, P0, P1
    string? DefaultValue
);

/// <summary>
/// Universal grid row - all data comes from metrics
/// </summary>
public record GridRowData(
    string RowId,
    Dictionary<string, string> Metrics  // MetricId -> formatted value
);

/// <summary>
/// Grid update message - same for Agent Grid and Queue Grid
/// </summary>
public record GridUpdate(
    int GridId,
    DateTime Timestamp,
    List<GridRowData> Rows
);
