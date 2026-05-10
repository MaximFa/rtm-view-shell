using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Dashboards;

public record GetDashboardsQuery(DashboardListRequest Request) : IRequest<PagedResult<DashboardDto>>;

public class GetDashboardsQueryHandler(
    IDashboardRepository dashboards,
    IUserRepository users,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDashboardsQuery, PagedResult<DashboardDto>>
{
    public async Task<PagedResult<DashboardDto>> Handle(GetDashboardsQuery query, CancellationToken ct)
    {
        var req = query.Request;
        var userId = currentUser.UserId!.Value;
        var pgId = currentUser.PermissionGroupId;
        var isSuperadmin = currentUser.Role == "Superadmin";
        var isAdmin = currentUser.Role is "Superadmin" or "Administrator";

        // For Superadmin: use specified TenantId or null (all tenants)
        // For others: always use current tenant
        Guid? tenantId = isSuperadmin ? req.TenantId : currentUser.TenantId!.Value;

        var (items, total) = await dashboards.GetPageAsync(
            tenantId, req.Search, req.Status, req.CategoryId, req.CreatedByUserId, req.IsPublic,
            userId, pgId, isSuperadmin, isAdmin, req.Page, req.PageSize, ct);

        // Get unique user IDs and fetch their names
        var userIds = items.SelectMany(d => new[] { d.CreatedByUserId, d.UpdatedByUserId }).Distinct().ToList();
        var userNames = new Dictionary<Guid, string>();
        foreach (var uid in userIds)
        {
            var user = await users.GetByIdAsync(uid, ct);
            if (user != null)
                userNames[uid] = $"{user.FirstName} {user.LastName}".Trim();
        }

        var dtos = items.Select(d => new DashboardDto(
            d.Id, d.TenantId, d.Tenant?.Name,
            d.Name, d.Description, d.CategoryId, d.Category?.Name, d.Status, d.IsPublic,
            d.CreatedByUserId, userNames.GetValueOrDefault(d.CreatedByUserId),
            d.CreatedAt,
            d.UpdatedByUserId, userNames.GetValueOrDefault(d.UpdatedByUserId),
            d.UpdatedAt, d.RowVersion,
            d.Widgets.Select(w => new DashboardWidgetDto(
                w.Id, w.DashboardId, w.WidgetCatalogItemId, w.PositionJson, w.ConfigJson)).ToList())).ToList();

        return new PagedResult<DashboardDto>(dtos, total, req.Page, req.PageSize);
    }
}
