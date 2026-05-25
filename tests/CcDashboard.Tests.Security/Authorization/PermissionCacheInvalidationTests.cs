using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Caching;
using CcDashboard.Infrastructure.Services;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for PG-07: Redis cache invalidation on PG update [DoD-9].
/// Per CLAUDE.md §15: "[PG-07] On PG edit: immediately invalidate PG permission cache in Redis
/// (`"{tenantId}:pg_permissions:{pgId}"`)."
/// </summary>
[Collection("Redis")]
public class PermissionCacheInvalidationTests
{
    private readonly RedisFixture _redis;

    private static readonly Guid TestTenantId = Uuid.NewSequential();
    private static readonly Guid TestPgId = Uuid.NewSequential();

    public PermissionCacheInvalidationTests(RedisFixture redis)
    {
        _redis = redis;
    }

    [Fact]
    [Trait("Req", "PG-07")]
    public async Task InvalidateCacheAsync_RemovesKeyFromRedis()
    {
        // Arrange
        await _redis.FlushAllAsync(); // Start clean

        var cacheService = new RedisCacheService(_redis.Connection, NullLogger<RedisCacheService>.Instance);
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cacheService, logger);
        var cacheKey = $"{TestTenantId}:pg_permissions:{TestPgId}";

        // Pre-populate cache
        var entry = new PermissionCacheEntry
        {
            PermissionGroupId = TestPgId,
            TenantId = TestTenantId,
            IsActive = true,
            MenuKeys = ["menu.users", "menu.dashboards"]
        };

        await cacheService.SetAsync(cacheKey, entry, TimeSpan.FromMinutes(15));

        // Verify cache is populated
        var cachedBefore = await cacheService.GetAsync<PermissionCacheEntry>(cacheKey);
        cachedBefore.Should().NotBeNull("Cache should be populated before invalidation");

        // Act
        await service.InvalidateCacheAsync(TestTenantId, TestPgId);

        // Assert
        var cachedAfter = await cacheService.GetAsync<PermissionCacheEntry>(cacheKey);
        cachedAfter.Should().BeNull("Cache should be invalidated after calling InvalidateCacheAsync");
    }

    [Fact]
    [Trait("Req", "PG-07")]
    public async Task InvalidateCacheAsync_CorrectKeyFormat()
    {
        // Arrange
        await _redis.FlushAllAsync();

        var db = _redis.GetDatabase();
        var cacheService = new RedisCacheService(_redis.Connection, NullLogger<RedisCacheService>.Instance);
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cacheService, logger);
        var expectedKey = $"{TestTenantId}:pg_permissions:{TestPgId}";

        // Pre-populate cache directly
        await db.StringSetAsync(expectedKey, "test_value", TimeSpan.FromMinutes(5));

        // Verify key exists
        var existsBefore = await db.KeyExistsAsync(expectedKey);
        existsBefore.Should().BeTrue("Key should exist before invalidation");

        // Act
        await service.InvalidateCacheAsync(TestTenantId, TestPgId);

        // Assert
        var existsAfter = await db.KeyExistsAsync(expectedKey);
        existsAfter.Should().BeFalse("Key should be deleted after invalidation");
    }

    [Fact]
    [Trait("Req", "PG-07")]
    public async Task InvalidateCacheAsync_DoesNotAffectOtherKeys()
    {
        // Arrange
        await _redis.FlushAllAsync();

        var cacheService = new RedisCacheService(_redis.Connection, NullLogger<RedisCacheService>.Instance);
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cacheService, logger);

        var otherPgId = Uuid.NewSequential();
        var otherTenantId = Uuid.NewSequential();

        // Pre-populate multiple cache entries
        await cacheService.SetAsync(
            $"{TestTenantId}:pg_permissions:{TestPgId}",
            new PermissionCacheEntry { PermissionGroupId = TestPgId },
            TimeSpan.FromMinutes(15));

        await cacheService.SetAsync(
            $"{TestTenantId}:pg_permissions:{otherPgId}",
            new PermissionCacheEntry { PermissionGroupId = otherPgId },
            TimeSpan.FromMinutes(15));

        await cacheService.SetAsync(
            $"{otherTenantId}:pg_permissions:{TestPgId}",
            new PermissionCacheEntry { PermissionGroupId = TestPgId },
            TimeSpan.FromMinutes(15));

        // Act - invalidate only TestTenantId:TestPgId
        await service.InvalidateCacheAsync(TestTenantId, TestPgId);

        // Assert - target key should be deleted
        var target = await cacheService.GetAsync<PermissionCacheEntry>(
            $"{TestTenantId}:pg_permissions:{TestPgId}");
        target.Should().BeNull("Target cache should be invalidated");

        // Other keys should remain
        var sameTenantOtherPg = await cacheService.GetAsync<PermissionCacheEntry>(
            $"{TestTenantId}:pg_permissions:{otherPgId}");
        sameTenantOtherPg.Should().NotBeNull("Other PG in same tenant should not be affected");

        var otherTenantSamePg = await cacheService.GetAsync<PermissionCacheEntry>(
            $"{otherTenantId}:pg_permissions:{TestPgId}");
        otherTenantSamePg.Should().NotBeNull("Same PG in other tenant should not be affected");
    }

    [Fact]
    [Trait("Req", "PG-07")]
    public async Task HasPermissionAsync_CacheMiss_LoadsFromDatabase()
    {
        // Arrange
        await _redis.FlushAllAsync();

        var cacheService = new RedisCacheService(_redis.Connection, NullLogger<RedisCacheService>.Instance);
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var permissionGroup = new PermissionGroup
        {
            Id = TestPgId,
            TenantId = TestTenantId,
            Name = "Test Group",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = Uuid.NewSequential(),
            UpdatedByUserId = Uuid.NewSequential()
        };

        permissionGroup.MenuPermissions.Add(new MenuPermission
        {
            PermissionGroupId = TestPgId,
            MenuKey = "menu.users",
            TenantId = TestTenantId
        });

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        var service = new PermissionService(repo.Object, cacheService, logger);

        // Act
        var result = await service.HasPermissionAsync(TestPgId, TestTenantId, "menu.users");

        // Assert
        result.Should().BeTrue("Permission should be granted from database");

        // Verify it was cached
        var cached = await cacheService.GetAsync<PermissionCacheEntry>(
            $"{TestTenantId}:pg_permissions:{TestPgId}");
        cached.Should().NotBeNull("Permission should be cached after first access");
        cached!.MenuKeys.Should().Contain("menu.users");
    }

    [Fact]
    [Trait("Req", "PG-07")]
    public async Task HasPermissionAsync_CacheHit_DoesNotQueryDatabase()
    {
        // Arrange
        await _redis.FlushAllAsync();

        var cacheService = new RedisCacheService(_redis.Connection, NullLogger<RedisCacheService>.Instance);
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        // Pre-populate cache
        var entry = new PermissionCacheEntry
        {
            PermissionGroupId = TestPgId,
            TenantId = TestTenantId,
            IsActive = true,
            MenuKeys = ["menu.dashboards"]
        };

        await cacheService.SetAsync(
            $"{TestTenantId}:pg_permissions:{TestPgId}",
            entry,
            TimeSpan.FromMinutes(15));

        var service = new PermissionService(repo.Object, cacheService, logger);

        // Act
        var result = await service.HasPermissionAsync(TestPgId, TestTenantId, "menu.dashboards");

        // Assert
        result.Should().BeTrue("Permission should be granted from cache");

        // Verify database was NOT queried
        repo.Verify(
            r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never,
            "Cache hit should not query database");
    }
}
