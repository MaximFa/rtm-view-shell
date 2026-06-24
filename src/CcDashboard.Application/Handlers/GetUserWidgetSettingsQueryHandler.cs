using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Widgets;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Handlers;

public sealed class GetUserWidgetSettingsQueryHandler(
    IAppDbContextFactory dbFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetUserWidgetSettingsQuery, string?>
{
    public async Task<string?> Handle(GetUserWidgetSettingsQuery query, CancellationToken ct)
    {
        if (currentUser.UserId is null) return null;

        await using var db = await dbFactory.CreateDbContextAsync(ct);
        var row = await db.UserWidgetSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == query.WidgetId,
                ct);
        return row?.SettingsJson;
    }
}
