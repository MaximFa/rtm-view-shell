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
/// Tests for LICENSE-USER concurrency (DoD-5).
/// Verifies that concurrent CreateAsync calls respect the PurchasedLicences limit.
/// Per MC-T2-4: if race condition fires, file as SF-007 and fix with row-level locking.
/// </summary>
[Collection("Postgres")]
public class LicenseUserConcurrencyTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private Guid _testTenantId;
    private Guid _pgId;

    public LicenseUserConcurrencyTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        _testTenantId = UUIDNext.Uuid.NewSequential();
        _pgId = UUIDNext.Uuid.NewSequential();
        var now = DateTime.UtcNow;

        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        db.Tenants.Add(new Domain.Domain.Tenant
        {
            Id = _testTenantId,
            Slug = $"lic-conc-{_testTenantId:N}"[..20],
            Name = "License Concurrency Test Tenant",
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        });

        db.TenantSettings.Add(new Domain.Domain.TenantSettings
        {
            TenantId = _testTenantId,
            DefaultLocale = "en-US",
            PurchasedLicences = 10  // For race condition test
        });

        db.PermissionGroups.Add(new Domain.Domain.PermissionGroup
        {
            Id = _pgId,
            TenantId = _testTenantId,
            Name = "Concurrency Test PG",
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

    /// <summary>
    /// DoD-5: Race condition test. 9 users exist, limit is 10, run 5 concurrent CreateAsync.
    /// Expected: exactly 1 succeeds (reaching limit of 10), 4 fail.
    /// If more than 1 succeeds → TOCTOU bug (SF-007).
    /// </summary>
    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_ConcurrentCallsAtLimit_ExactlyOneSucceeds()
    {
        // Arrange - 9 users exist, limit is 10
        await CreateTestUsers(9);

        // Create 5 parallel CreateAsync tasks
        var tasks = Enumerable.Range(0, 5)
            .Select(i => Task.Run(async () =>
            {
                // Each task gets its own service instance with independent DbContext
                var sut = CreateUserManagementService();
                var request = new CreateUserRequest(
                    FirstName: $"Concurrent{i}",
                    LastName: "User",
                    Email: $"concurrent{i}@race.local",
                    UserName: $"concurrent{i}@race.local",
                    Role: "Editor",
                    PermissionGroupId: _pgId,
                    PreferredLocale: "en-US");

                return await sut.CreateAsync(_testTenantId, request);
            }))
            .ToArray();

        // Act - wait for all concurrent creations
        var results = await Task.WhenAll(tasks);

        // Assert
        var successCount = results.Count(r => r.Succeeded);
        var failCount = results.Count(r => !r.Succeeded);

        // With proper locking, exactly 1 should succeed (filling slot 10/10)
        // and 4 should fail (limit reached)
        successCount.Should().Be(1,
            "Exactly 1 of 5 concurrent creations should succeed when 1 slot remains. " +
            $"Got {successCount} successes. If >1, TOCTOU race condition exists (SF-007).");
        failCount.Should().Be(4);

        // Verify final user count is exactly 10
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var finalCount = await db.Users.IgnoreQueryFilters()
            .CountAsync(u => u.TenantId == _testTenantId);
        finalCount.Should().Be(10, "Final user count should be exactly at the limit");
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    public async Task CreateAsync_SequentialCreations_RespectLimit()
    {
        // Arrange - 8 users exist, limit is 10
        await CreateTestUsers(8);

        var sut = CreateUserManagementService();

        // Act - create 3 users sequentially (2 should succeed, 1 should fail)
        var results = new List<(bool Succeeded, string? Error)>();
        for (int i = 0; i < 3; i++)
        {
            var request = new CreateUserRequest(
                FirstName: $"Sequential{i}",
                LastName: "User",
                Email: $"sequential{i}@race.local",
                UserName: $"sequential{i}@race.local",
                Role: "Editor",
                PermissionGroupId: _pgId,
                PreferredLocale: "en-US");

            var result = await sut.CreateAsync(_testTenantId, request);
            results.Add((result.Succeeded, result.Error));

            // Small delay to ensure sequential execution
            await Task.Delay(10);
        }

        // Assert
        var successes = results.Count(r => r.Succeeded);
        successes.Should().Be(2, "2 users should succeed (slots 9 and 10)");
        results[2].Succeeded.Should().BeFalse("3rd user should fail (over limit)");
    }

    #region Helpers

    private async Task CreateTestUsers(int count)
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = sp.GetRequiredService<RoleManager<ApplicationRole>>();

        if (!await roleManager.RoleExistsAsync("Editor"))
            await roleManager.CreateAsync(new ApplicationRole("Editor") { Id = UUIDNext.Uuid.NewSequential() });

        for (int i = 0; i < count; i++)
        {
            var user = new ApplicationUser
            {
                Id = UUIDNext.Uuid.NewSequential(),
                TenantId = _testTenantId,
                UserName = $"raceuser{i}@conctest.local",
                NormalizedUserName = $"RACEUSER{i}@CONCTEST.LOCAL",
                Email = $"raceuser{i}@conctest.local",
                NormalizedEmail = $"RACEUSER{i}@CONCTEST.LOCAL",
                EmailConfirmed = true,
                FirstName = $"Race{i}",
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

        var envMock = new Mock<IHostEnvironment>();
        envMock.Setup(e => e.EnvironmentName).Returns("Development");

        var loggerMock = new Mock<ILogger<UserManagementService>>();

        return new UserManagementService(
            userManager, db, emailMock.Object, clock, auditMock.Object,
            currentUserMock.Object, envMock.Object, loggerMock.Object);
    }

    #endregion
}
