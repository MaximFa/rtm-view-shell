using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class RtsRepository(BackendEmulationDbContext db) : IRtsRepository
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

    // ========== Queue Grid (RTSGrid_*) - Raw ADO.NET for RETURNING ==========

    public async Task<int> InsertQueueGridAsync(string title, CancellationToken ct = default)
    {
        var conn = db.Database.GetDbConnection();
        await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO ""RTSGrid_Grid"" (""UnionId"", ""StyleId"", ""Title"", ""ThresholdScript"")
                                VALUES (-1, 1, @title, NULL)
                                RETURNING ""GridId""";
            cmd.Parameters.Add(new NpgsqlParameter("@title", title));
            var result = await cmd.ExecuteScalarAsync(ct);
            return Convert.ToInt32(result);
        }
        finally
        {
            await conn.CloseAsync();
        }
    }

    public async Task UpdateQueueGridAsync(int gridId, string title, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Grid"" SET ""Title"" = @p0 WHERE ""GridId"" = @p1";
        await db.Database.ExecuteSqlRawAsync(sql, [title, gridId], ct);
    }

    public async Task DeleteQueueGridAsync(int gridId, CancellationToken ct = default)
    {
        // Get all row IDs for this grid to delete their cells
        var rowIds = await GetQueueGridRowIdsAsync(gridId, ct);
        foreach (var rowId in rowIds)
        {
            await DeleteQueueGridCellsByRowIdAsync(rowId, ct);
        }

        // Get all column IDs for this grid to delete them
        var columnIds = await GetQueueGridColumnIdsAsync(gridId, ct);
        foreach (var columnId in columnIds)
        {
            await DeleteQueueGridColumnAsync(columnId, ct);
        }

        // Delete all rows
        foreach (var rowId in rowIds)
        {
            await DeleteQueueGridRowAsync(rowId, ct);
        }

        // Finally delete the grid itself
        var sql = @"DELETE FROM ""RTSGrid_Grid"" WHERE ""GridId"" = @p0";
        await db.Database.ExecuteSqlRawAsync(sql, [gridId], ct);
    }

    public async Task<int> InsertQueueGridColumnAsync(int gridId, int columnNumber, CancellationToken ct = default)
    {
        var conn = db.Database.GetDbConnection();
        await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO ""RTSGrid_Column"" (""GridId"", ""ColumnNumber"", ""CellTemplateId"")
                                VALUES (@gridId, @columnNumber, NULL)
                                RETURNING ""ColumnId""";
            cmd.Parameters.Add(new NpgsqlParameter("@gridId", gridId));
            cmd.Parameters.Add(new NpgsqlParameter("@columnNumber", columnNumber));
            var result = await cmd.ExecuteScalarAsync(ct);
            var columnId = Convert.ToInt32(result);

            // Update CellTemplateId to match ColumnId (self-reference)
            await using var updateCmd = conn.CreateCommand();
            updateCmd.CommandText = @"UPDATE ""RTSGrid_Column"" SET ""CellTemplateId"" = @colId WHERE ""ColumnId"" = @colId";
            updateCmd.Parameters.Add(new NpgsqlParameter("@colId", columnId));
            await updateCmd.ExecuteNonQueryAsync(ct);

            return columnId;
        }
        finally
        {
            await conn.CloseAsync();
        }
    }

    public async Task UpdateQueueGridColumnAsync(int columnId, int columnNumber, CancellationToken ct = default)
    {
        var sql = @"UPDATE ""RTSGrid_Column"" SET ""ColumnNumber"" = @p0 WHERE ""ColumnId"" = @p1";
        await db.Database.ExecuteSqlRawAsync(sql, [columnNumber, columnId], ct);
    }

    public async Task DeleteQueueGridColumnAsync(int columnId, CancellationToken ct = default)
    {
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
        var conn = db.Database.GetDbConnection();
        await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO ""RTSGrid_Row"" (""GridId"", ""RowNumber"", ""UnionId"", ""StyleId"", ""ThresholdScript"", ""OldRowId"")
                                VALUES (@gridId, @rowNumber, @unionId, 1, NULL, NULL)
                                RETURNING ""RowId""";
            cmd.Parameters.Add(new NpgsqlParameter("@gridId", gridId));
            cmd.Parameters.Add(new NpgsqlParameter("@rowNumber", rowNumber));
            cmd.Parameters.Add(new NpgsqlParameter("@unionId", NpgsqlTypes.NpgsqlDbType.Integer) { Value = unionId.HasValue ? unionId.Value : DBNull.Value });
            var result = await cmd.ExecuteScalarAsync(ct);
            return Convert.ToInt32(result);
        }
        finally
        {
            await conn.CloseAsync();
        }
    }

    public async Task UpdateQueueGridRowAsync(int rowId, int rowNumber, int? unionId, CancellationToken ct = default)
    {
        await db.Database.ExecuteSqlInterpolatedAsync(
            $@"UPDATE ""RTSGrid_Row"" SET ""RowNumber"" = {rowNumber}, ""UnionId"" = {unionId} WHERE ""RowId"" = {rowId}", ct);
    }

    public async Task DeleteQueueGridRowAsync(int rowId, CancellationToken ct = default)
    {
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
        var conn = db.Database.GetDbConnection();
        await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO ""RTSGrid_Cell"" (""RowId"", ""ColumnId"", ""ColNumber"", ""UnionId"", ""StyleId"", ""CellType"", ""Value"", ""Tooltip"", ""OnClick"", ""ThresholdSetId"", ""NewRowId"", ""OldRowId"")
                                VALUES (@rowId, @columnId, @colNumber, -1, 3, @cellType, @value, NULL, NULL, 0, NULL, NULL)
                                RETURNING ""CellId""";
            cmd.Parameters.Add(new NpgsqlParameter("@rowId", rowId));
            cmd.Parameters.Add(new NpgsqlParameter("@columnId", columnId));
            cmd.Parameters.Add(new NpgsqlParameter("@colNumber", colNumber));
            cmd.Parameters.Add(new NpgsqlParameter("@cellType", cellType));
            cmd.Parameters.Add(new NpgsqlParameter("@value", value ?? (object)DBNull.Value));
            var result = await cmd.ExecuteScalarAsync(ct);
            return Convert.ToInt32(result);
        }
        finally
        {
            await conn.CloseAsync();
        }
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

    public async Task<Dictionary<int, string>> GetCellMapForGridAsync(int gridId, CancellationToken ct = default)
    {
        var result = new Dictionary<int, string>();
        var conn = (NpgsqlConnection)db.Database.GetDbConnection();
        var wasOpen = conn.State == System.Data.ConnectionState.Open;
        if (!wasOpen) await conn.OpenAsync(ct);
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT c.""CellId"", c.""Value""
                FROM ""RTSGrid_Cell"" c
                JOIN ""RTSGrid_Row"" r ON r.""RowId"" = c.""RowId""
                WHERE r.""GridId"" = @gridId
                  AND c.""Value"" IS NOT NULL AND c.""Value"" <> ''";
            cmd.Parameters.AddWithValue("gridId", gridId);
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
                result[reader.GetInt32(0)] = reader.GetString(1);
        }
        finally
        {
            if (!wasOpen) await conn.CloseAsync();
        }
        return result;
    }
}
