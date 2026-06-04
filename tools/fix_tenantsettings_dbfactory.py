#!/usr/bin/env python3
"""Fix TenantSettingsRepository - use IDbContextFactory for concurrent read safety."""

import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\Persistence\Repositories\TenantSettingsRepository.cs"

new_content = '''using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class TenantSettingsRepository(
    AppDbContext db,
    IDbContextFactory<AppDbContext> dbFactory) : ITenantSettingsRepository
{
    // Read-only: uses a fresh context per call to avoid concurrent DbContext errors
    // when multiple Blazor widgets call GetTenantSettingsQuery simultaneously.
    public async Task<TenantSettings?> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        await using var ctx = await dbFactory.CreateDbContextAsync(ct);
        return await ctx.TenantSettings.FirstOrDefaultAsync(s => s.TenantId == tenantId, ct);
    }

    public async Task UpsertAsync(TenantSettings settings, CancellationToken ct = default)
    {
        // Write path: uses the scoped db to participate in the circuit's transaction.
        var entry = db.Entry(settings);
        if (entry.State != EntityState.Detached)
            return; // already tracked - TransactionBehavior's SaveChanges will persist changes

        var exists = await db.TenantSettings.IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == settings.TenantId, ct);
        if (exists)
            db.TenantSettings.Update(settings);
        else
            db.TenantSettings.Add(settings);
    }
}
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)
    f.flush()
    os.fsync(f.fileno())

print("Done: TenantSettingsRepository.cs (%d lines)" % (new_content.count('\n') + 1))
