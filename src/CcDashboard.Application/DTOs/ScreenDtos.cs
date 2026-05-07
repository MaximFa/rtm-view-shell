using CcDashboard.Core.Enums;

namespace CcDashboard.Application.DTOs;

public record ScreenDto(
    Guid Id,
    string Name,
    Guid OwnerId,
    Guid? OwnerGroupId,
    ScreenStatus Status,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CreateScreenRequest(string Name, Guid? OwnerGroupId = null);

public record UpdateScreenRequest(string Name, ScreenStatus Status);

public record SetScreenPermissionRequest(
    Guid ScreenId,
    Guid GroupId,
    bool CanView,
    bool CanEdit,
    bool CanDelete);

public record WidgetSlotDto(Guid Id, Guid ScreenId, string CategoryId, string WidgetTypeId);

public record AddWidgetSlotRequest(Guid ScreenId, string CategoryId, string WidgetTypeId);

public record WidgetCategoryDto(string CategoryId, string Name, string Description);

public record WidgetTypeDto(string TypeId, string CategoryId, string Name, string Description);
