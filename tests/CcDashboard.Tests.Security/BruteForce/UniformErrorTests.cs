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

namespace CcDashboard.Tests.Security.BruteForce;

/// <summary>
/// Tests for uniform error messages per BFP-03.
/// Error message must always be "Invalid username or password" —
/// never reveal whether user exists, password is wrong, or tenant mismatches.
/// </summary>
[Collection("Postgres")]
public class UniformErrorTests
{
    private readonly PostgresFixture _fixture;

    public UniformErrorTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_UserNotFound_ReturnsInvalidCredentials()
    {
        // Arrange
        var sut = CreateAuthService(_fixture.TenantAId);

        // Act
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "nonexistent@user.com", "AnyPassword123!", "192.168.1.1", "TestAgent");

        // Assert
        result.Status.Should().Be(IdentitySignInStatus.InvalidCredentials,
            "Non-existent user should return InvalidCredentials [BFP-03]");
    }

    [Fact]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_WrongPassword_ReturnsInvalidCredentials()
    {
        // Arrange
        var sut = CreateAuthService(_fixture.TenantAId);

        // Act - user exists but password is wrong
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantAId, "user.a@tenant-a.local", "WrongPassword123!", "192.168.1.1", "TestAgent");

        // Assert
        result.Status.Should().Be(IdentitySignInStatus.InvalidCredentials,
            "Wrong password should return InvalidCredentials [BFP-03]");
    }

    [Fact]
    [Trait("Req", "ARCH-04")]
    public async Task PasswordSignInAsync_TenantMismatch_ReturnsTenantMismatchStatus()
    {
        // Arrange - user.a belongs to TenantA, but we pass TenantB as the tenant
        var sut = CreateAuthService(_fixture.TenantBId);

        // Act - user from TenantA trying to login in TenantB context
        var result = await sut.PasswordSignInAsync(
            _fixture.TenantBId, "user.a@tenant-a.local", "Test@123456", "192.168.1.1", "TestAgent");

        // Assert - Service returns specific status for routing/audit;
        // UI layer enforces uniform message per BFP-03
        result.Status.Should().Be(IdentitySignInStatus.TenantMismatch,
            "Tenant mismatch detected and returned specific status for audit [ARCH-04]");
    }

    [Fact]
    [Trait("Req", "ARCH-06")]
    public async Task PasswordSignInAsync_SuspendedTenant_ReturnsTenantSuspendedStatus()
    {
        // Arrange - temporarily suspend TenantA
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstAsync(t => t.Id == _fixture.TenantAId);
        var originalStatus = tenant.Status;
        tenant.Status = TenantStatus.Suspended;
        await db.SaveChangesAsync();

        try
        {
            var sut = CreateAuthService(_fixture.TenantAId);

            // Act
            var result = await sut.PasswordSignInAsync(
                _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456", "192.168.1.1", "TestAgent");

            // Assert - Service returns specific status for routing/audit;
            // UI layer enforces uniform message per BFP-03
            result.Status.Should().Be(IdentitySignInStatus.TenantSuspended,
                "Suspended tenant detected and returned specific status [ARCH-06]");
        }
        finally
        {
            // Restore tenant status
            tenant.Status = originalStatus;
            await db.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "BFP-03")]
    [Trait("Req", "ARCH-06")]
    public async Task PasswordSignInAsync_DeletedTenant_ReturnsInvalidCredentials()
    {
        // Arrange - temporarily mark TenantA as deleted
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstAsync(t => t.Id == _fixture.TenantAId);
        var originalStatus = tenant.Status;
        tenant.Status = TenantStatus.Deleted;
        await db.SaveChangesAsync();

        try
        {
            var sut = CreateAuthService(_fixture.TenantAId);

            // Act
            var result = await sut.PasswordSignInAsync(
                _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456", "192.168.1.1", "TestAgent");

            // Assert
            result.Status.Should().Be(IdentitySignInStatus.InvalidCredentials,
                "Deleted tenant should return InvalidCredentials [BFP-03, ARCH-06]");
        }
        finally
        {
            // Restore tenant status
            tenant.Status = originalStatus;
            await db.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_LockedAccount_ReturnsLockedOut()
    {
        // Arrange - lock the account
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        await userManager.SetLockoutEndDateAsync(user!, DateTimeOffset.UtcNow.AddMinutes(15));

        try
        {
            var sut = CreateAuthService(_fixture.TenantAId);

            // Act
            var result = await sut.PasswordSignInAsync(
                _fixture.TenantAId, "user.a@tenant-a.local", "Test@123456", "192.168.1.1", "TestAgent");

            // Assert - LockedOut is acceptable since it doesn't reveal user existence
            result.Status.Should().Be(IdentitySignInStatus.LockedOut,
                "Locked account returns LockedOut (acceptable per BFP-01, doesn't reveal existence differently than InvalidCredentials)");
        }
        finally
        {
            // Unlock the account
            await userManager.SetLockoutEndDateAsync(user!, null);
        }
    }

    #region Helpers

    private IIdentityAuthService CreateAuthService(Guid tenantId)
    {
        var sp = _fixture.CreateServiceProvider(tenantId);
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
