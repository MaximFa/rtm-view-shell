using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Exceptions;
using MediatR;

namespace CcDashboard.Application.Commands.WidgetTemplates;

public record DeleteWidgetTemplateCommand(Guid TemplateId) : IRequest<Unit>, ITransactional;

public class DeleteWidgetTemplateCommandHandler(IWidgetTemplateRepository templates)
    : IRequestHandler<DeleteWidgetTemplateCommand, Unit>
{
    public async Task<Unit> Handle(DeleteWidgetTemplateCommand cmd, CancellationToken ct)
    {
        var template = await templates.GetByIdAsync(cmd.TemplateId, ct)
            ?? throw new NotFoundException("WidgetTemplate", cmd.TemplateId);

        templates.Remove(template);

        return Unit.Value;
    }
}
