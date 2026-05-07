namespace CcDashboard.Application.DTOs;

public record LoginRequest(string Email, string Password);

public record LoginResponse(
    Guid UserId,
    string Email,
    string DisplayName,
    bool RequiresTwoFactor,
    string? AccessToken,
    string? RefreshToken);

public record RegisterUserRequest(string Email, string DisplayName, string Password);

public record UpdateUserRequest(string DisplayName, bool? IsActive = null);

public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

public record VerifyTwoFactorRequest(Guid UserId, string Code);

public record RefreshTokenRequest(string RefreshToken);

public record TokenPair(string AccessToken, string RefreshToken, DateTime ExpiresAt);

public record UserDto(
    Guid Id,
    string Email,
    string DisplayName,
    bool IsSsoUser,
    bool TwoFactorEnabled,
    bool IsActive,
    DateTime? LastLoginAt,
    DateTime CreatedAt);
