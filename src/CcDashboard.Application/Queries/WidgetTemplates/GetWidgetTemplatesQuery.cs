using CcDashboard.Application.Commands.WidgetTemplates;
using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.WidgetTemplates;

public record GetWidgetTemplatesQuery : IRequest<IReadOnlyList<WidgetTemplateDto>>;

public class GetWidgetTemplatesQueryHandler(IWidgetTemplateRepository templates)
    : IRequestHandler<GetWidgetTemplatesQuery, IReadOnlyList<WidgetTemplateDto>>
{
    public async Task<IReadOnlyList<WidgetTemplateDto>> Handle(GetWidgetTemplatesQuery query, CancellationToken ct)
    {
        var items = await templates.GetAllAsync(ct);

        return items.Select(t => new WidgetTemplateDto(
            t.Id,
            t.Name,
            t.WidgetCatalogItemId,
            t.CatalogItem?.Category,
            t.CatalogItem?.Name,
            t.ConfigJson,
            t.CreatedAt)).ToList();
    }
}
