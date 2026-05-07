namespace CcDashboard.Contracts.DTOs.PermissionGroups;

public record PermissionGroupDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    bool IsActive,
    int UserCount,
    IReadOnlyList<string> MenuPermissions,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    uint RowVersion = 0);

public record CreatePermissionGroupRequest(
    string Name,
    string? Description,
    IReadOnlyList<string> MenuPermissions);

public record UpdatePermissionGroupRequest(
    Guid Id,
    string Name,
    string? Description,
    bool IsActive,
    IReadOnlyList<string> MenuPermissions,
    uint RowVersion);
