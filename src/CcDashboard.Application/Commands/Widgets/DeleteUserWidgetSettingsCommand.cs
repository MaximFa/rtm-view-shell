using MediatR;

namespace CcDashboard.Application.Commands.Widgets;

public record DeleteUserWidgetSettingsCommand(Guid WidgetId) : IRequest;
