using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class TenantSettingsRepository(AppDbContext db) : ITenantSettingsRepository
{
    public Task<TenantSettings?> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
        => db.TenantSettings.FirstOrDefaultAsync(s => s.TenantId == tenantId, ct);

    public async Task UpsertAsync(TenantSettings settings, CancellationToken ct = default)
    {
        var entry = db.Entry(settings);
        if (entry.State != EntityState.Detached)
            return; // already tracked — TransactionBehavior's SaveChanges will persist changes

        var exists = await db.TenantSettings.IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == settings.TenantId, ct);
        if (exists)
            db.TenantSettings.Update(settings);
        else
            db.TenantSettings.Add(settings);
    }
}
