namespace CcDashboard.Contracts.DTOs.Users;

public record UserDto(
    Guid Id,
    Guid TenantId,
    string UserName,
    string Email,
    string FirstName,
    string LastName,
    string Role,
    Guid? PermissionGroupId,
    string? PermissionGroupName,
    bool IsActive,
    bool Is2faEnabled,
    DateTime? LastLoginAt,
    string PreferredLocale,
    DateTime CreatedAt);

public record CreateUserRequest(
    string UserName,
    string Email,
    string FirstName,
    string LastName,
    string Role,
    Guid? PermissionGroupId,
    string PreferredLocale = "en-US");

public record UpdateUserRequest(
    Guid Id,
    string FirstName,
    string LastName,
    string Email,
    string Role,
    Guid? PermissionGroupId,
    bool IsActive,
    bool Is2faEnabled,
    string PreferredLocale);

public record UserListRequest(
    string? Search,
    string? Role,
    Guid? PermissionGroupId,
    bool? IsActive,
    int Page = 1,
    int PageSize = 25,
    string SortBy = "UserName",
    bool SortDescending = false);
