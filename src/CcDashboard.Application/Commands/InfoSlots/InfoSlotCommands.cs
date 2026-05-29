using CcDashboard.Application.Behaviors;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.InfoSlots;
using MediatR;

namespace CcDashboard.Application.Commands.InfoSlots;

#region Create Info Slot

public record CreateInfoSlotCommand(
    string Name,
    string? Description,
    string DisplayMode,
    int SecondsPerMessage,
    List<Guid> PermissionGroupIds
) : IRequest<Result<Guid>>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.Created";
    public object? AuditDetails => new { Name };
}

#endregion

#region Update Info Slot

public record UpdateInfoSlotCommand(
    Guid Id,
    string Name,
    string? Description,
    string DisplayMode,
    int SecondsPerMessage,
    bool IsActive,
    List<Guid> PermissionGroupIds
) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.Updated";
    public object? AuditDetails => new { Id, Name, IsActive };
}

#endregion

#region Delete Info Slot

public record DeleteInfoSlotCommand(Guid Id) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.Deleted";
    public object? AuditDetails => new { Id };
}

#endregion

#region Create Message

public record CreateInfoSlotMessageCommand(
    Guid InfoSlotId,
    string Content,
    string Priority,
    DateTime? ExpiresAt
) : IRequest<Result<InfoSlotMessageDto>>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.MessageAdded";
    public object? AuditDetails => new { InfoSlotId, Priority, ExpiresAt };
}

#endregion

#region Update Message

public record UpdateInfoSlotMessageCommand(
    Guid MessageId,
    string Content,
    string Priority,
    DateTime? ExpiresAt
) : IRequest<InfoSlotMessageDto>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.MessageUpdated";
    public object? AuditDetails => new { MessageId, Priority, ExpiresAt };
}

#endregion

#region Deactivate Message

public record DeactivateInfoSlotMessageCommand(Guid MessageId) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.MessageDeactivated";
    public object? AuditDetails => new { MessageId };
}

#endregion

#region Update Display Mode

public record UpdateInfoSlotDisplayModeCommand(
    Guid InfoSlotId,
    string DisplayMode,
    int SecondsPerMessage
) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "InfoSlot.Updated";
    public object? AuditDetails => null; // Set in handler with old/new values
}

#endregion
