using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

/// <summary>
/// Regression tests for Defect K: NGC config handlers must flush BackendEmulationDbContext.
/// Verifies that SaveChangesAsync is called after Add/Update/Delete operations.
/// </summary>
public class SaveSupergroupPersistTests
{
    private readonly INgcSupergroupRepository _repo = Substitute.For<INgcSupergroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();

    public SaveSupergroupPersistTests()
    {
        _user.TenantId.Returns(Guid.NewGuid());
        _user.UserName.Returns("testuser");
        _clock.UtcNow.Returns(DateTime.UtcNow);
    }

    [Fact]
    public async Task SaveSupergroupCommand_NewSupergroup_CallsSaveChangesAsync()
    {
        // Arrange
        var handler = new SaveSupergroupCommandHandler(_repo, _user, _clock, _apiHook);
        var request = new SaveSupergroupRequest(
            SupergroupId: null,
            SupergroupName: "Test Supergroup",
            Description: null,
            AgentGroupIds: []);
        var command = new SaveSupergroupCommand(request);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        await _repo.Received(1).AddAsync(Arg.Any<NgcSupergroup>(), Arg.Any<CancellationToken>());
        await _repo.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SaveSupergroupCommand_ExistingSupergroup_CallsSaveChangesAsync()
    {
        // Arrange
        var tenantId = _user.TenantId!.Value;
        var existingSg = new NgcSupergroup
        {
            SupergroupId = 42,
            TenantId = tenantId,
            SupergroupName = "Existing",
            AgentGroupAssignments = []
        };
        _repo.GetByIdAsync(42, tenantId, Arg.Any<CancellationToken>()).Returns(existingSg);

        var handler = new SaveSupergroupCommandHandler(_repo, _user, _clock, _apiHook);
        var request = new SaveSupergroupRequest(
            SupergroupId: 42,
            SupergroupName: "Updated Supergroup",
            Description: null,
            AgentGroupIds: []);
        var command = new SaveSupergroupCommand(request);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Update(Arg.Any<NgcSupergroup>());
        await _repo.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task DeleteSupergroupCommand_CallsSaveChangesAsync()
    {
        // Arrange
        var tenantId = _user.TenantId!.Value;
        var existingSg = new NgcSupergroup
        {
            SupergroupId = 99,
            TenantId = tenantId,
            SupergroupName = "ToDelete"
        };
        _repo.GetByIdAsync(99, tenantId, Arg.Any<CancellationToken>()).Returns(existingSg);

        var handler = new DeleteSupergroupCommandHandler(_repo, _user);
        var command = new DeleteSupergroupCommand(99);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Delete(existingSg);
        await _repo.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }
}
