namespace CcDashboard.Contracts.DTOs.Widgets;

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

/// <summary>
/// Row configuration sent from widget to simulator
/// </summary>
public record RowConfig(
    string RowId,
    int RowIndex,
    string? DisplayName
);
