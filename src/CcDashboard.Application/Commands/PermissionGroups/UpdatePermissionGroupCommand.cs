using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.PermissionGroups;

public record UpdatePermissionGroupCommand(UpdatePermissionGroupRequest Request)
    : IRequest<Result>, ITransactional;

public class UpdatePermissionGroupCommandHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock,
    ICacheService cache)
    : IRequestHandler<UpdatePermissionGroupCommand, Result>
{
    public async Task<Result> Handle(UpdatePermissionGroupCommand cmd, CancellationToken ct)
    {
        var req = cmd.Request;
        var group = await repo.GetByIdAsync(req.Id, ct)
                   ?? throw new NotFoundException(nameof(PermissionGroup), req.Id);

        group.Name = req.Name.Trim();
        group.Description = req.Description;
        group.IsActive = req.IsActive;
        group.UpdatedAt = clock.UtcNow;
        group.UpdatedByUserId = currentUser.UserId!.Value;

        // Replace menu permissions
        group.MenuPermissions.Clear();
        foreach (var key in req.MenuPermissions)
            group.MenuPermissions.Add(new MenuPermission
            {
                PermissionGroupId = group.Id,
                MenuKey = key,
                TenantId = group.TenantId
            });

        repo.Update(group);

        // [PG-07] Invalidate cached permissions so active sessions re-fetch on next interaction
        await cache.RemoveAsync($"{group.TenantId}:pg_permissions:{group.Id}", ct);

        return Result.Success();
    }
}
