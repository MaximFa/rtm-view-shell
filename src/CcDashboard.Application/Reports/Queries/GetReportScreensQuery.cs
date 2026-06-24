using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Queries;

public record GetReportScreensQuery(ReportScreenListRequest Request) : IRequest<PagedResult<ReportScreenDto>>;

public class GetReportScreensQueryHandler(
    IReportScreenRepository repo,
    IUserRepository users,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetReportScreensQuery, PagedResult<ReportScreenDto>>
{
    public async Task<PagedResult<ReportScreenDto>> Handle(GetReportScreensQuery query, CancellationToken ct)
    {
        var req = query.Request;
        var userId = currentUser.UserId!.Value;
        var pgId = currentUser.PermissionGroupId;
        var isSuperadmin = currentUser.Role == "Superadmin";
        var tenantId = currentUser.TenantId!.Value;

        var (items, total) = await repo.GetPageAsync(
            tenantId, req.Search, req.CategoryId, req.Status, req.IsPublic,
            userId, pgId, isSuperadmin, req.Page, req.PageSize, ct);

        // Get unique user IDs and fetch their names
        var userIds = items.SelectMany(s => new[] { s.CreatedByUserId, s.UpdatedByUserId }).Distinct().ToList();
        var userNames = new Dictionary<Guid, string>();
        foreach (var uid in userIds)
        {
            var user = await users.GetByIdAsync(uid, ct);
            if (user != null)
                userNames[uid] = $"{user.FirstName} {user.LastName}".Trim();
        }

        // Calculate access level for each screen
        var dtos = new List<ReportScreenDto>();
        foreach (var s in items)
        {
            var accessLevel = isSuperadmin ? 7 : await repo.GetUserAccessLevelAsync(s.Id, pgId, s.IsPublic, isSuperadmin, ct);
            dtos.Add(new ReportScreenDto(
                s.Id, s.TenantId, s.Name, s.Description,
                s.CategoryId, s.Category?.Name, s.Status, s.IsPublic, s.IsDarkMode,
                s.CreatedByUserId, userNames.GetValueOrDefault(s.CreatedByUserId),
                s.CreatedAt,
                s.UpdatedByUserId, userNames.GetValueOrDefault(s.UpdatedByUserId),
                s.UpdatedAt, s.RowVersion, accessLevel));
        }

        return new PagedResult<ReportScreenDto>(dtos, total, req.Page, req.PageSize);
    }
}
