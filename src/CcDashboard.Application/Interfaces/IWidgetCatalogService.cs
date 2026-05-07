using CcDashboard.Application.DTOs;

namespace CcDashboard.Application.Interfaces;

public interface IWidgetCatalogService
{
    Task<IReadOnlyList<WidgetCategoryDto>> GetCategoriesAsync(CancellationToken ct = default);
    Task<IReadOnlyList<WidgetTypeDto>> GetTypesInCategoryAsync(string categoryId, CancellationToken ct = default);
    Task<WidgetTypeDto?> GetTypeByIdAsync(string categoryId, string typeId, CancellationToken ct = default);
}
