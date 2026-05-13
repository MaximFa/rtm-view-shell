using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record RtsColumnInput(int? DbColumnId, string Title, string MetricId, int ColumnsOrder);

public record SaveAgentGridRtsResult(
    int GridId,
    int ColumnsSetId,
    List<(string Title, int DbColumnId)> SavedColumns);

public record SaveAgentGridRtsCommand(
    int GridId,
    int? ColumnsSetId,
    string WidgetName,
    int? BusinessUnitId,
    string? RowsFilter,
    List<RtsColumnInput> Columns) : IRequest<SaveAgentGridRtsResult>;

public class SaveAgentGridRtsCommandHandler(
    IRtsRepository rtsRepository,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveAgentGridRtsCommand, SaveAgentGridRtsResult>
{
    public async Task<SaveAgentGridRtsResult> Handle(SaveAgentGridRtsCommand cmd, CancellationToken ct)
    {
        int columnsSetId;
        int gridId;
        var savedColumns = new List<(string Title, int DbColumnId)>();

        // Step 1: Handle ColumnsSet
        if (cmd.ColumnsSetId is null)
        {
            // INSERT new ColumnsSet
            var columnsSet = new RtsUserGridColumnsSet
            {
                Title = cmd.WidgetName,
                Description = cmd.WidgetName,
                Direction = null
            };
            columnsSetId = await rtsRepository.InsertColumnsSetAsync(columnsSet, ct);
        }
        else
        {
            // Use existing ColumnsSetId - DO NOT update
            columnsSetId = cmd.ColumnsSetId.Value;
        }

        // Step 2: Handle Columns
        // Get existing column IDs for this ColumnsSet
        var existingColumnIds = await rtsRepository.GetColumnIdsForColumnsSetAsync(columnsSetId, ct);
        var incomingColumnIds = cmd.Columns
            .Where(c => c.DbColumnId.HasValue)
            .Select(c => c.DbColumnId!.Value)
            .ToHashSet();

        // Delete columns that are no longer in the list
        var columnsToDelete = existingColumnIds.Except(incomingColumnIds).ToList();
        foreach (var columnId in columnsToDelete)
        {
            await rtsRepository.DeleteColumnAsync(columnId, ct);
        }

        // Insert or update columns
        foreach (var col in cmd.Columns)
        {
            if (col.DbColumnId is null)
            {
                // INSERT new column
                var newColumn = new RtsUserGridColumn
                {
                    ColumnsSetId = columnsSetId,
                    Title = col.Title,
                    MetricId = col.MetricId,
                    ColumnsOrder = col.ColumnsOrder,
                    StyleId = null
                };
                var newColumnId = await rtsRepository.InsertColumnAsync(newColumn, ct);
                savedColumns.Add((col.Title, newColumnId));
            }
            else
            {
                // UPDATE existing column
                await rtsRepository.UpdateColumnAsync(col.DbColumnId.Value, col.Title, col.MetricId, col.ColumnsOrder, ct);
                savedColumns.Add((col.Title, col.DbColumnId.Value));
            }
        }

        // Step 3: Handle Grid
        if (cmd.GridId == 0)
        {
            // INSERT new Grid
            var grid = new RtsUserGridGrid
            {
                UnionId = cmd.BusinessUnitId,
                StyleId = 1,
                Title = cmd.WidgetName,
                RowsFilter = cmd.RowsFilter,
                PageSize = 40,
                ColumnsSetId = columnsSetId,
                ThresholdScript = null,
                RowsFilterNew = cmd.RowsFilter,
                NoRecordsText = null,
                AllowPaging = null,
                AllowScroll = null,
                TextDirection = null
            };
            gridId = await rtsRepository.InsertGridAsync(grid, ct);
        }
        else
        {
            // UPDATE existing Grid (only specific fields)
            await rtsRepository.UpdateGridAsync(cmd.GridId, cmd.BusinessUnitId, cmd.WidgetName, cmd.RowsFilter, ct);
            gridId = cmd.GridId;
        }

        // API hook placeholder
        // TODO: replace NoOp with real REST or SignalR call — TBD
        await apiHook.NotifyAsync("AgentGridRts.Saved", new { GridId = gridId, ColumnsSetId = columnsSetId }, ct);

        return new SaveAgentGridRtsResult(gridId, columnsSetId, savedColumns);
    }
}
