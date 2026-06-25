using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Queries;

public record GetDeletedReportScreensQuery(string? Search, int Page = 1, int PageSize = 25)
    : IRequest<PagedResult<DeletedReportScreenDto>>;

public record DeletedReportScreenDto(
    Guid Id,
    string Name,
    string? Description,
    DateTime DeletedAt,
    string? DeletedByName,
    int DaysUntilPermanentDelete);

public class GetDeletedReportScreensQueryHandler(
    IReportScreenRepository reportScreens,
    IUserRepository users,
    ITenantSettingsRepository tenantSettings,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDeletedReportScreensQuery, PagedResult<DeletedReportScreenDto>>
{
    public async Task<PagedResult<DeletedReportScreenDto>> Handle(
        GetDeletedReportScreensQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;

        // Check if soft-delete is enabled for this tenant (mirror dashboards)
        var settings = await tenantSettings.GetByTenantAsync(tenantId, ct);
        if (settings is null || !settings.SoftDeleteDashboards)
            return new PagedResult<DeletedReportScreenDto>([], 0, query.Page, query.PageSize);

        var retentionDays = settings.SoftDeleteRetentionDays;

        var (items, total) = await reportScreens.GetDeletedPageAsync(
            tenantId, query.Search, query.Page, query.PageSize, ct);

        // Resolve DeletedByName via user repository
        var userIds = items.Where(s => s.DeletedByUserId.HasValue)
            .Select(s => s.DeletedByUserId!.Value).Distinct().ToList();
        var userNames = new Dictionary<Guid, string>();
        foreach (var uid in userIds)
        {
            var user = await users.GetByIdAsync(uid, ct);
            if (user != null)
                userNames[uid] = $"{user.FirstName} {user.LastName}".Trim();
        }

        var now = DateTime.UtcNow;
        var dtos = items.Select(s =>
        {
            var deletedAt = s.DeletedAt ?? now;
            var permanentDeleteDate = deletedAt.AddDays(retentionDays);
            var daysRemaining = Math.Max(0, (int)(permanentDeleteDate - now).TotalDays);

            return new DeletedReportScreenDto(
                s.Id,
                s.Name,
                s.Description,
                deletedAt,
                s.DeletedByUserId.HasValue ? userNames.GetValueOrDefault(s.DeletedByUserId.Value) : null,
                daysRemaining);
        }).ToList();

        return new PagedResult<DeletedReportScreenDto>(dtos, total, query.Page, query.PageSize);
    }
}
