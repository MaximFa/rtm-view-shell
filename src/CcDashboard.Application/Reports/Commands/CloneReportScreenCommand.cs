using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentValidation;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Reports.Commands;

public record CloneReportScreenCommand(Guid SourceId) : IRequest<ReportScreenDto>, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.Cloned";
    public object? AuditDetails { get; private set; }

    public void SetNewId(Guid newId) => AuditDetails = new { SourceId, NewId = newId };
}

public class CloneReportScreenCommandValidator : AbstractValidator<CloneReportScreenCommand>
{
    public CloneReportScreenCommandValidator()
    {
        RuleFor(x => x.SourceId)
            .NotEmpty()
            .WithMessage("SourceId is required");
    }
}

public class CloneReportScreenCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CloneReportScreenCommand, ReportScreenDto>
{
    public async Task<ReportScreenDto> Handle(CloneReportScreenCommand cmd, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var userId = currentUser.UserId!.Value;
        var tenantId = currentUser.TenantId!.Value;
        var isSuperadmin = currentUser.Role == "Superadmin";

        // 1. Load source screen with widgets (bypass GQF for Superadmin cross-tenant)
        var source = await repo.GetByIdWithWidgetsAsync(cmd.SourceId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.SourceId);

        // Tenant isolation: source must belong to current tenant (GQF enforces this, but double-check)
        if (source.TenantId != tenantId && !isSuperadmin)
            throw new NotFoundException(nameof(ReportScreen), cmd.SourceId);

        // 2. Check View permission on source (can only clone what you can see)
        if (!isSuperadmin)
        {
            var accessLevel = await repo.GetUserAccessLevelAsync(
                source.Id, currentUser.PermissionGroupId, source.IsPublic, isSuperadmin, ct);
            if ((accessLevel & 1) == 0) // View = 1
                throw new ForbiddenException("View permission required on source screen");
        }

        // 3. Create new screen (deep copy)
        var newScreen = new ReportScreen
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = source.Name + " (copy)",
            Description = source.Description,
            CategoryId = source.CategoryId,
            IsPublic = source.IsPublic,
            IsDarkMode = source.IsDarkMode,
            LayoutJson = source.LayoutJson,
            Status = ReportScreenStatus.Draft, // Always Draft for cloned
            CreatedByUserId = userId,
            UpdatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
        };

        await repo.AddAsync(newScreen, ct);

        // 4. [PG-01] Cloner's PG gets Full access automatically
        if (currentUser.PermissionGroupId.HasValue)
        {
            newScreen.Permissions.Add(new ReportPermission
            {
                PermissionGroupId = currentUser.PermissionGroupId.Value,
                ReportScreenId = newScreen.Id,
                TenantId = tenantId,
                AccessLevel = 7, // Full = View + Edit + Delete
            });
        }

        // 5. Copy ALL non-deleted widgets with new IDs
        foreach (var sourceWidget in source.Widgets.Where(w => !w.IsDeleted))
        {
            var newWidget = new ReportWidget
            {
                Id = Uuid.NewSequential(),
                ReportScreenId = newScreen.Id,
                TenantId = tenantId,
                WidgetType = sourceWidget.WidgetType,
                PositionJson = sourceWidget.PositionJson,
                ConfigJson = sourceWidget.ConfigJson,
                IsDeleted = false
            };
            await repo.AddWidgetAsync(newWidget, ct);
        }

        // Set audit details with new ID
        cmd.SetNewId(newScreen.Id);

        return new ReportScreenDto(
            newScreen.Id, newScreen.TenantId, newScreen.Name, newScreen.Description,
            newScreen.CategoryId, source.Category?.Name, newScreen.Status, newScreen.IsPublic, newScreen.IsDarkMode,
            newScreen.CreatedByUserId, null, newScreen.CreatedAt,
            newScreen.UpdatedByUserId, null, newScreen.UpdatedAt,
            newScreen.RowVersion, 7);
    }
}
