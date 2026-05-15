using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Security.Cryptography;
using UUIDNext;

namespace CcDashboard.Infrastructure.Identity;

public class UserManagementService(
    UserManager<ApplicationUser> userManager,
    AppDbContext db,
    IEmailSender emailSender,
    IDateTimeProvider clock,
    IAuditService audit,
    ICurrentUserAccessor currentUser,
    ILogger<UserManagementService> logger)
    : IUserManagementService
{
    public async Task<(bool Succeeded, string? Error, Guid UserId)> CreateAsync(
        Guid tenantId, CreateUserRequest req, CancellationToken ct = default)
    {
        // [LIC-01] Check purchased licence limit
        // [ARCH-01] IgnoreQueryFilters for cross-tenant licence check — explicit TenantId filter applied
        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == tenantId, ct);
        if (settings?.PurchasedLicences > 0)
        {
            var userCount = await db.Users.IgnoreQueryFilters()
                .CountAsync(u => u.TenantId == tenantId, ct);
            if (userCount >= settings.PurchasedLicences)
                return (false, $"Licence limit reached ({settings.PurchasedLicences} users). Cannot create more users.", Guid.Empty);
        }

        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            UserName = req.UserName,
            NormalizedUserName = req.UserName.ToUpperInvariant(),
            Email = req.Email,
            NormalizedEmail = req.Email.ToUpperInvariant(),
            EmailConfirmed = true,
            FirstName = req.FirstName,
            LastName = req.LastName,
            PermissionGroupId = req.PermissionGroupId,
            IsActive = true,
            PreferredLocale = req.PreferredLocale,
            MustChangePasswordAt = clock.UtcNow,  // [USR-03] force change on first login
        };

        var tempPassword = GenerateTempPassword();
        var result = await userManager.CreateAsync(user, tempPassword);
        if (!result.Succeeded)
            return (false, string.Join(" ", result.Errors.Select(e => e.Description)), Guid.Empty);

        var roleResult = await userManager.AddToRoleAsync(user, req.Role);
        if (!roleResult.Succeeded)
            logger.LogWarning("Failed to assign role {Role} to user {Id}: {Errors}",
                req.Role, user.Id, string.Join(", ", roleResult.Errors.Select(e => e.Description)));

        await audit.LogAsync("User.Created", AuditEventResult.Success,
            tenantId, currentUser.UserId, currentUser.UserName,
            details: new { TargetUserId = user.Id, user.UserName, req.Role }, ct: ct);

        // [USR-03] Send temporary password by email
        try
        {
            await emailSender.SendAsync(req.Email,
                "Your RTM View Shell account has been created",
                $"Hello {req.FirstName},\n\nYour account has been created.\nUsername: {req.UserName}\nTemporary password: {tempPassword}\n\nYou will be required to change your password on first login.",
                ct);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send welcome email to {Email}", req.Email);
            // [MAINT-02] Never log passwords — admin must re-trigger password reset if email fails
        }

        return (true, null, user.Id);
    }

    public async Task<(bool Succeeded, string? Error)> UpdateAsync(UpdateUserRequest req, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(req.Id.ToString());
        if (user == null) return (false, "User not found.");

        user.FirstName = req.FirstName;
        user.LastName = req.LastName;
        user.Email = req.Email;
        user.NormalizedEmail = req.Email.ToUpperInvariant();
        user.IsActive = req.IsActive;
        user.Is2faEnabled = req.Is2faEnabled;
        user.PermissionGroupId = req.PermissionGroupId;
        user.PreferredLocale = req.PreferredLocale;

        var result = await userManager.UpdateAsync(user);
        if (!result.Succeeded)
            return (false, string.Join(" ", result.Errors.Select(e => e.Description)));

        // Update role
        var currentRoles = await userManager.GetRolesAsync(user);
        if (!currentRoles.Contains(req.Role))
        {
            await userManager.RemoveFromRolesAsync(user, currentRoles);
            await userManager.AddToRoleAsync(user, req.Role);
        }

        await audit.LogAsync("User.Updated", AuditEventResult.Success,
            user.TenantId, currentUser.UserId, currentUser.UserName,
            details: new { TargetUserId = user.Id, user.UserName }, ct: ct);

        return (true, null);
    }

    public async Task<(bool Succeeded, string? Error)> SetActiveAsync(Guid userId, bool isActive, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null) return (false, "User not found.");

        user.IsActive = isActive;
        if (!isActive)
            await userManager.UpdateSecurityStampAsync(user);  // [USR-09] invalidate sessions

        var result = await userManager.UpdateAsync(user);
        if (result.Succeeded)
        {
            var eventType = isActive ? "User.Activated" : "User.Deactivated";
            await audit.LogAsync(eventType, AuditEventResult.Success,
                user.TenantId, currentUser.UserId, currentUser.UserName,
                details: new { TargetUserId = userId }, ct: ct);
        }
        return (result.Succeeded, result.Succeeded ? null : string.Join(" ", result.Errors.Select(e => e.Description)));
    }

    public async Task<(bool Succeeded, string? Error)> AdminResetPasswordAsync(Guid userId, string resetBaseUrl, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null) return (false, "User not found.");

        // [USR-11] generate reset token, build clickable link, send email
        var token = await userManager.GeneratePasswordResetTokenAsync(user);
        var link = $"{resetBaseUrl.TrimEnd('/')}?email={Uri.EscapeDataString(user.Email!)}&token={Uri.EscapeDataString(token)}";
        try
        {
            await emailSender.SendAsync(user.Email!,
                "Password Reset — RTM View Shell",
                $"Hello {user.FirstName},\n\nA password reset was requested for your account by an administrator.\n\nClick the link below to set a new password (valid for 24 hours):\n{link}",
                ct);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send password reset email to {Email}", user.Email);
            return (false, "Failed to send password reset email.");
        }

        return (true, null);
    }

    public async Task ForceLogoutAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user != null)
            await userManager.UpdateSecurityStampAsync(user);  // [USR-09]
    }

    public async Task<(bool Succeeded, string? Error)> DeleteAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user == null) return (false, "User not found.");

        var result = await userManager.DeleteAsync(user);
        if (result.Succeeded)
            await audit.LogAsync("User.Deleted", AuditEventResult.Success,
                user.TenantId, currentUser.UserId, currentUser.UserName,
                details: new { TargetUserId = userId, user.UserName }, ct: ct);
        return (result.Succeeded, result.Succeeded ? null : string.Join(" ", result.Errors.Select(e => e.Description)));
    }

    public async Task RequestPasswordResetAsync(Guid tenantId, string email, string resetBaseUrl, CancellationToken ct = default)
    {
        // Always show uniform response — look up silently [BFP-03]
        var user = await db.Set<ApplicationUser>()
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.TenantId == tenantId &&
                                      u.NormalizedEmail == email.ToUpperInvariant(), ct);
        if (user == null) return;

        var token = await userManager.GeneratePasswordResetTokenAsync(user);
        var encodedToken = Uri.EscapeDataString(token);
        var encodedEmail = Uri.EscapeDataString(email);
        var link = $"{resetBaseUrl}?email={encodedEmail}&token={encodedToken}";

        try
        {
            await emailSender.SendAsync(user.Email!,
                "Password Reset — RTM View Shell",
                $"Hello {user.FirstName},\n\nClick the link below to reset your password (valid 24 hours):\n{link}",
                ct);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to send password reset email to {Email}", email);
        }
    }

    public async Task<ChangePasswordResult> ResetPasswordWithTokenAsync(
        Guid tenantId, string email, string token, string newPassword, CancellationToken ct = default)
    {
        var user = await db.Set<ApplicationUser>()
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.TenantId == tenantId &&
                                      u.NormalizedEmail == email.ToUpperInvariant(), ct);
        if (user == null)
            return new ChangePasswordResult(false, "Invalid request.");

        var result = await userManager.ResetPasswordAsync(user, token, newPassword);
        if (!result.Succeeded)
            return new ChangePasswordResult(false, string.Join(" ", result.Errors.Select(e => e.Description)));

        user.MustChangePasswordAt = null;
        await userManager.UpdateAsync(user);
        return new ChangePasswordResult(true);
    }

    private static string GenerateTempPassword()
    {
        const string upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
        const string lower = "abcdefghjkmnpqrstuvwxyz";
        const string digits = "23456789";
        const string special = "!@#$%";
        const string all = upper + lower + digits + special;

        var bytes = new byte[12];
        RandomNumberGenerator.Fill(bytes);

        // Ensure complexity
        var chars = new char[12];
        chars[0] = upper[bytes[0] % upper.Length];
        chars[1] = lower[bytes[1] % lower.Length];
        chars[2] = digits[bytes[2] % digits.Length];
        chars[3] = special[bytes[3] % special.Length];
        for (int i = 4; i < 12; i++)
            chars[i] = all[bytes[i] % all.Length];

        // Shuffle
        RandomNumberGenerator.Shuffle(chars.AsSpan());
        return new string(chars);
    }
}
