using CcDashboard.Contracts.DTOs.Users;

namespace CcDashboard.Application.Interfaces;

public interface IUserManagementService
{
    Task<(bool Succeeded, string? Error, Guid UserId)> CreateAsync(Guid tenantId, CreateUserRequest req, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> UpdateAsync(UpdateUserRequest req, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> SetActiveAsync(Guid userId, bool isActive, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> AdminResetPasswordAsync(Guid userId, string resetBaseUrl, CancellationToken ct = default);
    Task ForceLogoutAsync(Guid userId, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> DeleteAsync(Guid userId, CancellationToken ct = default);

    /// <summary>Self-service reset: looks up user by email, generates token, sends link [USR-12].</summary>
    Task RequestPasswordResetAsync(Guid tenantId, string email, string resetBaseUrl, CancellationToken ct = default);

    /// <summary>Applies a password reset token obtained from RequestPasswordResetAsync.</summary>
    Task<ChangePasswordResult> ResetPasswordWithTokenAsync(Guid tenantId, string email, string token, string newPassword, CancellationToken ct = default);
}
