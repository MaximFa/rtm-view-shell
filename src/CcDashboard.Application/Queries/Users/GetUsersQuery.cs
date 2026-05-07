using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Users;

public record GetUsersQuery(UserListRequest Request) : IRequest<PagedResult<UserDto>>;

public class GetUsersQueryHandler(IUserRepository users, ICurrentUserAccessor currentUser)
    : IRequestHandler<GetUsersQuery, PagedResult<UserDto>>
{
    public async Task<PagedResult<UserDto>> Handle(GetUsersQuery query, CancellationToken ct)
    {
        var req = query.Request;
        var tenantId = currentUser.TenantId!.Value;

        var items = await users.GetPageAsync(
            tenantId, req.Search, req.Role, req.PermissionGroupId, req.IsActive,
            req.Page, req.PageSize, req.SortBy, req.SortDescending, ct);

        var total = await users.CountAsync(tenantId, req.Search, req.Role, req.PermissionGroupId, req.IsActive, ct);

        var dtos = items.Select(u => new UserDto(
            u.Id, u.TenantId, u.UserName, u.Email, u.FirstName, u.LastName,
            u.Role ?? string.Empty, u.PermissionGroupId, null,
            u.IsActive, u.Is2faEnabled, u.LastLoginAt, u.PreferredLocale,
            u.MustChangePasswordAt.HasValue ? u.CreatedAt : u.CreatedAt)).ToList();

        return new PagedResult<UserDto>(dtos, total, req.Page, req.PageSize);
    }
}
