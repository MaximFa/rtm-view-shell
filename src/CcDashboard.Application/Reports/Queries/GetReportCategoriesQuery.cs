using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Reports.Queries;

public record GetReportCategoriesQuery : IRequest<IReadOnlyList<ReportCategoryDto>>;

public class GetReportCategoriesQueryHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetReportCategoriesQuery, IReadOnlyList<ReportCategoryDto>>
{
    public async Task<IReadOnlyList<ReportCategoryDto>> Handle(GetReportCategoriesQuery request, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var categories = await repo.GetCategoriesAsync(tenantId, ct);

        return categories
            .Select(c => new ReportCategoryDto(c.Id, c.Name, c.IsActive))
            .ToList();
    }
}
