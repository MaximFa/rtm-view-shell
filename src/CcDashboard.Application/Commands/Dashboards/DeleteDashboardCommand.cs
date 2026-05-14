using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using System.Text.Json;

namespace CcDashboard.Application.Commands.Dashboards;

public record DeleteDashboardCommand(Guid DashboardId) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.Deleted";
    public object? AuditDetails => new { Id = DashboardId };
}

public class DeleteDashboardCommandHandler(
    IDashboardRepository dashboards,
    IRtsRepository rtsRepository,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeleteDashboardCommand>
{
    public async Task Handle(DeleteDashboardCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var dashboard = await dashboards.GetByIdWithWidgetsAsync(cmd.DashboardId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        // Clean up RTS tables for all widgets
        foreach (var widget in dashboard.Widgets.Where(w => !w.IsDeleted))
        {
            var catalogName = widget.CatalogItem?.Name?.ToLower() ?? "";

            // Agent Grid - delete by widget's GridId (RTSUserGrid tables)
            if (catalogName.Contains("agent") && catalogName.Contains("grid") && widget.GridId > 0)
            {
                // Get ColumnsSetId before deleting grid
                var columnsSetId = await rtsRepository.GetColumnsSetIdByGridIdAsync(widget.GridId, ct);
                await rtsRepository.DeleteGridAsync(widget.GridId, ct);
                if (columnsSetId.HasValue)
                {
                    await rtsRepository.DeleteColumnsSetAsync(columnsSetId.Value, ct);
                }
            }
            // Queue Grid - delete by config's GridId (RTSGrid tables)
            else if (catalogName.Contains("queue") && catalogName.Contains("grid"))
            {
                var gridId = ExtractQueueGridId(widget.ConfigJson);
                if (gridId > 0)
                {
                    await rtsRepository.DeleteQueueGridAsync(gridId, ct);
                }
            }
        }

        dashboard.IsDeleted = true;
        dashboard.DeletedAt = clock.UtcNow;
        dashboard.DeletedByUserId = currentUser.UserId;
        dashboards.Update(dashboard);
    }

    private static int ExtractQueueGridId(string? configJson)
    {
        if (string.IsNullOrEmpty(configJson)) return 0;
        try
        {
            using var doc = JsonDocument.Parse(configJson);
            if (doc.RootElement.TryGetProperty("gridId", out var gridIdProp) &&
                gridIdProp.ValueKind == JsonValueKind.Number)
            {
                return gridIdProp.GetInt32();
            }
        }
        catch { }
        return 0;
    }
}
