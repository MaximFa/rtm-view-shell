using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Moq;

namespace CcDashboard.Tests.Security.Licensing;

/// <summary>
/// Tests for LICENSE-USER enforcement (PurchasedLicences limit on user creation).
/// DoD-1, DoD-2, DoD-3 per T2-licensing-enforcement.md.
/// </summary>
[Collection("Postgres")]
public class LicenseUserEnforcementTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private Guid _testTenantId;
    private Guid _pgId;

    public LicenseUserEnforcementTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        // Create an isolated test tenant with its own PG for each test class
        _testTenantId = UUIDNext.Uuid.NewSequential();
        _pgId = UUIDNext.Uuid.NewSequential();
        var now = DateTime.UtcNow;

        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        db.Tenants.Add(new Domain.Domain.Tenant
        {
            Id = _testTenantId,
            Slug = $"lic-test-{_testTenantId:N}"[..20],
            Name = "License Test Tenant",
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        });

        db.TenantSettings.Add(new Domain.Domain.TenantSettings
        {
            TenantId = _testTenantId,
            DefaultLocale = "en-US",
            PurchasedLicences = 3  // Default limit for tests
        });

        db.PermissionGroups.Add(new Domain.Domain.PermissionGroup
        {
            Id = _pgId,
            TenantId = _testTenantId,
            Name = "Test PG",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.SuperadminId,
            UpdatedByUserId = _fixture.SuperadminId
        });

        await db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        // Cleanup test tenant data
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        var users = await db.Users.IgnoreQueryFilters()
            .Where(u => u.TenantId == _testTenantId)
            .ToListAsync();
        db.Users.RemoveRange(users);

        var pg = await db.PermissionGroups.IgnoreQueryFilters()
            .FirstOrDefaultAsync(p => p.Id == _pgId);
        if (pg != null) db.PermissionGroups.Remove(pg);

        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == _testTenantId);
        if (settings != null) db.TenantSettings.Remove(settings);

        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Id == _testTenantId);
        if (tenant != null) db.Tenants.Remove(tenant);

        await db.SaveChangesAsync();
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_WhenAtLimit_ReturnsLicenceLimitError()
    {
        // Arrange - 3 users exist, limit is 3
        await SetPurchasedLicences(3);
        await CreateTestUsers(3);

        var sut = CreateUserManagementService();
        var request = new CreateUserRequest(
            FirstName: "Fourth",
            LastName: "User",
            Email: "fourth@test.local",
            UserName: "fourth@test.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, error, _, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert
        succeeded.Should().BeFalse("4th user should be rejected when limit is 3 [LIC-01]");
        error.Should().Contain("Licence limit reached");
        error.Should().Contain("3 users");
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_WhenBelowLimit_Succeeds()
    {
        // Arrange - 2 users exist, limit is 3
        await SetPurchasedLicences(3);
        await CreateTestUsers(2);

        var sut = CreateUserManagementService();
        var request = new CreateUserRequest(
            FirstName: "Third",
            LastName: "User",
            Email: "third@test.local",
            UserName: "third@test.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, error, userId, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert
        succeeded.Should().BeTrue("3rd user should be allowed when limit is 3");
        error.Should().BeNull();
        userId.Should().NotBeEmpty();
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_WhenZeroLimit_AllowsUnlimitedUsers()
    {
        // Arrange - 0 = unlimited
        await SetPurchasedLicences(0);

        var sut = CreateUserManagementService();

        // Act - create 5 users sequentially
        for (int i = 0; i < 5; i++)
        {
            var request = new CreateUserRequest(
                FirstName: $"User{i}",
                LastName: "Unlimited",
                Email: $"unlimited{i}@test.local",
                UserName: $"unlimited{i}@test.local",
                Role: "Viewer",
                PermissionGroupId: _pgId,
                PreferredLocale: "en-US");

            var (succeeded, error, _, _) = await sut.CreateAsync(_testTenantId, request);

            // Assert each creation succeeds
            succeeded.Should().BeTrue($"User {i} should succeed when limit is 0 (unlimited)");
            error.Should().BeNull();
        }
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    [Trait("Req", "ARCH-01")]
    public async Task CreateAsync_TenantBoundary_DoesNotCountOtherTenantUsers()
    {
        // Arrange
        // Test tenant has limit=1
        await SetPurchasedLicences(1);
        // TenantA (from fixture) already has multiple users — should NOT affect test tenant

        var sut = CreateUserManagementService();
        var request = new CreateUserRequest(
            FirstName: "Isolated",
            LastName: "User",
            Email: "isolated@test.local",
            UserName: "isolated@test.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, error, userId, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert - should succeed because test tenant has 0 users, not affected by TenantA
        succeeded.Should().BeTrue("Test tenant user count should be independent of TenantA [ARCH-01]");
        error.Should().BeNull();
        userId.Should().NotBeEmpty();
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_ExactlyAtLimit_RejectsNextUser()
    {
        // Arrange - exactly 5 users, limit 5
        await SetPurchasedLicences(5);
        await CreateTestUsers(5);

        var sut = CreateUserManagementService();
        var request = new CreateUserRequest(
            FirstName: "Sixth",
            LastName: "User",
            Email: "sixth@test.local",
            UserName: "sixth@test.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, error, _, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert
        succeeded.Should().BeFalse("6th user should be rejected when exactly at limit of 5");
        error.Should().Contain("Licence limit reached");
    }

    #region Helpers

    private async Task SetPurchasedLicences(int limit)
    {
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == _testTenantId);
        if (settings != null)
        {
            settings.PurchasedLicences = limit;
            await db.SaveChangesAsync();
        }
    }

    private async Task CreateTestUsers(int count)
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = sp.GetRequiredService<RoleManager<ApplicationRole>>();

        // Ensure Editor role exists
        if (!await roleManager.RoleExistsAsync("Editor"))
            await roleManager.CreateAsync(new ApplicationRole("Editor") { Id = UUIDNext.Uuid.NewSequential() });

        for (int i = 0; i < count; i++)
        {
            var user = new ApplicationUser
            {
                Id = UUIDNext.Uuid.NewSequential(),
                TenantId = _testTenantId,
                UserName = $"testuser{i}@lictest.local",
                NormalizedUserName = $"TESTUSER{i}@LICTEST.LOCAL",
                Email = $"testuser{i}@lictest.local",
                NormalizedEmail = $"TESTUSER{i}@LICTEST.LOCAL",
                EmailConfirmed = true,
                FirstName = $"Test{i}",
                LastName = "User",
                IsActive = true,
                PermissionGroupId = _pgId
            };
            await userManager.CreateAsync(user, "Test@123456");
        }
    }

    private IUserManagementService CreateUserManagementService()
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var db = sp.GetRequiredService<AppDbContext>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        var auditMock = new Mock<IAuditService>();
        var emailMock = new Mock<IEmailSender>();
        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.UserId).Returns(_fixture.SuperadminId);
        currentUserMock.Setup(c => c.UserName).Returns("superadmin@platform.local");
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var envMock = new Mock<IHostEnvironment>();
        envMock.Setup(e => e.EnvironmentName).Returns("Development");

        var loggerMock = new Mock<ILogger<UserManagementService>>();

        return new UserManagementService(
            userManager, db, emailMock.Object, clock, auditMock.Object,
            currentUserMock.Object, envMock.Object, loggerMock.Object);
    }

    #endregion
}
