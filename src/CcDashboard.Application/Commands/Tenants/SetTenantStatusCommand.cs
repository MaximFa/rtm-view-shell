using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Tenants;

public record SetTenantStatusCommand(Guid TenantId, TenantStatus NewStatus) : IRequest, ITransactional;

public class SetTenantStatusCommandHandler(ITenantRepository repo, IDateTimeProvider clock)
    : IRequestHandler<SetTenantStatusCommand>
{
    public async Task Handle(SetTenantStatusCommand cmd, CancellationToken ct)
    {
        var tenant = await repo.GetByIdAsync(cmd.TenantId, ct)
            ?? throw new KeyNotFoundException($"Tenant {cmd.TenantId} not found.");

        tenant.Status = cmd.NewStatus;
        tenant.UpdatedAt = clock.UtcNow;
        repo.Update(tenant);
    }
}
