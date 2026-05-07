using CcDashboard.Application.DTOs;
using CcDashboard.Application.Interfaces;
using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;

namespace CcDashboard.Application.Services;

public class ScreenService : IScreenService
{
    private readonly IRepository<Screen> _screens;
    private readonly IRepository<ScreenPermission> _screenPermissions;
    private readonly IRepository<WidgetSlot> _widgetSlots;
    private readonly IUserRepository _users;

    public ScreenService(
        IRepository<Screen> screens,
        IRepository<ScreenPermission> screenPermissions,
        IRepository<WidgetSlot> widgetSlots,
        IUserRepository users)
    {
        _screens = screens;
        _screenPermissions = screenPermissions;
        _widgetSlots = widgetSlots;
        _users = users;
    }

    public async Task<ScreenDto?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var screen = await _screens.GetByIdAsync(id, ct);
        return screen is null ? null : MapToDto(screen);
    }

    public async Task<IReadOnlyList<ScreenDto>> GetForUserAsync(Guid userId, CancellationToken ct = default)
    {
        var owned = await _screens.FindAsync(s => s.OwnerId == userId, ct);

        var user = await _users.GetByIdWithGroupsAsync(userId, ct);
        var groupIds = user?.Groups.Select(ug => ug.GroupId).ToList() ?? new List<Guid>();

        IReadOnlyList<Screen> permitted = Array.Empty<Screen>();
        if (groupIds.Count > 0)
        {
            var perms = await _screenPermissions.FindAsync(
                sp => groupIds.Contains(sp.GroupId) && sp.CanView, ct);
            var permittedIds = perms.Select(sp => sp.ScreenId).ToList();

            if (permittedIds.Count > 0)
                permitted = await _screens.FindAsync(s => permittedIds.Contains(s.Id), ct);
        }

        return owned.Union(permitted).DistinctBy(s => s.Id).Select(MapToDto).ToList();
    }

    public async Task<ScreenDto> CreateAsync(Guid ownerId, CreateScreenRequest request, CancellationToken ct = default)
    {
        var screen = new Screen
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            OwnerId = ownerId,
            OwnerGroupId = request.OwnerGroupId,
            Status = ScreenStatus.Draft,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _screens.AddAsync(screen, ct);
        return MapToDto(screen);
    }

    public async Task<ScreenDto> UpdateAsync(Guid id, UpdateScreenRequest request, CancellationToken ct = default)
    {
        var screen = await _screens.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(Screen), id);

        screen.Name = request.Name;
        screen.Status = request.Status;
        screen.UpdatedAt = DateTime.UtcNow;

        await _screens.UpdateAsync(screen, ct);
        return MapToDto(screen);
    }

    public async Task DeleteAsync(Guid id, CancellationToken ct = default)
    {
        var screen = await _screens.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(Screen), id);

        await _screens.DeleteAsync(screen, ct);
    }

    public async Task SetPermissionAsync(SetScreenPermissionRequest request, CancellationToken ct = default)
    {
        var existing = (await _screenPermissions.FindAsync(
            sp => sp.ScreenId == request.ScreenId && sp.GroupId == request.GroupId, ct))
            .FirstOrDefault();

        if (existing is null)
        {
            await _screenPermissions.AddAsync(new ScreenPermission
            {
                ScreenId = request.ScreenId,
                GroupId = request.GroupId,
                CanView = request.CanView,
                CanEdit = request.CanEdit,
                CanDelete = request.CanDelete
            }, ct);
        }
        else
        {
            existing.CanView = request.CanView;
            existing.CanEdit = request.CanEdit;
            existing.CanDelete = request.CanDelete;
            await _screenPermissions.UpdateAsync(existing, ct);
        }
    }

    public async Task<WidgetSlotDto> AddWidgetSlotAsync(AddWidgetSlotRequest request, CancellationToken ct = default)
    {
        if (!await _screens.ExistsAsync(s => s.Id == request.ScreenId, ct))
            throw new NotFoundException(nameof(Screen), request.ScreenId);

        var slot = new WidgetSlot
        {
            Id = Guid.NewGuid(),
            ScreenId = request.ScreenId,
            CategoryId = request.CategoryId,
            WidgetTypeId = request.WidgetTypeId
        };

        await _widgetSlots.AddAsync(slot, ct);
        return new WidgetSlotDto(slot.Id, slot.ScreenId, slot.CategoryId, slot.WidgetTypeId);
    }

    public async Task RemoveWidgetSlotAsync(Guid slotId, CancellationToken ct = default)
    {
        var slot = await _widgetSlots.GetByIdAsync(slotId, ct)
            ?? throw new NotFoundException(nameof(WidgetSlot), slotId);

        await _widgetSlots.DeleteAsync(slot, ct);
    }

    private static ScreenDto MapToDto(Screen s) =>
        new(s.Id, s.Name, s.OwnerId, s.OwnerGroupId, s.Status, s.CreatedAt, s.UpdatedAt);
}
