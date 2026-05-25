using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Tests.Security.MultiTenancy;

/// <summary>
/// Tests for Global Query Filter (GQF) isolation per ARCH-01.
/// Verifies that rows written in tenant A context are NOT returned
/// to queries in tenant B context.
/// </summary>
[Collection("Postgres")]
public class GlobalQueryFilterTests
{
    private readonly PostgresFixture _fixture;

    public GlobalQueryFilterTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    #region Users (ApplicationUser) GQF

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetUsers_FromTenantAContext_ReturnsOnlyTenantAUsers()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var users = await dbTenantA.Users.ToListAsync();

        // Assert
        users.Should().NotBeEmpty();
        users.Should().OnlyContain(u => u.TenantId == _fixture.TenantAId,
            "GQF should filter users to current tenant only");
        users.Should().NotContain(u => u.TenantId == _fixture.TenantBId,
            "Users from other tenants should not be visible");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetUsers_FromTenantBContext_ReturnsOnlyTenantBUsers()
    {
        // Arrange
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var users = await dbTenantB.Users.ToListAsync();

        // Assert
        users.Should().NotBeEmpty();
        users.Should().OnlyContain(u => u.TenantId == _fixture.TenantBId,
            "GQF should filter users to current tenant only");
        users.Should().NotContain(u => u.TenantId == _fixture.TenantAId,
            "Users from other tenants should not be visible");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task CreateUser_InTenantA_NotVisibleToTenantB()
    {
        // Arrange
        var newUserId = Uuid.NewSequential();
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        var newUser = new ApplicationUser
        {
            Id = newUserId,
            TenantId = _fixture.TenantAId,
            UserName = $"new.user.{newUserId:N}@tenant-a.local",
            Email = $"new.user.{newUserId:N}@tenant-a.local",
            NormalizedUserName = $"NEW.USER.{newUserId:N}@TENANT-A.LOCAL",
            NormalizedEmail = $"NEW.USER.{newUserId:N}@TENANT-A.LOCAL",
            EmailConfirmed = true,
            FirstName = "New",
            LastName = "User",
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString()
        };

        dbTenantA.Users.Add(newUser);
        await dbTenantA.SaveChangesAsync();

        // Act
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);
        var visibleToB = await dbTenantB.Users.AnyAsync(u => u.Id == newUserId);

        // Assert
        visibleToB.Should().BeFalse("User created in Tenant A should not be visible from Tenant B context");
    }

    #endregion

    #region PermissionGroups GQF

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetPermissionGroups_FromTenantAContext_ReturnsOnlyTenantAGroups()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var groups = await dbTenantA.PermissionGroups.ToListAsync();

