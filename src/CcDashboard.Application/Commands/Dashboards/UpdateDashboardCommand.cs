using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record UpdateDashboardCommand(UpdateDashboardRequest Request) : IRequest<DashboardDto>, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.Updated";
    public object? AuditDetails => new { Name = Request.Name, Id = Request.Id };
}

public class UpdateDashboardCommandHandler(
    IDashboardRepository dashboards,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateDashboardCommand, DashboardDto>
{
    public async Task<DashboardDto> Handle(UpdateDashboardCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var dashboard = await dashboards.GetByIdAsync(cmd.Request.Id, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.Request.Id);

        dashboard.Name = cmd.Request.Name.Trim();
        dashboard.Description = cmd.Request.Description?.Trim();
        dashboard.CategoryId = cmd.Request.CategoryId;
        dashboard.Status = cmd.Request.Status;
        dashboard.IsPublic = cmd.Request.IsPublic;
        dashboard.UpdatedAt = clock.UtcNow;
        dashboard.UpdatedByUserId = currentUser.UserId!.Value;

        dashboards.Update(dashboard);

        return new DashboardDto(
            dashboard.Id, dashboard.TenantId, null, dashboard.Name, dashboard.Description,
            dashboard.CategoryId, null, dashboard.Status, dashboard.IsPublic, dashboard.CreatedByUserId, null,
            dashboard.CreatedAt, dashboard.UpdatedByUserId, null, dashboard.UpdatedAt);
    }
}
