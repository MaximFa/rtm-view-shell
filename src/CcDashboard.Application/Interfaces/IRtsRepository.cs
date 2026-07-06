using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IRtsRepository
{
    // ========== Agent Grid (RTSUserGrid_*) ==========

    // ColumnsSet operations
    Task<int> InsertColumnsSetAsync(RtsUserGridColumnsSet columnsSet, CancellationToken ct = default);

    // Column operations
    Task<List<int>> GetColumnIdsForColumnsSetAsync(int columnsSetId, CancellationToken ct = default);
    Task<int> InsertColumnAsync(RtsUserGridColumn column, CancellationToken ct = default);
    Task UpdateColumnAsync(int columnId, string title, string metricId, int columnsOrder, CancellationToken ct = default);
    Task DeleteColumnAsync(int columnId, CancellationToken ct = default);

    // Grid operations
    Task<int> InsertGridAsync(RtsUserGridGrid grid, CancellationToken ct = default);
    Task UpdateGridAsync(int gridId, int? businessUnitId, string title, string? rowsFilter, CancellationToken ct = default);

    // Delete operations
    Task DeleteGridAsync(int gridId, CancellationToken ct = default);
    Task DeleteColumnsSetAsync(int columnsSetId, CancellationToken ct = default);
    Task<int?> GetColumnsSetIdByGridIdAsync(int gridId, CancellationToken ct = default);

    // ========== Queue Grid (RTSGrid_*) ==========

    // Grid operations
    Task<int> InsertQueueGridAsync(string title, CancellationToken ct = default);
    Task UpdateQueueGridAsync(int gridId, string title, CancellationToken ct = default);
    Task DeleteQueueGridAsync(int gridId, CancellationToken ct = default);
    Task<bool> QueueGridExistsAsync(int gridId, CancellationToken ct = default);

    // Column operations
    Task<int> InsertQueueGridColumnAsync(int gridId, int columnNumber, CancellationToken ct = default);
    Task UpdateQueueGridColumnAsync(int columnId, int columnNumber, CancellationToken ct = default);
    Task DeleteQueueGridColumnAsync(int columnId, CancellationToken ct = default);
    Task<List<int>> GetQueueGridColumnIdsAsync(int gridId, CancellationToken ct = default);

    // Row operations
    Task<int> InsertQueueGridRowAsync(int gridId, int rowNumber, int? unionId, CancellationToken ct = default);
    Task UpdateQueueGridRowAsync(int rowId, int rowNumber, int? unionId, CancellationToken ct = default);
    Task DeleteQueueGridRowAsync(int rowId, CancellationToken ct = default);
    Task<List<int>> GetQueueGridRowIdsAsync(int gridId, CancellationToken ct = default);

    // Cell operations
    Task<int> InsertQueueGridCellAsync(int rowId, int columnId, int colNumber, string cellType, string? value, CancellationToken ct = default);
    Task UpdateQueueGridCellAsync(int cellId, string cellType, string? value, CancellationToken ct = default);
    Task DeleteQueueGridCellAsync(int cellId, CancellationToken ct = default);
    Task DeleteQueueGridCellsByRowIdAsync(int rowId, CancellationToken ct = default);
    Task DeleteQueueGridCellsByColumnIdAsync(int columnId, CancellationToken ct = default);

    /// <summary>CellId -> MetricId map for all cells in a queue grid (RTSGrid_Cell.Value).</summary>
    Task<Dictionary<int, string>> GetCellMapForGridAsync(int gridId, CancellationToken ct = default);
}
