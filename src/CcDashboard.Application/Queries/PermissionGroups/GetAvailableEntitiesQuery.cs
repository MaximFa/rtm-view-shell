using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.PermissionGroups;

public record AvailableEntityDto(Guid Id, string Name);
public record AvailableEntityIntDto(int Id, string Name);

public record AvailableEntitiesResult(
    IReadOnlyList<AvailableEntityDto> Dashboards,
    IReadOnlyList<AvailableEntityDto> Queues,
    IReadOnlyList<AvailableEntityDto> AgentGroups,
    IReadOnlyList<AvailableEntityIntDto> BusinessUnits,
    IReadOnlyList<AvailableEntityIntDto> Supergroups);

public record GetAvailableEntitiesQuery(Guid TenantId) : IRequest<AvailableEntitiesResult>;

public class GetAvailableEntitiesQueryHandler(
    IPermissionGroupRepository pgRepo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAvailableEntitiesQuery, AvailableEntitiesResult>
{
    public async Task<AvailableEntitiesResult> Handle(GetAvailableEntitiesQuery query, CancellationToken ct)
    {
        // For Superadmin: return all entities in the tenant
        // For Admin: return only entities that the admin's own PG has access to
        var isSuperadmin = currentUser.Role == "Superadmin";

        if (isSuperadmin)
        {
            return await pgRepo.GetAllEntitiesForTenantAsync(query.TenantId, ct);
        }
        else
        {
            var adminPgId = currentUser.PermissionGroupId;
            if (adminPgId == null)
                return new AvailableEntitiesResult([], [], [], [], []);

            return await pgRepo.GetEntitiesForPermissionGroupAsync(adminPgId.Value, query.TenantId, ct);
        }
    }
}
