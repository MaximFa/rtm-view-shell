using CcDashboard.Application.Commands.Widgets;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Handlers;

public sealed class DeleteUserWidgetSettingsCommandHandler(
    IAppDbContextFactory dbFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<DeleteUserWidgetSettingsCommand>
{
    public async Task Handle(DeleteUserWidgetSettingsCommand cmd, CancellationToken ct)
    {
        if (currentUser.UserId is null) return;

        await using var db = await dbFactory.CreateDbContextAsync(ct);
        var row = await db.UserWidgetSettings
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == cmd.WidgetId,
                ct);
        if (row is not null)
        {
            db.UserWidgetSettings.Remove(row);
            await db.SaveChangesAsync(ct);
        }
    }
}
