using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
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

namespace CcDashboard.Tests.Security.MultiTenancy;

/// <summary>
/// Tests for tenant mismatch on login per ARCH-04 and BFP-03.
/// Verifies that user from tenant A trying to log into tenant B's subdomain
/// is rejected with generic "Invalid credentials" message and proper audit event.
/// </summary>
[Collection("Postgres")]
public class TenantMismatchLoginTests
{
    private readonly PostgresFixture _fixture;

    public TenantMismatchLoginTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_UserFromTenantA_LoginAtTenantB_ReturnsTenantMismatch()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantBId, auditMock.Object);

        // Act: User A (belongs to Tenant A) tries to login at Tenant B
        var result = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantBId,
            userName: "user.a@tenant-a.local",
            password: "Test@123456",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Assert
        result.Status.Should().Be(IdentitySignInStatus.TenantMismatch,
            "Login should fail due to tenant mismatch");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_TenantMismatch_AuditsLoginFailureWithCorrectSubtype()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantBId, auditMock.Object);

        // Act
        await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantBId,
            userName: "user.a@tenant-a.local",
            password: "Test@123456",
            ipAddress: "192.168.1.100",
            userAgent: "Mozilla/5.0");

        // Assert: Verify audit event was logged with TenantMismatch subtype
        auditMock.Verify(
            a => a.LogAsync(
                "Login.Failure",
                AuditEventResult.Failure,
                _fixture.TenantBId,
                _fixture.UserAId,
                It.IsAny<string>(),
                "192.168.1.100",
                "Mozilla/5.0",
                It.Is<object>(d => d.ToString()!.Contains("TenantMismatch")),
                It.IsAny<CancellationToken>()),
            Times.Once,
            "Audit event should be logged with subtype TenantMismatch");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    public async Task PasswordSignInAsync_CorrectTenant_ReturnsSuccess()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantAId, auditMock.Object);

        // Act: User A (belongs to Tenant A) logs in at Tenant A
        var result = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantAId,
            userName: "user.a@tenant-a.local",
            password: "Test@123456",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Assert: Should succeed (or require 2FA if enabled)
        result.Status.Should().BeOneOf(new[]
        {
            IdentitySignInStatus.Success,
            IdentitySignInStatus.RequiresTwoFactor
        }, "Login to correct tenant should succeed");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_UserNotFound_AndTenantMismatch_BothReturnGenericError()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantBId, auditMock.Object);

        // Act: Non-existent user
        var resultNotFound = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantBId,
            userName: "nonexistent@tenant-b.local",
            password: "AnyPassword",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Act: User from wrong tenant
        var resultMismatch = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantBId,
            userName: "user.a@tenant-a.local",
            password: "Test@123456",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Assert: Both should return a status that maps to "Invalid credentials"
        // per BFP-03 — no account enumeration
        var genericErrorStatuses = new[]
        {
            IdentitySignInStatus.InvalidCredentials,
            IdentitySignInStatus.TenantMismatch
        };

        resultNotFound.Status.Should().BeOneOf(genericErrorStatuses,
            "User not found should return generic error status");
        resultMismatch.Status.Should().BeOneOf(genericErrorStatuses,
            "Tenant mismatch should return generic error status");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    public async Task PasswordSignInAsync_SuperadminFromPlatform_LoginAtCustomerTenant_RejectsMismatch()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantAId, auditMock.Object);

        // Act: Superadmin (belongs to Platform tenant) tries to login at Tenant A
        var result = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantAId,
            userName: "superadmin@platform.local",
            password: "Admin@123456",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Assert: Even Superadmin must login from their own tenant subdomain
        result.Status.Should().Be(IdentitySignInStatus.TenantMismatch,
            "Superadmin belongs to Platform tenant, not Tenant A — mismatch should occur");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    public async Task PasswordSignInAsync_UserByEmail_TenantMismatch_StillRejects()
    {
        // Arrange
        var auditMock = new Mock<IAuditService>();
        var sut = CreateAuthService(_fixture.TenantBId, auditMock.Object);

        // Act: Use email instead of username — same behavior expected
        var result = await sut.PasswordSignInAsync(
            tenantId: _fixture.TenantBId,
            userName: "user.a@tenant-a.local", // email
            password: "Test@123456",
            ipAddress: "127.0.0.1",
            userAgent: "TestAgent");

        // Assert
        result.Status.Should().Be(IdentitySignInStatus.TenantMismatch,
            "Login by email should also check tenant mismatch");
    }

    #region Helper Methods

    private IIdentityAuthService CreateAuthService(Guid tenantId, IAuditService auditService)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider, TestDateTimeProvider>();
        services.AddSingleton(auditService);

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));

        services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
            {
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        // Mock IHttpContextAccessor
        var httpContextAccessor = new Mock<IHttpContextAccessor>();
        var httpContext = new DefaultHttpContext();
        httpContextAccessor.Setup(x => x.HttpContext).Returns(httpContext);
        services.AddSingleton(httpContextAccessor.Object);

        // Mock ITwoFactorService
        var twoFactorService = new Mock<ITwoFactorService>();
        twoFactorService
            .Setup(x => x.SendCodeAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TwoFactorSendResult(true));
        twoFactorService
            .Setup(x => x.IsResendThrottledAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        services.AddSingleton(twoFactorService.Object);

        services.AddLogging();

        var sp = services.BuildServiceProvider();

        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var db = sp.GetRequiredService<AppDbContext>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();
        var logger = sp.GetRequiredService<ILogger<IdentityAuthService>>();

        return new IdentityAuthService(
            signInManager,
            userManager,
            db,
            auditService,
            clock,
            twoFactorService.Object,
            httpContextAccessor.Object,
            logger);
    }

    #endregion
}
