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

// RTS Grid additional entities - needed for RTM stored procedures

/// <summary>
/// RTSGrid_Statistic - statistic definitions for grid cells.
/// PK: StatisticId (IDENTITY).
/// </summary>
public class RtsGridStatistic
{
    public int StatisticId { get; set; }
    public string? Category { get; set; }
    public string? Definition { get; set; }
    public string? ParamType1 { get; set; }
    public string? ParamValue1 { get; set; }
    public string? ParamType2 { get; set; }
    public string? ParamValue2 { get; set; }
    public string? ParamType3 { get; set; }
    public string? ParamValue3 { get; set; }
    public string? ParamType4 { get; set; }
    public string? ParamValue4 { get; set; }
    public string? ParamType5 { get; set; }
    public string? ParamValue5 { get; set; }
    public string? ParamType6 { get; set; }
    public string? ParamValue6 { get; set; }
    public string? ParamType7 { get; set; }
    public string? ParamValue7 { get; set; }
    public string? ParamType8 { get; set; }
    public string? ParamValue8 { get; set; }
    public string? ParamType9 { get; set; }
    public string? ParamValue9 { get; set; }
    public string? ParamType10 { get; set; }
    public string? ParamValue10 { get; set; }
}

/// <summary>
/// RTSGrid_TemplateCell - cell template definitions referenced by RTSGrid_Column.CellTemplateId.
/// PK: CellTemplateId (IDENTITY). FK from RtsGridColumn.CellTemplateId.
/// </summary>
public class RtsGridTemplateCell
{
    public int CellTemplateId { get; set; }
    public int? StyleId { get; set; }
    public string? CellType { get; set; }
    public string? Value { get; set; }
    public string? Tooltip { get; set; }
    public string? OnClick { get; set; }
}

/// <summary>
/// RTSGrid_UserStatus - user status records written by RTSGrid_SetUserStatus SP.
/// PK: (UserId, StatusId). No DDL in SQL Server dump - reconstructed from SP params.
/// </summary>
public class RtsGridUserStatus
{
    public string UserId { get; set; } = string.Empty;
    public string StatusId { get; set; } = string.Empty;
    public string? StatusName { get; set; }
    public string? StatusGroup { get; set; }
    public int? TotalDuration { get; set; }
    public int? MaxDuraction { get; set; }  // intentional typo - matches SQL Server SP parameter name
    public int? TotalCount { get; set; }
    public string? SourceServer { get; set; }
    public string? OnDate { get; set; }
}
