using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for dashboard access level bitmask semantics [DoD-5].
/// AccessLevel: View=1, Edit=2 (mask 3), Delete=4 (mask 5), Full=7.
/// Per CLAUDE.md §15: (grantedLevel & requiredLevel) == requiredLevel.
/// </summary>
public class DashboardAccessTests
{
    private static readonly Guid TestTenantId = Uuid.NewSequential();
    private static readonly Guid TestPgId = Uuid.NewSequential();
    private static readonly Guid TestDashboardId = Uuid.NewSequential();

    // Access level constants per CLAUDE.md
    private const int AccessLevel_View = 1;
    private const int AccessLevel_Edit = 2;  // Edit permission bit only
    private const int AccessLevel_Delete = 4; // Delete permission bit only
    private const int AccessLevel_ViewEdit = 3;  // View + Edit
    private const int AccessLevel_ViewDelete = 5; // View + Delete
    private const int AccessLevel_Full = 7;  // View + Edit + Delete

    public static IEnumerable<object[]> BitmaskTestCases()
    {
        // Format: grantedLevel, requiredLevel, expectedResult

        // View only grants View
        yield return new object[] { AccessLevel_View, AccessLevel_View, true };
        yield return new object[] { AccessLevel_View, AccessLevel_Edit, false };
        yield return new object[] { AccessLevel_View, AccessLevel_Delete, false };
        yield return new object[] { AccessLevel_View, AccessLevel_ViewEdit, false };

        // Edit (mask 3 = View + Edit) grants View and Edit
        yield return new object[] { AccessLevel_ViewEdit, AccessLevel_View, true };
        yield return new object[] { AccessLevel_ViewEdit, AccessLevel_Edit, true };
        yield return new object[] { AccessLevel_ViewEdit, AccessLevel_Delete, false };
        yield return new object[] { AccessLevel_ViewEdit, AccessLevel_ViewEdit, true };

        // Delete (mask 5 = View + Delete) grants View and Delete
        yield return new object[] { AccessLevel_ViewDelete, AccessLevel_View, true };
        yield return new object[] { AccessLevel_ViewDelete, AccessLevel_Edit, false };
        yield return new object[] { AccessLevel_ViewDelete, AccessLevel_Delete, true };
        yield return new object[] { AccessLevel_ViewDelete, AccessLevel_ViewDelete, true };

        // Full (7) grants everything
        yield return new object[] { AccessLevel_Full, AccessLevel_View, true };
        yield return new object[] { AccessLevel_Full, AccessLevel_Edit, true };
        yield return new object[] { AccessLevel_Full, AccessLevel_Delete, true };
        yield return new object[] { AccessLevel_Full, AccessLevel_ViewEdit, true };
        yield return new object[] { AccessLevel_Full, AccessLevel_ViewDelete, true };
        yield return new object[] { AccessLevel_Full, AccessLevel_Full, true };

        // Zero grants nothing
        yield return new object[] { 0, AccessLevel_View, false };
        yield return new object[] { 0, AccessLevel_Edit, false };
        yield return new object[] { 0, AccessLevel_Delete, false };
    }

    [Theory]
    [Trait("Req", "PG-04")]
    [MemberData(nameof(BitmaskTestCases))]
    public async Task HasDashboardAccessAsync_BitmaskSemantics_Correct(
        int grantedLevel, int requiredLevel, bool expectedResult)
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var permissionGroup = CreatePermissionGroupWithDashboard(TestDashboardId, grantedLevel);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasDashboardAccessAsync(
            TestPgId, TestTenantId, TestDashboardId, requiredLevel);

        // Assert
        result.Should().Be(expectedResult,
            $"grantedLevel={grantedLevel}, requiredLevel={requiredLevel}: " +
            $"({grantedLevel} & {requiredLevel}) == {requiredLevel} should be {expectedResult}");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task HasDashboardAccessAsync_DashboardNotInList_ReturnsFalse()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var otherDashboardId = Uuid.NewSequential();
        var permissionGroup = CreatePermissionGroupWithDashboard(otherDashboardId, AccessLevel_Full);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasDashboardAccessAsync(
            TestPgId, TestTenantId, TestDashboardId, AccessLevel_View);

        // Assert
        result.Should().BeFalse("Dashboard is not in the permission group's list");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task HasDashboardAccessAsync_NullPermissionGroupId_ReturnsTrue()
    {
        // Arrange - Superadmin has null PG ID
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasDashboardAccessAsync(
            null, TestTenantId, TestDashboardId, AccessLevel_Full);

        // Assert
        result.Should().BeTrue("Superadmin (null PG) always has access");
        repo.Verify(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task HasDashboardAccessAsync_PermissionGroupNotFound_ReturnsFalse()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionGroup?)null);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasDashboardAccessAsync(
            TestPgId, TestTenantId, TestDashboardId, AccessLevel_View);

        // Assert
        result.Should().BeFalse("Non-existent permission group should deny access");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task HasDashboardAccessAsync_WrongTenant_ReturnsFalse()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var otherTenantId = Uuid.NewSequential();
        var permissionGroup = CreatePermissionGroupWithDashboard(TestDashboardId, AccessLevel_Full);
        // PG belongs to TestTenantId, but we're checking with otherTenantId

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasDashboardAccessAsync(
            TestPgId, otherTenantId, TestDashboardId, AccessLevel_View);

        // Assert
        result.Should().BeFalse("PG from different tenant should deny access");
    }

    private static PermissionGroup CreatePermissionGroupWithDashboard(Guid dashboardId, int accessLevel)
    {
        var group = new PermissionGroup
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

        group.DashboardPermissions.Add(new DashboardPermission
        {
            PermissionGroupId = TestPgId,
            DashboardId = dashboardId,
            AccessLevel = accessLevel
        });

        return group;
    }
}
