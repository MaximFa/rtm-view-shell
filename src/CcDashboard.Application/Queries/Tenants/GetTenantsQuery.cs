using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Tenants;
using MediatR;

namespace CcDashboard.Application.Queries.Tenants;

public record GetTenantsQuery : IRequest<IReadOnlyList<TenantDto>>;

public class GetTenantsQueryHandler(ITenantRepository repo)
    : IRequestHandler<GetTenantsQuery, IReadOnlyList<TenantDto>>
{
    public async Task<IReadOnlyList<TenantDto>> Handle(GetTenantsQuery _, CancellationToken ct)
    {
        var tenants = await repo.GetAllAsync(ct);
        return tenants.Select(t => new TenantDto(t.Id, t.Slug, t.Name, t.Status, t.CreatedAt, t.UpdatedAt)).ToList();
    }
}
