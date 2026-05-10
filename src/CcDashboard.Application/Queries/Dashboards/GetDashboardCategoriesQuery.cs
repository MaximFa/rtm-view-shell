using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Dashboards;

public record GetDashboardCategoriesQuery(DashboardCategoryListRequest Request) : IRequest<PagedResult<DashboardCategoryDto>>;

public class GetDashboardCategoriesQueryHandler(
    IDashboardCategoryRepository categories,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDashboardCategoriesQuery, PagedResult<DashboardCategoryDto>>
{
    public async Task<PagedResult<DashboardCategoryDto>> Handle(GetDashboardCategoriesQuery query, CancellationToken ct)
    {
        var req = query.Request;
        var isSuperadmin = currentUser.Role == "Superadmin";
        Guid? tenantId = isSuperadmin ? req.TenantId : currentUser.TenantId!.Value;

        var (items, total) = await categories.GetPageAsync(
            tenantId, req.Search, isSuperadmin, req.Page, req.PageSize, ct);

        var dtos = new List<DashboardCategoryDto>();
        foreach (var c in items)
        {
            var dashboardCount = await categories.GetDashboardCountAsync(c.Id, ct);
            dtos.Add(new DashboardCategoryDto(
                c.Id, c.TenantId, c.Tenant?.Name, c.Name, c.Description,
                dashboardCount, c.CreatedAt, c.UpdatedAt));
        }

        return new PagedResult<DashboardCategoryDto>(dtos, total, req.Page, req.PageSize);
    }
}

public record GetAllDashboardCategoriesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<DashboardCategoryDto>>;

public class GetAllDashboardCategoriesQueryHandler(
    IDashboardCategoryRepository categories,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAllDashboardCategoriesQuery, IReadOnlyList<DashboardCategoryDto>>
{
    public async Task<IReadOnlyList<DashboardCategoryDto>> Handle(GetAllDashboardCategoriesQuery query, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        Guid? tenantId = isSuperadmin ? query.TenantId : currentUser.TenantId!.Value;

        var items = await categories.GetAllAsync(tenantId, isSuperadmin, ct);

        return items.Select(c => new DashboardCategoryDto(
            c.Id, c.TenantId, c.Tenant?.Name, c.Name, c.Description,
            0, c.CreatedAt, c.UpdatedAt)).ToList();
    }
}

public record GetUsedDashboardCategoriesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<DashboardCategoryDto>>;

public class GetUsedDashboardCategoriesQueryHandler(
    IDashboardCategoryRepository categories,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetUsedDashboardCategoriesQuery, IReadOnlyList<DashboardCategoryDto>>
{
    public async Task<IReadOnlyList<DashboardCategoryDto>> Handle(GetUsedDashboardCategoriesQuery query, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        Guid? tenantId = isSuperadmin ? query.TenantId : currentUser.TenantId!.Value;

        var items = await categories.GetUsedAsync(tenantId, isSuperadmin, ct);

        return items.Select(c => new DashboardCategoryDto(
            c.Id, c.TenantId, c.Tenant?.Name, c.Name, c.Description,
            0, c.CreatedAt, c.UpdatedAt)).ToList();
    }
}
