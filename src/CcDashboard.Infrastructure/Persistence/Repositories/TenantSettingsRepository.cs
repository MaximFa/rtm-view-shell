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
        var existing = await db.TenantSettings.FindAsync([settings.TenantId], ct);
        if (existing is null)
            db.TenantSettings.Add(settings);
        else
        {
            existing.PasswordMinLength = settings.PasswordMinLength;
            existing.PasswordExpireDays = settings.PasswordExpireDays;
            existing.Require2faForAll = settings.Require2faForAll;
            existing.AuditRetentionDays = settings.AuditRetentionDays;
            existing.DefaultLocale = settings.DefaultLocale;
            existing.SoftDeleteDashboards = settings.SoftDeleteDashboards;
            existing.SoftDeleteRetentionDays = settings.SoftDeleteRetentionDays;
            db.TenantSettings.Update(existing);
        }
    }
}
