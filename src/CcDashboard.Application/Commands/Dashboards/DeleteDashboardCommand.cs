using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record DeleteDashboardCommand(Guid DashboardId) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.Deleted";
    public object? AuditDetails => new { Id = DashboardId };
}

public class DeleteDashboardCommandHandler(
    IDashboardRepository dashboards,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeleteDashboardCommand>
{
    public async Task Handle(DeleteDashboardCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var dashboard = await dashboards.GetByIdAsync(cmd.DashboardId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        dashboard.IsDeleted = true;
        dashboard.DeletedAt = clock.UtcNow;
        dashboard.DeletedByUserId = currentUser.UserId;
        dashboards.Update(dashboard);
    }
}
