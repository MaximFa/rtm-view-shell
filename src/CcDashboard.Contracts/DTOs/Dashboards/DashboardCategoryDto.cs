namespace CcDashboard.Contracts.DTOs.Dashboards;

public record DashboardCategoryDto(
    Guid Id,
    Guid TenantId,
    string? TenantName,
    string Name,
    string? Description,
    int DashboardCount,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CreateDashboardCategoryRequest(
    string Name,
    string? Description = null);

public record UpdateDashboardCategoryRequest(
    Guid Id,
    string Name,
    string? Description);

public record DashboardCategoryListRequest(
    string? Search = null,
    Guid? TenantId = null,
    int Page = 1,
    int PageSize = 25);
