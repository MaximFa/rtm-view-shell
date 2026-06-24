using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Commands;

public record UpdateReportScreenCommand(UpdateReportScreenRequest Request) : IRequest<ReportScreenDto>, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.Updated";
    public object? AuditDetails => new { Id = Request.Id, Name = Request.Name };
}

public class UpdateReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateReportScreenCommand, ReportScreenDto>
{
    public async Task<ReportScreenDto> Handle(UpdateReportScreenCommand cmd, CancellationToken ct)
    {
        var screen = await repo.GetByIdAsync(cmd.Request.Id, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.Request.Id);

        // Check Edit permission
        var isSuperadmin = currentUser.Role == "Superadmin";
        if (!isSuperadmin)
        {
            var accessLevel = await repo.GetUserAccessLevelAsync(
                screen.Id, currentUser.PermissionGroupId, screen.IsPublic, isSuperadmin, ct);
            if ((accessLevel & 2) == 0) // Edit = 2
                throw new ForbiddenException("Edit permission required");
        }

        screen.Name = cmd.Request.Name.Trim();
        screen.Description = cmd.Request.Description?.Trim();
        screen.CategoryId = cmd.Request.CategoryId;
        screen.Status = cmd.Request.Status;
        screen.IsPublic = cmd.Request.IsPublic;
        screen.IsDarkMode = cmd.Request.IsDarkMode;
        screen.LayoutJson = cmd.Request.LayoutJson;
        screen.UpdatedAt = clock.UtcNow;
        screen.UpdatedByUserId = currentUser.UserId!.Value;

        repo.Update(screen);

        return new ReportScreenDto(
            screen.Id, screen.TenantId, screen.Name, screen.Description,
            screen.CategoryId, screen.Category?.Name, screen.Status, screen.IsPublic, screen.IsDarkMode,
            screen.CreatedByUserId, null, screen.CreatedAt,
            screen.UpdatedByUserId, null, screen.UpdatedAt,
            screen.RowVersion);
    }
}
