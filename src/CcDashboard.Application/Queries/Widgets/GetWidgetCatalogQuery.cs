using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Widgets;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Widgets;

public record GetWidgetCatalogQuery(bool IncludeInactive = false) : IRequest<IReadOnlyList<WidgetCatalogCategoryDto>>;

public class GetWidgetCatalogQueryHandler(IWidgetCatalogRepository repo, ICurrentUserAccessor currentUser)
    : IRequestHandler<GetWidgetCatalogQuery, IReadOnlyList<WidgetCatalogCategoryDto>>
{
    public async Task<IReadOnlyList<WidgetCatalogCategoryDto>> Handle(GetWidgetCatalogQuery query, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var items = isSuperadmin && query.IncludeInactive
            ? await repo.GetAllAsync(ct)
            : await repo.GetAllActiveAsync(ct);

        return items
            .GroupBy(i => i.Category)
            .Select(g => new WidgetCatalogCategoryDto(
                g.Key,
                g.Select(i => new WidgetCatalogItemDto(i.Id, i.Category, i.Name, i.Description, i.IconUrl, i.IsActive))
                 .ToList()))
            .ToList();
    }
}
