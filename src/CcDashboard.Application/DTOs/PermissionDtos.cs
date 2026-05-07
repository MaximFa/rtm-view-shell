namespace CcDashboard.Application.DTOs;

public record PermissionGroupDto(
    Guid Id,
    string Name,
    string Description,
    IReadOnlyList<string> MenuPermissions,
    DateTime CreatedAt);

public record CreatePermissionGroupRequest(
    string Name,
    string Description,
    List<string> MenuPermissions);

public record UpdatePermissionGroupRequest(
    string Name,
    string Description,
    List<string> MenuPermissions);
