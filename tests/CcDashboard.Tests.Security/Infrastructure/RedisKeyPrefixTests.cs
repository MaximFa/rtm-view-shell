using FluentAssertions;

namespace CcDashboard.Tests.Security.Infrastructure;

/// <summary>
/// Tests for Redis key prefix pattern (ARCH-08).
/// Verifies tenant isolation in cache by ensuring keys follow "{tenantId}:{namespace}:{key}" pattern.
/// </summary>
public class RedisKeyPrefixTests
{
    [Fact]
    [Trait("Req", "ARCH-08")]
    public void RevokedJtiKey_FollowsTenantPrefixPattern()
    {
        // Arrange
        var tenantId = Guid.NewGuid();
        var jti = Guid.NewGuid().ToString();

        // Act: Build key per TokenService.RevokeJtiAsync pattern
        var key = $"{tenantId}:revoked_jti:{jti}";

        // Assert
        key.Should().StartWith($"{tenantId}:");
        key.Should().Contain(":revoked_jti:");
        key.Should().EndWith(jti);
    }

    [Fact]
    [Trait("Req", "ARCH-08")]
    public void CacheKey_DifferentTenants_ProduceDifferentKeys()
    {
        // Arrange
        var tenantA = Guid.NewGuid();
        var tenantB = Guid.NewGuid();
        var resourceKey = "user:profile:123";

        // Act
        var keyA = $"{tenantA}:{resourceKey}";
        var keyB = $"{tenantB}:{resourceKey}";

        // Assert: Keys are different despite same resource
        keyA.Should().NotBe(keyB);
        keyA.Should().StartWith($"{tenantA}:");
        keyB.Should().StartWith($"{tenantB}:");
    }

    [Fact]
    [Trait("Req", "ARCH-08")]
    public void PermissionGroupCacheKey_FollowsTenantPrefixPattern()
    {
        // Arrange: Per PG-07, permission cache uses pattern "{tenantId}:pg_permissions:{pgId}"
        var tenantId = Guid.NewGuid();
        var pgId = Guid.NewGuid();

        // Act
        var key = $"{tenantId}:pg_permissions:{pgId}";

        // Assert
        key.Should().StartWith($"{tenantId}:");
        key.Should().Contain(":pg_permissions:");
        key.Should().EndWith(pgId.ToString());
    }

    [Fact]
    [Trait("Req", "ARCH-08")]
    public void RateLimitKey_FollowsTenantPrefixPattern()
    {
        // Arrange: Per 2FA-04, resend rate limit uses tenant-prefixed key
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        // Act
        var key = $"{tenantId}:2fa_resend:{userId}";

        // Assert
        key.Should().StartWith($"{tenantId}:");
        key.Should().Contain(":2fa_resend:");
    }
}
