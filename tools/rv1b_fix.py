#!/usr/bin/env python3
"""
RV-1b: Remove metric-mutation Tests.Unit orphans.
- Delete 2 files (done via git rm separately)
- Edit DeleteConfigurationCommandsTests.cs to remove DeleteRtsGridMetricCommandHandlerTests class
"""
import os

# Edit DeleteConfigurationCommandsTests.cs - keep only BU and Supergroup test classes
path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Unit\Commands\Configuration\DeleteConfigurationCommandsTests.cs"

# New content: lines 1-84 from original (up to end of DeleteSupergroupCommandHandlerTests)
content = r'''using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class DeleteBusinessUnitCommandHandlerTests
{
    private readonly INgcBusinessUnitRepository _repo = Substitute.For<INgcBusinessUnitRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly DeleteBusinessUnitCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public DeleteBusinessUnitCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new DeleteBusinessUnitCommandHandler(_repo, _user);
    }

    [Fact]
    public async Task Handle_ExistingBU_DeletesSuccessfully()
    {
        var bu = new NgcBusinessUnit { BusinessUnitId = 1, TenantId = TenantId, BusinessUnitName = "To Delete" };
        _repo.GetByIdAsync(1, TenantId, Arg.Any<CancellationToken>()).Returns(bu);

        var result = await _handler.Handle(new DeleteBusinessUnitCommand(1), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Delete(bu);
    }

    [Fact]
    public async Task Handle_NonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync(999, TenantId, Arg.Any<CancellationToken>()).Returns((NgcBusinessUnit?)null);

        var result = await _handler.Handle(new DeleteBusinessUnitCommand(999), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}

public class DeleteSupergroupCommandHandlerTests
{
    private readonly INgcSupergroupRepository _repo = Substitute.For<INgcSupergroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly DeleteSupergroupCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public DeleteSupergroupCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new DeleteSupergroupCommandHandler(_repo, _user);
    }

    [Fact]
    public async Task Handle_ExistingSG_DeletesSuccessfully()
    {
        var sg = new NgcSupergroup { SupergroupId = 10, TenantId = TenantId, SupergroupName = "To Delete" };
        _repo.GetByIdAsync(10, TenantId, Arg.Any<CancellationToken>()).Returns(sg);

        var result = await _handler.Handle(new DeleteSupergroupCommand(10), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Delete(sg);
    }

    [Fact]
    public async Task Handle_NonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync(999, TenantId, Arg.Any<CancellationToken>()).Returns((NgcSupergroup?)null);

        var result = await _handler.Handle(new DeleteSupergroupCommand(999), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"DeleteConfigurationCommandsTests.cs written: {len(content.splitlines())} lines")
print("Removed: DeleteRtsGridMetricCommandHandlerTests class")
print("Kept: DeleteBusinessUnitCommandHandlerTests, DeleteSupergroupCommandHandlerTests")
