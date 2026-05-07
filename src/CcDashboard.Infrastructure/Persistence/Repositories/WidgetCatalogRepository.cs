using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class WidgetCatalogRepository(AppDbContext db) : IWidgetCatalogRepository
{
    public async Task<IReadOnlyList<WidgetCatalogItem>> GetAllActiveAsync(CancellationToken ct = default)
        => await db.WidgetCatalogItems.AsNoTracking().Where(i => i.IsActive).OrderBy(i => i.Category).ThenBy(i => i.Name).ToListAsync(ct);

    public async Task<IReadOnlyList<WidgetCatalogItem>> GetAllAsync(CancellationToken ct = default)
        => await db.WidgetCatalogItems.AsNoTracking().OrderBy(i => i.Category).ThenBy(i => i.Name).ToListAsync(ct);

    public Task<WidgetCatalogItem?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.WidgetCatalogItems.FindAsync([id], ct).AsTask();

    public Task AddAsync(WidgetCatalogItem item, CancellationToken ct = default)
    {
        db.WidgetCatalogItems.Add(item);
        return Task.CompletedTask;
    }

    public void Update(WidgetCatalogItem item) => db.WidgetCatalogItems.Update(item);
}
