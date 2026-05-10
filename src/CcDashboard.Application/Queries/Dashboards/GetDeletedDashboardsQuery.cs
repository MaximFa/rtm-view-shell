using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Dashboards;

public record GetDeletedDashboardsQuery(string? Search, int Page = 1, int PageSize = 25)
    : IRequest<PagedResult<DeletedDashboardDto>>;

public record DeletedDashboardDto(
    Guid Id,
    string Name,
    string? Description,
    DateTime DeletedAt,
    string? DeletedByName,
    int DaysUntilPermanentDelete);

public class GetDeletedDashboardsQueryHandler(
    IDashboardRepository dashboards,
    IUserRepository users,
    ITenantSettingsRepository tenantSettings,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDeletedDashboardsQuery, PagedResult<DeletedDashboardDto>>
{
    public async Task<PagedResult<DeletedDashboardDto>> Handle(
        GetDeletedDashboardsQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;

        var settings = await tenantSettings.GetByTenantAsync(tenantId, ct);
        if (settings is null || !settings.SoftDeleteDashboards)
            return new PagedResult<DeletedDashboardDto>([], 0, query.Page, query.PageSize);

        var retentionDays = settings.SoftDeleteRetentionDays;

        var (items, total) = await dashboards.GetDeletedPageAsync(
            tenantId, query.Search, query.Page, query.PageSize, ct);

        var userIds = items.Where(d => d.DeletedByUserId.HasValue)
            .Select(d => d.DeletedByUserId!.Value).Distinct().ToList();
        var userNames = new Dictionary<Guid, string>();
        foreach (var uid in userIds)
        {
            var user = await users.GetByIdAsync(uid, ct);
            if (user != null)
                userNames[uid] = $"{user.FirstName} {user.LastName}".Trim();
        }

        var now = DateTime.UtcNow;
        var dtos = items.Select(d =>
        {
            var deletedAt = d.DeletedAt ?? now;
            var permanentDeleteDate = deletedAt.AddDays(retentionDays);
            var daysRemaining = Math.Max(0, (int)(permanentDeleteDate - now).TotalDays);

            return new DeletedDashboardDto(
                d.Id,
                d.Name,
                d.Description,
                deletedAt,
                d.DeletedByUserId.HasValue ? userNames.GetValueOrDefault(d.DeletedByUserId.Value) : null,
                daysRemaining);
        }).ToList();

        return new PagedResult<DeletedDashboardDto>(dtos, total, query.Page, query.PageSize);
    }
}
