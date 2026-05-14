using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Interfaces;

public interface IWidgetTemplateRepository
{
    Task<IReadOnlyList<WidgetTemplate>> GetAllAsync(CancellationToken ct = default);
    Task<WidgetTemplate?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task AddAsync(WidgetTemplate template, CancellationToken ct = default);
    void Remove(WidgetTemplate template);
}
