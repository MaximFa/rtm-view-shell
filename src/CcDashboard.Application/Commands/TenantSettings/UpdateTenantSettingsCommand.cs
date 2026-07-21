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

        // WFM Phase 1 config (spec §5)
        settings.WfmServingStateGroups = (r.WfmServingStateGroups is { Count: > 0 }) ? r.WfmServingStateGroups.ToArray() : settings.WfmServingStateGroups;
        settings.WfmWindowMinutes = Math.Clamp(r.WfmWindowMinutes, 1, 1440);
        settings.WfmSlTargetPct = Math.Clamp(r.WfmSlTargetPct, 1, 100);
        settings.WfmSlThresholdSec = Math.Clamp(r.WfmSlThresholdSec, 1, 3600);
        settings.WfmTrunkCapacity = Math.Clamp(r.WfmTrunkCapacity, 1, 100000);
        settings.WfmDefaultShrinkage = Math.Clamp(r.WfmDefaultShrinkage, 0.0, 0.95);
        settings.WfmEnableRealtime = r.WfmEnableRealtime;
        settings.WfmThresholds = NormalizeJsonOrNull(r.WfmThresholds);

        await repo.UpsertAsync(settings, ct);
    }

    private static string? SerializeList(List<string>? list)
    {
        if (list is null || list.Count == 0) return null;
        return JsonSerializer.Serialize(list);
    }

    private static string? NormalizeJsonOrNull(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        var trimmed = json.Trim();
        if (string.IsNullOrEmpty(trimmed)) return null;
        // Validate JSON structure
        try
        {
            using var doc = JsonDocument.Parse(trimmed);
            return trimmed;
        }
        catch (JsonException ex)
        {
            throw new FluentValidation.ValidationException($"Invalid JSON in WfmThresholds: {ex.Message}");
        }
    }
}
