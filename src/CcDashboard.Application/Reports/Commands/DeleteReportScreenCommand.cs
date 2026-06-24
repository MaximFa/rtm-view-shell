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
    public object? AuditDetails => new { Id };
}

public class DeleteReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeleteReportScreenCommand>
{
    public async Task Handle(DeleteReportScreenCommand cmd, CancellationToken ct)
    {
        var screen = await repo.GetByIdWithWidgetsAsync(cmd.Id, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.Id);

        // Check Delete permission
        var isSuperadmin = currentUser.Role == "Superadmin";
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

        repo.Update(screen);
    }
}
