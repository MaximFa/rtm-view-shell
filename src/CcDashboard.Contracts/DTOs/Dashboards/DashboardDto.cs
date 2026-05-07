using CcDashboard.Domain.Enums;

namespace CcDashboard.Contracts.DTOs.Dashboards;

public record DashboardDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    DashboardStatus Status,
    bool IsPublic,
    Guid CreatedByUserId,
    string? CreatedByName,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CreateDashboardRequest(
    string Name,
    string? Description = null,
    bool IsPublic = false);

public record UpdateDashboardRequest(
    Guid Id,
    string Name,
    string? Description,
    DashboardStatus Status,
    bool IsPublic,
    uint RowVersion);

public record DashboardListRequest(
    string? Search,
    DashboardStatus? Status,
    Guid? CreatedByUserId,
    bool? IsPublic,
    int Page = 1,
    int PageSize = 25);
