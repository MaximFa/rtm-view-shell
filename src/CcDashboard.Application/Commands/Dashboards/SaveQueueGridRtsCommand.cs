using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

// Input for a Queue Grid column
public record QueueGridColumnInput(
    string LocalId,       // Local GUID for tracking (from QueueGridColumnDef.Id)
    int? ColumnId,        // DB ColumnId if existing, null if new
    string Name,          // Display name (header text)
    string MetricId,      // Reference to RtsGridMetric.MetricId
    int ColumnNumber);    // 1-based order

// Input for a Queue Grid row
public record QueueGridRowInput(
    string LocalId,       // Local GUID for tracking (from QueueGridRowDef.Id)
    int? RowId,           // DB RowId if existing, null if new
    int? BusinessUnitId,  // UnionId for data binding
    int RowNumber,        // 2-based (1 = header row)
    Dictionary<string, int?> CellIds);  // Existing CellIds keyed by column LocalId

// Result after save
public record SaveQueueGridRtsResult(
    int GridId,
    int HeaderRowId,
    Dictionary<string, int> SavedColumnIds,   // Key = column LocalId, Value = DB ColumnId
    Dictionary<string, int> HeaderCellIds,    // Key = column LocalId, Value = DB CellId for header
    Dictionary<string, int> SavedRowIds,      // Key = row LocalId, Value = DB RowId
    Dictionary<string, Dictionary<string, int>> SavedCellIds);  // Key = row LocalId, Value = { column LocalId -> CellId }

public record SaveQueueGridRtsCommand(
    int? GridId,
    int? HeaderRowId,
    string Title,
    List<QueueGridColumnInput> Columns,
    List<QueueGridRowInput> Rows,
    Dictionary<string, int?> ExistingHeaderCellIds) : IRequest<SaveQueueGridRtsResult>;

