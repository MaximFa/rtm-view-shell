using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record SaveDashboardWidgetCommand(
    Guid DashboardId,
    DashboardWidgetDto Widget,
    int? PreassignedGridId = null) : IRequest<int>
{
    // Returns the GridId (auto-generated for new widgets, or PreassignedGridId if provided)
}

public class SaveDashboardWidgetCommandHandler(
    IDashboardRepository dashboards,
    IUnitOfWork unitOfWork,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<SaveDashboardWidgetCommand, int>
{
    public async Task<int> Handle(SaveDashboardWidgetCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var dashboard = await dashboards.GetByIdWithWidgetsAsync(cmd.DashboardId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        var tenantId = dashboard.TenantId;
        var dto = cmd.Widget;

        var existing = dashboard.Widgets.FirstOrDefault(w => w.Id == dto.Id);
        if (existing != null)
        {
            // Update existing widget
            existing.WidgetCatalogItemId = dto.WidgetCatalogItemId;
            existing.PositionJson = dto.PositionJson;
            existing.ConfigJson = dto.ConfigJson;

            // Update GridId if PreassignedGridId is provided (from RTS save)
            if (cmd.PreassignedGridId.HasValue && cmd.PreassignedGridId.Value > 0)
            {
                existing.GridId = cmd.PreassignedGridId.Value;
            }

            dashboard.UpdatedAt = clock.UtcNow;
            dashboard.UpdatedByUserId = currentUser.UserId!.Value;
            dashboards.Update(dashboard);

            await unitOfWork.SaveChangesAsync(ct);
            return existing.GridId;
        }
        else
        {
            // Create new widget - use PreassignedGridId if provided, otherwise auto-generate
            var newWidget = new DashboardWidget
            {
                Id = dto.Id,
                DashboardId = dashboard.Id,
                TenantId = tenantId,
                WidgetCatalogItemId = dto.WidgetCatalogItemId,
                PositionJson = dto.PositionJson,
                ConfigJson = dto.ConfigJson,
                IsDeleted = false
            };

            // If PreassignedGridId is provided (from RTS table), use it
            if (cmd.PreassignedGridId.HasValue)
            {
                newWidget.GridId = cmd.PreassignedGridId.Value;
            }

            dashboard.Widgets.Add(newWidget);
            dashboard.UpdatedAt = clock.UtcNow;
            dashboard.UpdatedByUserId = currentUser.UserId!.Value;
            dashboards.Update(dashboard);

            // SaveChanges populates GridId from database identity (if not pre-assigned)
            await unitOfWork.SaveChangesAsync(ct);

            return newWidget.GridId;
        }
    }
}