        // Assert
        groups.Should().NotBeEmpty();
        groups.Should().OnlyContain(g => g.TenantId == _fixture.TenantAId,
            "GQF should filter permission groups to current tenant only");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetPermissionGroups_FromTenantBContext_DoesNotIncludeTenantAGroups()
    {
        // Arrange
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var groups = await dbTenantB.PermissionGroups.ToListAsync();

        // Assert
        groups.Should().NotBeEmpty("Tenant B should have its own groups");
        groups.Should().NotContain(g => g.Id == _fixture.PgAId,
            "Tenant A's permission group should not be visible to Tenant B");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task CreatePermissionGroup_InTenantA_NotVisibleToTenantB()
    {
        // Arrange
        var newPgId = Uuid.NewSequential();
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        var now = DateTime.UtcNow;

        var newGroup = new PermissionGroup
        {
            Id = newPgId,
            TenantId = _fixture.TenantAId,
            Name = $"Test Group {newPgId:N}",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        dbTenantA.PermissionGroups.Add(newGroup);
        await dbTenantA.SaveChangesAsync();

        // Act
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);
        var visibleToB = await dbTenantB.PermissionGroups.AnyAsync(g => g.Id == newPgId);

        // Assert
        visibleToB.Should().BeFalse("PermissionGroup created in Tenant A should not be visible from Tenant B context");
    }

    #endregion

    #region Dashboards GQF

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetDashboards_FromTenantAContext_ReturnsOnlyTenantADashboards()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var dashboards = await dbTenantA.Dashboards.ToListAsync();

        // Assert
        dashboards.Should().NotBeEmpty();
        dashboards.Should().OnlyContain(d => d.TenantId == _fixture.TenantAId,
            "GQF should filter dashboards to current tenant only");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetDashboards_FromTenantBContext_DoesNotIncludeTenantADashboards()
    {
        // Arrange
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var dashboards = await dbTenantB.Dashboards.ToListAsync();

        // Assert
        dashboards.Should().NotBeEmpty("Tenant B should have its own dashboards");
        dashboards.Should().NotContain(d => d.Id == _fixture.DashboardAId,
            "Tenant A's dashboard should not be visible to Tenant B");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task CreateDashboard_InTenantA_NotVisibleToTenantB()
    {
        // Arrange
        var newDashId = Uuid.NewSequential();
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        var now = DateTime.UtcNow;

        var newDash = new Dashboard
        {
            Id = newDashId,
            TenantId = _fixture.TenantAId,
            Name = $"Test Dashboard {newDashId:N}",
            Status = DashboardStatus.Draft,
            IsPublic = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        dbTenantA.Dashboards.Add(newDash);
        await dbTenantA.SaveChangesAsync();

        // Act
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);
        var visibleToB = await dbTenantB.Dashboards.AnyAsync(d => d.Id == newDashId);

        // Assert
        visibleToB.Should().BeFalse("Dashboard created in Tenant A should not be visible from Tenant B context");
    }

    #endregion

    #region Soft-Delete + GQF Combined (Dashboard)

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetDashboards_SoftDeletedDashboard_NotVisibleEvenToSameTenant()
    {
        // Arrange
        var deletedDashId = Uuid.NewSequential();
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        var now = DateTime.UtcNow;

        var deletedDash = new Dashboard
        {
            Id = deletedDashId,
            TenantId = _fixture.TenantAId,
            Name = $"Deleted Dashboard {deletedDashId:N}",
            Status = DashboardStatus.Published,
            IsPublic = false,
            IsDeleted = true,
            DeletedAt = now,
            DeletedByUserId = _fixture.UserAId,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        dbTenantA.Dashboards.Add(deletedDash);
        await dbTenantA.SaveChangesAsync();

        // Act: Query without IgnoreQueryFilters
        var visibleDashboards = await dbTenantA.Dashboards
            .Where(d => d.Id == deletedDashId)
            .ToListAsync();

        // Assert
        visibleDashboards.Should().BeEmpty(
            "Soft-deleted dashboard should not be visible due to combined GQF (TenantId + !IsDeleted)");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task GetDashboards_WithIgnoreQueryFilters_ReturnsSoftDeletedDashboard()
    {
        // Arrange
        var deletedDashId = Uuid.NewSequential();
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        var now = DateTime.UtcNow;

        var deletedDash = new Dashboard
        {
            Id = deletedDashId,
            TenantId = _fixture.TenantAId,
            Name = $"Recoverable Dashboard {deletedDashId:N}",
            Status = DashboardStatus.Published,
            IsPublic = false,
            IsDeleted = true,
            DeletedAt = now,
            DeletedByUserId = _fixture.UserAId,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        dbTenantA.Dashboards.Add(deletedDash);
        await dbTenantA.SaveChangesAsync();

        // Act: Query with IgnoreQueryFilters
        var allDashboards = await dbTenantA.Dashboards
            .IgnoreQueryFilters()
            .Where(d => d.Id == deletedDashId)
            .ToListAsync();

        // Assert
        allDashboards.Should().ContainSingle(d => d.Id == deletedDashId,
            "IgnoreQueryFilters should bypass GQF and return soft-deleted dashboard");
    }

    #endregion

    #region IgnoreQueryFilters still respects explicit Where

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task IgnoreQueryFilters_WithExplicitTenantWhere_OnlyReturnsThatTenant()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act: Use IgnoreQueryFilters but add explicit Where
        var users = await dbTenantA.Users
            .IgnoreQueryFilters()
            .Where(u => u.TenantId == _fixture.TenantAId)
            .ToListAsync();

        // Assert
        users.Should().NotBeEmpty();
        users.Should().OnlyContain(u => u.TenantId == _fixture.TenantAId,
            "Explicit Where clause should still filter correctly even with IgnoreQueryFilters");
    }

    #endregion
}
