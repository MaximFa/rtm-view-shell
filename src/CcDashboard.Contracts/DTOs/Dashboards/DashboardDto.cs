using CcDashboard.Domain.Enums;

namespace CcDashboard.Contracts.DTOs.Dashboards;

public record DashboardDto(
    Guid Id,
    Guid TenantId,
    string? TenantName,
    string Name,
    string? Description,
    Guid? CategoryId,
    string? CategoryName,
    DashboardStatus Status,
    bool IsPublic,
    bool IsDarkMode,
    Guid CreatedByUserId,
    string? CreatedByName,
    DateTime CreatedAt,
    Guid UpdatedByUserId,
    string? UpdatedByName,
    DateTime UpdatedAt,
    uint RowVersion = 0,
    IReadOnlyList<DashboardWidgetDto>? Widgets = null);

public record DashboardWidgetDto(
    Guid Id,
    int GridId,
    Guid DashboardId,
    Guid WidgetCatalogItemId,
    string? PositionJson,
    string? ConfigJson);

public record CreateDashboardRequest(
    string Name,
    string? Description = null,
    Guid? CategoryId = null,
    bool IsPublic = false,
    Guid? TenantId = null);

public record UpdateDashboardRequest(
    Guid Id,
    string Name,
    string? Description,
    Guid? CategoryId,
    DashboardStatus Status,
    bool IsPublic,
    bool IsDarkMode,
    uint RowVersion);

public record DashboardListRequest(
    string? Search,
    DashboardStatus? Status,
    Guid? CategoryId,
    Guid? CreatedByUserId,
    bool? IsPublic,
    Guid? TenantId = null,
    int Page = 1,
    int PageSize = 25);
