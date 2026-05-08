using System.Security.Claims;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using UUIDNext;

namespace CcDashboard.Infrastructure.Identity;

public class IdentityAuthService(
    SignInManager<ApplicationUser> signInManager,
    UserManager<ApplicationUser> userManager,
    AppDbContext db,
    IAuditService audit,
    IDateTimeProvider clock,
    ITwoFactorService twoFactorService,
    IHttpContextAccessor httpContextAccessor,
    ILogger<IdentityAuthService> logger)
    : IIdentityAuthService
{
    public async Task<IdentitySignInResult> PasswordSignInAsync(
        Guid tenantId, string userName, string password,
        string ipAddress, string userAgent,
        CancellationToken ct = default)
    {
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

        if (user.TenantId != tenantId)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "TenantMismatch" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.TenantMismatch);
        }

        if (!user.IsActive)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "AccountDeactivated" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.AccountInactive);
        }

        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Id == tenantId, ct);
        if (tenant?.Status == TenantStatus.Suspended)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "TenantSuspended" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.TenantSuspended);
        }

        var checkResult = await signInManager.CheckPasswordSignInAsync(user, password, lockoutOnFailure: true);

        if (checkResult.IsLockedOut)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "AccountLocked" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.LockedOut);
        }

        if (!checkResult.Succeeded)
        {
            await audit.LogAsync("Login.Failure", AuditEventResult.Failure,
                tenantId, user.Id, user.UserName, ipAddress, userAgent,
                new { Subtype = "WrongPassword" }, ct);
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);
        }

        // 2FA required?
        if (user.Is2faEnabled)
        {
            await StorePendingTwoFactorAsync(user.Id, user.TenantId, user.Email ?? "");
            var sendResult = await twoFactorService.SendCodeAsync(user.Id, user.TenantId, user.Email ?? "", ct);
            if (!sendResult.Succeeded)
                logger.LogWarning("Failed to send 2FA code for userId={UserId}: {Error}", user.Id, sendResult.Error);
            await audit.LogAsync("2FA.CodeSent", AuditEventResult.Success,
                tenantId, user.Id, user.UserName, ipAddress, userAgent, null, ct);
            return new IdentitySignInResult(IdentitySignInStatus.RequiresTwoFactor, UserId: user.Id);
        }

        await CompleteSignInAsync(user, ipAddress, userAgent, ct);
        bool mustChange = user.MustChangePasswordAt.HasValue && user.MustChangePasswordAt.Value <= clock.UtcNow;
        return new IdentitySignInResult(IdentitySignInStatus.Success,
            UserId: user.Id, UserName: user.UserName, RequiresPasswordChange: mustChange);
    }

    public async Task<IdentitySignInResult> CompleteTwoFactorAsync(string code, CancellationToken ct = default)
    {
        var httpContext = httpContextAccessor.HttpContext
            ?? throw new InvalidOperationException("No HTTP context.");

        var authResult = await httpContext.AuthenticateAsync(IdentityConstants.TwoFactorUserIdScheme);
        if (!authResult.Succeeded)
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);

        var userIdStr = authResult.Principal?.FindFirstValue(ClaimTypes.Name);
        if (!Guid.TryParse(userIdStr, out var userId))
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);

        var verifyResult = await twoFactorService.VerifyCodeAsync(userId, code, ct);
        if (!verifyResult.Succeeded)
        {
            if (verifyResult.MaxAttemptsExceeded)
                return new IdentitySignInResult(IdentitySignInStatus.LockedOut);
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);
        }

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null)
            return new IdentitySignInResult(IdentitySignInStatus.InvalidCredentials);

        // Clear partial auth cookie
        await httpContext.SignOutAsync(IdentityConstants.TwoFactorUserIdScheme);

        var ipAddress = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var userAgent = httpContext.Request.Headers.UserAgent.ToString();
        await CompleteSignInAsync(user, ipAddress, userAgent, ct);

        await audit.LogAsync("2FA.Success", AuditEventResult.Success,
            user.TenantId, user.Id, user.UserName, ipAddress, userAgent, null, ct);

        bool mustChange = user.MustChangePasswordAt.HasValue && user.MustChangePasswordAt.Value <= clock.UtcNow;
        return new IdentitySignInResult(IdentitySignInStatus.Success,
            UserId: user.Id, UserName: user.UserName, RequiresPasswordChange: mustChange);
    }

    public async Task<TwoFactorSendResult> ResendTwoFactorCodeAsync(CancellationToken ct = default)
    {
        var httpContext = httpContextAccessor.HttpContext
            ?? throw new InvalidOperationException("No HTTP context.");

        var authResult = await httpContext.AuthenticateAsync(IdentityConstants.TwoFactorUserIdScheme);
        if (!authResult.Succeeded)
            return new TwoFactorSendResult(false, "Session expired. Please sign in again.");

        var userIdStr = authResult.Principal?.FindFirstValue(ClaimTypes.Name);
        if (!Guid.TryParse(userIdStr, out var userId))
            return new TwoFactorSendResult(false, "Session expired. Please sign in again.");

        var throttled = await twoFactorService.IsResendThrottledAsync(userId, ct);
        if (throttled)
            return new TwoFactorSendResult(false, "Please wait before requesting another code.");

        var email = authResult.Principal?.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
        var tenantIdStr = authResult.Principal?.FindFirstValue("tenant_id");
        if (!Guid.TryParse(tenantIdStr, out var tenantId))
            return new TwoFactorSendResult(false, "Session expired.");

        return await twoFactorService.SendCodeAsync(userId, tenantId, email, ct);
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

        // [PWD-04] Check last 10 password hashes
        var history = await db.UserPasswordHistories
            .IgnoreQueryFilters()
            .Where(h => h.UserId == userId)
            .OrderByDescending(h => h.CreatedAt)
            .Take(10)
            .ToListAsync(ct);

        foreach (var h in history)
        {
            var check = userManager.PasswordHasher.VerifyHashedPassword(user, h.PasswordHash, newPassword);
            if (check != PasswordVerificationResult.Failed)
                return new ChangePasswordResult(false, "Password has been used recently. Please choose a different password.");
        }

        var oldHash = user.PasswordHash ?? string.Empty;
        var result = await userManager.ChangePasswordAsync(user, currentPassword, newPassword);
        if (!result.Succeeded)
            return new ChangePasswordResult(false, string.Join(" ", result.Errors.Select(e => e.Description)));

        // Store old hash in history
        db.UserPasswordHistories.Add(new UserPasswordHistory
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = user.TenantId,
            PasswordHash = oldHash,
            CreatedAt = clock.UtcNow
        });

        // Prune excess entries beyond 10
        var excess = history.Skip(9).ToList();
        if (excess.Count > 0)
            db.UserPasswordHistories.RemoveRange(excess);

        user.MustChangePasswordAt = null;
        await userManager.UpdateAsync(user);
        await db.SaveChangesAsync(ct);
        return new ChangePasswordResult(true);
    }

    public async Task<ChangePasswordResult> ForceSetPasswordAsync(
        Guid userId, string newPassword, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null)
            return new ChangePasswordResult(false, "User not found.");

        var history = await db.UserPasswordHistories
            .Where(h => h.UserId == userId)
            .OrderByDescending(h => h.CreatedAt)
            .Take(10).ToListAsync(ct);

        foreach (var h in history)
        {
            var check = userManager.PasswordHasher.VerifyHashedPassword(user, h.PasswordHash, newPassword);
            if (check != PasswordVerificationResult.Failed)
                return new ChangePasswordResult(false, "Password has been used recently. Please choose a different password.");
        }

        var oldHash = user.PasswordHash ?? string.Empty;
        await userManager.RemovePasswordAsync(user);
        var result = await userManager.AddPasswordAsync(user, newPassword);
        if (!result.Succeeded)
            return new ChangePasswordResult(false, string.Join(" ", result.Errors.Select(e => e.Description)));

        db.UserPasswordHistories.Add(new UserPasswordHistory
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = user.TenantId,
            PasswordHash = oldHash,
            CreatedAt = clock.UtcNow
        });

        var excess = history.Skip(9).ToList();
        if (excess.Count > 0)
            db.UserPasswordHistories.RemoveRange(excess);

        user.MustChangePasswordAt = null;
        await userManager.UpdateAsync(user);
        await db.SaveChangesAsync(ct);
        return new ChangePasswordResult(true);
    }

    private async Task StorePendingTwoFactorAsync(Guid userId, Guid tenantId, string email)
    {
        var httpContext = httpContextAccessor.HttpContext!;
        var identity = new ClaimsIdentity(IdentityConstants.TwoFactorUserIdScheme);
        identity.AddClaim(new Claim(ClaimTypes.Name, userId.ToString()));
        identity.AddClaim(new Claim("tenant_id", tenantId.ToString()));
        identity.AddClaim(new Claim(ClaimTypes.Email, email));
        await httpContext.SignInAsync(
            IdentityConstants.TwoFactorUserIdScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent = false });
    }

    private async Task CompleteSignInAsync(ApplicationUser user, string ipAddress, string userAgent, CancellationToken ct)
    {
        await signInManager.SignInAsync(user, isPersistent: false);
        user.LastLoginAt = clock.UtcNow;
        await userManager.UpdateAsync(user);
        await audit.LogAsync("Login.Success", AuditEventResult.Success,
            user.TenantId, user.Id, user.UserName, ipAddress, userAgent, null, ct);
    }
}
