using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Licensing;

/// <summary>
/// Tests for LICENSE-SESSION enforcement per AUTH-WEB-04, AUTH-API-07.
/// MaxConcurrentConnections limits distinct IPs per user.
/// </summary>
[Collection("Postgres")]
public class LicenseSessionTests
{
    private readonly PostgresFixture _fixture;

    public LicenseSessionTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact(Skip = "Requires full ASP.NET Core Auth pipeline (HttpContext); tested via WebApplicationFactory")]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_NoLimit_AllowsMultipleConnections()
    {
        // Arrange - MaxConcurrentConnections = 0 means unlimited
        await SetMaxConcurrentConnections(0);
        await ClearUserSessions();

        var sut = CreateAuthService();

        // Act - login from 5 different IPs
        for (int i = 1; i <= 5; i++)
        {
            var result = await sut.PasswordSignInAsync(
                _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
                $"192.168.100.{i}", "TestAgent");

            // Assert
            result.Status.Should().NotBe(IdentitySignInStatus.SessionLimitExceeded,
                $"Connection {i} should succeed when MaxConcurrentConnections = 0 [AUTH-WEB-04]");
        }
    }

    [Fact(Skip = "Requires full ASP.NET Core Auth pipeline (HttpContext); tested via WebApplicationFactory")]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_WithinLimit_AllowsLogin()
    {
        // Arrange - limit to 3 concurrent connections
        await SetMaxConcurrentConnections(3);
        await ClearUserSessions();

        // Create 2 existing sessions from different IPs
        await CreateSession(_fixture.UserAId, "192.168.200.1");
        await CreateSession(_fixture.UserAId, "192.168.200.2");

        var sut = CreateAuthService();

        // Act - third IP (within limit)
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
            "192.168.200.3", "TestAgent");

        // Assert - should succeed (3rd connection, limit is 3)
        result.Status.Should().NotBe(IdentitySignInStatus.SessionLimitExceeded,
            "Login from 3rd IP should succeed when limit is 3 [AUTH-WEB-04]");
    }

    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    [Trait("Req", "AUTH-API-07")]
    public async Task PasswordSignInAsync_ExceedsLimit_ReturnsSessionLimitExceeded()
    {
        // Arrange - limit to 2 concurrent connections
        await SetMaxConcurrentConnections(2);
        await ClearUserSessions();

        // Create 2 existing sessions from different IPs (at limit)
        await CreateSession(_fixture.UserAId, "192.168.201.1");
        await CreateSession(_fixture.UserAId, "192.168.201.2");

        var sut = CreateAuthService();

        // Act - third IP (exceeds limit)
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
            "192.168.201.3", "TestAgent");

        // Assert
        result.Status.Should().Be(IdentitySignInStatus.SessionLimitExceeded,
            "Login from 3rd IP should be rejected when limit is 2 [AUTH-WEB-04, AUTH-API-07]");
    }

    [Fact(Skip = "Requires full ASP.NET Core Auth pipeline (HttpContext); tested via WebApplicationFactory")]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_SameIp_AllowsUnlimitedConnections()
    {
        // Arrange - limit to 1 concurrent connection
        await SetMaxConcurrentConnections(1);
        await ClearUserSessions();

        // Create existing session from same IP that will be used
        await CreateSession(_fixture.UserAId, "192.168.202.1");

        var sut = CreateAuthService();

        // Act - same IP (should allow unlimited from same IP)
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
            "192.168.202.1", "TestAgent");

        // Assert
        result.Status.Should().NotBe(IdentitySignInStatus.SessionLimitExceeded,
            "Multiple connections from same IP should always be allowed [AUTH-WEB-04]");
    }

    [Fact(Skip = "Requires full ASP.NET Core Auth pipeline (HttpContext); tested via WebApplicationFactory")]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_ExpiredSession_NotCounted()
    {
        // Arrange - limit to 1 concurrent connection
        await SetMaxConcurrentConnections(1);
        await ClearUserSessions();

        // Create expired session (should not count toward limit)
        await CreateSession(_fixture.UserAId, "192.168.203.1", expired: true);

        var sut = CreateAuthService();

        // Act - new IP (should succeed since expired session doesn't count)
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
            "192.168.203.2", "TestAgent");

        // Assert
        result.Status.Should().NotBe(IdentitySignInStatus.SessionLimitExceeded,
            "Expired sessions should not count toward limit [AUTH-WEB-04]");
    }

    [Fact(Skip = "Requires full ASP.NET Core Auth pipeline (HttpContext); tested via WebApplicationFactory")]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_RevokedSession_NotCounted()
    {
        // Arrange - limit to 1 concurrent connection
        await SetMaxConcurrentConnections(1);
        await ClearUserSessions();

        // Create revoked session (should not count toward limit)
        await CreateSession(_fixture.UserAId, "192.168.204.1", revoked: true);

        var sut = CreateAuthService();

        // Act - new IP (should succeed since revoked session doesn't count)
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456",
            "192.168.204.2", "TestAgent");

        // Assert
        result.Status.Should().NotBe(IdentitySignInStatus.SessionLimitExceeded,
            "Revoked sessions should not count toward limit [AUTH-WEB-04]");
    }

    #region Helpers

    private async Task SetMaxConcurrentConnections(int limit)
    {
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == _fixture.TenantAId);

        if (settings != null)
        {
            settings.MaxConcurrentConnections = limit;
            await db.SaveChangesAsync();
        }
    }

    private async Task ClearUserSessions()
    {
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var sessions = await db.UserSessions.IgnoreQueryFilters()
            .Where(s => s.UserId == _fixture.UserAId)
            .ToListAsync();
        db.UserSessions.RemoveRange(sessions);
        await db.SaveChangesAsync();
    }

    private async Task CreateSession(Guid userId, string ipAddress, bool expired = false, bool revoked = false)
    {
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var now = DateTime.UtcNow;
        db.UserSessions.Add(new UserSession
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = _fixture.TenantAId,
            IpAddress = ipAddress,
            UserAgent = "TestAgent",
            CreatedAt = now.AddHours(-1),
            ExpiresAt = expired ? now.AddHours(-1) : now.AddHours(8),
            IsRevoked = revoked
        });
        await db.SaveChangesAsync();
    }

    private IIdentityAuthService CreateAuthService()
    {
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var db = sp.GetRequiredService<AppDbContext>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        var auditMock = new Mock<IAuditService>();
        var twoFactorMock = new Mock<ITwoFactorService>();
        var loggerMock = new Mock<ILogger<IdentityAuthService>>();
        var httpContextAccessorMock = new Mock<IHttpContextAccessor>();

        return new IdentityAuthService(
            signInManager,
            userManager,
            db,
            auditMock.Object,
            clock,
            twoFactorMock.Object,
            httpContextAccessorMock.Object,
            loggerMock.Object);
    }

    #endregion
}
