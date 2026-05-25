using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Services;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for IPermissionService resource access enforcement [PG-03].
/// Per PG-03: empty list = access denied (not "access to all").
/// </summary>
public class ResourceAccessTests
{
    private static readonly Guid TestTenantId = Uuid.NewSequential();
    private static readonly Guid TestPgId = Uuid.NewSequential();
    private static readonly Guid TestResourceId = Uuid.NewSequential();

    /// <summary>
    /// [Theory] Per DoD-4: 4 resource types with empty list should return false.
    /// </summary>
    [Theory]
    [Trait("Req", "PG-03")]
    [InlineData("queue")]
    [InlineData("skill")]
    [InlineData("agentgroup")]
    public async Task HasResourceAccessAsync_EmptyList_ReturnsFalse(string resourceType)
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        // Create a permission group with empty resource lists
        var permissionGroup = CreatePermissionGroup(
            queueIds: [],
            skillIds: [],
            businessUnitIds: [],
            supergroupIds: []);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        // Return null from cache to force DB lookup
        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            TestPgId, TestTenantId, resourceType, TestResourceId);

        // Assert
        result.Should().BeFalse(
            $"PG-03: empty {resourceType} list should deny access");
    }

    [Fact]
    [Trait("Req", "PG-03")]
    public async Task HasResourceAccessAsync_QueueInList_ReturnsTrue()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var permissionGroup = CreatePermissionGroup(
            queueIds: [TestResourceId], // Grant access to this queue
            skillIds: [],
            businessUnitIds: [],
            supergroupIds: []);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            TestPgId, TestTenantId, "queue", TestResourceId);

        // Assert
        result.Should().BeTrue("Queue is in the allowed list");
    }

    [Fact]
    [Trait("Req", "PG-03")]
    public async Task HasResourceAccessAsync_QueueNotInList_ReturnsFalse()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var otherQueueId = Uuid.NewSequential();
        var permissionGroup = CreatePermissionGroup(
            queueIds: [otherQueueId], // Different queue
            skillIds: [],
            businessUnitIds: [],
            supergroupIds: []);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            TestPgId, TestTenantId, "queue", TestResourceId);

        // Assert
        result.Should().BeFalse("Queue is not in the allowed list");
    }

    [Fact]
    [Trait("Req", "PG-03")]
    public async Task HasResourceAccessAsync_SkillInList_ReturnsTrue()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var permissionGroup = CreatePermissionGroup(
            queueIds: [],
            skillIds: [TestResourceId], // Grant access to this skill
            businessUnitIds: [],
            supergroupIds: []);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            TestPgId, TestTenantId, "skill", TestResourceId);

        // Assert
        result.Should().BeTrue("Skill is in the allowed list");
    }

    [Fact]
    [Trait("Req", "PG-03")]
    public async Task HasResourceAccessAsync_NullPermissionGroupId_ReturnsTrue()
    {
        // Arrange - Superadmin has null PG ID
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            null, TestTenantId, "queue", TestResourceId);

        // Assert
        result.Should().BeTrue("Superadmin (null PG) always has access");
        repo.Verify(r => r.GetByIdAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    [Trait("Req", "PG-03")]
    public async Task HasResourceAccessAsync_UnknownResourceType_ReturnsFalse()
    {
        // Arrange
        var cache = new Mock<ICacheService>();
        var repo = new Mock<IPermissionGroupRepository>();
        var logger = NullLogger<PermissionService>.Instance;

        var permissionGroup = CreatePermissionGroup(
            queueIds: [TestResourceId],
            skillIds: [TestResourceId],
            businessUnitIds: [],
            supergroupIds: []);

        repo.Setup(r => r.GetByIdAsync(TestPgId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(permissionGroup);

        cache.Setup(c => c.GetAsync<PermissionCacheEntry>(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((PermissionCacheEntry?)null);

        var service = new PermissionService(repo.Object, cache.Object, logger);

        // Act
        var result = await service.HasResourceAccessAsync(
            TestPgId, TestTenantId, "unknown_type", TestResourceId);

        // Assert
        result.Should().BeFalse("Unknown resource type should deny access");
    }

    private static PermissionGroup CreatePermissionGroup(
        IEnumerable<Guid> queueIds,
        IEnumerable<Guid> skillIds,
        IEnumerable<int> businessUnitIds,
        IEnumerable<int> supergroupIds)
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

        // Add queue permissions
        foreach (var queueId in queueIds)
        {
            group.AllowedQueues.Add(new PgQueue
            {
                PermissionGroupId = TestPgId,
                ObjectId = queueId,
                TenantId = TestTenantId
            });
        }

        // Add skill permissions
        foreach (var skillId in skillIds)
        {
            group.AllowedSkills.Add(new PgSkill
            {
                PermissionGroupId = TestPgId,
                ObjectId = skillId,
                TenantId = TestTenantId
            });
        }

        // Add business unit permissions
        foreach (var buId in businessUnitIds)
        {
            group.AllowedBusinessUnits.Add(new PgBusinessUnit
            {
                PermissionGroupId = TestPgId,
                BusinessUnitId = buId,
                TenantId = TestTenantId
            });
        }

        // Add supergroup permissions
        foreach (var sgId in supergroupIds)
        {
            group.AllowedSupergroups.Add(new PgSupergroup
            {
                PermissionGroupId = TestPgId,
                SupergroupId = sgId,
                TenantId = TestTenantId
            });
        }

        return group;
    }
}
