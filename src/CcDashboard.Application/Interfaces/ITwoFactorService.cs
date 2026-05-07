namespace CcDashboard.Application.Interfaces;

public interface ITwoFactorService
{
    /// <summary>Generates OTP, stores HMAC-SHA256 hash in DB, sends email [2FA-02..05].</summary>
    Task<TwoFactorSendResult> SendCodeAsync(Guid userId, Guid tenantId, string email, CancellationToken ct = default);

    /// <summary>Verifies submitted code; tracks attempts, invalidates on exceed [2FA-04].</summary>
    Task<TwoFactorVerifyResult> VerifyCodeAsync(Guid userId, string code, CancellationToken ct = default);

    /// <summary>Returns true if resend is rate-limited (1/min per userId) [2FA-04].</summary>
    Task<bool> IsResendThrottledAsync(Guid userId, CancellationToken ct = default);
}

public record TwoFactorSendResult(bool Succeeded, string? Error = null);

public record TwoFactorVerifyResult(bool Succeeded, bool MaxAttemptsExceeded = false, string? Error = null);
