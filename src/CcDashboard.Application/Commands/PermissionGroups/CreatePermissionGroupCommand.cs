using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.PermissionGroups;

public record CreatePermissionGroupCommand(CreatePermissionGroupRequest Request, Guid? TenantId = null)
    : IRequest<Result<Guid>>, ITransactional, IAuditable
{
    public string AuditEventType => "PermissionGroup.Created";
    public object? AuditDetails => new { Name = Request.Name };
}

public class CreatePermissionGroupCommandHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreatePermissionGroupCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreatePermissionGroupCommand cmd, CancellationToken ct)
    {
        var tenantId = cmd.TenantId ?? currentUser.TenantId!.Value;
        var userId = currentUser.UserId!.Value;
        var now = clock.UtcNow;
        var req = cmd.Request;

        var group = new PermissionGroup
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = req.Name.Trim(),
            Description = req.Description?.Trim(),
            IsActive = true,
            CreatedAt = now,
            CreatedByUserId = userId,
            UpdatedAt = now,
            UpdatedByUserId = userId,
        };

        foreach (var key in req.MenuPermissions)
            group.MenuPermissions.Add(new MenuPermission { PermissionGroupId = group.Id, MenuKey = key, TenantId = tenantId });

        foreach (var id in req.AllowedQueueIds ?? [])
            group.AllowedQueues.Add(new PgQueue { PermissionGroupId = group.Id, ObjectId = id, TenantId = tenantId });

        foreach (var id in req.AllowedSkillIds ?? [])
            group.AllowedSkills.Add(new PgSkill { PermissionGroupId = group.Id, ObjectId = id, TenantId = tenantId });

        foreach (var id in req.AllowedSupergroupIds ?? [])
            group.AllowedSupergroups.Add(new PgAgentSupergroup { PermissionGroupId = group.Id, ObjectId = id, TenantId = tenantId });

        foreach (var id in req.AllowedBusinessUnitIds ?? [])
            group.AllowedBusinessUnits.Add(new PgBusinessUnit { PermissionGroupId = group.Id, ObjectId = id, TenantId = tenantId });

        await repo.AddAsync(group, ct);
        return Result<Guid>.Success(group.Id);
    }
}
