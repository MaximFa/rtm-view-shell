using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Commands;

/// <summary>
/// Permanently deletes a soft-deleted (Trash) report screen and all related entities.
/// Only works on IsDeleted=true screens. Requires Delete permission or Superadmin.
/// </summary>
public record PurgeReportScreenCommand(Guid Id) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.PermanentlyDeleted";
    public object? AuditDetails { get; private set; }

    public void SetAuditDetails(string name, int widgetCount, int scheduleCount, int permissionCount) =>
        AuditDetails = new { Id, Name = name, WidgetCount = widgetCount, ScheduleCount = scheduleCount, PermissionCount = permissionCount };
}

public class PurgeReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<PurgeReportScreenCommand>
{
    public async Task Handle(PurgeReportScreenCommand cmd, CancellationToken ct)
    {
        // Load with IgnoreQueryFilters — Trash items have IsDeleted=true, hidden by GQF
        var screen = await repo.GetByIdForPurgeAsync(cmd.Id, currentUser.TenantId!.Value, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.Id);

        // GUARD: only purge IsDeleted==true (Trash items)
        if (!screen.IsDeleted)
            throw new DomainException("Cannot permanently delete a live screen. Soft-delete it first.");

        // PERMISSION (CODE-03, non-bypassable): Delete permission or Superadmin
        var isSuperadmin = currentUser.Role == "Superadmin";
        if (!isSuperadmin)
        {
            var accessLevel = await repo.GetUserAccessLevelAsync(
                screen.Id, currentUser.PermissionGroupId, screen.IsPublic, isSuperadmin, ct);
            if ((accessLevel & 4) == 0) // Delete = 4
                throw new ForbiddenException("Delete permission required to permanently delete");
        }

        // Capture counts BEFORE delete for audit
        cmd.SetAuditDetails(
            screen.Name,
            screen.Widgets.Count,
            screen.Schedules.Count,
            screen.Permissions.Count);

        // PHYSICAL delete — cascade-agnostic, explicit removal
        await repo.PurgeAsync(screen, ct);
    }
}
