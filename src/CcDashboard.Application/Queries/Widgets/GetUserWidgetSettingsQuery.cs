using MediatR;

namespace CcDashboard.Application.Queries.Widgets;

public record GetUserWidgetSettingsQuery(Guid WidgetId) : IRequest<string?>;
