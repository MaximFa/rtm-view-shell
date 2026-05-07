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

    public void Update(Tenant tenant) => db.Tenants.Update(tenant);
}
