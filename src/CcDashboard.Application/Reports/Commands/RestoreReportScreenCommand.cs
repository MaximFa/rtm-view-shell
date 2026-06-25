using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Commands;

public record RestoreReportScreenCommand(Guid Id) : IRequest<ReportScreenDto>, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.Restored";
    public object? AuditDetails { get; private set; }

    public void SetAuditDetails(int schedulesLeftInactive) =>
        AuditDetails = new { Id, SchedulesLeftInactive = schedulesLeftInactive };
}

public class RestoreReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<RestoreReportScreenCommand, ReportScreenDto>
{
    public async Task<ReportScreenDto> Handle(RestoreReportScreenCommand cmd, CancellationToken ct)
    {
        // Only Superadmin can restore
        if (currentUser.Role != "Superadmin")
            throw new ForbiddenException("Only Superadmin can restore deleted screens");

        // Load with schedules to count inactive ones
        var screen = await repo.GetByIdWithWidgetsAndSchedulesAsync(cmd.Id, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.Id);

        if (!screen.IsDeleted)
            throw new DomainException("Screen is not deleted");

        screen.IsDeleted = false;
        screen.DeletedAt = null;
        screen.DeletedByUserId = null;
        screen.UpdatedAt = clock.UtcNow;
        screen.UpdatedByUserId = currentUser.UserId!.Value;

        // Restore widgets too
        foreach (var widget in screen.Widgets.Where(w => w.IsDeleted))
        {
            widget.IsDeleted = false;
        }

        // [REPORT-SCHED-02] Do NOT auto-reactivate schedules on restore
        // User must consciously re-enable — avoid surprise resumption of emails
        var schedulesLeftInactive = screen.Schedules.Count(s => !s.IsActive);
        cmd.SetAuditDetails(schedulesLeftInactive);

        repo.Update(screen);

        return new ReportScreenDto(
            screen.Id, screen.TenantId, screen.Name, screen.Description,
            screen.CategoryId, screen.Category?.Name, screen.Status, screen.IsPublic, screen.IsDarkMode,
            screen.CreatedByUserId, null, screen.CreatedAt,
            screen.UpdatedByUserId, null, screen.UpdatedAt,
            screen.RowVersion, 7);
    }
}
