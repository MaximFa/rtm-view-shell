using CcDashboard.Application.Interfaces;
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

        // The instance we are given comes from GetByTenantAsync, which deliberately reads through a
        // FRESH context (see above), so it is detached from this scoped one. If the scoped context
        // is ALREADY tracking a different instance of the same TenantSettings, Update() throws
        // "another instance with the same key value for {'TenantId'} is already being tracked" -
        // which is exactly what the operator hit on 234 (15.10).
        //
        // That is not hypothetical. The surest source is THIS method: on the first save in a circuit
        // the Update() below attaches the instance, and it stays tracked after SaveChanges. The scoped
        // context lives as long as the circuit, so the SECOND save of tenant settings in the same
        // circuit (TenantsPage.razor SaveEdit, TenantSettingsPage.razor) used to throw every time.
        // Another in-circuit source is UserManagementService.CreateAsync (tracked SELECT ... FOR UPDATE).
        // The sign-in reads in IdentityAuthService run in the HTTP request of the login page, not in
        // the admin circuit. The write path has to be safe on its own, whoever tracked first.
        //
        // So: copy the values INTO the tracked instance instead of attaching a second one. The
        // tracked entity is the one SaveChanges will write, and CurrentValues.SetValues copies the
        // scalar properties by name - which is all TenantSettings has.
        var tracked = db.ChangeTracker.Entries<TenantSettings>()
            .FirstOrDefault(e => e.Entity.TenantId == settings.TenantId);

        if (tracked is not null)
        {
            tracked.CurrentValues.SetValues(settings);
            return;
        }

        var exists = await db.TenantSettings.IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == settings.TenantId, ct);
        if (exists)
            db.TenantSettings.Update(settings);
        else
            db.TenantSettings.Add(settings);
    }
}
