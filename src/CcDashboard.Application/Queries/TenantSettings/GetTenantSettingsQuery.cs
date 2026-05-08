using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.TenantSettings;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.TenantSettings;

public record GetTenantSettingsQuery(Guid? TenantId = null) : IRequest<TenantSettingsDto?>;

public class GetTenantSettingsQueryHandler(
    ITenantSettingsRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetTenantSettingsQuery, TenantSettingsDto?>
{
    public async Task<TenantSettingsDto?> Handle(GetTenantSettingsQuery query, CancellationToken ct)
    {
        var tenantId = query.TenantId ?? currentUser.TenantId!.Value;
        var s = await repo.GetByTenantAsync(tenantId, ct);
        if (s is null) return null;

        return new TenantSettingsDto(
            s.TenantId, s.PasswordMinLength, s.PasswordExpireDays,
            s.Require2faForAll, s.AuditRetentionDays, s.DefaultLocale,
            s.SoftDeleteDashboards, s.SoftDeleteRetentionDays);
    }
}
