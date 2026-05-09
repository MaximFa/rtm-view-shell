namespace CcDashboard.Contracts.DTOs.PermissionGroups;

public record PermissionGroupDto(
    Guid Id,
    Guid TenantId,
    string Name,
    string? Description,
    bool IsActive,
    int UserCount,
    IReadOnlyList<string> MenuPermissions,
    IReadOnlyList<Guid> AllowedQueueIds,
    IReadOnlyList<Guid> AllowedAgentGroupIds,
    IReadOnlyList<int> AllowedBusinessUnitIds,
    IReadOnlyList<int> AllowedSupergroupIds,
    IReadOnlyList<Guid> AllowedDashboardIds,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    uint RowVersion = 0);

public record CreatePermissionGroupRequest(
    string Name,
    string? Description,
    IReadOnlyList<string> MenuPermissions,
    IReadOnlyList<Guid>? AllowedQueueIds = null,
    IReadOnlyList<Guid>? AllowedAgentGroupIds = null,
    IReadOnlyList<int>? AllowedBusinessUnitIds = null,
    IReadOnlyList<int>? AllowedSupergroupIds = null,
    IReadOnlyList<Guid>? AllowedDashboardIds = null);

public record UpdatePermissionGroupRequest(
    Guid Id,
    string Name,
    string? Description,
    bool IsActive,
    IReadOnlyList<string> MenuPermissions,
    uint RowVersion,
    IReadOnlyList<Guid>? AllowedQueueIds = null,
    IReadOnlyList<Guid>? AllowedAgentGroupIds = null,
    IReadOnlyList<int>? AllowedBusinessUnitIds = null,
    IReadOnlyList<int>? AllowedSupergroupIds = null,
    IReadOnlyList<Guid>? AllowedDashboardIds = null);
