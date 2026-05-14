using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class WidgetTemplateRepository(AppDbContext db) : IWidgetTemplateRepository
{
    public async Task<IReadOnlyList<WidgetTemplate>> GetAllAsync(CancellationToken ct = default)
        => await db.WidgetTemplates
            .Include(t => t.CatalogItem)
            .AsNoTracking()
            .OrderBy(t => t.Name)
            .ToListAsync(ct);

    public Task<WidgetTemplate?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => db.WidgetTemplates
            .Include(t => t.CatalogItem)
            .FirstOrDefaultAsync(t => t.Id == id, ct);

    public Task AddAsync(WidgetTemplate template, CancellationToken ct = default)
    {
        db.WidgetTemplates.Add(template);
        return Task.CompletedTask;
    }

    public void Remove(WidgetTemplate template) => db.WidgetTemplates.Remove(template);
}
