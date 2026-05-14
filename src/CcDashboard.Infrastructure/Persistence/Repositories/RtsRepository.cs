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

    // ========== Queue Grid (RTSGrid_*) - Raw SQL ==========

    public async Task<int> InsertQueueGridAsync(string title, CancellationToken ct = default)
    {
        var sql = @"INSERT INTO ""RTSGrid_Grid"" (""UnionId"", ""StyleId"", ""Title"", ""ThresholdScript"")
                    VALUES (-1, 1, @p0, NULL)
                    RETURNING ""GridId""";
        var result = await db.Database.SqlQueryRaw<int>(sql, title).ToListAsync(ct);
        return result.First();
    }

    public async Task UpdateQueueGridAsync(int gridId, string title, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Grid"" SET ""Title"" = @p0 WHERE ""GridId"" = @p1";
        await db.Database.ExecuteSqlRawAsync(sql, [title, gridId], ct);
    }

    public async Task DeleteQueueGridAsync(int gridId, CancellationToken ct = default)
    {
        // CASCADE will delete columns, rows, and cells
        var sql = @"DELETE FROM ""RTSGrid_Grid"" WHERE ""GridId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [gridId], ct);
    }

    public async Task<int> InsertQueueGridColumnAsync(int gridId, int columnNumber, CancellationToken ct = default)
    {
        var sql = @"INSERT INTO ""RTSGrid_Column"" (""GridId"", ""ColumnNumber"", ""CellTemplateId"")
                    VALUES (@p0, @p1, NULL)
                    RETURNING ""ColumnId""";
        var result = await db.Database.SqlQueryRaw<int>(sql, gridId, columnNumber).ToListAsync(ct);
        var columnId = result.First();

        // Update CellTemplateId to match ColumnId (self-reference)
        var updateSql = @"UPDATE ""RTSGrid_Column"" SET ""CellTemplateId"" = @p0 WHERE ""ColumnId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(updateSql, [columnId], ct);

        return columnId;
    }

    public async Task UpdateQueueGridColumnAsync(int columnId, int columnNumber, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Column"" SET ""ColumnNumber"" = @p0 WHERE ""ColumnId"" = @p1";
        await db.Database.ExecuteSqlRawAsync(sql, [columnNumber, columnId], ct);
    }

    public async Task DeleteQueueGridColumnAsync(int columnId, CancellationToken ct = default)
    {
        // CASCADE will delete cells referencing this column
        var sql = @"DELETE FROM ""RTSGrid_Column"" WHERE ""ColumnId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [columnId], ct);
    }

    public async Task<List<int>> GetQueueGridColumnIdsAsync(int gridId, CancellationToken ct = default)
    {
        var sql = @"SELECT ""ColumnId"" FROM ""RTSGrid_Column"" WHERE ""GridId"" = @p0";
        return await db.Database.SqlQueryRaw<int>(sql, gridId).ToListAsync(ct);
    }

    public async Task<int> InsertQueueGridRowAsync(int gridId, int rowNumber, int? unionId, CancellationToken ct = default)
    {
        var sql = @"INSERT INTO ""RTSGrid_Row"" (""GridId"", ""RowNumber"", ""UnionId"", ""StyleId"", ""ThresholdScript"", ""OldRowId"")
                    VALUES (@p0, @p1, @p2, 1, NULL, NULL)
                    RETURNING ""RowId""";
        var result = await db.Database.SqlQueryRaw<int>(sql, gridId, rowNumber, unionId ?? (object)DBNull.Value).ToListAsync(ct);
        return result.First();
    }

    public async Task UpdateQueueGridRowAsync(int rowId, int rowNumber, int? unionId, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Row"" SET ""RowNumber"" = @p0, ""UnionId"" = @p1 WHERE ""RowId"" = @p2";
        await db.Database.ExecuteSqlRawAsync(sql, [rowNumber, unionId ?? (object)DBNull.Value, rowId], ct);
    }

    public async Task DeleteQueueGridRowAsync(int rowId, CancellationToken ct = default)
    {
        // CASCADE will delete cells
        var sql = @"DELETE FROM ""RTSGrid_Row"" WHERE ""RowId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [rowId], ct);
    }

    public async Task<List<int>> GetQueueGridRowIdsAsync(int gridId, CancellationToken ct = default)
    {
        var sql = @"SELECT ""RowId"" FROM ""RTSGrid_Row"" WHERE ""GridId"" = @p0";
        return await db.Database.SqlQueryRaw<int>(sql, gridId).ToListAsync(ct);
    }

    public async Task<int> InsertQueueGridCellAsync(int rowId, int columnId, int colNumber, string cellType, string? value, CancellationToken ct = default)
    {
        var sql = @"INSERT INTO ""RTSGrid_Cell"" (""RowId"", ""ColumnId"", ""ColNumber"", ""UnionId"", ""StyleId"", ""CellType"", ""Value"", ""Tooltip"", ""OnClick"", ""ThresholdSetId"", ""NewRowId"", ""OldRowId"")
                    VALUES (@p0, @p1, @p2, -1, 3, @p3, @p4, NULL, NULL, 0, NULL, NULL)
                    RETURNING ""CellId""";
        var result = await db.Database.SqlQueryRaw<int>(sql, rowId, columnId, colNumber, cellType, value ?? (object)DBNull.Value).ToListAsync(ct);
        return result.First();
    }

    public async Task UpdateQueueGridCellAsync(int cellId, string cellType, string? value, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Cell"" SET ""CellType"" = @p0, ""Value"" = @p1 WHERE ""CellId"" = @p2";
        await db.Database.ExecuteSqlRawAsync(sql, [cellType, value ?? (object)DBNull.Value, cellId], ct);
    }

    public async Task DeleteQueueGridCellAsync(int cellId, CancellationToken ct = default)
    {
        var sql = @"DELETE FROM ""RTSGrid_Cell"" WHERE ""CellId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [cellId], ct);
    }

    public async Task DeleteQueueGridCellsByRowIdAsync(int rowId, CancellationToken ct = default)
    {
        var sql = @"DELETE FROM ""RTSGrid_Cell"" WHERE ""RowId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [rowId], ct);
    }

    public async Task DeleteQueueGridCellsByColumnIdAsync(int columnId, CancellationToken ct = default)
    {
        var sql = @"DELETE FROM ""RTSGrid_Cell"" WHERE ""ColumnId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [columnId], ct);
    }
}
