using CcDashboard.Contracts.DTOs.Auth;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Auth;

public record LoginCommand(string UserName, string Password, Guid TenantId, string IpAddress, string UserAgent)
    : IRequest<LoginResult>;

public class LoginCommandHandler(
    IUserRepository users,
    IAuditService audit,
    IDateTimeProvider clock)
    : IRequestHandler<LoginCommand, LoginResult>
{
    public async Task<LoginResult> Handle(LoginCommand cmd, CancellationToken ct)
    {
        var user = await users.GetByUserNameAsync(cmd.TenantId, cmd.UserName, ct)
                   ?? await users.GetByEmailAsync(cmd.TenantId, cmd.UserName, ct);

        if (user == null || !user.IsActive)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                cmd.TenantId, null, cmd.UserName, cmd.IpAddress, cmd.UserAgent,
                new { Subtype = user == null ? "UserNotFound" : "AccountDeactivated" }, ct);
            throw new ForbiddenException("Invalid username or password.");
        }

        if (user.LockoutEnabled && user.LockoutEnd.HasValue && user.LockoutEnd > DateTimeOffset.UtcNow)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                user.TenantId, user.Id, user.UserName, cmd.IpAddress, cmd.UserAgent,
                new { Subtype = "AccountLocked" }, ct);
            throw new ForbiddenException("Invalid username or password.");
        }

        // Use the user's own TenantId, not the subdomain's — Superadmin events go to platform tenant
        await audit.LogAsync("Login.Success", AuditEventResult.Success,
            user.TenantId, user.Id, user.UserName, cmd.IpAddress, cmd.UserAgent, null, ct);

        bool mustChangePassword = user.MustChangePasswordAt.HasValue &&
                                   user.MustChangePasswordAt.Value <= clock.UtcNow;

        return new LoginResult(
            RequiresTwoFactor: user.Is2faEnabled,
            RequiresPasswordChange: mustChangePassword,
            UserId: user.Id,
            Email: user.Email,
            DisplayName: $"{user.FirstName} {user.LastName}".Trim());
    }
}
