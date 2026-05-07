using CcDashboard.Application.DTOs;

namespace CcDashboard.Application.Interfaces;

public interface IScreenService
{
    Task<ScreenDto?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<ScreenDto>> GetForUserAsync(Guid userId, CancellationToken ct = default);
    Task<ScreenDto> CreateAsync(Guid ownerId, CreateScreenRequest request, CancellationToken ct = default);
    Task<ScreenDto> UpdateAsync(Guid id, UpdateScreenRequest request, CancellationToken ct = default);
    Task DeleteAsync(Guid id, CancellationToken ct = default);
    Task SetPermissionAsync(SetScreenPermissionRequest request, CancellationToken ct = default);
    Task<WidgetSlotDto> AddWidgetSlotAsync(AddWidgetSlotRequest request, CancellationToken ct = default);
    Task RemoveWidgetSlotAsync(Guid slotId, CancellationToken ct = default);
}
