using CcDashboard.Application.DTOs;

namespace CcDashboard.Application.Interfaces;

public interface IPermissionService
{
    Task<PermissionGroupDto?> GetGroupByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<PermissionGroupDto>> GetAllGroupsAsync(CancellationToken ct = default);
    Task<PermissionGroupDto> CreateGroupAsync(CreatePermissionGroupRequest request, CancellationToken ct = default);
    Task<PermissionGroupDto> UpdateGroupAsync(Guid id, UpdatePermissionGroupRequest request, CancellationToken ct = default);
    Task DeleteGroupAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<PermissionGroupDto>> GetUserGroupsAsync(Guid userId, CancellationToken ct = default);
    Task<bool> HasMenuPermissionAsync(Guid userId, string menuKey, CancellationToken ct = default);
}
