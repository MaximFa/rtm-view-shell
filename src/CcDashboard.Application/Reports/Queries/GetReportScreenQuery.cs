using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Queries;

public record GetReportScreenQuery(Guid Id) : IRequest<ReportScreenDetailDto>;

public class GetReportScreenQueryHandler(
    IReportScreenRepository repo,
    IUserRepository users,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetReportScreenQuery, ReportScreenDetailDto>
{
    public async Task<ReportScreenDetailDto> Handle(GetReportScreenQuery request, CancellationToken ct)
    {
        var screen = await repo.GetByIdWithWidgetsAsync(request.Id, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), request.Id);

        var isSuperadmin = currentUser.Role == "Superadmin";
        var accessLevel = isSuperadmin ? 7
            : await repo.GetUserAccessLevelAsync(screen.Id, currentUser.PermissionGroupId, screen.IsPublic, isSuperadmin, ct);

        // Require View permission
        if ((accessLevel & 1) == 0)
            throw new ForbiddenException("View permission required");

        var createdBy = await users.GetByIdAsync(screen.CreatedByUserId, ct);
        var updatedBy = await users.GetByIdAsync(screen.UpdatedByUserId, ct);

        var widgets = screen.Widgets
            .Where(w => !w.IsDeleted)
            .Select(w => new ReportWidgetDto(w.Id, w.WidgetType, w.PositionJson, w.ConfigJson))
            .ToList();

        return new ReportScreenDetailDto(
            screen.Id, screen.TenantId, screen.Name, screen.Description,
            screen.CategoryId, screen.Category?.Name, screen.Status, screen.IsPublic, screen.IsDarkMode,
            screen.LayoutJson,
            screen.CreatedByUserId,
            createdBy != null ? $"{createdBy.FirstName} {createdBy.LastName}".Trim() : null,
            screen.CreatedAt,
            screen.UpdatedByUserId,
            updatedBy != null ? $"{updatedBy.FirstName} {updatedBy.LastName}".Trim() : null,
            screen.UpdatedAt, screen.RowVersion, accessLevel, widgets);
    }
}
