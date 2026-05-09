using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class SaveSupergroupCommandHandlerTests
{
    private readonly INgcSupergroupRepository _repo = Substitute.For<INgcSupergroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveSupergroupCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 7, 1, 11, 0, 0, DateTimeKind.Utc);

    public SaveSupergroupCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserName.Returns("admin");
        _clock.UtcNow.Returns(Now);
        _handler = new SaveSupergroupCommandHandler(_repo, _user, _clock, _apiHook);
    }

    [Fact]
    public async Task Handle_CreateNewSupergroup_ReturnsNewId()
    {
        NgcSupergroup? saved = null;
        await _repo.AddAsync(Arg.Do<NgcSupergroup>(sg => saved = sg), Arg.Any<CancellationToken>());

        var req = new SaveSupergroupRequest(null, "Support Team", "Support agents", ["AG-1", "AG-2", "AG-3"]);
        var result = await _handler.Handle(new SaveSupergroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.SupergroupName.Should().Be("Support Team");
        saved.Description.Should().Be("Support agents");
        saved.TenantId.Should().Be(TenantId);
        saved.CreatedDatetime.Should().Be(Now);
        saved.CreatedBy.Should().Be("admin");
        saved.AgentGroupAssignments.Should().HaveCount(3);
    }

    [Fact]
    public async Task Handle_UpdateExisting_ReplacesAgentGroups()
    {
        var existing = new NgcSupergroup
        {
            SupergroupId = 100,
            TenantId = TenantId,
            SupergroupName = "Old Name"
        };
        existing.AgentGroupAssignments.Add(new NgcSupergroupAgentgroup { AgentgroupId = "OLD-AG" });
        _repo.GetByIdAsync(100, TenantId, Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveSupergroupRequest(100, "New Name", "New desc", ["NEW-AG-1", "NEW-AG-2"]);
        var result = await _handler.Handle(new SaveSupergroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().Be(100);
        existing.SupergroupName.Should().Be("New Name");
        existing.Description.Should().Be("New desc");
        existing.AgentGroupAssignments.Should().HaveCount(2);
        existing.AgentGroupAssignments.Should().NotContain(a => a.AgentgroupId == "OLD-AG");
        _repo.Received(1).Update(existing);
    }

    [Fact]
    public async Task Handle_UpdateNonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync(888, TenantId, Arg.Any<CancellationToken>()).Returns((NgcSupergroup?)null);

        var req = new SaveSupergroupRequest(888, "Name", null, []);
        var result = await _handler.Handle(new SaveSupergroupCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_EmptyAgentGroups_ClearsCollection()
    {
        var existing = new NgcSupergroup { SupergroupId = 50, TenantId = TenantId, SupergroupName = "SG" };
        existing.AgentGroupAssignments.Add(new NgcSupergroupAgentgroup { AgentgroupId = "AG-1" });
        existing.AgentGroupAssignments.Add(new NgcSupergroupAgentgroup { AgentgroupId = "AG-2" });
        _repo.GetByIdAsync(50, TenantId, Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveSupergroupRequest(50, "SG", null, []);
        await _handler.Handle(new SaveSupergroupCommand(req), CancellationToken.None);

        existing.AgentGroupAssignments.Should().BeEmpty();
    }

    [Fact]
    public async Task Handle_NotifiesApiHook()
    {
        var req = new SaveSupergroupRequest(null, "SG", null, []);
        await _handler.Handle(new SaveSupergroupCommand(req), CancellationToken.None);

        await _apiHook.Received(1).NotifyAsync("Supergroup", Arg.Any<object>(), Arg.Any<CancellationToken>());
    }
}
