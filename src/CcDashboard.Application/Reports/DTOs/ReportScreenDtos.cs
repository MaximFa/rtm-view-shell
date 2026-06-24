using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.Reports.DTOs;

public record ReportScreenDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    Guid? CategoryId,
    string? CategoryName,
    ReportScreenStatus Status,
    bool IsPublic,
    bool IsDarkMode,
    Guid CreatedByUserId,
    string? CreatedByName,
    DateTime CreatedAt,
    Guid UpdatedByUserId,
    string? UpdatedByName,
    DateTime UpdatedAt,
    uint RowVersion = 0,
    int AccessLevel = 0);

public record ReportScreenDetailDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    Guid? CategoryId,
    string? CategoryName,
    ReportScreenStatus Status,
    bool IsPublic,
    bool IsDarkMode,
    string? LayoutJson,
    Guid CreatedByUserId,
    string? CreatedByName,
    DateTime CreatedAt,
    Guid UpdatedByUserId,
    string? UpdatedByName,
    DateTime UpdatedAt,
    uint RowVersion,
    int AccessLevel,
    IReadOnlyList<ReportWidgetDto> Widgets);

public record ReportWidgetDto(
    Guid Id,
    ReportWidgetType WidgetType,
    string? PositionJson,
    string? ConfigJson);

public record ReportCategoryDto(
    Guid Id,
    string Name,
    bool IsActive);

public record CreateReportScreenRequest(
    string Name,
    string? Description = null,
    Guid? CategoryId = null,
    bool IsPublic = false,
    bool IsDarkMode = false);

public record UpdateReportScreenRequest(
    Guid Id,
    string Name,
    string? Description,
    Guid? CategoryId,
    ReportScreenStatus Status,
    bool IsPublic,
    bool IsDarkMode,
    string? LayoutJson,
    uint RowVersion);

public record ReportScreenListRequest(
    string? Search = null,
    Guid? CategoryId = null,
    ReportScreenStatus? Status = null,
    bool? IsPublic = null,
    int Page = 1,
    int PageSize = 25);

public record SaveReportWidgetRequest(
    Guid? Id,
    ReportWidgetType WidgetType,
    string? PositionJson,
    string? ConfigJson,
    bool IsDeleted = false);
