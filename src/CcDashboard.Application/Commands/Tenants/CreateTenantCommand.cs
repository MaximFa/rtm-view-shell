using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Tenants;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.Tenants;

public record CreateTenantCommand(CreateTenantRequest Request) : IRequest<TenantDto>, ITransactional, IAuditable
{
    public string AuditEventType => "Tenant.Created";
    public object? AuditDetails => new { Name = Request.Name, Slug = Request.Slug };
}

public class CreateTenantCommandHandler(ITenantRepository repo, IDateTimeProvider clock)
    : IRequestHandler<CreateTenantCommand, TenantDto>
{
    public async Task<TenantDto> Handle(CreateTenantCommand cmd, CancellationToken ct)
    {
        var tenant = new Tenant
        {
            Id = Uuid.NewSequential(),
            Slug = cmd.Request.Slug.Trim().ToLowerInvariant(),
            Name = cmd.Request.Name.Trim(),
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = clock.UtcNow,
            UpdatedAt = clock.UtcNow
        };
        await repo.AddAsync(tenant, ct);
        return new TenantDto(tenant.Id, tenant.Slug, tenant.Name, tenant.Status, tenant.CreatedAt, tenant.UpdatedAt);
    }
}
