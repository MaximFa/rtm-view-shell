using CcDashboard.Application.Commands.InfoSlots;
using CcDashboard.Application.Queries.InfoSlots;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.InfoSlots;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Infrastructure.Handlers;

#region Query Handlers

public class GetInfoSlotsQueryHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetInfoSlotsQuery, IReadOnlyList<InfoSlotListDto>>
{
    public async Task<IReadOnlyList<InfoSlotListDto>> Handle(GetInfoSlotsQuery query, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var now = DateTime.UtcNow;

        IQueryable<InfoSlot> q = db.InfoSlots.Include(s => s.Permissions).Include(s => s.Messages);

        if (isSuperadmin && query.TenantId is null)
        {
            q = q.IgnoreQueryFilters();
        }
        else if (isSuperadmin && query.TenantId.HasValue)
        {
            q = q.IgnoreQueryFilters().Where(s => s.TenantId == query.TenantId.Value);
        }

        return await q.Select(s => new InfoSlotListDto(
            s.Id,
            s.Name,
            s.Description,
            s.DisplayMode,
            s.SecondsPerMessage,
            s.IsActive,
            s.Messages.Count(m => m.IsActive && (m.ExpiresAt == null || m.ExpiresAt > now)),
            s.Permissions.Count,
            s.Permissions.Select(p => p.PermissionGroupId).ToList()
        )).ToListAsync(ct);
    }
}

public class GetInfoSlotsForViewerQueryHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetInfoSlotsForViewerQuery, IReadOnlyList<InfoSlotViewerDto>>
{
    public async Task<IReadOnlyList<InfoSlotViewerDto>> Handle(GetInfoSlotsForViewerQuery query, CancellationToken ct)
    {
        var role = currentUser.Role;
        var pgId = currentUser.PermissionGroupId;
        var now = DateTime.UtcNow;
        var isSuperadmin = role == "Superadmin";
        var isAdmin = role == "Administrator";

        IQueryable<InfoSlot> q = db.InfoSlots
            .Include(s => s.Permissions)
            .Include(s => s.Messages.Where(m => m.IsActive && (m.ExpiresAt == null || m.ExpiresAt > now)))
            .Where(s => s.IsActive);

        if (isSuperadmin && query.TenantId is null)
        {
            q = q.IgnoreQueryFilters().Where(s => s.IsActive);
        }
        else if (isSuperadmin && query.TenantId.HasValue)
        {
            q = q.IgnoreQueryFilters().Where(s => s.TenantId == query.TenantId.Value && s.IsActive);
        }
        else if (!isAdmin && pgId.HasValue)
        {
            q = q.Where(s => s.Permissions.Any(p => p.PermissionGroupId == pgId.Value));
        }

        var slots = await q.ToListAsync(ct);
        var result = new List<InfoSlotViewerDto>();

        foreach (var slot in slots)
        {
            var idString = slot.Id.ToString();
            var dashboardNames = await db.DashboardWidgets
                .IgnoreQueryFilters()
                .Where(w => w.ConfigJson != null && w.ConfigJson.Contains(idString))
                .Select(w => w.Dashboard!.Name)
                .Distinct()
                .ToListAsync(ct);

            var userIds = slot.Messages.Select(m => m.CreatedByUserId).Distinct().ToList();
            var users = await db.Users.IgnoreQueryFilters()
                .Where(u => userIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => $"{u.FirstName} {u.LastName}".Trim(), ct);

            result.Add(new InfoSlotViewerDto(
                slot.Id,
                slot.Name,
                slot.DisplayMode,
                slot.SecondsPerMessage,
                slot.Messages.Count,
                dashboardNames,
                slot.Messages.OrderByDescending(m => m.Priority == "High")
                    .ThenByDescending(m => m.CreatedAt)
                    .Select(m => new InfoSlotMessageDto(
                        m.Id,
                        m.InfoSlotId,
                        m.Content,
                        m.Priority,
                        m.ExpiresAt,
                        users.TryGetValue(m.CreatedByUserId, out var name) && !string.IsNullOrEmpty(name) ? name : "Unknown",
                        m.CreatedAt
                    )).ToList()
            ));
        }

        return result;
    }
}

