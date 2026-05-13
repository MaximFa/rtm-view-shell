using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class RtsRepository(AppDbContext db) : IRtsRepository
{
    public async Task<int> InsertColumnsSetAsync(RtsUserGridColumnsSet columnsSet, CancellationToken ct = default)
    {
        db.RtsUserGridColumnsSets.Add(columnsSet);
        await db.SaveChangesAsync(ct);
        return columnsSet.ColumnsSetId;
    }

    public async Task<List<int>> GetColumnIdsForColumnsSetAsync(int columnsSetId, CancellationToken ct = default)
    {
        return await db.RtsUserGridColumns
            .Where(c => c.ColumnsSetId == columnsSetId)
            .Select(c => c.ColumnId)
            .ToListAsync(ct);
    }

    public async Task<int> InsertColumnAsync(RtsUserGridColumn column, CancellationToken ct = default)
    {
        db.RtsUserGridColumns.Add(column);
        await db.SaveChangesAsync(ct);
        return column.ColumnId;
    }

    public async Task UpdateColumnAsync(int columnId, string title, string metricId, int columnsOrder, CancellationToken ct = default)
    {
        var column = await db.RtsUserGridColumns.FindAsync([columnId], ct);
        if (column is not null)
        {
            column.Title = title;
            column.MetricId = metricId;
            column.ColumnsOrder = columnsOrder;
            await db.SaveChangesAsync(ct);
        }
    }

    public async Task DeleteColumnAsync(int columnId, CancellationToken ct = default)
    {
        var column = await db.RtsUserGridColumns.FindAsync([columnId], ct);
        if (column is not null)
        {
            db.RtsUserGridColumns.Remove(column);
            await db.SaveChangesAsync(ct);
        }
    }

    public async Task<int> InsertGridAsync(RtsUserGridGrid grid, CancellationToken ct = default)
    {
        db.RtsUserGridGrids.Add(grid);
        await db.SaveChangesAsync(ct);
        return grid.GridId;
    }

    public async Task UpdateGridAsync(int gridId, int? businessUnitId, string title, string? rowsFilter, CancellationToken ct = default)
    {
        var grid = await db.RtsUserGridGrids.FindAsync([gridId], ct);
        if (grid is not null)
        {
            grid.UnionId = businessUnitId;
            grid.Title = title;
            grid.RowsFilter = rowsFilter;
            grid.RowsFilterNew = rowsFilter;
            await db.SaveChangesAsync(ct);
        }
    }

    public async Task<int?> GetColumnsSetIdByGridIdAsync(int gridId, CancellationToken ct = default)
    {
        var grid = await db.RtsUserGridGrids.FindAsync([gridId], ct);
        return grid?.ColumnsSetId;
    }

    public async Task DeleteGridAsync(int gridId, CancellationToken ct = default)
    {
        var grid = await db.RtsUserGridGrids.FindAsync([gridId], ct);
        if (grid is not null)
        {
            db.RtsUserGridGrids.Remove(grid);
            await db.SaveChangesAsync(ct);
        }
    }

    public async Task DeleteColumnsSetAsync(int columnsSetId, CancellationToken ct = default)
    {
        // Delete all columns first
        var columns = await db.RtsUserGridColumns
            .Where(c => c.ColumnsSetId == columnsSetId)
            .ToListAsync(ct);
        db.RtsUserGridColumns.RemoveRange(columns);

        // Delete the columns set
        var columnsSet = await db.RtsUserGridColumnsSets.FindAsync([columnsSetId], ct);
        if (columnsSet is not null)
        {
            db.RtsUserGridColumnsSets.Remove(columnsSet);
        }

        await db.SaveChangesAsync(ct);
    }
}
