using CcDashboard.Application.Commands.Widgets;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Infrastructure.Handlers;

public sealed class SaveUserWidgetSettingsCommandHandler(
    IDbContextFactory<AppDbContext> dbFactory,
    ICurrentUserAccessor currentUser,
    ITenantContext tenantContext,
    IDateTimeProvider clock)
    : IRequestHandler<SaveUserWidgetSettingsCommand>
{
    public async Task Handle(SaveUserWidgetSettingsCommand cmd, CancellationToken ct)
    {
        if (currentUser.UserId is null) return;

        await using var db = await dbFactory.CreateDbContextAsync(ct);

        var existing = await db.UserWidgetSettings
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == cmd.WidgetId,
                ct);

        if (existing is null)
        {
            db.UserWidgetSettings.Add(new UserWidgetSettings
            {
                Id           = Uuid.NewSequential(),
                TenantId     = tenantContext.TenantId,
                UserId       = currentUser.UserId.Value,
                WidgetId     = cmd.WidgetId,
                SettingsJson = cmd.SettingsJson,
                CreatedAt    = clock.UtcNow,
                UpdatedAt    = clock.UtcNow
            });
        }
        else
        {
            existing.SettingsJson = cmd.SettingsJson;
            existing.UpdatedAt    = clock.UtcNow;
        }

        await db.SaveChangesAsync(ct);
    }
}
