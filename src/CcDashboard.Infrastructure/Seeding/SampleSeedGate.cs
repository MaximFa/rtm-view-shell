using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Seeding;

/// <summary>
/// Gate for sample/test CC data seeding — prod-mirror rebuild-safety (Prod-Mirror-Seed-Plan §3).
/// </summary>
public static class SampleSeedGate
{
    /// <summary>
    /// True only when sample/test CC data should be seeded: the Seed:SampleData flag is on
    /// AND no real CC data already exists for the tenant (prod-mirror rebuild-safety).
    /// Data-presence is the de-facto provenance sentinel (FORK1=B — no seed_provenance table).
    /// </summary>
    public static async Task<bool> ShouldSeedAsync(
        bool seedSampleData, BackendEmulationDbContext beDb, Guid tenantId, CancellationToken ct)
    {
        if (!seedSampleData) return false;                 // PRIMARY gate: flag off -> never seed sample

        // BELT: any real CC data for this tenant (prod-mirror re-stamped to OUR tenant, FORK2=2.4b) -> skip
        var hasRealData =
            await beDb.NgcQueues.IgnoreQueryFilters().AnyAsync(q => q.TenantId == tenantId, ct)
            || await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenantId, ct)
            || await beDb.NgcBusinessUnits.IgnoreQueryFilters().AnyAsync(b => b.TenantId == tenantId, ct);

        return !hasRealData;
    }
}
