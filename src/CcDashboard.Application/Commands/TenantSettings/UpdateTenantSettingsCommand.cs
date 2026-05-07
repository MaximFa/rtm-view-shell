using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.TenantSettings;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.TenantSettings;

public record UpdateTenantSettingsCommand(UpdateTenantSettingsRequest Request) : IRequest, ITransactional;

public class UpdateTenantSettingsCommandHandler(
    ITenantSettingsRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<UpdateTenantSettingsCommand>
{
    public async Task Handle(UpdateTenantSettingsCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var settings = await repo.GetByTenantAsync(tenantId, ct) ?? new Domain.Domain.TenantSettings { TenantId = tenantId };

        var r = cmd.Request;
        settings.PasswordMinLength = Math.Max(8, r.PasswordMinLength);
        settings.PasswordExpireDays = Math.Max(1, r.PasswordExpireDays);
        settings.Require2faForAll = r.Require2faForAll;
        settings.AuditRetentionDays = Math.Max(30, r.AuditRetentionDays);
        settings.DefaultLocale = r.DefaultLocale;
        settings.SoftDeleteDashboards = r.SoftDeleteDashboards;
        settings.SoftDeleteRetentionDays = Math.Max(1, r.SoftDeleteRetentionDays);

        await repo.UpsertAsync(settings, ct);
    }
}
