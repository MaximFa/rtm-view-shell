using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Application.Interfaces;

public interface IUserRepository
{
    Task<ApplicationUserSnapshot?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<ApplicationUserSnapshot?> GetByEmailAsync(Guid tenantId, string email, CancellationToken ct = default);
    Task<ApplicationUserSnapshot?> GetByUserNameAsync(Guid tenantId, string userName, CancellationToken ct = default);
    Task<bool> ExistsAsync(Guid tenantId, string email, CancellationToken ct = default);
    Task<IReadOnlyList<ApplicationUserSnapshot>> GetPageAsync(
        Guid? tenantId, string? search, string? role, Guid? pgId, bool? isActive,
        int page, int pageSize, string sortBy, bool desc, CancellationToken ct = default);
    Task<int> CountAsync(Guid? tenantId, string? search, string? role, Guid? pgId, bool? isActive, CancellationToken ct = default);
}

public record ApplicationUserSnapshot(
    Guid Id,
    Guid TenantId,
    string UserName,
    string Email,
    string FirstName,
    string LastName,
    string? Role,
    Guid? PermissionGroupId,
    bool IsActive,
    bool Is2faEnabled,
    DateTime? LastLoginAt,
    string PreferredLocale,
    DateTime? MustChangePasswordAt,
    DateTime CreatedAt,
    string? PasswordHash,
    int AccessFailedCount,
    DateTimeOffset? LockoutEnd,
    bool LockoutEnabled);
