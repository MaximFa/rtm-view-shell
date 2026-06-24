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
    public object? AuditDetails => new { Id };
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

        var screen = await repo.GetByIdWithWidgetsAsync(cmd.Id, ct)
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

        repo.Update(screen);

        return new ReportScreenDto(
            screen.Id, screen.TenantId, screen.Name, screen.Description,
            screen.CategoryId, screen.Category?.Name, screen.Status, screen.IsPublic, screen.IsDarkMode,
            screen.CreatedByUserId, null, screen.CreatedAt,
            screen.UpdatedByUserId, null, screen.UpdatedAt,
            screen.RowVersion, 7);
    }
}
