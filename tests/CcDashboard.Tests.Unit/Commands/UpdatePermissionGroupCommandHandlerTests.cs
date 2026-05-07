using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class UpdatePermissionGroupCommandHandlerTests
{
    private readonly IPermissionGroupRepository _repo = Substitute.For<IPermissionGroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly ICacheService _cache = Substitute.For<ICacheService>();
    private readonly UpdatePermissionGroupCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public UpdatePermissionGroupCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _clock.UtcNow.Returns(Now);
        _handler = new UpdatePermissionGroupCommandHandler(_repo, _user, _clock, _cache);
    }

    [Fact]
    public async Task Handle_ValidRequest_UpdatesGroupAndInvalidatesCache()
    {
        var id = Guid.NewGuid();
        var group = new PermissionGroup { Id = id, TenantId = TenantId, Name = "Old", IsActive = true };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(group);

        var req = new UpdatePermissionGroupRequest(id, "New Name", "desc", true, ["menu.dashboards"], 1);
        var result = await _handler.Handle(new UpdatePermissionGroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        group.Name.Should().Be("New Name");
        group.UpdatedAt.Should().Be(Now);
        group.UpdatedByUserId.Should().Be(UserId);
        group.MenuPermissions.Should().ContainSingle(m => m.MenuKey == "menu.dashboards");

        await _cache.Received(1).RemoveAsync(
            $"{TenantId}:pg_permissions:{id}",
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_GroupNotFound_ThrowsNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((PermissionGroup?)null);

        var req = new UpdatePermissionGroupRequest(id, "X", null, true, [], 0);
        var act = () => _handler.Handle(new UpdatePermissionGroupCommand(req), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
        await _cache.DidNotReceive().RemoveAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_MenuPermissions_Replaced_NotAppended()
    {
        var id = Guid.NewGuid();
        var group = new PermissionGroup { Id = id, TenantId = TenantId, Name = "G" };
        group.MenuPermissions.Add(new MenuPermission { MenuKey = "menu.users", TenantId = TenantId, PermissionGroupId = id });
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(group);

        var req = new UpdatePermissionGroupRequest(id, "G", null, true, ["menu.dashboards"], 0);
        await _handler.Handle(new UpdatePermissionGroupCommand(req), CancellationToken.None);

        group.MenuPermissions.Should().ContainSingle();
        group.MenuPermissions.Should().NotContain(m => m.MenuKey == "menu.users");
        group.MenuPermissions.Should().Contain(m => m.MenuKey == "menu.dashboards");
    }
}
