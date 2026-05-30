namespace SignalRSimulator.Models;

/// <summary>
/// Metric definition from rtsgrid_metric table
/// </summary>
public record MetricDefinition(
    string MetricId,
    string? Description,
    string DataType,       // Integer, Time, Percent, String  (format hint)
    string? MetricFormat,  // N0, mm:ss, P0, P1
    string? DefaultValue,
    string ValueType = "String"   // String | Time | Number  (semantic type from RTSGrid_Metric)
);

/// <summary>
/// Universal grid row - all data comes from metrics
/// </summary>
public record GridRowData(
    string RowId,
    int? UnionId,                        // BusinessUnitId from RTSGrid_Row.UnionId
    Dictionary<string, string> Metrics   // MetricId -> formatted value
);

/// <summary>
/// Row info from RTSGrid_Row table
/// </summary>
public record GridRowInfo(int RowId, int? UnionId, int RowNumber);

/// <summary>
/// Grid update message - same for Agent Grid and Queue Grid
/// </summary>
public record GridUpdate(
    int GridId,
    DateTime Timestamp,
    List<GridRowData> Rows
);

/// <summary>
/// Cell info from database for RTM protocol
/// </summary>
public record RtmCellInfo(int CellId, string MetricId, string DataType, string? DefaultValue);

/// <summary>
/// RTM protocol cell data (PascalCase to match real RTM server)
/// </summary>
public class RtmCellData
{
    public int CellId { get; set; }
    public string Value { get; set; } = "";
    public string Value2 { get; set; } = "";
    public RtmGridRef Grid { get; set; } = new();
}

public class RtmGridRef { public int GridId { get; set; } }

/// <summary>
/// RTM protocol agent grid result
/// </summary>
public class RtmUsersResult
{
    public List<Dictionary<string, string>> Data { get; set; } = new();
    public int Count { get; set; }
}
