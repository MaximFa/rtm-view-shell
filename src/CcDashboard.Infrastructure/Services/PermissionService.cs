using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// Permission service implementation with Redis caching [PG-04, PG-07].
/// Cache key format: {tenantId}:pg_permissions:{pgId} [ARCH-08].
/// </summary>
public class PermissionService(
    IPermissionGroupRepository repo,
    ICacheService cache,
    ILogger<PermissionService> logger) : IPermissionService
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(15);

    public async Task<bool> HasPermissionAsync(
        Guid? permissionGroupId, Guid tenantId, string permission, CancellationToken ct = default)
    {
        // No PG = no specific permission (typically Superadmin, who bypasses checks in AuthorizationBehavior)
        if (permissionGroupId is null)
            return true;

        var entry = await GetCachedPermissionsAsync(tenantId, permissionGroupId.Value, ct);
        if (entry is null)
        {
            logger.LogWarning("Permission group {PgId} not found for tenant {TenantId}", permissionGroupId, tenantId);
            return false;
        }

        // Check if it's a menu permission
        if (permission.StartsWith("menu."))
            return entry.MenuKeys.Contains(permission);

        // Generic permission key not found in known types
        logger.LogDebug("Unknown permission type: {Permission}", permission);
        return false;
    }

    public async Task<bool> HasDashboardAccessAsync(
        Guid? permissionGroupId, Guid tenantId, Guid dashboardId, int requiredLevel, CancellationToken ct = default)
    {
        if (permissionGroupId is null)
            return true;

        var entry = await GetCachedPermissionsAsync(tenantId, permissionGroupId.Value, ct);
        if (entry is null)
            return false;

        // Check if PG has the dashboard with required access level
        if (entry.DashboardPermissions.TryGetValue(dashboardId, out var grantedLevel))
        {
            // Bitmask check: (grantedLevel & requiredLevel) == requiredLevel
            return (grantedLevel & requiredLevel) == requiredLevel;
        }

        return false;
    }

    public async Task<bool> HasResourceAccessAsync(
        Guid? permissionGroupId, Guid tenantId, string resourceType, Guid resourceId, CancellationToken ct = default)
    {
        if (permissionGroupId is null)
            return true;

        var entry = await GetCachedPermissionsAsync(tenantId, permissionGroupId.Value, ct);
        if (entry is null)
            return false;

        // [PG-03] Empty list = access denied (not "access to all")
        return resourceType.ToLowerInvariant() switch
        {
            "queue" => entry.AllowedQueueIds.Contains(resourceId),
            "skill" or "agentgroup" => entry.AllowedSkillIds.Contains(resourceId),
            _ => false
        };
    }

    public async Task InvalidateCacheAsync(Guid tenantId, Guid permissionGroupId, CancellationToken ct = default)
    {
        var key = GetCacheKey(tenantId, permissionGroupId);
        await cache.RemoveAsync(key, ct);
        logger.LogDebug("Invalidated permission cache for PG {PgId} in tenant {TenantId}", permissionGroupId, tenantId);
    }

    private async Task<PermissionCacheEntry?> GetCachedPermissionsAsync(
        Guid tenantId, Guid permissionGroupId, CancellationToken ct)
    {
        var key = GetCacheKey(tenantId, permissionGroupId);

        // Try cache first
        var cached = await cache.GetAsync<PermissionCacheEntry>(key, ct);
        if (cached is not null)
            return cached;

        // Cache miss — load from database
        var group = await repo.GetByIdAsync(permissionGroupId, ct);
        if (group is null || group.TenantId != tenantId)
            return null;

        var entry = new PermissionCacheEntry
        {
            PermissionGroupId = permissionGroupId,
            TenantId = tenantId,
            IsActive = group.IsActive,
            MenuKeys = group.MenuPermissions.Select(m => m.MenuKey).ToHashSet(),
            DashboardPermissions = group.DashboardPermissions.ToDictionary(
                d => d.DashboardId,
                d => d.AccessLevel),
            AllowedQueueIds = group.AllowedQueues.Select(q => q.ObjectId).ToHashSet(),
            AllowedSkillIds = group.AllowedSkills.Select(s => s.ObjectId).ToHashSet(),
            AllowedBusinessUnitIds = group.AllowedBusinessUnits.Select(b => b.BusinessUnitId).ToHashSet(),
            AllowedSupergroupIds = group.AllowedSupergroups.Select(s => s.SupergroupId).ToHashSet()
        };

        // Cache for future requests
        await cache.SetAsync(key, entry, CacheTtl, ct);

        return entry;
    }

    private static string GetCacheKey(Guid tenantId, Guid permissionGroupId)
        => $"{tenantId}:pg_permissions:{permissionGroupId}";
}

/// <summary>
/// Cached permission data for a permission group.
/// </summary>
public class PermissionCacheEntry
{
    public Guid PermissionGroupId { get; set; }
    public Guid TenantId { get; set; }
    public bool IsActive { get; set; }
    public HashSet<string> MenuKeys { get; set; } = [];
    public Dictionary<Guid, int> DashboardPermissions { get; set; } = [];
    public HashSet<Guid> AllowedQueueIds { get; set; } = [];
    public HashSet<Guid> AllowedSkillIds { get; set; } = [];
    public HashSet<int> AllowedBusinessUnitIds { get; set; } = [];
    public HashSet<int> AllowedSupergroupIds { get; set; } = [];
}
