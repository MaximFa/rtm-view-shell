using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Tenants;

public record UpdateTenantCommand(Guid TenantId, string Name) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Tenant.Updated";
    public object? AuditDetails => new { Name, Id = TenantId };
}

public class UpdateTenantCommandHandler(ITenantRepository repo, IDateTimeProvider clock)
    : IRequestHandler<UpdateTenantCommand>
{
    public async Task Handle(UpdateTenantCommand cmd, CancellationToken ct)
    {
        var tenant = await repo.GetByIdAsync(cmd.TenantId, ct)
            ?? throw new InvalidOperationException($"Tenant {cmd.TenantId} not found.");
        tenant.Name = cmd.Name.Trim();
        tenant.UpdatedAt = clock.UtcNow;
        repo.Update(tenant);
    }
}
