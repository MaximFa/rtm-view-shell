namespace CcDashboard.Contracts.DTOs.Widgets;

public record WidgetCatalogItemDto(
    Guid Id,
    string Category,
    string Name,
    string? Description,
    string? IconUrl,
    bool IsActive);

public record WidgetCatalogCategoryDto(
    string Category,
    IReadOnlyList<WidgetCatalogItemDto> Items);
