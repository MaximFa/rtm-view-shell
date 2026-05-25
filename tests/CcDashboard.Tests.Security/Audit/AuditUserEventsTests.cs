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
using UUIDNext;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B4: User.* audit events (AUD-05).
/// Per CLAUDE.md §16: "User management: User.Created, User.Updated, User.Deactivated, User.Activated,
/// User.RoleChanged, User.PermissionGroupChanged"
///
/// These tests supplement Phase A coverage by verifying audit events are emitted
/// for all user management operations.
/// </summary>
[Collection("Postgres")]
public class AuditUserEventsTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private Guid _testTenantId;
    private Guid _testPgId;

    public AuditUserEventsTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        // Create isolated test tenant for audit event tests
        _testTenantId = Uuid.NewSequential();
        _testPgId = Uuid.NewSequential();
        var now = DateTime.UtcNow;

        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        db.Tenants.Add(new Domain.Domain.Tenant
        {
            Id = _testTenantId,
            Slug = $"aud-evt-{_testTenantId:N}"[..20],
            Name = "Audit Events Test Tenant",
            Status = TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        });

        db.TenantSettings.Add(new Domain.Domain.TenantSettings
        {
            TenantId = _testTenantId,
            DefaultLocale = "en-US",
            PurchasedLicences = 100
        });

        db.PermissionGroups.Add(new Domain.Domain.PermissionGroup
        {
            Id = _testPgId,
            TenantId = _testTenantId,
            Name = "Audit Test PG",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.SuperadminId,
            UpdatedByUserId = _fixture.SuperadminId
        });

        await db.SaveChangesAsync();

        // Clear audit logs for this tenant
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
            .FirstOrDefaultAsync(p => p.Id == _testPgId);
        if (pg != null) db.PermissionGroups.Remove(pg);

        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == _testTenantId);
        if (settings != null) db.TenantSettings.Remove(settings);

        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Id == _testTenantId);
        if (tenant != null) db.Tenants.Remove(tenant);

        await db.SaveChangesAsync();

        // Clean up audit logs
        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLogs = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId)
            .ToListAsync();
        auditDb.AuditLogs.RemoveRange(auditLogs);
        await auditDb.SaveChangesAsync();
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task CreateUser_EmitsUserCreatedAuditEvent()
    {
        // Arrange
        var sut = CreateUserManagementService();
        var request = new CreateUserRequest(
            FirstName: "Audit",
            LastName: "Test",
            Email: "audit.created@test.local",
            UserName: "audit.created@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        // Act
        var (succeeded, _, userId, _) = await sut.CreateAsync(_testTenantId, request);

        // Assert
        succeeded.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.Created")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("User.Created audit event should be emitted [AUD-05]");
        auditLog!.EventResult.Should().Be(AuditEventResult.Success);
        auditLog.Details.Should().Contain(userId.ToString());
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task UpdateUser_WithRoleChange_EmitsUserRoleChangedAuditEvent()
    {
        // Arrange
        var createSut = CreateUserManagementService();
        var createRequest = new CreateUserRequest(
            FirstName: "Role",
            LastName: "Change",
            Email: "role.change@test.local",
            UserName: "role.change@test.local",
            Role: "Viewer",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        var (_, _, userId, _) = await createSut.CreateAsync(_testTenantId, createRequest);

        // Clear audit logs to isolate the update event
        await using var clearDb = _fixture.CreateAuditDbContext();
        var oldLogs = await clearDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId)
            .ToListAsync();
        clearDb.AuditLogs.RemoveRange(oldLogs);
        await clearDb.SaveChangesAsync();

        // Act - update role from Viewer to Editor
        var updateSut = CreateUserManagementService();
        var updateRequest = new UpdateUserRequest(
            Id: userId,
            FirstName: "Role",
            LastName: "Change",
            Email: "role.change@test.local",
            Role: "Editor", // Changed from Viewer
            PermissionGroupId: _testPgId,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        await updateSut.UpdateAsync(updateRequest);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var roleChangeLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.RoleChanged")
            .FirstOrDefaultAsync();

        roleChangeLog.Should().NotBeNull("User.RoleChanged audit event should be emitted [AUD-05]");
        roleChangeLog!.Details.Should().Contain("Viewer", "Details should contain old role");
        roleChangeLog.Details.Should().Contain("Editor", "Details should contain new role");
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task UpdateUser_WithPgChange_EmitsUserPermissionGroupChangedAuditEvent()
    {
        // Arrange - create a second PG
        await using var setupDb = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var newPgId = Uuid.NewSequential();
        setupDb.PermissionGroups.Add(new Domain.Domain.PermissionGroup
        {
            Id = newPgId,
            TenantId = _testTenantId,
            Name = "Second PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.SuperadminId,
            UpdatedByUserId = _fixture.SuperadminId
        });
        await setupDb.SaveChangesAsync();

        var createSut = CreateUserManagementService();
        var createRequest = new CreateUserRequest(
            FirstName: "PG",
            LastName: "Change",
            Email: "pg.change@test.local",
            UserName: "pg.change@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        var (_, _, userId, _) = await createSut.CreateAsync(_testTenantId, createRequest);

        // Clear audit logs
        await using var clearDb = _fixture.CreateAuditDbContext();
        var oldLogs = await clearDb.AuditLogs.Where(l => l.TenantId == _testTenantId).ToListAsync();
        clearDb.AuditLogs.RemoveRange(oldLogs);
        await clearDb.SaveChangesAsync();

        // Act - change PG
        var updateSut = CreateUserManagementService();
        var updateRequest = new UpdateUserRequest(
            Id: userId,
            FirstName: "PG",
            LastName: "Change",
            Email: "pg.change@test.local",
            Role: "Editor",
            PermissionGroupId: newPgId, // Changed PG
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        await updateSut.UpdateAsync(updateRequest);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var pgChangeLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.PermissionGroupChanged")
            .FirstOrDefaultAsync();

        pgChangeLog.Should().NotBeNull(
            "User.PermissionGroupChanged audit event should be emitted [AUD-05]");

        // Cleanup second PG
        await using var cleanupDb = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var pgToRemove = await cleanupDb.PermissionGroups.IgnoreQueryFilters()
            .FirstOrDefaultAsync(p => p.Id == newPgId);
        if (pgToRemove != null)
        {
            cleanupDb.PermissionGroups.Remove(pgToRemove);
            await cleanupDb.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task DeactivateUser_EmitsUserDeactivatedAuditEvent()
    {
        // Arrange
        var createSut = CreateUserManagementService();
        var createRequest = new CreateUserRequest(
            FirstName: "Deactivate",
            LastName: "Test",
            Email: "deactivate@test.local",
            UserName: "deactivate@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        var (_, _, userId, _) = await createSut.CreateAsync(_testTenantId, createRequest);

        // Clear audit logs
        await using var clearDb = _fixture.CreateAuditDbContext();
        var oldLogs = await clearDb.AuditLogs.Where(l => l.TenantId == _testTenantId).ToListAsync();
        clearDb.AuditLogs.RemoveRange(oldLogs);
        await clearDb.SaveChangesAsync();

        // Act
        var sut = CreateUserManagementService();
        await sut.SetActiveAsync(userId, false);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var deactivateLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.Deactivated")
            .FirstOrDefaultAsync();

        deactivateLog.Should().NotBeNull("User.Deactivated audit event should be emitted [AUD-05]");
        deactivateLog!.EventResult.Should().Be(AuditEventResult.Success);
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task ActivateUser_EmitsUserActivatedAuditEvent()
    {
        // Arrange
        var createSut = CreateUserManagementService();
        var createRequest = new CreateUserRequest(
            FirstName: "Activate",
            LastName: "Test",
            Email: "activate@test.local",
            UserName: "activate@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        var (_, _, userId, _) = await createSut.CreateAsync(_testTenantId, createRequest);

        // First deactivate
        var deactivateSut = CreateUserManagementService();
        await deactivateSut.SetActiveAsync(userId, false);

        // Clear audit logs
        await using var clearDb = _fixture.CreateAuditDbContext();
        var oldLogs = await clearDb.AuditLogs.Where(l => l.TenantId == _testTenantId).ToListAsync();
        clearDb.AuditLogs.RemoveRange(oldLogs);
        await clearDb.SaveChangesAsync();

        // Act - reactivate
        var sut = CreateUserManagementService();
        await sut.SetActiveAsync(userId, true);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var activateLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.Activated")
            .FirstOrDefaultAsync();

        activateLog.Should().NotBeNull("User.Activated audit event should be emitted [AUD-05]");
        activateLog!.EventResult.Should().Be(AuditEventResult.Success);
    }

    [Fact]
    [Trait("Req", "AUD-05")]
    public async Task UpdateUser_WithBasicFieldChanges_EmitsUserUpdatedAuditEvent()
    {
        // Arrange
        var createSut = CreateUserManagementService();
        var createRequest = new CreateUserRequest(
            FirstName: "Basic",
            LastName: "Update",
            Email: "basic.update@test.local",
            UserName: "basic.update@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            PreferredLocale: "en-US");

        var (_, _, userId, _) = await createSut.CreateAsync(_testTenantId, createRequest);

        // Clear audit logs
        await using var clearDb = _fixture.CreateAuditDbContext();
        var oldLogs = await clearDb.AuditLogs.Where(l => l.TenantId == _testTenantId).ToListAsync();
        clearDb.AuditLogs.RemoveRange(oldLogs);
        await clearDb.SaveChangesAsync();

        // Act - update basic fields only (no role/PG change)
        var updateSut = CreateUserManagementService();
        var updateRequest = new UpdateUserRequest(
            Id: userId,
            FirstName: "BasicChanged", // Changed
            LastName: "Update",
            Email: "basic.update@test.local",
            Role: "Editor",
            PermissionGroupId: _testPgId,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        await updateSut.UpdateAsync(updateRequest);

        // Assert
        await using var auditDb = _fixture.CreateAuditDbContext();
        var updateLog = await auditDb.AuditLogs
            .Where(l => l.TenantId == _testTenantId &&
                       l.EventType == "User.Updated")
            .FirstOrDefaultAsync();

        updateLog.Should().NotBeNull("User.Updated audit event should be emitted [AUD-05]");
    }

    #region Helpers

    private IUserManagementService CreateUserManagementService()
    {
        var sp = _fixture.CreateServiceProvider(_testTenantId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var db = sp.GetRequiredService<AppDbContext>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        // Use REAL audit service
        var auditDbOptions = new DbContextOptionsBuilder<AuditDbContext>();
        auditDbOptions.UseNpgsql(_fixture.ConnectionString);
        var auditDb = new AuditDbContext(auditDbOptions.Options);
        var auditService = new AuditService(auditDb, clock);

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
            userManager, db, emailMock.Object, clock, auditService,
            currentUserMock.Object, envMock.Object, loggerMock.Object);
    }

    #endregion
}
