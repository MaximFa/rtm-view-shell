using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class CreatePermissionGroupCommandHandlerTests
{
    private readonly IPermissionGroupRepository _repo = Substitute.For<IPermissionGroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly ICacheService _cache = Substitute.For<ICacheService>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();
    private readonly CreatePermissionGroupCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 3, 1, 8, 0, 0, DateTimeKind.Utc);

    public CreatePermissionGroupCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _clock.UtcNow.Returns(Now);
        _handler = new CreatePermissionGroupCommandHandler(_repo, _user, _clock, _apiHook);
    }

    [Fact]
    public async Task Handle_ValidRequest_CreatesGroupWithMenuPermissions()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var req = new CreatePermissionGroupRequest(
            "Operators",
            "Operator group",
            ["menu.dashboards", "menu.widgetCatalog"],
            null, null, null, null, null);

        var result = await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.Name.Should().Be("Operators");
        saved.Description.Should().Be("Operator group");
        saved.TenantId.Should().Be(TenantId);
        saved.IsActive.Should().BeTrue();
        saved.CreatedAt.Should().Be(Now);
        saved.CreatedByUserId.Should().Be(UserId);
        saved.MenuPermissions.Should().HaveCount(2);
        saved.MenuPermissions.Should().Contain(m => m.MenuKey == "menu.dashboards");
        saved.MenuPermissions.Should().Contain(m => m.MenuKey == "menu.widgetCatalog");
    }

    [Fact]
    public async Task Handle_WithQueueAndSkillPermissions_AddsToCollections()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var queueId1 = Guid.NewGuid();
        var queueId2 = Guid.NewGuid();
        var skillId = Guid.NewGuid();

        var req = new CreatePermissionGroupRequest(
            "WithResources",
            null,
            ["menu.dashboards"],
            [queueId1, queueId2],
            [skillId],
            null, null, null);

        var result = await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved!.AllowedQueues.Should().HaveCount(2);
        saved.AllowedSkills.Should().HaveCount(1);
        saved.AllowedQueues.Should().Contain(q => q.ObjectId == queueId1);
        saved.AllowedSkills.Should().Contain(s => s.ObjectId == skillId);
    }

    [Fact]
    public async Task Handle_WithBusinessUnitsAndSupergroups_AddsToCollections()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var req = new CreatePermissionGroupRequest(
            "WithBuSg",
            null,
            [],
            null, null,
            [1, 2, 3],
            [10, 20],
            null);

        var result = await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved!.AllowedBusinessUnits.Should().HaveCount(3);
        saved.AllowedSupergroups.Should().HaveCount(2);
        saved.AllowedBusinessUnits.Should().Contain(b => b.BusinessUnitId == 1);
        saved.AllowedSupergroups.Should().Contain(s => s.SupergroupId == 20);
    }

    [Fact]
    public async Task Handle_WithDashboardPermissions_AddsFullAccess()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var dashId = Guid.NewGuid();
        var req = new CreatePermissionGroupRequest(
            "WithDashboards",
            null,
            [],
            null, null, null, null,
            [dashId]);

        var result = await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved!.DashboardPermissions.Should().HaveCount(1);
        saved.DashboardPermissions.Should().Contain(d => d.DashboardId == dashId && d.AccessLevel == 7);
    }

    [Fact]
    public async Task Handle_ExplicitTenantId_UsesThatTenant()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var explicitTenantId = Guid.NewGuid();
        var req = new CreatePermissionGroupRequest("CrossTenant", null, [], null, null, null, null, null);

        var result = await _handler.Handle(
            new CreatePermissionGroupCommand(req, explicitTenantId),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved!.TenantId.Should().Be(explicitTenantId);
    }

    [Fact]
    public async Task Handle_TrimsNameAndDescription()
    {
        PermissionGroup? saved = null;
        await _repo.AddAsync(Arg.Do<PermissionGroup>(g => saved = g), Arg.Any<CancellationToken>());

        var req = new CreatePermissionGroupRequest(
            "  Trimmed Name  ",
            "  Trimmed Description  ",
            [],
            null, null, null, null, null);

        await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        saved!.Name.Should().Be("Trimmed Name");
        saved.Description.Should().Be("Trimmed Description");
    }

    [Fact]
    public async Task Handle_NotifiesApiHook()
    {
        var req = new CreatePermissionGroupRequest("Notified", null, [], null, null, null, null, null);

        await _handler.Handle(new CreatePermissionGroupCommand(req), CancellationToken.None);

        await _apiHook.Received(1).NotifyAsync(
            "PermissionGroup.Created",
            Arg.Any<object>(),
            Arg.Any<CancellationToken>());
    }
}
