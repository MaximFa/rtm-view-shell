using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Security;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using StackExchange.Redis;

namespace CcDashboard.Tests.Security.ApiAuth;

/// <summary>
/// Tests for refresh token rotation and reuse detection per AUTH-API-03/04.
/// </summary>
[Collection("PostgresAndRedis")]
public class RefreshTokenRotationTests
{
    private readonly PostgresFixture _pgFixture;
    private readonly RedisFixture _redisFixture;

    public RefreshTokenRotationTests(PostgresFixture pgFixture, RedisFixture redisFixture)
    {
        _pgFixture = pgFixture;
        _redisFixture = redisFixture;
    }

    [Fact]
    [Trait("Req", "AUTH-API-03")]
    public async Task CreateTokenPair_StoresRefreshTokenAsHash_NotPlaintext()
    {
        // Arrange
        var sut = CreateTokenService(_pgFixture.TenantAId);
        await using var db = CreateDbContext(_pgFixture.TenantAId);

        // Act
        var pair = await sut.CreateTokenPairAsync(
            _pgFixture.UserAId, _pgFixture.TenantAId, "Editor", _pgFixture.PgAId,
            "192.168.1.1", "TestAgent");

        // Assert
        var storedToken = await db.RefreshTokens.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.UserId == _pgFixture.UserAId);

        storedToken.Should().NotBeNull();
        storedToken!.TokenHash.Should().NotBe(pair.RefreshToken,
            "Refresh token should be stored as SHA-256 hash, not plaintext [AUTH-API-03]");
        storedToken.TokenHash.Length.Should().Be(64,
            "SHA-256 hash in hex should be 64 characters");
    }

    [Fact]
    [Trait("Req", "AUTH-API-04")]
    public async Task RefreshAsync_ValidToken_MarksOldAsRevokedAndSetsReplacedBy()
    {
        // Arrange
        var sut = CreateTokenService(_pgFixture.TenantAId);

        var originalPair = await sut.CreateTokenPairAsync(
            _pgFixture.UserAId, _pgFixture.TenantAId, "Editor", _pgFixture.PgAId,
            "192.168.1.1", "TestAgent");

        await using var db = CreateDbContext(_pgFixture.TenantAId);
        var originalRecord = await db.RefreshTokens.IgnoreQueryFilters()
            .OrderByDescending(t => t.IssuedAt)
            .FirstAsync(t => t.UserId == _pgFixture.UserAId);
        var originalId = originalRecord.Id;

        // Act
        var newPair = await sut.RefreshAsync(originalPair.RefreshToken, "192.168.1.2", "NewAgent");

        // Assert
        newPair.Should().NotBeNull("Valid refresh should return new token pair");

        await using var verifyDb = CreateDbContext(_pgFixture.TenantAId);
        var oldRecord = await verifyDb.RefreshTokens.IgnoreQueryFilters()
            .FirstAsync(t => t.Id == originalId);

        oldRecord.RevokedAt.Should().NotBeNull("Old token should be marked as revoked [AUTH-API-04]");
        oldRecord.ReplacedByTokenId.Should().NotBeNull("Old token should track replacement [AUTH-API-04]");
    }

    [Fact]
    [Trait("Req", "AUTH-API-04")]
    public async Task RefreshAsync_RevokedToken_DetectsReuseAndRevokesAllUserTokens()
    {
        // Arrange
        var sut = CreateTokenService(_pgFixture.TenantAId);

        // Create original token
        var originalPair = await sut.CreateTokenPairAsync(
            _pgFixture.UserAId, _pgFixture.TenantAId, "Editor", _pgFixture.PgAId,
            "192.168.1.1", "TestAgent");

        // Legitimate refresh (marks original as revoked)
        var legitimatePair = await sut.RefreshAsync(originalPair.RefreshToken, "192.168.1.2", "Agent2");
        legitimatePair.Should().NotBeNull();

        // Create another valid token for the same user
        var anotherPair = await sut.CreateTokenPairAsync(
            _pgFixture.UserAId, _pgFixture.TenantAId, "Editor", _pgFixture.PgAId,
            "192.168.1.3", "Agent3");

        // Act: Attempt to reuse the already-revoked original token
        var reuseResult = await sut.RefreshAsync(originalPair.RefreshToken, "192.168.1.4", "Attacker");

        // Assert
        reuseResult.Should().BeNull("Reuse of revoked token should be rejected [AUTH-API-04]");

        await using var db = CreateDbContext(_pgFixture.TenantAId);
        var allUserTokens = await db.RefreshTokens.IgnoreQueryFilters()
            .Where(t => t.UserId == _pgFixture.UserAId)
            .ToListAsync();

        allUserTokens.Should().OnlyContain(t => t.RevokedAt != null,
            "Reuse detection should revoke ALL user's refresh tokens [AUTH-API-04]");
    }

    [Fact]
    [Trait("Req", "AUTH-API-04")]
    public async Task RefreshAsync_ExpiredToken_ReturnsNull()
    {
        // Arrange - manually insert an expired refresh token
        var rawToken = "test-expired-token-12345678901234567890";
        var tokenHash = Convert.ToHexString(
            System.Security.Cryptography.SHA256.HashData(
                System.Text.Encoding.UTF8.GetBytes(rawToken)));

        await using var db = CreateDbContext(_pgFixture.TenantAId);
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = UUIDNext.Uuid.NewSequential(),
            UserId = _pgFixture.UserAId,
            TenantId = _pgFixture.TenantAId,
            Jti = Guid.NewGuid(),
            TokenHash = tokenHash,
            ExpiresAt = DateTime.UtcNow.AddHours(-1), // Already expired
            IssuedAt = DateTime.UtcNow.AddHours(-9),
            IpAddress = "192.168.1.1",
            UserAgent = "TestAgent"
        });
        await db.SaveChangesAsync();

        var sut = CreateTokenService(_pgFixture.TenantAId);

        // Act
        var result = await sut.RefreshAsync(rawToken, "192.168.1.2", "Agent2");

        // Assert
        result.Should().BeNull("Expired refresh token should be rejected");
    }

    [Fact]
    [Trait("Req", "AUTH-API-03")]
    public async Task RefreshAsync_TokenNotFound_ReturnsNull()
    {
        // Arrange
        var sut = CreateTokenService(_pgFixture.TenantAId);

        // Act
        var result = await sut.RefreshAsync("invalid-token-that-does-not-exist", "192.168.1.1", "Agent");

        // Assert
        result.Should().BeNull("Non-existent refresh token should return null");
    }

    #region Helpers

    private ITokenService CreateTokenService(Guid tenantId, IDateTimeProvider? clock = null)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider>(clock ?? new TestDateTimeProvider());
        services.AddSingleton(_redisFixture.Connection);

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_pgFixture.ConnectionString));

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:SecretKey"] = "dev-test-secret-key-32-chars-min!",
                ["Jwt:Issuer"] = "TestIssuer",
                ["Jwt:Audience"] = "TestAudience",
                ["Jwt:AccessTokenExpiryMinutes"] = "15",
                ["Jwt:RefreshTokenExpiryHours"] = "8"
            })
            .Build();
        services.AddSingleton<IConfiguration>(config);

        services.AddLogging();
        services.AddScoped<ITokenService, TokenService>();

        var sp = services.BuildServiceProvider();
        return sp.GetRequiredService<ITokenService>();
    }

    private AppDbContext CreateDbContext(Guid tenantId)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(_pgFixture.ConnectionString)
            .Options;
        return new AppDbContext(options, new TestTenantContext(tenantId));
    }

    #endregion
}
