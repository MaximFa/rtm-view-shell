using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.WidgetTemplates;

public record CreateWidgetTemplateCommand(
    string Name,
    Guid WidgetCatalogItemId,
    string? ConfigJson) : IRequest<WidgetTemplateDto>, ITransactional;

public record WidgetTemplateDto(
    Guid Id,
    string Name,
    Guid WidgetCatalogItemId,
    string? WidgetCategory,
    string? WidgetName,
    string? ConfigJson,
    DateTime CreatedAt);

public class CreateWidgetTemplateCommandHandler(
    IWidgetTemplateRepository templates,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateWidgetTemplateCommand, WidgetTemplateDto>
{
    public async Task<WidgetTemplateDto> Handle(CreateWidgetTemplateCommand cmd, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var tenantId = currentUser.TenantId!.Value;
        var userId = currentUser.UserId!.Value;

        var template = new WidgetTemplate
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Name.Trim(),
            WidgetCatalogItemId = cmd.WidgetCatalogItemId,
            ConfigJson = cmd.ConfigJson,
            CreatedByUserId = userId,
            CreatedAt = now
        };

        await templates.AddAsync(template, ct);

        return new WidgetTemplateDto(
            template.Id,
            template.Name,
            template.WidgetCatalogItemId,
            null,
            null,
            template.ConfigJson,
            template.CreatedAt);
    }
}
