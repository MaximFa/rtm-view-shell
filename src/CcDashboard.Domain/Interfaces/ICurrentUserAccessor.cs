namespace CcDashboard.Domain.Interfaces;

public interface ICurrentUserAccessor
{
    Guid? UserId { get; }
    string? UserName { get; }
    string? Role { get; }
    Guid? PermissionGroupId { get; }
    Guid? TenantId { get; }
    string PreferredLocale { get; }
    bool IsAuthenticated { get; }
}
