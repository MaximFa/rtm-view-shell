using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IRtsRepository
{
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
}
