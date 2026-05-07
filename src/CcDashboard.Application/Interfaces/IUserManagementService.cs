using CcDashboard.Contracts.DTOs.Users;

namespace CcDashboard.Application.Interfaces;

public interface IUserManagementService
{
    Task<(bool Succeeded, string? Error, Guid UserId)> CreateAsync(Guid tenantId, CreateUserRequest req, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> UpdateAsync(UpdateUserRequest req, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> SetActiveAsync(Guid userId, bool isActive, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> AdminResetPasswordAsync(Guid userId, CancellationToken ct = default);
    Task ForceLogoutAsync(Guid userId, CancellationToken ct = default);
    Task<(bool Succeeded, string? Error)> DeleteAsync(Guid userId, CancellationToken ct = default);
}
