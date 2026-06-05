using MediatR;

namespace CcDashboard.Application.Commands.Widgets;

public record SaveUserWidgetSettingsCommand(Guid WidgetId, string SettingsJson) : IRequest;
