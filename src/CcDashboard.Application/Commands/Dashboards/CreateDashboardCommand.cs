using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.Dashboards;

public record CreateDashboardCommand(CreateDashboardRequest Request) : IRequest<DashboardDto>, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.Created";
    public object? AuditDetails => new { Name = Request.Name };
}

public class CreateDashboardCommandHandler(
    IDashboardRepository dashboards,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateDashboardCommand, DashboardDto>
{
    public async Task<DashboardDto> Handle(CreateDashboardCommand cmd, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var userId = currentUser.UserId!.Value;
        // Superadmin can specify target tenant; otherwise use current user's tenant
        var tenantId = currentUser.Role == "Superadmin" && cmd.Request.TenantId.HasValue
            ? cmd.Request.TenantId.Value
            : currentUser.TenantId!.Value;

        var dashboard = new Dashboard
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Request.Name.Trim(),
            Description = cmd.Request.Description?.Trim(),
            CategoryId = cmd.Request.CategoryId,
            IsPublic = cmd.Request.IsPublic,
            CreatedByUserId = userId,
            UpdatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
        };

        await dashboards.AddAsync(dashboard, ct);

        // [PG-01] Creator's PG gets Full access automatically
        if (currentUser.PermissionGroupId.HasValue)
        {
            dashboard.Permissions.Add(new DashboardPermission
            {
                PermissionGroupId = currentUser.PermissionGroupId.Value,
                DashboardId = dashboard.Id,
                TenantId = tenantId,
                AccessLevel = 7,
            });
        }

        return MapToDto(dashboard);
    }

    private static DashboardDto MapToDto(Dashboard d) => new(
        d.Id, d.TenantId, null, d.Name, d.Description, d.CategoryId, null, d.Status, d.IsPublic, d.IsDarkMode,
        d.CreatedByUserId, null, d.CreatedAt, d.UpdatedByUserId, null, d.UpdatedAt);
}
