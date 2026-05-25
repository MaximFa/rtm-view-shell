using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
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
/// Tests for LICENSE-USER audit event emission (DoD-4).
/// Verifies User.RejectedLicenceLimit event is emitted when creation is rejected.
/// </summary>
[Collection("Postgres")]
public class LicenseUserAuditTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private Guid _testTenantId;
    private Guid _pgId;

    public LicenseUserAuditTests(PostgresFixture fixture)
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
            Slug = $"lic-aud-{_testTenantId:N}"[..20],
            Name = "License Audit Test Tenant",
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        });

        db.TenantSettings.Add(new Domain.Domain.TenantSettings
        {
            TenantId = _testTenantId,
            DefaultLocale = "en-US",
            PurchasedLicences = 1
        });

        db.PermissionGroups.Add(new Domain.Domain.PermissionGroup
        {
            Id = _pgId,
            TenantId = _testTenantId,
            Name = "Audit Test PG",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.SuperadminId,
            UpdatedByUserId = _fixture.SuperadminId
        });

        await db.SaveChangesAsync();

        // Clear any existing audit logs for this tenant
        await using var auditDb = _fixture.CreateAuditDbContext();
        var oldLogs = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId)
            .ToListAsync();
        auditDb.AuditLogs.RemoveRange(oldLogs);
        await auditDb.SaveChangesAsync();
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

    [Fact]
    [Trait("Req", "LIC-01")]
    [Trait("Req", "AUD-01")]
    public async Task CreateAsync_WhenLicenceLimitExceeded_EmitsAuditEvent()
    {
        // Arrange - 1 user exists, limit is 1
        await CreateTestUser();

        var sut = CreateUserManagementServiceWithRealAudit();
        var request = new CreateUserRequest(
            FirstName: "Rejected",
            LastName: "User",
            Email: "rejected@audit.local",
            UserName: "rejected@audit.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, _, _, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert - rejection should emit audit event
        succeeded.Should().BeFalse();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId && l.EventType == "User.RejectedLicenceLimit")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Audit log should be created for licence limit rejection [LIC-01, AUD-01]");
        auditLog!.EventResult.Should().Be(AuditEventResult.Failure);
        auditLog.Details.Should().Contain("rejected@audit.local");
        auditLog.Details.Should().Contain("Limit");
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    [Trait("Req", "AUD-01")]
    public async Task CreateAsync_WhenBelowLimit_DoesNotEmitRejectionAuditEvent()
    {
        // Arrange - no users exist, limit is 1
        var sut = CreateUserManagementServiceWithRealAudit();
        var request = new CreateUserRequest(
            FirstName: "Allowed",
            LastName: "User",
            Email: "allowed@audit.local",
            UserName: "allowed@audit.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, _, _, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert - success should NOT emit rejection event
        succeeded.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var rejectionLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId && l.EventType == "User.RejectedLicenceLimit")
            .FirstOrDefaultAsync();

        rejectionLog.Should().BeNull("No rejection audit should exist when user creation succeeds");

        // But User.Created event SHOULD exist
        var createdLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId && l.EventType == "User.Created")
            .FirstOrDefaultAsync();

        createdLog.Should().NotBeNull("User.Created audit should be logged on success");
    }

    [Fact]
    [Trait("Req", "LIC-01")]
    [Trait("Req", "AUD-01")]
    public async Task CreateAsync_AuditEventContainsCurrentCountAndLimit()
    {
        // Arrange - 2 users exist, limit is 2
        await SetPurchasedLicences(2);
        await CreateTestUser();
        await CreateTestUser("second");

        var sut = CreateUserManagementServiceWithRealAudit();
        var request = new CreateUserRequest(
            FirstName: "Third",
            LastName: "User",
            Email: "third@audit.local",
            UserName: "third@audit.local",
            Role: "Editor",
            PermissionGroupId: _pgId,
            PreferredLocale: "en-US");

        // Act
        await sut.CreateAsync(_testTenantId, request);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId && l.EventType == "User.RejectedLicenceLimit")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull();
        // Details should contain count and limit for ops/billing visibility
        auditLog!.Details.Should().Contain("CurrentCount");
        auditLog.Details.Should().Contain("2"); // current count
        auditLog.Details.Should().Contain("Limit");
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

    private async Task CreateTestUser(string suffix = "first")
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = sp.GetRequiredService<RoleManager<ApplicationRole>>();

        if (!await roleManager.RoleExistsAsync("Editor"))
            await roleManager.CreateAsync(new ApplicationRole("Editor") { Id = UUIDNext.Uuid.NewSequential() });

        var user = new ApplicationUser
        {
            Id = UUIDNext.Uuid.NewSequential(),
            TenantId = _testTenantId,
            UserName = $"{suffix}user@audittest.local",
            NormalizedUserName = $"{suffix.ToUpper()}USER@AUDITTEST.LOCAL",
            Email = $"{suffix}user@audittest.local",
            NormalizedEmail = $"{suffix.ToUpper()}USER@AUDITTEST.LOCAL",
            EmailConfirmed = true,
            FirstName = suffix,
            LastName = "User",
            IsActive = true,
            PermissionGroupId = _pgId
        };
        await userManager.CreateAsync(user, "Test@123456");
    }

    private IUserManagementService CreateUserManagementServiceWithRealAudit()
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var db = sp.GetRequiredService<AppDbContext>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        // Use REAL audit service to verify DB writes
        var auditDbOptions = new Microsoft.EntityFrameworkCore.DbContextOptionsBuilder<AuditDbContext>();
        auditDbOptions.UseNpgsql(_fixture.ConnectionString);
        var auditDb = new AuditDbContext(auditDbOptions.Options);
        var auditService = new AuditService(auditDb, clock);

        var emailMock = new Mock<IEmailSender>();
        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.UserId).Returns(_fixture.SuperadminId);
        currentUserMock.Setup(c => c.UserName).Returns("superadmin@platform.local");

        var envMock = new Mock<IHostEnvironment>();
        envMock.Setup(e => e.EnvironmentName).Returns("Development");

        var loggerMock = new Mock<ILogger<UserManagementService>>();

        return new UserManagementService(
            userManager, db, emailMock.Object, clock, auditService,
            currentUserMock.Object, envMock.Object, loggerMock.Object);
    }

    #endregion
}
