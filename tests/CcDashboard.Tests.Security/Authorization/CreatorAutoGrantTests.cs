using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for PG-01: dashboard creator auto-grant Full access [DoD-7].
/// Per CLAUDE.md §6.2: "[PG-01] On dashboard creation, creator's PG gets AccessLevel = 7 (Full) automatically."
/// </summary>
public class CreatorAutoGrantTests
{
    private static readonly Guid TestUserId = Uuid.NewSequential();
    private static readonly Guid TestTenantId = Uuid.NewSequential();
    private static readonly Guid TestPgId = Uuid.NewSequential();
    private static readonly DateTime TestNow = new(2026, 5, 25, 12, 0, 0, DateTimeKind.Utc);

    private const int AccessLevel_Full = 7;

    [Fact]
    [Trait("Req", "PG-01")]
    public async Task CreateDashboard_WithPermissionGroup_AutoGrantsFullAccess()
    {
        // Arrange
        var dashboardRepo = new Mock<IDashboardRepository>();
        var currentUser = new Mock<ICurrentUserAccessor>();
        var clock = new Mock<IDateTimeProvider>();

        currentUser.Setup(u => u.UserId).Returns(TestUserId);
        currentUser.Setup(u => u.TenantId).Returns(TestTenantId);
        currentUser.Setup(u => u.PermissionGroupId).Returns(TestPgId);
        currentUser.Setup(u => u.Role).Returns("Editor");
        clock.Setup(c => c.UtcNow).Returns(TestNow);

        Dashboard? savedDashboard = null;
        dashboardRepo
            .Setup(r => r.AddAsync(It.IsAny<Dashboard>(), It.IsAny<CancellationToken>()))
            .Callback<Dashboard, CancellationToken>((d, _) => savedDashboard = d)
            .Returns(Task.CompletedTask);

        var handler = new CreateDashboardCommandHandler(
            dashboardRepo.Object, currentUser.Object, clock.Object);

        var request = new CreateDashboardRequest("Test Dashboard", "Description", null, false);
        var command = new CreateDashboardCommand(request);

        // Act
        await handler.Handle(command, CancellationToken.None);

        // Assert
        savedDashboard.Should().NotBeNull();
        savedDashboard!.Permissions.Should().ContainSingle(p =>
            p.PermissionGroupId == TestPgId &&
            p.AccessLevel == AccessLevel_Full &&
            p.DashboardId == savedDashboard.Id,
            "[PG-01] Creator's PG should get AccessLevel = 7 (Full) automatically");
    }

    [Fact]
    [Trait("Req", "PG-01")]
    public async Task CreateDashboard_WithoutPermissionGroup_NoAutoGrant()
    {
        // Arrange - Superadmin has no PG
        var dashboardRepo = new Mock<IDashboardRepository>();
        var currentUser = new Mock<ICurrentUserAccessor>();
        var clock = new Mock<IDateTimeProvider>();

        currentUser.Setup(u => u.UserId).Returns(TestUserId);
        currentUser.Setup(u => u.TenantId).Returns(TestTenantId);
        currentUser.Setup(u => u.PermissionGroupId).Returns((Guid?)null); // Superadmin
        currentUser.Setup(u => u.Role).Returns("Superadmin");
        clock.Setup(c => c.UtcNow).Returns(TestNow);

        Dashboard? savedDashboard = null;
        dashboardRepo
            .Setup(r => r.AddAsync(It.IsAny<Dashboard>(), It.IsAny<CancellationToken>()))
            .Callback<Dashboard, CancellationToken>((d, _) => savedDashboard = d)
            .Returns(Task.CompletedTask);

        var handler = new CreateDashboardCommandHandler(
            dashboardRepo.Object, currentUser.Object, clock.Object);

        var request = new CreateDashboardRequest("Public Screen", null, null, true);
        var command = new CreateDashboardCommand(request);

        // Act
        await handler.Handle(command, CancellationToken.None);

        // Assert
        savedDashboard.Should().NotBeNull();
        savedDashboard!.Permissions.Should().BeEmpty(
            "Superadmin (no PG) should not have auto-granted permissions");
    }

    [Fact]
    [Trait("Req", "PG-01")]
    public async Task CreateDashboard_FullAccessMask_Is7()
    {
        // Arrange
        var dashboardRepo = new Mock<IDashboardRepository>();
        var currentUser = new Mock<ICurrentUserAccessor>();
        var clock = new Mock<IDateTimeProvider>();

        currentUser.Setup(u => u.UserId).Returns(TestUserId);
        currentUser.Setup(u => u.TenantId).Returns(TestTenantId);
        currentUser.Setup(u => u.PermissionGroupId).Returns(TestPgId);
        currentUser.Setup(u => u.Role).Returns("Administrator");
        clock.Setup(c => c.UtcNow).Returns(TestNow);

        Dashboard? savedDashboard = null;
        dashboardRepo
            .Setup(r => r.AddAsync(It.IsAny<Dashboard>(), It.IsAny<CancellationToken>()))
            .Callback<Dashboard, CancellationToken>((d, _) => savedDashboard = d)
            .Returns(Task.CompletedTask);

        var handler = new CreateDashboardCommandHandler(
            dashboardRepo.Object, currentUser.Object, clock.Object);

        var request = new CreateDashboardRequest("My Dashboard", null, null, false);
        var command = new CreateDashboardCommand(request);

        // Act
        await handler.Handle(command, CancellationToken.None);

        // Assert - verify the bitmask value
        var permission = savedDashboard!.Permissions.First();

        // Full = 7 = View(1) + Edit(2) + Delete(4)
        (permission.AccessLevel & 1).Should().Be(1, "Full access includes View");
        (permission.AccessLevel & 2).Should().Be(2, "Full access includes Edit");
        (permission.AccessLevel & 4).Should().Be(4, "Full access includes Delete");
        permission.AccessLevel.Should().Be(7, "Full access mask should be exactly 7");
    }

    [Fact]
    [Trait("Req", "PG-01")]
    public async Task CreateDashboard_Permission_LinkedToCorrectDashboard()
    {
        // Arrange
        var dashboardRepo = new Mock<IDashboardRepository>();
        var currentUser = new Mock<ICurrentUserAccessor>();
        var clock = new Mock<IDateTimeProvider>();

        currentUser.Setup(u => u.UserId).Returns(TestUserId);
        currentUser.Setup(u => u.TenantId).Returns(TestTenantId);
        currentUser.Setup(u => u.PermissionGroupId).Returns(TestPgId);
        currentUser.Setup(u => u.Role).Returns("Editor");
        clock.Setup(c => c.UtcNow).Returns(TestNow);

        Dashboard? savedDashboard = null;
        dashboardRepo
            .Setup(r => r.AddAsync(It.IsAny<Dashboard>(), It.IsAny<CancellationToken>()))
            .Callback<Dashboard, CancellationToken>((d, _) => savedDashboard = d)
            .Returns(Task.CompletedTask);

        var handler = new CreateDashboardCommandHandler(
            dashboardRepo.Object, currentUser.Object, clock.Object);

        var request = new CreateDashboardRequest("Dashboard XYZ", null, null, false);
        var command = new CreateDashboardCommand(request);

        // Act
        await handler.Handle(command, CancellationToken.None);

        // Assert
        var permission = savedDashboard!.Permissions.First();
        permission.DashboardId.Should().Be(savedDashboard.Id,
            "Permission should be linked to the created dashboard's ID");
        permission.TenantId.Should().Be(TestTenantId,
            "Permission should have the correct TenantId");
    }
}