public class SaveQueueGridRtsCommandHandler(
    IRtsRepository rtsRepository,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveQueueGridRtsCommand, SaveQueueGridRtsResult>
{
    public async Task<SaveQueueGridRtsResult> Handle(SaveQueueGridRtsCommand cmd, CancellationToken ct)
    {
        int gridId;
        int headerRowId;
        var savedColumnIds = new Dictionary<string, int>();
        var headerCellIds = new Dictionary<string, int>();
        var savedRowIds = new Dictionary<string, int>();
        var savedCellIds = new Dictionary<string, Dictionary<string, int>>();

        // Step 1: Handle Grid
        if (cmd.GridId is null or 0)
        {
            gridId = await rtsRepository.InsertQueueGridAsync(cmd.Title, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridAsync(cmd.GridId.Value, cmd.Title, ct);
            gridId = cmd.GridId.Value;
        }

        // Step 2: Handle Columns
        var existingColumnIds = await rtsRepository.GetQueueGridColumnIdsAsync(gridId, ct);
        var incomingColumnIds = cmd.Columns
            .Where(c => c.ColumnId.HasValue)
            .Select(c => c.ColumnId!.Value)
            .ToHashSet();

        // Delete columns no longer in the list
        var columnsToDelete = existingColumnIds.Except(incomingColumnIds).ToList();
        foreach (var columnId in columnsToDelete)
        {
            // Cascade will delete cells, but delete explicitly for clarity
            await rtsRepository.DeleteQueueGridCellsByColumnIdAsync(columnId, ct);
            await rtsRepository.DeleteQueueGridColumnAsync(columnId, ct);
        }

        // Insert or update columns
        foreach (var col in cmd.Columns)
        {
            int dbColumnId;
            if (col.ColumnId is null)
            {
                dbColumnId = await rtsRepository.InsertQueueGridColumnAsync(gridId, col.ColumnNumber, ct);
            }
            else
            {
                await rtsRepository.UpdateQueueGridColumnAsync(col.ColumnId.Value, col.ColumnNumber, ct);
                dbColumnId = col.ColumnId.Value;
            }
            savedColumnIds[col.LocalId] = dbColumnId;
        }

        // Step 3: Handle Header Row (RowNumber=1, UnionId=-1)
        if (cmd.HeaderRowId is null or 0)
        {
            headerRowId = await rtsRepository.InsertQueueGridRowAsync(gridId, 1, -1, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridRowAsync(cmd.HeaderRowId.Value, 1, -1, ct);
            headerRowId = cmd.HeaderRowId.Value;
        }

        // Step 4: Handle Header Cells (CellType="Text", Value=column name)
        // Delete header cells for columns that were removed
        foreach (var (colLocalId, cellId) in cmd.ExistingHeaderCellIds)
        {
            if (cellId.HasValue && !savedColumnIds.ContainsKey(colLocalId))
            {
                await rtsRepository.DeleteQueueGridCellAsync(cellId.Value, ct);
            }
        }

        // Insert or update header cells
        foreach (var col in cmd.Columns)
        {
            var dbColumnId = savedColumnIds[col.LocalId];
            var existingCellId = cmd.ExistingHeaderCellIds.GetValueOrDefault(col.LocalId);

            int cellId;
            if (existingCellId is null)
            {
                cellId = await rtsRepository.InsertQueueGridCellAsync(
                    headerRowId, dbColumnId, col.ColumnNumber, "Text", col.Name, ct);
            }
            else
            {
                await rtsRepository.UpdateQueueGridCellAsync(existingCellId.Value, "Text", col.Name, ct);
                cellId = existingCellId.Value;
            }
            headerCellIds[col.LocalId] = cellId;
        }

        // Step 5: Handle Data Rows
        var existingRowIds = await rtsRepository.GetQueueGridRowIdsAsync(gridId, ct);
        // Exclude header row from deletion candidates
        existingRowIds = existingRowIds.Where(id => id != headerRowId).ToList();

        var incomingRowIds = cmd.Rows
            .Where(r => r.RowId.HasValue)
            .Select(r => r.RowId!.Value)
            .ToHashSet();

        // Delete rows no longer in the list
        var rowsToDelete = existingRowIds.Except(incomingRowIds).ToList();
        foreach (var rowId in rowsToDelete)
        {
            // Cascade will delete cells
            await rtsRepository.DeleteQueueGridRowAsync(rowId, ct);
        }

        // Insert or update data rows and their cells
        foreach (var row in cmd.Rows)
        {
            int dbRowId;
            if (row.RowId is null)
            {
                dbRowId = await rtsRepository.InsertQueueGridRowAsync(
                    gridId, row.RowNumber, row.BusinessUnitId, ct);
            }
            else
            {
                await rtsRepository.UpdateQueueGridRowAsync(
                    row.RowId.Value, row.RowNumber, row.BusinessUnitId, ct);
                dbRowId = row.RowId.Value;
            }
            savedRowIds[row.LocalId] = dbRowId;

            // Handle cells for this row
            var rowCellIds = new Dictionary<string, int>();

            // Delete cells for columns that no longer exist
            foreach (var (colLocalId, cellId) in row.CellIds)
            {
                if (cellId.HasValue && !savedColumnIds.ContainsKey(colLocalId))
                {
                    await rtsRepository.DeleteQueueGridCellAsync(cellId.Value, ct);
                }
            }

            // Insert or update cells for each column
            foreach (var col in cmd.Columns)
            {
                var dbColumnId = savedColumnIds[col.LocalId];
                var existingCellId = row.CellIds.GetValueOrDefault(col.LocalId);

                int cellId;
                // CellType="Data", Value=MetricId for SignalR binding
                if (existingCellId is null)
                {
                    cellId = await rtsRepository.InsertQueueGridCellAsync(
                        dbRowId, dbColumnId, col.ColumnNumber, "Data", col.MetricId, ct);
                }
                else
                {
                    await rtsRepository.UpdateQueueGridCellAsync(existingCellId.Value, "Data", col.MetricId, ct);
                    cellId = existingCellId.Value;
                }
                rowCellIds[col.LocalId] = cellId;
            }

            savedCellIds[row.LocalId] = rowCellIds;
        }

        // API hook placeholder
        await apiHook.NotifyAsync("QueueGridRts.Saved", new { GridId = gridId }, ct);

        return new SaveQueueGridRtsResult(
            gridId,
            headerRowId,
            savedColumnIds,
            headerCellIds,
            savedRowIds,
            savedCellIds);
    }
}
