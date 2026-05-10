using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Dashboards;

public record GetDashboardByIdQuery(Guid Id) : IRequest<DashboardDto?>;

public class GetDashboardByIdQueryHandler(
    IDashboardRepository repo,
    IUserRepository users,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDashboardByIdQuery, DashboardDto?>
{
    public async Task<DashboardDto?> Handle(GetDashboardByIdQuery request, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var d = await repo.GetByIdWithWidgetsAsync(request.Id, bypassTenantFilter: isSuperadmin, ct);
        if (d is null) return null;

        var createdBy = await users.GetByIdAsync(d.CreatedByUserId, ct);
        var updatedBy = await users.GetByIdAsync(d.UpdatedByUserId, ct);

        var widgets = d.Widgets.Select(w => new DashboardWidgetDto(
            w.Id, w.DashboardId, w.WidgetCatalogItemId, w.PositionJson, w.ConfigJson
        )).ToList();

        return new DashboardDto(
            d.Id, d.TenantId, d.Tenant?.Name,
            d.Name, d.Description, d.CategoryId, d.Category?.Name, d.Status,
            d.IsPublic, d.CreatedByUserId,
            createdBy != null ? $"{createdBy.FirstName} {createdBy.LastName}".Trim() : null,
            d.CreatedAt,
            d.UpdatedByUserId,
            updatedBy != null ? $"{updatedBy.FirstName} {updatedBy.LastName}".Trim() : null,
            d.UpdatedAt,
            d.RowVersion, widgets);
    }
}
