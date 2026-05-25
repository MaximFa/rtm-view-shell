using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Security;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NSubstitute;
using StackExchange.Redis;

namespace CcDashboard.Tests.Security.Authentication;

/// <summary>
/// Unit tests for JWT claims completeness (AUTH-API-01).
/// Tests TokenService.CreateTokenPairAsync directly per MC-T3-3.
/// </summary>
[Collection("Postgres")]
public class JwtClaimsTests(PostgresFixture postgres)
{
    [Fact]
    [Trait("Req", "AUTH-API-01")]
    public async Task CreateTokenPairAsync_ContainsRequiredClaims()
    {
        // Arrange
        var (tokenService, clock) = CreateTokenService();
        var userId = Guid.NewGuid();
        var tenantId = postgres.TenantAId;
        var role = "Editor";
        var pgId = postgres.PgAId;

        // Act
        var pair = await tokenService.CreateTokenPairAsync(
            userId, tenantId, role, pgId, "127.0.0.1", "test-agent");

        // Assert: Decode and verify claims
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(pair.AccessToken);

        token.Claims.Should().Contain(c => c.Type == JwtRegisteredClaimNames.Sub && c.Value == userId.ToString());
        token.Claims.Should().Contain(c => c.Type == "tenant_id" && c.Value == tenantId.ToString());
        token.Claims.Should().Contain(c => c.Type == ClaimTypes.Role && c.Value == role);
        token.Claims.Should().Contain(c => c.Type == "permission_group_id" && c.Value == pgId.ToString());
        token.Claims.Should().Contain(c => c.Type == JwtRegisteredClaimNames.Jti);
        token.Claims.Should().Contain(c => c.Type == JwtRegisteredClaimNames.Iat);
    }

    [Fact]
    [Trait("Req", "AUTH-API-01")]
    public async Task CreateTokenPairAsync_ExpiryIs15MinutesFromNow()
    {
        // Arrange
        var (tokenService, clock) = CreateTokenService();
        var now = new DateTime(2026, 5, 25, 12, 0, 0, DateTimeKind.Utc);
        clock.SetUtcNow(now);

        var userId = Guid.NewGuid();
        var tenantId = postgres.TenantAId;

        // Act
        var pair = await tokenService.CreateTokenPairAsync(
            userId, tenantId, "Viewer", null, "127.0.0.1", "test-agent");

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(pair.AccessToken);

        var expectedExpiry = now.AddMinutes(15);
        token.ValidTo.Should().BeCloseTo(expectedExpiry, TimeSpan.FromSeconds(5));
        pair.ExpiresAt.Should().BeCloseTo(expectedExpiry, TimeSpan.FromSeconds(5));
    }

    [Fact]
    [Trait("Req", "AUTH-API-01")]
    public async Task CreateTokenPairAsync_IssuerAndAudienceMatchConfig()
    {
        // Arrange
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Issuer"] = "RTMViewTest",
                ["Jwt:Audience"] = "RTMView.TestUsers",
                ["Jwt:SecretKey"] = "dev-test-secret-key-for-unit-tests-only-32bytes!"
            })
            .Build();

        var (tokenService, clock) = CreateTokenService(config);
        var userId = Guid.NewGuid();

        // Act
        var pair = await tokenService.CreateTokenPairAsync(
            userId, postgres.TenantAId, "Administrator", null, "127.0.0.1", "test-agent");

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(pair.AccessToken);

        token.Issuer.Should().Be("RTMViewTest");
        token.Audiences.Should().Contain("RTMView.TestUsers");
    }

    [Fact]
    [Trait("Req", "AUTH-API-01")]
    public async Task CreateTokenPairAsync_RoleClaimMatchesUserRole()
    {
        // Arrange
        var (tokenService, _) = CreateTokenService();
        var userId = Guid.NewGuid();

        // Act: Test different roles
        var adminPair = await tokenService.CreateTokenPairAsync(
            userId, postgres.TenantAId, "Administrator", null, "127.0.0.1", "test-agent");
        var viewerPair = await tokenService.CreateTokenPairAsync(
            userId, postgres.TenantAId, "Viewer", null, "127.0.0.1", "test-agent");

        // Assert
        var handler = new JwtSecurityTokenHandler();

        var adminToken = handler.ReadJwtToken(adminPair.AccessToken);
        adminToken.Claims.Should().Contain(c => c.Type == ClaimTypes.Role && c.Value == "Administrator");

        var viewerToken = handler.ReadJwtToken(viewerPair.AccessToken);
        viewerToken.Claims.Should().Contain(c => c.Type == ClaimTypes.Role && c.Value == "Viewer");
    }

    [Fact]
    [Trait("Req", "AUTH-API-01")]
    public async Task CreateTokenPairAsync_WithoutPermissionGroup_OmitsPgClaim()
    {
        // Arrange: Superadmin has no PG
        var (tokenService, _) = CreateTokenService();
        var userId = Guid.NewGuid();

        // Act
        var pair = await tokenService.CreateTokenPairAsync(
            userId, postgres.PlatformTenantId, "Superadmin", null, "127.0.0.1", "test-agent");

        // Assert
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(pair.AccessToken);

        token.Claims.Should().NotContain(c => c.Type == "permission_group_id");
    }

    private (TokenService service, TestDateTimeProvider clock) CreateTokenService(IConfiguration? config = null)
    {
        config ??= new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Issuer"] = "RTMView",
                ["Jwt:Audience"] = "RTMView.Users",
                ["Jwt:SecretKey"] = "dev-test-secret-key-for-unit-tests-only-32bytes!",
                ["Jwt:AccessTokenExpiryMinutes"] = "15",
                ["Jwt:RefreshTokenExpiryHours"] = "8"
            })
            .Build();

        var dbOptions = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(postgres.ConnectionString)
            .Options;
        var db = new AppDbContext(dbOptions, new TestTenantContext(postgres.PlatformTenantId));

        var redis = Substitute.For<IConnectionMultiplexer>();
        var redisDb = Substitute.For<IDatabase>();
        redis.GetDatabase(Arg.Any<int>(), Arg.Any<object>()).Returns(redisDb);

        var clock = new TestDateTimeProvider();
        var logger = Substitute.For<ILogger<TokenService>>();

        var service = new TokenService(db, redis, clock, config, logger);
        return (service, clock);
    }
}
