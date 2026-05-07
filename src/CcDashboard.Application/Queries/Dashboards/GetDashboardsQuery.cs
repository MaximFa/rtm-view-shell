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
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDashboardsQuery, PagedResult<DashboardDto>>
{
    public async Task<PagedResult<DashboardDto>> Handle(GetDashboardsQuery query, CancellationToken ct)
    {
        var req = query.Request;
        var tenantId = currentUser.TenantId!.Value;
        var userId = currentUser.UserId!.Value;
        var pgId = currentUser.PermissionGroupId;
        var isAdmin = currentUser.Role is "Superadmin" or "Administrator";

        var (items, total) = await dashboards.GetPageAsync(
            tenantId, req.Search, req.Status, req.CreatedByUserId, req.IsPublic,
            userId, pgId, isAdmin, req.Page, req.PageSize, ct);

        var dtos = items.Select(d => new DashboardDto(
            d.Id, d.TenantId, d.Name, d.Description, d.Status, d.IsPublic,
            d.CreatedByUserId, null, d.CreatedAt, d.UpdatedAt)).ToList();

        return new PagedResult<DashboardDto>(dtos, total, req.Page, req.PageSize);
    }
}
