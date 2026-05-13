namespace CcDashboard.Domain.Domain;

// RTS UserGrid entities — compatibility tables for external SignalR server

public class RtsUserGridGrid
{
    public int GridId { get; set; }
    public int? UnionId { get; set; }
    public int? StyleId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? RowsFilter { get; set; }
    public int? PageSize { get; set; }
    public int? ColumnsSetId { get; set; }
    public string? ThresholdScript { get; set; }
    public string? RowsFilterNew { get; set; }
    public string? NoRecordsText { get; set; }
    public bool? AllowPaging { get; set; }
    public bool? AllowScroll { get; set; }
    public string? TextDirection { get; set; }
}

public class RtsUserGridColumnsSet
{
    public int ColumnsSetId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Direction { get; set; }
}

public class RtsUserGridColumn
{
    public int ColumnId { get; set; }
    public int ColumnsSetId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? MetricId { get; set; }
    public int? StyleId { get; set; }
    public int ColumnsOrder { get; set; }
}
