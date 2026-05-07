namespace CcDashboard.Contracts.DTOs.Auth;

public record LoginRequest(string UserName, string Password);

public record LoginResult(
    bool RequiresTwoFactor,
    bool RequiresPasswordChange,
    Guid UserId,
    string Email,
    string DisplayName,
    string? AccessToken = null,
    string? RefreshToken = null);

public record TwoFactorRequest(Guid UserId, string Code);

public record TwoFactorResult(
    bool Success,
    Guid UserId,
    string Email,
    string DisplayName,
    string? AccessToken = null);

public record ChangePasswordRequest(Guid UserId, string CurrentPassword, string NewPassword);

public record ResetPasswordRequest(string Email);

public record ConfirmResetPasswordRequest(string Token, string NewPassword);

public record RefreshTokenRequest(string RefreshToken);

public record TokenResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt);
