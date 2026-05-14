using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CcDashboard.Application.Commands.Dashboards;

public record CloneDashboardCommand(Guid DashboardId, string? NewName = null) : IRequest<Guid>;

public class CloneDashboardCommandHandler(
    IDashboardRepository dashboards,
    IRtsRepository rtsRepository,
    IUnitOfWork unitOfWork,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CloneDashboardCommand, Guid>
{
    public async Task<Guid> Handle(CloneDashboardCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var original = await dashboards.GetByIdWithWidgetsAsync(cmd.DashboardId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        var now = clock.UtcNow;
        var userId = currentUser.UserId!.Value;
        var tenantId = original.TenantId;

        // Create cloned dashboard
        var cloned = new Dashboard
        {
            Id = Guid.NewGuid(),
            TenantId = tenantId,
            Name = cmd.NewName ?? $"Copy of {original.Name}",
            Description = original.Description,
            CategoryId = original.CategoryId,
            Status = DashboardStatus.Draft,
            IsPublic = original.IsPublic,
            IsDarkMode = original.IsDarkMode,
            CreatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
            UpdatedByUserId = userId,
            IsDeleted = false,
            LayoutJson = original.LayoutJson
        };

        // Clone widgets with new IDs and cleared RTS references
        foreach (var widget in original.Widgets.Where(w => !w.IsDeleted))
        {
            var catalogName = widget.CatalogItem?.Name?.ToLower() ?? "";
            var clearedConfig = ClearRtsIdsFromConfig(widget.ConfigJson);

            var clonedWidget = new DashboardWidget
            {
                Id = Guid.NewGuid(),
                DashboardId = cloned.Id,
                TenantId = tenantId,
                WidgetCatalogItemId = widget.WidgetCatalogItemId,
                IsDeleted = false,
                PositionJson = widget.PositionJson,
                ConfigJson = clearedConfig
            };

            // Create RTS records for Queue Grid widgets
            if (catalogName.Contains("queue") && catalogName.Contains("grid") && !string.IsNullOrEmpty(clearedConfig))
            {
                var (updatedConfig, _) = await CreateQueueGridRtsRecords(clearedConfig, ct);
                clonedWidget.ConfigJson = updatedConfig;
            }
            // Create RTS records for Agent Grid widgets
            else if (catalogName.Contains("agent") && catalogName.Contains("grid") && !string.IsNullOrEmpty(clearedConfig))
            {
                var (updatedConfig, gridId) = await CreateAgentGridRtsRecords(clearedConfig, ct);
                clonedWidget.ConfigJson = updatedConfig;
                clonedWidget.GridId = gridId;
            }

            cloned.Widgets.Add(clonedWidget);
        }

        await dashboards.AddAsync(cloned, ct);
        await unitOfWork.SaveChangesAsync(ct);

        return cloned.Id;
    }

    private async Task<(string UpdatedConfig, int GridId)> CreateQueueGridRtsRecords(string configJson, CancellationToken ct)
    {
        var json = JsonNode.Parse(configJson);
        if (json is not JsonObject obj) return (configJson, 0);

        var title = obj["displayName"]?.GetValue<string>() ?? "Queue Grid";

        // Create Grid
        var gridId = await rtsRepository.InsertQueueGridAsync(title, ct);
        obj["gridId"] = gridId;

        // Get column definitions
        var columnDefs = obj["queueGridColumnDefs"] as JsonArray;
        if (columnDefs == null || columnDefs.Count == 0)
            return (obj.ToJsonString(), gridId);

        // Create columns and track IDs
        var columnIdMap = new Dictionary<string, int>(); // localId -> dbColumnId
        var columnNumber = 1;
        foreach (var colNode in columnDefs)
        {
            if (colNode is not JsonObject colObj) continue;
            var localId = colObj["id"]?.GetValue<string>() ?? "";
            var dbColumnId = await rtsRepository.InsertQueueGridColumnAsync(gridId, columnNumber++, ct);
            columnIdMap[localId] = dbColumnId;
            colObj["columnId"] = dbColumnId;
        }

        // Create header row (RowNumber=1, UnionId=-1)
        var headerRowId = await rtsRepository.InsertQueueGridRowAsync(gridId, 1, -1, ct);
        obj["headerRowId"] = headerRowId;

        // Create header cells
        var headerCellIds = new JsonObject();
        columnNumber = 1;
        foreach (var colNode in columnDefs)
        {
            if (colNode is not JsonObject colObj) continue;
            var localId = colObj["id"]?.GetValue<string>() ?? "";
            var colName = colObj["name"]?.GetValue<string>() ?? "";
            if (columnIdMap.TryGetValue(localId, out var dbColumnId))
            {
                var cellId = await rtsRepository.InsertQueueGridCellAsync(
                    headerRowId, dbColumnId, columnNumber++, "Text", colName, ct);
                headerCellIds[localId] = cellId;
            }
        }
        obj["headerCellIds"] = headerCellIds;

        // Create data rows and cells
        var rowDefs = obj["queueGridRows"] as JsonArray;
        if (rowDefs != null)
        {
            var rowNumber = 2; // Data rows start at 2
            foreach (var rowNode in rowDefs)
            {
                if (rowNode is not JsonObject rowObj) continue;
                var localRowId = rowObj["id"]?.GetValue<string>() ?? "";
                var buId = rowObj["businessUnitId"]?.GetValue<int?>();

                var dbRowId = await rtsRepository.InsertQueueGridRowAsync(gridId, rowNumber++, buId, ct);
                rowObj["rowId"] = dbRowId;

                // Create cells for this row
                var cellIds = new JsonObject();
                var cellColNum = 1;
                foreach (var colNode in columnDefs)
                {
                    if (colNode is not JsonObject colObj) continue;
                    var colLocalId = colObj["id"]?.GetValue<string>() ?? "";
                    var metricId = colObj["metricId"]?.GetValue<string>() ?? "";
                    if (columnIdMap.TryGetValue(colLocalId, out var dbColumnId))
                    {
                        var cellId = await rtsRepository.InsertQueueGridCellAsync(
                            dbRowId, dbColumnId, cellColNum++, "Data", metricId, ct);
                        cellIds[colLocalId] = cellId;
                    }
                }
                rowObj["cellIds"] = cellIds;
            }
        }

        return (obj.ToJsonString(), gridId);
    }

    private async Task<(string UpdatedConfig, int GridId)> CreateAgentGridRtsRecords(string configJson, CancellationToken ct)
    {
        var json = JsonNode.Parse(configJson);
        if (json is not JsonObject obj) return (configJson, 0);

        var title = obj["displayName"]?.GetValue<string>() ?? "Agent Grid";

        // Create ColumnsSet
        var columnsSet = new RtsUserGridColumnsSet { Title = title };
        var columnsSetId = await rtsRepository.InsertColumnsSetAsync(columnsSet, ct);
        obj["columnsSetId"] = columnsSetId;

        // Get column definitions and create columns
        var columnDefs = obj["agentGridColumnDefs"] as JsonArray;
        if (columnDefs != null)
        {
            var columnsOrder = 1;
            foreach (var colNode in columnDefs)
            {
                if (colNode is not JsonObject colObj) continue;
                var colTitle = colObj["name"]?.GetValue<string>() ?? "";
                var metricId = colObj["metricId"]?.GetValue<string>() ?? "";

                var column = new RtsUserGridColumn
                {
                    ColumnsSetId = columnsSetId,
                    Title = colTitle,
                    MetricId = metricId,
                    ColumnsOrder = columnsOrder++
                };
                var dbColumnId = await rtsRepository.InsertColumnAsync(column, ct);
                colObj["dbColumnId"] = dbColumnId;
            }
        }

        // Create Grid
        var grid = new RtsUserGridGrid
        {
            ColumnsSetId = columnsSetId,
            Title = title
        };
        var gridId = await rtsRepository.InsertGridAsync(grid, ct);

        return (obj.ToJsonString(), gridId);
    }

    private static string? ClearRtsIdsFromConfig(string? configJson)
    {
        if (string.IsNullOrEmpty(configJson)) return configJson;

        try
        {
            var json = JsonNode.Parse(configJson);
            if (json is not JsonObject obj) return configJson;

            // Clear RTS IDs for Queue Grid - REMOVE properties entirely
            obj.Remove("gridId");
            obj.Remove("headerRowId");
            obj["headerCellIds"] = new JsonObject();

            // Clear RTS IDs for Agent Grid
            obj.Remove("columnsSetId");

            // Clear column IDs for Queue Grid
            if (obj["queueGridColumnDefs"] is JsonArray queueCols)
            {
                foreach (var col in queueCols)
                {
                    if (col is JsonObject colObj)
                    {
                        colObj.Remove("columnId");
                        colObj["id"] = Guid.NewGuid().ToString();
                    }
                }
            }

            // Clear row/cell IDs for Queue Grid - but keep row definitions
            if (obj["queueGridRows"] is JsonArray rows)
            {
                foreach (var row in rows)
                {
                    if (row is JsonObject rowObj)
                    {
                        rowObj.Remove("rowId");
                        rowObj["cellIds"] = new JsonObject();
                        rowObj["id"] = Guid.NewGuid().ToString();
                    }
                }
            }

            // Clear column IDs for Agent Grid
            if (obj["agentGridColumnDefs"] is JsonArray agentCols)
            {
                foreach (var col in agentCols)
                {
                    if (col is JsonObject colObj)
                    {
                        colObj.Remove("dbColumnId");
                    }
                }
            }

            return obj.ToJsonString();
        }
        catch
        {
            return configJson;
        }
    }
}
