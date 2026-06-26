using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentValidation;
using MediatR;

namespace CcDashboard.Application.Commands.Tenants;

/// <summary>
/// Switches the Superadmin's active tenant context (ARCH-02).
/// The handler validates and audits; the Web endpoint re-issues the cookie with the new active_tenant_id claim.
/// </summary>
public record SwitchTenantCommand(Guid TargetTenantId) : IRequest<SwitchTenantResult>;

public record SwitchTenantResult(Guid TenantId, string Slug, string Name);

public class SwitchTenantCommandValidator : AbstractValidator<SwitchTenantCommand>
{
    public SwitchTenantCommandValidator()
    {
        RuleFor(x => x.TargetTenantId)
            .NotEmpty().WithMessage("Target tenant ID is required.");
    }
}

public class SwitchTenantCommandHandler(
    ICurrentUserAccessor currentUser,
    ITenantContext tenantContext,
    ITenantRepository tenants,
    IAuditService auditService)
    : IRequestHandler<SwitchTenantCommand, SwitchTenantResult>
{
    public async Task<SwitchTenantResult> Handle(SwitchTenantCommand cmd, CancellationToken ct)
    {
        // ARCH-02 + CODE-03: Superadmin-only authorization (defense-in-depth with Web endpoint's [Authorize])
        if (currentUser.Role != "Superadmin")
        {
            await auditService.LogAsync(
                "Authorization.Failure",
                AuditEventResult.Failure,
                tenantContext.TenantId,
                currentUser.UserId,
                currentUser.UserName,
                details: new { subtype = "TenantSwitchForbidden", attemptedTarget = cmd.TargetTenantId },
                ct: ct);

            throw new ForbiddenException("Only Superadmin can switch tenant context.");
        }

        // ARCH-05: Tenant has no GQF — cross-tenant query is allowed
        var target = await tenants.GetByIdAsync(cmd.TargetTenantId, ct);

        if (target is null)
            throw new NotFoundException("Tenant", cmd.TargetTenantId);

        // ARCH-06: Only Active tenants are switchable
        if (target.Status != TenantStatus.Active)
            throw new DomainException($"Tenant '{target.Name}' is not available (status: {target.Status}).");

        // ARCH-02: Audit the switch with from/to details
        await auditService.LogAsync(
            "Tenant.Switched",
            AuditEventResult.Success,
            target.Id,
            currentUser.UserId,
            currentUser.UserName,
            details: new { from = tenantContext.TenantId, to = cmd.TargetTenantId },
            ct: ct);

        return new SwitchTenantResult(target.Id, target.Slug, target.Name);
    }
}
