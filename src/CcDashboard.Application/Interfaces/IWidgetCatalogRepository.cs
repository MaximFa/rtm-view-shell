using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IWidgetCatalogRepository
{
    Task<IReadOnlyList<WidgetCatalogItem>> GetAllActiveAsync(CancellationToken ct = default);
    Task<IReadOnlyList<WidgetCatalogItem>> GetAllAsync(CancellationToken ct = default);
    Task<WidgetCatalogItem?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task AddAsync(WidgetCatalogItem item, CancellationToken ct = default);
    void Update(WidgetCatalogItem item);
}
