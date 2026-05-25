using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using System.Reflection;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for single permission group assignment constraint [DoD-6].
/// Per CLAUDE.md §15: "Every user (except Superadmin) belongs to exactly one Permission Group."
/// Effective permission = union of all group permissions within that single PG.
/// </summary>
public class PermissionGroupAssignmentTests
{
    private static readonly Guid TestTenantId = Uuid.NewSequential();
    private static readonly Guid TestPgId = Uuid.NewSequential();
    private static readonly Guid TestUserId = Uuid.NewSequential();

    [Fact]
    [Trait("Req", "PG-04")]
    public void ApplicationUser_PermissionGroupId_IsSingleValue_NotCollection()
    {
        // Arrange & Act
        var property = typeof(ApplicationUser).GetProperty("PermissionGroupId");

        // Assert - verify it's a single Guid?, not a collection
        property.Should().NotBeNull("ApplicationUser should have PermissionGroupId property");
        property!.PropertyType.Should().Be(typeof(Guid?),
            "PermissionGroupId should be Guid? (single value, not a collection) to enforce one PG per user");

        // Verify it's not a collection type (Guid? is Nullable<Guid> which is generic, but not a collection)
        var isCollectionType = property.PropertyType.IsGenericType &&
            (typeof(System.Collections.IEnumerable).IsAssignableFrom(property.PropertyType) &&
             property.PropertyType != typeof(string));

        isCollectionType.Should().BeFalse(
            "PermissionGroupId should not be a collection type");

        // Verify no PG collection property exists
        var pgCollectionProperty = typeof(ApplicationUser).GetProperties()
            .Where(p => p.Name.Contains("PermissionGroup", StringComparison.OrdinalIgnoreCase))
            .Where(p => p.PropertyType.IsGenericType &&
                       (p.PropertyType.GetGenericTypeDefinition() == typeof(ICollection<>) ||
                        p.PropertyType.GetGenericTypeDefinition() == typeof(IList<>) ||
                        p.PropertyType.GetGenericTypeDefinition() == typeof(List<>)));

        pgCollectionProperty.Should().BeEmpty(
            "ApplicationUser should not have a collection of PermissionGroups - single assignment only");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public void ApplicationUser_CanOnlyHaveOnePG_AtModelLevel()
    {
        // Arrange
        var user = new ApplicationUser
        {
            Id = TestUserId,
            TenantId = TestTenantId,
            UserName = "test@test.com",
            Email = "test@test.com",
            FirstName = "Test",
            LastName = "User",
            IsActive = true
        };

        var pgId1 = Uuid.NewSequential();
        var pgId2 = Uuid.NewSequential();

        // Act - assign first PG
        user.PermissionGroupId = pgId1;

        // Assert
        user.PermissionGroupId.Should().Be(pgId1);

        // Act - "reassign" to second PG (this is how single assignment works)
        user.PermissionGroupId = pgId2;

        // Assert - only the latest PG is assigned, not both
        user.PermissionGroupId.Should().Be(pgId2);
        user.PermissionGroupId.Should().NotBe(pgId1,
            "User should only have one PG at a time (replacement, not addition)");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task EffectivePermission_ComesFromSinglePG_UnionWithinPG()
    {
        // Arrange - a PG with multiple menu permissions and dashboard permissions
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var dashboardId1 = Uuid.NewSequential();
        var dashboardId2 = Uuid.NewSequential();
        var queueId1 = Uuid.NewSequential();
        var queueId2 = Uuid.NewSequential();

        var permissionGroup = new PermissionGroup
        {
            Id = TestPgId,
            TenantId = TestTenantId,
            Name = "Test Group",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = Uuid.NewSequential(),
            UpdatedByUserId = Uuid.NewSequential()
        };

        // Add multiple menu permissions (union within PG)
        permissionGroup.MenuPermissions.Add(new MenuPermission
        {
            PermissionGroupId = TestPgId,
            MenuKey = "menu.users",
            TenantId = TestTenantId
        });
        permissionGroup.MenuPermissions.Add(new MenuPermission
        {
            PermissionGroupId = TestPgId,
            MenuKey = "menu.dashboards",
            TenantId = TestTenantId
        });

        // Add multiple dashboard permissions (union within PG)
        permissionGroup.DashboardPermissions.Add(new DashboardPermission
        {
            PermissionGroupId = TestPgId,
            DashboardId = dashboardId1,
            AccessLevel = 7 // Full
        });
        permissionGroup.DashboardPermissions.Add(new DashboardPermission
        {
            PermissionGroupId = TestPgId,
            DashboardId = dashboardId2,
            AccessLevel = 1 // View only
        });

        // Add multiple queue permissions (union within PG)
        permissionGroup.AllowedQueues.Add(new PgQueue
        {
            PermissionGroupId = TestPgId,
            ObjectId = queueId1,
            TenantId = TestTenantId
        });
        permissionGroup.AllowedQueues.Add(new PgQueue
        {
            PermissionGroupId = TestPgId,
            ObjectId = queueId2,
            TenantId = TestTenantId
        });

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act & Assert - verify union of permissions within the single PG

        // Both menu permissions should be accessible
        var hasMenuUsers = await service.HasPermissionAsync(TestPgId, TestTenantId, "menu.users");
        var hasMenuDashboards = await service.HasPermissionAsync(TestPgId, TestTenantId, "menu.dashboards");

        hasMenuUsers.Should().BeTrue("menu.users is in PG's permissions");
        hasMenuDashboards.Should().BeTrue("menu.dashboards is in PG's permissions");

        // Both dashboards should be accessible
        var hasDash1Access = await service.HasDashboardAccessAsync(TestPgId, TestTenantId, dashboardId1, 1);
        var hasDash2Access = await service.HasDashboardAccessAsync(TestPgId, TestTenantId, dashboardId2, 1);

        hasDash1Access.Should().BeTrue("dashboard1 is in PG with Full access");
        hasDash2Access.Should().BeTrue("dashboard2 is in PG with View access");

        // Both queues should be accessible
        var hasQueue1Access = await service.HasResourceAccessAsync(TestPgId, TestTenantId, "queue", queueId1);
        var hasQueue2Access = await service.HasResourceAccessAsync(TestPgId, TestTenantId, "queue", queueId2);

        hasQueue1Access.Should().BeTrue("queue1 is in PG's allowed queues");
        hasQueue2Access.Should().BeTrue("queue2 is in PG's allowed queues");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public void Superadmin_HasNullPermissionGroupId()
    {
        // Arrange - Superadmin should have null PermissionGroupId per CLAUDE.md §15
        var superadmin = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = TestTenantId,
            UserName = "superadmin@test.com",
            Email = "superadmin@test.com",
            FirstName = "Super",
            LastName = "Admin",
            IsActive = true,
            PermissionGroupId = null // Superadmin has null PG
        };

        // Assert
        superadmin.PermissionGroupId.Should().BeNull(
            "Superadmin should have null PermissionGroupId - bypasses PG checks");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task PermissionService_NullPgId_BypassesAllChecks()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cache.Object, logger);
        var anyDashboard = Uuid.NewSequential();
        var anyResource = Uuid.NewSequential();

        // Act - all checks with null PG ID
        var hasPermission = await service.HasPermissionAsync(null, TestTenantId, "menu.users");
        var hasDashboardAccess = await service.HasDashboardAccessAsync(null, TestTenantId, anyDashboard, 7);
        var hasResourceAccess = await service.HasResourceAccessAsync(null, TestTenantId, "queue", anyResource);

        // Assert - all should return true (Superadmin bypass)
        hasPermission.Should().BeTrue("Superadmin (null PG) bypasses permission check");
        hasDashboardAccess.Should().BeTrue("Superadmin (null PG) bypasses dashboard access check");
        hasResourceAccess.Should().BeTrue("Superadmin (null PG) bypasses resource access check");

        // Verify no repo calls were made
        repo.Verify(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }
}
