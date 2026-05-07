using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class DeletePermissionGroupCommandHandlerTests
{
    private readonly IPermissionGroupRepository _repo = Substitute.For<IPermissionGroupRepository>();
    private readonly DeletePermissionGroupCommandHandler _handler;

    public DeletePermissionGroupCommandHandlerTests()
    {
        _handler = new DeletePermissionGroupCommandHandler(_repo);
    }

    [Fact]
    public async Task Handle_GroupExists_NoUsers_DeletesAndSucceeds()
    {
        var id = Guid.NewGuid();
        var group = new PermissionGroup { Id = id, TenantId = Guid.NewGuid(), Name = "Test" };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(group);
        _repo.CountUsersAsync(id, Arg.Any<CancellationToken>()).Returns(0);

        var result = await _handler.Handle(new DeletePermissionGroupCommand(id), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Remove(group);
    }

    [Fact]
    public async Task Handle_GroupHasUsers_ReturnsFailure()
    {
        var id = Guid.NewGuid();
        var group = new PermissionGroup { Id = id, TenantId = Guid.NewGuid(), Name = "Test" };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(group);
        _repo.CountUsersAsync(id, Arg.Any<CancellationToken>()).Returns(3);

        var result = await _handler.Handle(new DeletePermissionGroupCommand(id), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("3");
        _repo.DidNotReceive().Remove(Arg.Any<PermissionGroup>());
    }

    [Fact]
    public async Task Handle_GroupNotFound_ThrowsNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((PermissionGroup?)null);

        var act = () => _handler.Handle(new DeletePermissionGroupCommand(id), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }
}