public class GetActiveMessagesQueryHandler(AppDbContext db)
    : IRequestHandler<GetActiveMessagesQuery, IReadOnlyList<InfoSlotMessageDto>>
{
    public async Task<IReadOnlyList<InfoSlotMessageDto>> Handle(GetActiveMessagesQuery query, CancellationToken ct)
    {
        var now = DateTime.UtcNow;

        var messages = await db.InfoSlotMessages
            .Where(m => m.InfoSlotId == query.InfoSlotId &&
                        m.IsActive &&
                        (m.ExpiresAt == null || m.ExpiresAt > now))
            .OrderByDescending(m => m.Priority == "High")
            .ThenByDescending(m => m.CreatedAt)
            .ToListAsync(ct);

        var userIds = messages.Select(m => m.CreatedByUserId).Distinct().ToList();
        var users = await db.Users.IgnoreQueryFilters()
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => $"{u.FirstName} {u.LastName}".Trim(), ct);

        return messages.Select(m => new InfoSlotMessageDto(
            m.Id,
            m.InfoSlotId,
            m.Content,
            m.Priority,
            m.ExpiresAt,
            users.TryGetValue(m.CreatedByUserId, out var name) && !string.IsNullOrEmpty(name) ? name : "Unknown",
            m.CreatedAt
        )).ToList();
    }
}

public class GetInfoSlotsForWidgetConfigQueryHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetInfoSlotsForWidgetConfigQuery, IReadOnlyList<InfoSlotSummaryDto>>
{
    public async Task<IReadOnlyList<InfoSlotSummaryDto>> Handle(GetInfoSlotsForWidgetConfigQuery query, CancellationToken ct)
    {
        var role = currentUser.Role;
        var pgId = currentUser.PermissionGroupId;

        IQueryable<InfoSlot> q = db.InfoSlots
            .Include(s => s.Permissions)
            .Where(s => s.IsActive);

        if (role != "Superadmin" && role != "Administrator" && pgId.HasValue)
        {
            q = q.Where(s => s.Permissions.Any(p => p.PermissionGroupId == pgId.Value));
        }

        return await q.OrderBy(s => s.Name)
            .Select(s => new InfoSlotSummaryDto(s.Id, s.Name, s.DisplayMode))
            .ToListAsync(ct);
    }
}

#endregion

#region Command Handlers

public class CreateInfoSlotCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateInfoSlotCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateInfoSlotCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var userId = currentUser.UserId!.Value;
        var now = clock.UtcNow;

        var slot = new InfoSlot
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Name.Trim(),
            Description = cmd.Description?.Trim(),
            DisplayMode = cmd.DisplayMode,
            SecondsPerMessage = cmd.SecondsPerMessage,
            IsActive = true,
            CreatedAt = now,
            CreatedByUserId = userId,
            UpdatedAt = now,
            UpdatedByUserId = userId
        };

        foreach (var pgId in cmd.PermissionGroupIds)
        {
            slot.Permissions.Add(new InfoSlotPermission
            {
                InfoSlotId = slot.Id,
                PermissionGroupId = pgId,
                TenantId = tenantId
            });
        }

        db.InfoSlots.Add(slot);
        await db.SaveChangesAsync(ct);

        return Result<Guid>.Success(slot.Id);
    }
}

public class UpdateInfoSlotCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateInfoSlotCommand, Result>
{
    public async Task<Result> Handle(UpdateInfoSlotCommand cmd, CancellationToken ct)
    {
        var slot = await db.InfoSlots
            .Include(s => s.Permissions)
            .FirstOrDefaultAsync(s => s.Id == cmd.Id, ct);

        if (slot is null)
            return Result.Failure("Info Slot not found");

        if (slot.IsActive && !cmd.IsActive)
        {
            var placements = await GetDashboardPlacementsAsync(slot.Id, ct);
            if (placements.Count > 0)
                return Result.Failure($"Cannot deactivate: Info Slot is placed on {placements.Count} dashboard(s): {string.Join(", ", placements)}");
        }

        slot.Name = cmd.Name.Trim();
        slot.Description = cmd.Description?.Trim();
        slot.DisplayMode = cmd.DisplayMode;
        slot.SecondsPerMessage = cmd.SecondsPerMessage;
        slot.IsActive = cmd.IsActive;
        slot.UpdatedAt = clock.UtcNow;
        slot.UpdatedByUserId = currentUser.UserId!.Value;

        slot.Permissions.Clear();
        foreach (var pgId in cmd.PermissionGroupIds)
        {
            slot.Permissions.Add(new InfoSlotPermission
            {
                InfoSlotId = slot.Id,
                PermissionGroupId = pgId,
                TenantId = slot.TenantId
            });
        }

        await db.SaveChangesAsync(ct);
        return Result.Success();
    }

