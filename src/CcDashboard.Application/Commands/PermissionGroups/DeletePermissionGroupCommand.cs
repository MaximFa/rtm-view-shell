using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using MediatR;

namespace CcDashboard.Application.Commands.PermissionGroups;

public record DeletePermissionGroupCommand(Guid Id) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "PermissionGroup.Deleted";
    public object? AuditDetails => new { Id };
}

public class DeletePermissionGroupCommandHandler(
    IPermissionGroupRepository repo,
    IConfigurationApiHook apiHook)
    : IRequestHandler<DeletePermissionGroupCommand, Result>
{
    public async Task<Result> Handle(DeletePermissionGroupCommand cmd, CancellationToken ct)
    {
        var group = await repo.GetByIdAsync(cmd.Id, ct)
                   ?? throw new NotFoundException(nameof(PermissionGroup), cmd.Id);

        var userCount = await repo.CountUsersAsync(cmd.Id, ct);
        if (userCount > 0)
            return Result.Failure($"Cannot delete group with {userCount} assigned user(s). [PG-06]");

        repo.Remove(group);

        // TODO: API hook — notify CC-platform when API is available
        await apiHook.NotifyAsync("PermissionGroup.Deleted", new { group.Id, group.Name, group.TenantId }, ct);

        return Result.Success();
    }
}
