namespace CcDashboard.Application.Interfaces;

public interface IIdentityAuthService
{
    /// <summary>
    /// Verifies credentials for a user within the given tenant and creates the auth cookie.
    /// Password verification, lockout tracking, and cookie creation all happen here.
    /// </summary>
    Task<IdentitySignInResult> PasswordSignInAsync(
        Guid tenantId, string userName, string password,
        string ipAddress, string userAgent,
        CancellationToken ct = default);

    Task SignOutAsync(CancellationToken ct = default);

    Task<ChangePasswordResult> ChangePasswordAsync(
        Guid userId, string currentPassword, string newPassword,
        CancellationToken ct = default);
}

public record IdentitySignInResult(
    IdentitySignInStatus Status,
    Guid? UserId = null,
    string? UserName = null,
    bool RequiresPasswordChange = false);

public enum IdentitySignInStatus
{
    Success,
    InvalidCredentials,
    LockedOut,
    RequiresTwoFactor,
    TenantMismatch,
    AccountInactive,
    TenantSuspended
}

public record ChangePasswordResult(bool Succeeded, string? Error = null);
