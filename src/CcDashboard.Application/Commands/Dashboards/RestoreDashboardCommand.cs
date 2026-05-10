using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record RestoreDashboardCommand(Guid DashboardId) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.Restored";
    public object? AuditDetails => new { Id = DashboardId };
}

public class RestoreDashboardCommandHandler(IDashboardRepository dashboards)
    : IRequestHandler<RestoreDashboardCommand>
{
    public async Task Handle(RestoreDashboardCommand cmd, CancellationToken ct)
    {
        var dashboard = await dashboards.GetDeletedByIdAsync(cmd.DashboardId, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.DashboardId);

        dashboard.IsDeleted = false;
        dashboard.DeletedAt = null;
        dashboard.DeletedByUserId = null;
        dashboards.Update(dashboard);
    }
}
