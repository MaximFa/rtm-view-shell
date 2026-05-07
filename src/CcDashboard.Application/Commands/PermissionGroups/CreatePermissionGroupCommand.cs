using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.PermissionGroups;

public record CreatePermissionGroupCommand(CreatePermissionGroupRequest Request)
    : IRequest<Result<Guid>>, ITransactional;

public class CreatePermissionGroupCommandHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreatePermissionGroupCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreatePermissionGroupCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var userId = currentUser.UserId!.Value;
        var now = clock.UtcNow;

        var group = new PermissionGroup
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Request.Name.Trim(),
            Description = cmd.Request.Description,
            IsActive = true,
            CreatedAt = now,
            CreatedByUserId = userId,
            UpdatedAt = now,
            UpdatedByUserId = userId,
        };

        foreach (var key in cmd.Request.MenuPermissions)
            group.MenuPermissions.Add(new MenuPermission { PermissionGroupId = group.Id, MenuKey = key, TenantId = tenantId });

        await repo.AddAsync(group, ct);
        return Result<Guid>.Success(group.Id);
    }
}
