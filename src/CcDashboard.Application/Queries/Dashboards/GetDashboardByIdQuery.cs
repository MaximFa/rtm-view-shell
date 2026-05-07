using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using MediatR;

namespace CcDashboard.Application.Queries.Dashboards;

public record GetDashboardByIdQuery(Guid Id) : IRequest<DashboardDto?>;

public class GetDashboardByIdQueryHandler(IDashboardRepository repo)
    : IRequestHandler<GetDashboardByIdQuery, DashboardDto?>
{
    public async Task<DashboardDto?> Handle(GetDashboardByIdQuery request, CancellationToken ct)
    {
        var d = await repo.GetByIdAsync(request.Id, ct);
        if (d is null) return null;

        return new DashboardDto(
            d.Id, d.TenantId, d.Name, d.Description, d.Status,
            d.IsPublic, d.CreatedByUserId, null, d.CreatedAt, d.UpdatedAt,
            d.RowVersion);
    }
}
