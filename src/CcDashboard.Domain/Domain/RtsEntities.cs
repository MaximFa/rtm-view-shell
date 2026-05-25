namespace CcDashboard.Domain.Domain;

// RTS UserGrid entities — compatibility tables for external SignalR server (Agent Grid)

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

// RTS Grid entities — compatibility tables for external SignalR server (Queue Grid)

public class RtsGridGrid
{
    public int GridId { get; set; }
    public int? UnionId { get; set; }
    public int? StyleId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? ThresholdScript { get; set; }
}

public class RtsGridColumn
{
    public int ColumnId { get; set; }
    public int GridId { get; set; }
    public int ColumnNumber { get; set; }
    public int? CellTemplateId { get; set; }
}

public class RtsGridRow
{
    public int RowId { get; set; }
    public int GridId { get; set; }
    public int RowNumber { get; set; }
    public int? UnionId { get; set; }
    public int? StyleId { get; set; }
    public string? ThresholdScript { get; set; }
    public int? OldRowId { get; set; }
}

public class RtsGridCell
{
    public int CellId { get; set; }
    public int RowId { get; set; }
    public int ColumnId { get; set; }
    public int? ColNumber { get; set; }
    public int? UnionId { get; set; }
    public int? StyleId { get; set; }
    public string? CellType { get; set; }
    public string? Value { get; set; }
    public string? Tooltip { get; set; }
    public string? OnClick { get; set; }
    public int? ThresholdSetId { get; set; }
    public int? NewRowId { get; set; }
    public int? OldRowId { get; set; }
}
