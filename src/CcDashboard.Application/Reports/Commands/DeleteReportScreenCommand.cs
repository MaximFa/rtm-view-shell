using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Commands;

public record DeleteReportScreenCommand(Guid Id) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.Deleted";
    public object? AuditDetails { get; private set; }

    public void SetAuditDetails(int schedulesDeactivated) =>
        AuditDetails = new { Id, SchedulesDeactivated = schedulesDeactivated };
}

public class DeleteReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeleteReportScreenCommand>
{
    public async Task Handle(DeleteReportScreenCommand cmd, CancellationToken ct)
    {
        // Check Delete permission
        var isSuperadmin = currentUser.Role == "Superadmin";
        // Load with widgets AND schedules for deactivation
        var screen = await repo.GetByIdWithWidgetsAndSchedulesAsync(cmd.Id, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.Id);
        if (!isSuperadmin)
        {
            var accessLevel = await repo.GetUserAccessLevelAsync(
                screen.Id, currentUser.PermissionGroupId, screen.IsPublic, isSuperadmin, ct);
            if ((accessLevel & 4) == 0) // Delete = 4
                throw new ForbiddenException("Delete permission required");
        }

        // Soft delete (no RTS cleanup needed — reports don't use RTM grids)
        screen.IsDeleted = true;
        screen.DeletedAt = clock.UtcNow;
        screen.DeletedByUserId = currentUser.UserId;

        // Soft delete widgets too
        foreach (var widget in screen.Widgets.Where(w => !w.IsDeleted))
        {
            widget.IsDeleted = true;
        }

        // Deactivate all schedules to prevent auto-sending from Trash
        // Keep rows for audit/history — just deactivate
        var schedulesDeactivated = 0;
        foreach (var schedule in screen.Schedules.Where(s => s.IsActive))
        {
            schedule.IsActive = false;
            schedule.NextRunAt = null; // Clear so dispatcher scan also skips
            schedulesDeactivated++;
        }

        cmd.SetAuditDetails(schedulesDeactivated);
        repo.Update(screen);
    }
}
