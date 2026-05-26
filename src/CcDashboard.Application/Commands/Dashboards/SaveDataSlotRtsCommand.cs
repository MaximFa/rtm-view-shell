using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

// Result after Data Slot RTS save
public record SaveDataSlotRtsResult(
    int GridId,
    int ColumnId,
    int RowId,
    int CellId);

// Data Slot is a Grid with exactly 1 Column, 1 Row, 1 Cell
public record SaveDataSlotRtsCommand(
    int? GridId,
    int? ColumnId,
    int? RowId,
    int? CellId,
    string Title,
    string MetricId,
    int? BusinessUnitId) : IRequest<SaveDataSlotRtsResult>;

public class SaveDataSlotRtsCommandHandler(
    IRtsRepository rtsRepository,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveDataSlotRtsCommand, SaveDataSlotRtsResult>
{
    public async Task<SaveDataSlotRtsResult> Handle(SaveDataSlotRtsCommand cmd, CancellationToken ct)
    {
        int gridId;
        int columnId;
        int rowId;
        int cellId;

        // Step 1: Grid
        if (cmd.GridId is null or 0)
        {
            gridId = await rtsRepository.InsertQueueGridAsync(cmd.Title, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridAsync(cmd.GridId.Value, cmd.Title, ct);
            gridId = cmd.GridId.Value;
        }

        // Step 2: Column (ColumnNumber=1)
        // Check if column exists in DB, not just if ID is provided
        var existingColumnIds = await rtsRepository.GetQueueGridColumnIdsAsync(gridId, ct);
        if (cmd.ColumnId is null or 0 || !existingColumnIds.Contains(cmd.ColumnId.Value))
        {
            columnId = await rtsRepository.InsertQueueGridColumnAsync(gridId, 1, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridColumnAsync(cmd.ColumnId.Value, 1, ct);
            columnId = cmd.ColumnId.Value;
        }

        // Step 3: Row (RowNumber=1, UnionId=BusinessUnitId)
        var existingRowIds = await rtsRepository.GetQueueGridRowIdsAsync(gridId, ct);
        if (cmd.RowId is null or 0 || !existingRowIds.Contains(cmd.RowId.Value))
        {
            rowId = await rtsRepository.InsertQueueGridRowAsync(gridId, 1, cmd.BusinessUnitId, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridRowAsync(cmd.RowId.Value, 1, cmd.BusinessUnitId, ct);
            rowId = cmd.RowId.Value;
        }

        // Step 4: Cell (CellType="Data", Value=MetricId)
        // Always insert new cell if row was just created, or if cell doesn't exist
        if (cmd.CellId is null or 0 || !existingRowIds.Contains(cmd.RowId ?? 0))
        {
            cellId = await rtsRepository.InsertQueueGridCellAsync(
                rowId, columnId, 1, "Data", cmd.MetricId, ct);
        }
        else
        {
            await rtsRepository.UpdateQueueGridCellAsync(cmd.CellId.Value, "Data", cmd.MetricId, ct);
            cellId = cmd.CellId.Value;
        }

        // API hook placeholder
        await apiHook.NotifyAsync("DataSlotRts.Saved", new
        {
            GridId = gridId,
            ColumnId = columnId,
            RowId = rowId,
            CellId = cellId,
            Title = cmd.Title,
            MetricId = cmd.MetricId,
            BusinessUnitId = cmd.BusinessUnitId
        }, ct);

        return new SaveDataSlotRtsResult(gridId, columnId, rowId, cellId);
    }
}
