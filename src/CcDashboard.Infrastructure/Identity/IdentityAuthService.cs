using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Identity;

public class IdentityAuthService(
    SignInManager<ApplicationUser> signInManager,
    UserManager<ApplicationUser> userManager,
    AppDbContext db,
    IAuditService audit,
    IDateTimeProvider clock,
    ILogger<IdentityAuthService> logger)
    : IIdentityAuthService
{
    public async Task<IdentitySignInResult> PasswordSignInAsync(
        Guid tenantId, string userName, string password,
        string ipAddress, string userAgent,
        CancellationToken ct = default)
    {
        // Resolve user within the tenant (bypass GQF since TenantContext not set yet at login)
        var user = await db.Set<ApplicationUser>()
            .IgnoreQueryFilters()
            .Where(u => u.TenantId == tenantId &&
                        (u.NormalizedUserName == userName.ToUpperInvariant() ||
                         u.NormalizedEmail == userName.ToUpperInvariant()))
            .FirstOrDefaultAsync(ct);

        if (user == null)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, null, userName, ipAddress, userAgent,
                new { Subtype = "UserNotFound" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);
        }

        // Check tenant match
        if (user.TenantId != tenantId)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "TenantMismatch" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.TenantMismatch);
        }

        // Check active
        if (!user.IsActive)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "AccountDeactivated" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.AccountInactive);
        }

        // Check tenant status
        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Id == tenantId, ct);
        if (tenant?.Status == TenantStatus.Suspended)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "TenantSuspended" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.TenantSuspended);
        }

        // Verify password and handle lockout via Identity
        var result = await signInManager.CheckPasswordSignInAsync(user, password, lockoutOnFailure: true);

        if (result.IsLockedOut)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "AccountLocked" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.LockedOut);
        }

        if (!result.Succeeded)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "WrongPassword" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);
        }

        // 2FA required?
        if (result.RequiresTwoFactor || user.Is2faEnabled)
        {
            await signInManager.SignInAsync(user, isPersistent: false, authenticationMethod: "2fa_pending");
            return new IdentitySignInResult(IdentitySignInStatus.RequiresTwoFactor,
                UserId: user.Id, UserName: user.UserName);
        }

        // Full sign-in
        await signInManager.SignInAsync(user, isPersistent: false);

        // Update last login
        user.LastLoginAt = clock.UtcNow;
        await userManager.UpdateAsync(user);

        bool mustChangePassword = user.MustChangePasswordAt.HasValue &&
                                   user.MustChangePasswordAt.Value <= clock.UtcNow;

        await audit.LogAsync("Login.Success", AuditEventResult.Success,
            tenantId, user.Id, user.UserName, ipAddress, userAgent, null, ct);

        return new IdentitySignInResult(
            IdentitySignInStatus.Success,
            UserId: user.Id,
            UserName: user.UserName,
            RequiresPasswordChange: mustChangePassword);
    }

    public async Task SignOutAsync(CancellationToken ct = default)
    {
        await signInManager.SignOutAsync();
    }

    public async Task<ChangePasswordResult> ChangePasswordAsync(
        Guid userId, string currentPassword, string newPassword,
        CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null)
            return new ChangePasswordResult(false, "User not found.");

        var result = await userManager.ChangePasswordAsync(user, currentPassword, newPassword);
        if (!result.Succeeded)
            return new ChangePasswordResult(false, string.Join(" ", result.Errors.Select(e => e.Description)));

        // Clear forced change flag
        user.MustChangePasswordAt = null;
        await userManager.UpdateAsync(user);

        return new ChangePasswordResult(true);
    }
}
