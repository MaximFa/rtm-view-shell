using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.PermissionGroups;

public record GetPermissionGroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<PermissionGroupDto>>;

public class GetPermissionGroupsQueryHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetPermissionGroupsQuery, IReadOnlyList<PermissionGroupDto>>
{
    public async Task<IReadOnlyList<PermissionGroupDto>> Handle(GetPermissionGroupsQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.Role == "Superadmin"
            ? query.TenantId
            : (query.TenantId ?? currentUser.TenantId!.Value);
        var groups = await repo.GetAllByTenantAsync(tenantId, ct);

        return groups.Select(g => new PermissionGroupDto(
            g.Id, g.TenantId, g.Name, g.Description, g.IsActive,
            UserCount: 0,
            MenuPermissions:       g.MenuPermissions.Select(m => m.MenuKey).ToList(),
            AllowedQueueIds:       g.AllowedQueues.Select(q => q.ObjectId).ToList(),
            AllowedSkillIds:       g.AllowedSkills.Select(s => s.ObjectId).ToList(),
            AllowedSupergroupIds:  g.AllowedSupergroups.Select(s => s.ObjectId).ToList(),
            AllowedBusinessUnitIds: g.AllowedBusinessUnits.Select(b => b.ObjectId).ToList(),
            g.CreatedAt, g.UpdatedAt, g.RowVersion)).ToList();
    }
}
