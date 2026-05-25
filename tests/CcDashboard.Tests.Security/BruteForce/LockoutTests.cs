using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace CcDashboard.Tests.Security.BruteForce;

/// <summary>
/// Tests for account lockout after failed login attempts per BFP-01.
/// 5 failed attempts -> 15-minute lockout.
/// </summary>
[Collection("Postgres")]
public class LockoutTests
{
    private readonly PostgresFixture _fixture;

    public LockoutTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "BFP-01")]
    public async Task CheckPasswordSignInAsync_FiveFailedAttempts_LocksAccount()
    {
        // Arrange
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        user.Should().NotBeNull();

        // Reset lockout state
        await userManager.SetLockoutEndDateAsync(user!, null);
        await userManager.ResetAccessFailedCountAsync(user!);

        // Act - 5 failed attempts with wrong password
        for (int i = 0; i < 5; i++)
        {
            await signInManager.CheckPasswordSignInAsync(user!, "WrongPassword!", lockoutOnFailure: true);
        }

        // Assert
        var refreshedUser = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        var isLockedOut = await userManager.IsLockedOutAsync(refreshedUser!);

        isLockedOut.Should().BeTrue("Account should be locked after 5 failed attempts [BFP-01]");
    }

    [Fact]
    [Trait("Req", "BFP-01")]
    public async Task CheckPasswordSignInAsync_LockedAccount_ReturnsLockedOut()
    {
        // Arrange
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        user.Should().NotBeNull();

        // Lock the account
        await userManager.SetLockoutEndDateAsync(user!, DateTimeOffset.UtcNow.AddMinutes(15));

        // Act
        var result = await signInManager.CheckPasswordSignInAsync(user!, "Test@123456", lockoutOnFailure: true);

        // Assert
        result.IsLockedOut.Should().BeTrue("Locked account should return IsLockedOut [BFP-01]");
        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    [Trait("Req", "BFP-01")]
    public async Task CheckPasswordSignInAsync_FourFailedAttempts_DoesNotLock()
    {
        // Arrange
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        user.Should().NotBeNull();

        // Reset lockout state
        await userManager.SetLockoutEndDateAsync(user!, null);
        await userManager.ResetAccessFailedCountAsync(user!);

        // Act - only 4 failed attempts
        for (int i = 0; i < 4; i++)
        {
            await signInManager.CheckPasswordSignInAsync(user!, "WrongPassword!", lockoutOnFailure: true);
        }

        // Assert
        var refreshedUser = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        var isLockedOut = await userManager.IsLockedOutAsync(refreshedUser!);

        isLockedOut.Should().BeFalse("Account should NOT be locked after only 4 failed attempts");
    }

    [Fact]
    [Trait("Req", "BFP-01")]
    public async Task CheckPasswordSignInAsync_ExpiredLockout_AllowsLogin()
    {
        // Arrange
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        user.Should().NotBeNull();

        // Set lockout to the past (expired)
        await userManager.SetLockoutEndDateAsync(user!, DateTimeOffset.UtcNow.AddMinutes(-1));

        // Act
        var result = await signInManager.CheckPasswordSignInAsync(user!, "Test@123456", lockoutOnFailure: true);

        // Assert
        result.IsLockedOut.Should().BeFalse("Expired lockout should allow login");
        result.Succeeded.Should().BeTrue("Correct password with expired lockout should succeed");
    }

    [Fact]
    [Trait("Req", "BFP-01")]
    public async Task CheckPasswordSignInAsync_SuccessfulLogin_ResetsFailedCount()
    {
        // Arrange
        var sp = _fixture.CreateServiceProvider(_fixture.TenantAId);
        var signInManager = sp.GetRequiredService<SignInManager<ApplicationUser>>();
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        user.Should().NotBeNull();

        // Reset lockout state and add some failed attempts
        await userManager.SetLockoutEndDateAsync(user!, null);
        await userManager.ResetAccessFailedCountAsync(user!);

        // 3 failed attempts (below threshold)
        for (int i = 0; i < 3; i++)
        {
            await signInManager.CheckPasswordSignInAsync(user!, "WrongPassword!", lockoutOnFailure: true);
        }

        // Act - successful login
        var result = await signInManager.CheckPasswordSignInAsync(user!, "Test@123456", lockoutOnFailure: true);

        // Assert
        result.Succeeded.Should().BeTrue();

        var refreshedUser = await userManager.FindByIdAsync(_fixture.UserAId.ToString());
        refreshedUser!.AccessFailedCount.Should().Be(0, "Successful login should reset failed count");
    }
}
