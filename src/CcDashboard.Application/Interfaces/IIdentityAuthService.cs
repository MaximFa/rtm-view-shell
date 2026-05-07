namespace CcDashboard.Application.Interfaces;

public interface IIdentityAuthService
{
    /// <summary>
    /// Verifies credentials; on 2FA required stores partial auth cookie and sends OTP.
    /// Returns RequiresTwoFactor to redirect to /login/2fa.
    /// </summary>
    Task<IdentitySignInResult> PasswordSignInAsync(
        Guid tenantId, string userName, string password,
        string ipAddress, string userAgent,
        CancellationToken ct = default);

    /// <summary>Verifies OTP from partial auth cookie and issues full application cookie.</summary>
    Task<IdentitySignInResult> CompleteTwoFactorAsync(string code, CancellationToken ct = default);

    /// <summary>Resends a new OTP to the user stored in the partial auth cookie.</summary>
    Task<TwoFactorSendResult> ResendTwoFactorCodeAsync(CancellationToken ct = default);

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
