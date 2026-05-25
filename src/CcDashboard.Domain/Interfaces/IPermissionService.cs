namespace CcDashboard.Domain.Interfaces;

/// <summary>
/// Service for checking user permissions at the Application layer [PG-04].
/// Implementations should use Redis caching with key format {tenantId}:pg_permissions:{pgId}.
/// </summary>
public interface IPermissionService
{
    /// <summary>
    /// Checks if a permission group has the specified permission.
    /// </summary>
    /// <param name="permissionGroupId">The permission group ID (null for Superadmin = always true).</param>
    /// <param name="tenantId">The tenant context for cache key prefixing [ARCH-08].</param>
    /// <param name="permission">The permission key (e.g., "menu.users", "dashboard.view:{id}").</param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>True if the permission is granted; false otherwise.</returns>
    Task<bool> HasPermissionAsync(Guid? permissionGroupId, Guid tenantId, string permission, CancellationToken ct = default);

    /// <summary>
    /// Checks if a permission group has access to a specific dashboard with the required access level.
    /// </summary>
    /// <param name="permissionGroupId">The permission group ID.</param>
    /// <param name="tenantId">The tenant context.</param>
    /// <param name="dashboardId">The dashboard ID.</param>
    /// <param name="requiredLevel">The required access level (View=1, Edit=2, Delete=4).</param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>True if the access level is granted; false otherwise.</returns>
    Task<bool> HasDashboardAccessAsync(Guid? permissionGroupId, Guid tenantId, Guid dashboardId, int requiredLevel, CancellationToken ct = default);

    /// <summary>
    /// Checks if a permission group has access to a specific CC-resource (queue, skill, etc.).
    /// Per PG-03: empty list = access denied (not "access to all").
    /// </summary>
    /// <param name="permissionGroupId">The permission group ID.</param>
    /// <param name="tenantId">The tenant context.</param>
    /// <param name="resourceType">The resource type (queue, skill, supergroup, business_unit).</param>
    /// <param name="resourceId">The resource ID.</param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>True if access to the resource is granted; false otherwise.</returns>
    Task<bool> HasResourceAccessAsync(Guid? permissionGroupId, Guid tenantId, string resourceType, Guid resourceId, CancellationToken ct = default);

    /// <summary>
    /// Invalidates the cached permissions for a permission group [PG-07].
    /// Called when a PG is updated to ensure active sessions re-fetch on next interaction.
    /// </summary>
    Task InvalidateCacheAsync(Guid tenantId, Guid permissionGroupId, CancellationToken ct = default);
}
