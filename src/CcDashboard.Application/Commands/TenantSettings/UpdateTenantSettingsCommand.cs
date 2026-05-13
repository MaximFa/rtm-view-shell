using System.Text.Json;
using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.TenantSettings;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.TenantSettings;

public record UpdateTenantSettingsCommand(UpdateTenantSettingsRequest Request, Guid? TenantId = null) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "TenantSettings.Updated";
}

public class UpdateTenantSettingsCommandHandler(
    ITenantSettingsRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<UpdateTenantSettingsCommand>
{
    public async Task Handle(UpdateTenantSettingsCommand cmd, CancellationToken ct)
    {
        var tenantId = cmd.TenantId ?? currentUser.TenantId!.Value;
        var settings = await repo.GetByTenantAsync(tenantId, ct) ?? new Domain.Domain.TenantSettings { TenantId = tenantId };

        var r = cmd.Request;
        settings.PasswordMinLength = Math.Clamp(r.PasswordMinLength, 8, 128);
        settings.PasswordExpireDays = Math.Clamp(r.PasswordExpireDays, 1, 3650);
        settings.Require2faForAll = r.Require2faForAll;
        settings.AuditRetentionDays = Math.Clamp(r.AuditRetentionDays, 30, 3650);
        settings.DefaultLocale = r.DefaultLocale?.Trim().Substring(0, Math.Min(10, r.DefaultLocale.Length)) ?? "en-US";
        settings.SoftDeleteDashboards = r.SoftDeleteDashboards;
        settings.SoftDeleteRetentionDays = Math.Clamp(r.SoftDeleteRetentionDays, 1, 365);
        settings.PurchasedLicences = Math.Max(0, r.PurchasedLicences);
        settings.MaxConcurrentConnections = Math.Max(0, r.MaxConcurrentConnections);
        settings.SignalRConnectionUrl = string.IsNullOrWhiteSpace(r.SignalRConnectionUrl) ? null : r.SignalRConnectionUrl.Trim();

        // Appearance settings
        settings.BackgroundColorPalette = SerializeList(r.BackgroundColorPalette);
        settings.FontColorPalette = SerializeList(r.FontColorPalette);
        settings.FontSizes = SerializeList(r.FontSizes);

        await repo.UpsertAsync(settings, ct);
    }

    private static string? SerializeList(List<string>? list)
    {
        if (list is null || list.Count == 0) return null;
        return JsonSerializer.Serialize(list);
    }
}
