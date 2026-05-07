using CcDashboard.Application.DTOs;
using CcDashboard.Application.Interfaces;
using CcDashboard.Core.Domain;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;

namespace CcDashboard.Application.Services;

public class PermissionService : IPermissionService
{
    private readonly IRepository<PermissionGroup> _groups;
    private readonly IUserRepository _users;

    public PermissionService(IRepository<PermissionGroup> groups, IUserRepository users)
    {
        _groups = groups;
        _users = users;
    }

    public async Task<PermissionGroupDto?> GetGroupByIdAsync(Guid id, CancellationToken ct = default)
    {
        var group = await _groups.GetByIdAsync(id, ct);
        return group is null ? null : MapToDto(group);
    }

    public async Task<IReadOnlyList<PermissionGroupDto>> GetAllGroupsAsync(CancellationToken ct = default)
    {
        var groups = await _groups.GetAllAsync(ct);
        return groups.Select(MapToDto).ToList();
    }

    public async Task<PermissionGroupDto> CreateGroupAsync(CreatePermissionGroupRequest request, CancellationToken ct = default)
    {
        if (await _groups.ExistsAsync(g => g.Name == request.Name, ct))
            throw new DomainException($"Permission group '{request.Name}' already exists.");

        var group = new PermissionGroup
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Description = request.Description,
            MenuPermissions = request.MenuPermissions,
            CreatedAt = DateTime.UtcNow
        };

        await _groups.AddAsync(group, ct);
        return MapToDto(group);
    }

    public async Task<PermissionGroupDto> UpdateGroupAsync(Guid id, UpdatePermissionGroupRequest request, CancellationToken ct = default)
    {
        var group = await _groups.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(PermissionGroup), id);

        if (await _groups.ExistsAsync(g => g.Name == request.Name && g.Id != id, ct))
            throw new DomainException($"Permission group '{request.Name}' already exists.");

        group.Name = request.Name;
        group.Description = request.Description;
        group.MenuPermissions = request.MenuPermissions;

        await _groups.UpdateAsync(group, ct);
        return MapToDto(group);
    }

    public async Task DeleteGroupAsync(Guid id, CancellationToken ct = default)
    {
        var group = await _groups.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(PermissionGroup), id);

        await _groups.DeleteAsync(group, ct);
    }

    public async Task<IReadOnlyList<PermissionGroupDto>> GetUserGroupsAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _users.GetByIdWithGroupsAsync(userId, ct);
        if (user is null) return Array.Empty<PermissionGroupDto>();

        return user.Groups.Select(ug => MapToDto(ug.Group)).ToList();
    }

    public async Task<bool> HasMenuPermissionAsync(Guid userId, string menuKey, CancellationToken ct = default)
    {
        var user = await _users.GetByIdWithGroupsAsync(userId, ct);
        if (user is null) return false;

        return user.Groups
            .SelectMany(ug => ug.Group.MenuPermissions)
            .Any(p => p == menuKey);
    }

    private static PermissionGroupDto MapToDto(PermissionGroup g) =>
        new(g.Id, g.Name, g.Description, g.MenuPermissions.AsReadOnly(), g.CreatedAt);
}
