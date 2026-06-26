using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Reports.Commands;

public record CreateReportScreenCommand(CreateReportScreenRequest Request, Guid? TenantId = null) : IRequest<ReportScreenDto>, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.Created";
    public object? AuditDetails => new { Name = Request.Name };
}

public class CreateReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateReportScreenCommand, ReportScreenDto>
{
    public async Task<ReportScreenDto> Handle(CreateReportScreenCommand cmd, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var userId = currentUser.UserId!.Value;
        // Superadmin-gated tenant resolution: non-Superadmin's TenantId param IGNORED (own tenant only)
        var tenantId = currentUser.Role == "Superadmin"
            ? (cmd.TenantId ?? currentUser.TenantId!.Value)   // SA: page-selected tenant; null (All-Tenants) → session
            : currentUser.TenantId!.Value;                     // non-SA: own tenant, param IGNORED

        var screen = new ReportScreen
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Request.Name.Trim(),
            Description = cmd.Request.Description?.Trim(),
            CategoryId = cmd.Request.CategoryId,
            IsPublic = cmd.Request.IsPublic,
            IsDarkMode = cmd.Request.IsDarkMode,
            Status = ReportScreenStatus.Draft,
            CreatedByUserId = userId,
            UpdatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
        };

        await repo.AddAsync(screen, ct);

        // [PG-01] Creator's PG gets Full access automatically
        if (currentUser.PermissionGroupId.HasValue)
        {
            screen.Permissions.Add(new ReportPermission
            {
                PermissionGroupId = currentUser.PermissionGroupId.Value,
                ReportScreenId = screen.Id,
                TenantId = tenantId,
                AccessLevel = 7, // Full = View + Edit + Delete
            });
        }

        return new ReportScreenDto(
            screen.Id, screen.TenantId, screen.Name, screen.Description,
            screen.CategoryId, null, screen.Status, screen.IsPublic, screen.IsDarkMode,
            screen.CreatedByUserId, null, screen.CreatedAt,
            screen.UpdatedByUserId, null, screen.UpdatedAt,
            screen.RowVersion, 7);
    }
}
