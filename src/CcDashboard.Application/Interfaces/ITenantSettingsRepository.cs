using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface ITenantSettingsRepository
{
    Task<TenantSettings?> GetByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task UpsertAsync(TenantSettings settings, CancellationToken ct = default);
}
