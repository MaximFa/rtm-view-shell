using CcDashboard.Application.DTOs;
using CcDashboard.Application.Services;
using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Services;

public class ScreenServiceTests
{
    private readonly IRepository<Screen> _screens = Substitute.For<IRepository<Screen>>();
    private readonly IRepository<ScreenPermission> _perms = Substitute.For<IRepository<ScreenPermission>>();
    private readonly IRepository<WidgetSlot> _slots = Substitute.For<IRepository<WidgetSlot>>();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly ScreenService _sut;

    public ScreenServiceTests()
    {
        _sut = new ScreenService(_screens, _perms, _slots, _users);
    }

    [Fact]
    public async Task CreateAsync_sets_Draft_status_and_owner()
    {
        var ownerId = Guid.NewGuid();
        Screen? saved = null;
        await _screens.AddAsync(Arg.Do<Screen>(s => saved = s));

        await _sut.CreateAsync(ownerId, new CreateScreenRequest("My Board"));

        saved.Should().NotBeNull();
        saved!.Name.Should().Be("My Board");
        saved.OwnerId.Should().Be(ownerId);
        saved.Status.Should().Be(ScreenStatus.Draft);
    }

    [Fact]
    public async Task GetByIdAsync_returns_null_for_missing_screen()
    {
        _screens.GetByIdAsync(Arg.Any<Guid>()).Returns((Screen?)null);

        var result = await _sut.GetByIdAsync(Guid.NewGuid());

        result.Should().BeNull();
    }

    [Fact]
    public async Task UpdateAsync_throws_NotFoundException_for_missing_screen()
    {
        _screens.GetByIdAsync(Arg.Any<Guid>()).Returns((Screen?)null);

        await _sut.Invoking(s => s.UpdateAsync(Guid.NewGuid(),
                new UpdateScreenRequest("New Name", ScreenStatus.Active)))
            .Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task UpdateAsync_persists_name_and_status()
    {
        var screen = new Screen
        {
            Id = Guid.NewGuid(),
            Name = "Old",
            OwnerId = Guid.NewGuid(),
            Status = ScreenStatus.Draft,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _screens.GetByIdAsync(screen.Id).Returns(screen);

        var result = await _sut.UpdateAsync(screen.Id, new UpdateScreenRequest("New Name", ScreenStatus.Active));

        result.Name.Should().Be("New Name");
        result.Status.Should().Be(ScreenStatus.Active);
        await _screens.Received(1).UpdateAsync(screen);
    }

    [Fact]
    public async Task DeleteAsync_throws_NotFoundException_for_missing_screen()
    {
        _screens.GetByIdAsync(Arg.Any<Guid>()).Returns((Screen?)null);

        await _sut.Invoking(s => s.DeleteAsync(Guid.NewGuid()))
            .Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task DeleteAsync_calls_repository_delete()
    {
        var screen = new Screen
        {
            Id = Guid.NewGuid(),
            Name = "Test",
            OwnerId = Guid.NewGuid(),
            Status = ScreenStatus.Draft,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _screens.GetByIdAsync(screen.Id).Returns(screen);

        await _sut.DeleteAsync(screen.Id);

        await _screens.Received(1).DeleteAsync(screen);
    }

    [Fact]
    public async Task AddWidgetSlotAsync_throws_NotFoundException_when_screen_missing()
    {
        _screens.ExistsAsync(Arg.Any<System.Linq.Expressions.Expression<Func<Screen, bool>>>())
            .Returns(false);

        await _sut.Invoking(s => s.AddWidgetSlotAsync(
                new AddWidgetSlotRequest(Guid.NewGuid(), "queues", "queue-summary")))
            .Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task SetPermissionAsync_creates_new_permission_when_none_exists()
    {
        var screenId = Guid.NewGuid();
        var groupId = Guid.NewGuid();
        _perms.FindAsync(Arg.Any<System.Linq.Expressions.Expression<Func<ScreenPermission, bool>>>())
            .Returns(Array.Empty<ScreenPermission>());

        await _sut.SetPermissionAsync(new SetScreenPermissionRequest(screenId, groupId, true, false, false));

        await _perms.Received(1).AddAsync(Arg.Is<ScreenPermission>(p =>
            p.ScreenId == screenId && p.GroupId == groupId && p.CanView));
    }

    [Fact]
    public async Task SetPermissionAsync_updates_existing_permission()
    {
        var existing = new ScreenPermission
        {
            ScreenId = Guid.NewGuid(),
            GroupId = Guid.NewGuid(),
            CanView = false,
            CanEdit = false,
            CanDelete = false
        };
        _perms.FindAsync(Arg.Any<System.Linq.Expressions.Expression<Func<ScreenPermission, bool>>>())
            .Returns(new[] { existing });

        await _sut.SetPermissionAsync(new SetScreenPermissionRequest(
            existing.ScreenId, existing.GroupId, true, true, false));

        existing.CanView.Should().BeTrue();
        existing.CanEdit.Should().BeTrue();
        await _perms.Received(1).UpdateAsync(existing);
    }
}
