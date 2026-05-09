using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class TenantRepository(AppDbContext db) : ITenantRepository
{
    public Task<Tenant?> GetBySlugAsync(string slug, CancellationToken ct = default)
        => db.Tenants.AsNoTracking().Include(t => t.Settings).FirstOrDefaultAsync(t => t.Slug == slug, ct);

    public Task<Tenant?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.Tenants.AsNoTracking().Include(t => t.Settings).FirstOrDefaultAsync(t => t.Id == id, ct);

    public async Task<IReadOnlyList<Tenant>> GetAllAsync(CancellationToken ct = default)
        => await db.Tenants.AsNoTracking().OrderBy(t => t.Name).ToListAsync(ct);

    public Task AddAsync(Tenant tenant, CancellationToken ct = default)
    {
        db.Tenants.Add(tenant);
        return Task.CompletedTask;
    }

    public void Update(Tenant tenant)
    {
        var tracked = db.ChangeTracker.Entries<Tenant>()
            .FirstOrDefault(e => e.Entity.Id == tenant.Id);

        if (tracked != null)
        {
            // Update the already-tracked instance
            tracked.Entity.Name = tenant.Name;
            tracked.Entity.Status = tenant.Status;
            tracked.Entity.UpdatedAt = tenant.UpdatedAt;
            tracked.State = EntityState.Modified;
        }
        else
        {
            // Detach navigation to avoid conflict with already-loaded TenantSettings
            tenant.Settings = null!;
            db.Tenants.Attach(tenant);
            db.Entry(tenant).State = EntityState.Modified;
        }
    }
}
