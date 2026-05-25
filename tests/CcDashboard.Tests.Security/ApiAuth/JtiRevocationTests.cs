using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Security;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace CcDashboard.Tests.Security.ApiAuth;

/// <summary>
/// Tests for JTI (JWT ID) revocation via Redis per AUTH-API-05.
/// On logout/deactivation/force-logout: add jti to Redis with TTL = remaining token lifetime.
/// Middleware checks Redis on every request.
/// </summary>
[Collection("PostgresAndRedis")]
public class JtiRevocationTests
{
    private readonly PostgresFixture _pgFixture;
    private readonly RedisFixture _redisFixture;

    public JtiRevocationTests(PostgresFixture pgFixture, RedisFixture redisFixture)
    {
        _pgFixture = pgFixture;
        _redisFixture = redisFixture;
    }

    [Fact]
    [Trait("Req", "AUTH-API-05")]
    public async Task RevokeJtiAsync_AddsKeyToRedisWithCorrectTtl()
    {
        // Arrange
        await _redisFixture.FlushAllAsync();
        var sut = CreateTokenService(_pgFixture.TenantAId);
        var jti = Guid.NewGuid().ToString();
        var remaining = TimeSpan.FromMinutes(10);

        // Act
        await sut.RevokeJtiAsync(jti, _pgFixture.TenantAId, remaining);

        // Assert
        var db = _redisFixture.GetDatabase();
        var key = $"{_pgFixture.TenantAId}:revoked_jti:{jti}";
        var exists = await db.KeyExistsAsync(key);
        exists.Should().BeTrue("JTI should be added to Redis revocation list [AUTH-API-05]");

        var ttl = await db.KeyTimeToLiveAsync(key);
        ttl.Should().NotBeNull("JTI key should have TTL");
        ttl!.Value.TotalMinutes.Should().BeApproximately(10, 0.5,
            "TTL should be approximately the remaining token lifetime");
    }

    [Fact]
    [Trait("Req", "AUTH-API-05")]
    public async Task IsJtiRevokedAsync_RevokedJti_ReturnsTrue()
    {
        // Arrange
        await _redisFixture.FlushAllAsync();
        var sut = CreateTokenService(_pgFixture.TenantAId);
        var jti = Guid.NewGuid().ToString();

        await sut.RevokeJtiAsync(jti, _pgFixture.TenantAId, TimeSpan.FromMinutes(15));

        // Act
        var isRevoked = await sut.IsJtiRevokedAsync(jti, _pgFixture.TenantAId);

        // Assert
        isRevoked.Should().BeTrue("Revoked JTI should be detected [AUTH-API-05]");
    }

    [Fact]
    [Trait("Req", "AUTH-API-05")]
    public async Task IsJtiRevokedAsync_NonRevokedJti_ReturnsFalse()
    {
        // Arrange
        await _redisFixture.FlushAllAsync();
        var sut = CreateTokenService(_pgFixture.TenantAId);
        var jti = Guid.NewGuid().ToString();

        // Act
        var isRevoked = await sut.IsJtiRevokedAsync(jti, _pgFixture.TenantAId);

        // Assert
        isRevoked.Should().BeFalse("Non-revoked JTI should not be detected as revoked");
    }

    [Fact]
    [Trait("Req", "AUTH-API-05")]
    [Trait("Req", "ARCH-08")]
    public async Task RevokeJtiAsync_UsesTenantPrefixedKey()
    {
        // Arrange - Redis keys must be tenant-isolated [ARCH-08]
        await _redisFixture.FlushAllAsync();
        var jti = Guid.NewGuid().ToString();

        var sutA = CreateTokenService(_pgFixture.TenantAId);
        var sutB = CreateTokenService(_pgFixture.TenantBId);

        // Act - Revoke same JTI in TenantA only
        await sutA.RevokeJtiAsync(jti, _pgFixture.TenantAId, TimeSpan.FromMinutes(15));

        // Assert
        var isRevokedInA = await sutA.IsJtiRevokedAsync(jti, _pgFixture.TenantAId);
        var isRevokedInB = await sutB.IsJtiRevokedAsync(jti, _pgFixture.TenantBId);

        isRevokedInA.Should().BeTrue("JTI should be revoked in TenantA");
        isRevokedInB.Should().BeFalse(
            "JTI revoked in TenantA should NOT affect TenantB — keys are tenant-prefixed [ARCH-08]");
    }

    [Fact]
    [Trait("Req", "AUTH-API-05")]
    public async Task RevokeJtiAsync_ZeroOrNegativeRemaining_DoesNotAddKey()
    {
        // Arrange - if token already expired, no need to add to revocation list
        await _redisFixture.FlushAllAsync();
        var sut = CreateTokenService(_pgFixture.TenantAId);
        var jti = Guid.NewGuid().ToString();

        // Act
        await sut.RevokeJtiAsync(jti, _pgFixture.TenantAId, TimeSpan.Zero);

        // Assert
        var isRevoked = await sut.IsJtiRevokedAsync(jti, _pgFixture.TenantAId);
        isRevoked.Should().BeFalse("Already-expired token doesn't need revocation entry");
    }

    #region Helpers

    private ITokenService CreateTokenService(Guid tenantId)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider>(new TestDateTimeProvider());
        services.AddSingleton(_redisFixture.Connection);

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_pgFixture.ConnectionString));

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:SecretKey"] = "dev-test-secret-key-32-chars-min!",
                ["Jwt:Issuer"] = "TestIssuer",
                ["Jwt:Audience"] = "TestAudience"
            })
            .Build();
        services.AddSingleton<IConfiguration>(config);

        services.AddLogging();
        services.AddScoped<ITokenService, TokenService>();

        var sp = services.BuildServiceProvider();
        return sp.GetRequiredService<ITokenService>();
    }

    #endregion
}