    private async Task<List<string>> GetDashboardPlacementsAsync(Guid infoSlotId, CancellationToken ct)
    {
        var idString = infoSlotId.ToString();
        return await db.DashboardWidgets
            .IgnoreQueryFilters()
            .Where(w => w.ConfigJson != null && w.ConfigJson.Contains(idString))
            .Select(w => w.Dashboard!.Name)
            .Distinct()
            .ToListAsync(ct);
    }
}

public class DeleteInfoSlotCommandHandler(AppDbContext db)
    : IRequestHandler<DeleteInfoSlotCommand, Result>
{
    public async Task<Result> Handle(DeleteInfoSlotCommand cmd, CancellationToken ct)
    {
        var slot = await db.InfoSlots.FirstOrDefaultAsync(s => s.Id == cmd.Id, ct);
        if (slot is null)
            return Result.Failure("Info Slot not found");

        var idString = cmd.Id.ToString();
        var placements = await db.DashboardWidgets
            .IgnoreQueryFilters()
            .Where(w => w.ConfigJson != null && w.ConfigJson.Contains(idString))
            .Select(w => w.Dashboard!.Name)
            .Distinct()
            .ToListAsync(ct);

        if (placements.Count > 0)
            return Result.Failure($"Cannot delete: Info Slot is placed on {placements.Count} dashboard(s): {string.Join(", ", placements)}");

        db.InfoSlots.Remove(slot);
        await db.SaveChangesAsync(ct);

        return Result.Success();
    }
}

public class CreateInfoSlotMessageCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateInfoSlotMessageCommand, Result<InfoSlotMessageDto>>
{
    public async Task<Result<InfoSlotMessageDto>> Handle(CreateInfoSlotMessageCommand cmd, CancellationToken ct)
    {
        var userId = currentUser.UserId!.Value;
        var tenantId = currentUser.TenantId!.Value;
        var now = clock.UtcNow;

        var slot = await db.InfoSlots
            .Include(s => s.Permissions)
            .FirstOrDefaultAsync(s => s.Id == cmd.InfoSlotId, ct);

        if (slot is null)
            return Result.Failure<InfoSlotMessageDto>("Info Slot not found");

        var role = currentUser.Role;
        if (role != "Superadmin" && role != "Administrator")
        {
            var pgId = currentUser.PermissionGroupId;
            if (pgId is null || !slot.Permissions.Any(p => p.PermissionGroupId == pgId))
                return Result.Failure<InfoSlotMessageDto>("Access denied: your permission group cannot write to this Info Slot");
        }

        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        var authorName = user is not null ? $"{user.FirstName} {user.LastName}".Trim() : "Unknown";
        if (string.IsNullOrEmpty(authorName)) authorName = user?.UserName ?? "Unknown";

        var message = new InfoSlotMessage
        {
            Id = Uuid.NewSequential(),
            InfoSlotId = cmd.InfoSlotId,
            TenantId = tenantId,
            Content = cmd.Content.Trim(),
            Priority = cmd.Priority,
            ExpiresAt = cmd.ExpiresAt,
            IsActive = true,
            CreatedAt = now,
            CreatedByUserId = userId
        };

        db.InfoSlotMessages.Add(message);
        await db.SaveChangesAsync(ct);

        return Result.Success(new InfoSlotMessageDto(
            message.Id,
            message.InfoSlotId,
            message.Content,
            message.Priority,
            message.ExpiresAt,
            authorName,
            message.CreatedAt));
    }
}

public class DeactivateInfoSlotMessageCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeactivateInfoSlotMessageCommand, Result>
{
    public async Task<Result> Handle(DeactivateInfoSlotMessageCommand cmd, CancellationToken ct)
    {
        var message = await db.InfoSlotMessages.FirstOrDefaultAsync(m => m.Id == cmd.MessageId, ct);
        if (message is null)
            return Result.Failure("Message not found");

        var role = currentUser.Role;
        var userId = currentUser.UserId!.Value;

        if (role != "Superadmin" && role != "Administrator")
        {
            if (message.CreatedByUserId != userId)
                return Result.Failure("Access denied: you can only deactivate your own messages");
        }

        message.IsActive = false;
        message.DeactivatedAt = clock.UtcNow;
        message.DeactivatedByUserId = userId;

        await db.SaveChangesAsync(ct);
        return Result.Success();
    }
}

#endregion