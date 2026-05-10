using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record UpdateDashboardWidgetsCommand(
    Guid DashboardId,
    IReadOnlyList<DashboardWidgetDto> Widgets) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.WidgetsUpdated";
    public object? AuditDetails => new { DashboardId, WidgetCount = Widgets.Count };
}

public class UpdateDashboardWidgetsCommandHandler(
    IDashboardRepository dashboards,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateDashboardWidgetsCommand>
{
    public async Task Handle(UpdateDashboardWidgetsCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var dashboard = await dashboards.GetByIdWithWidgetsAsync(cmd.DashboardId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        // Use dashboard's tenant, not current user's (important for Superadmin editing other tenants)
        var tenantId = dashboard.TenantId;

        // Remove widgets that are no longer in the list
        var incomingIds = cmd.Widgets.Select(w => w.Id).ToHashSet();
        var toRemove = dashboard.Widgets.Where(w => !incomingIds.Contains(w.Id)).ToList();
        foreach (var widget in toRemove)
        {
            dashboard.Widgets.Remove(widget);
        }

        // Update existing and add new widgets
        foreach (var dto in cmd.Widgets)
        {
            var existing = dashboard.Widgets.FirstOrDefault(w => w.Id == dto.Id);
            if (existing != null)
            {
                existing.WidgetCatalogItemId = dto.WidgetCatalogItemId;
                existing.PositionJson = dto.PositionJson;
                existing.ConfigJson = dto.ConfigJson;
            }
            else
            {
                dashboard.Widgets.Add(new DashboardWidget
                {
                    Id = dto.Id,
                    DashboardId = dashboard.Id,
                    TenantId = tenantId,
                    WidgetCatalogItemId = dto.WidgetCatalogItemId,
                    PositionJson = dto.PositionJson,
                    ConfigJson = dto.ConfigJson,
                    IsDeleted = false
                });
            }
        }

        dashboard.UpdatedAt = clock.UtcNow;
        dashboard.UpdatedByUserId = currentUser.UserId!.Value;

        dashboards.Update(dashboard);
    }
}
