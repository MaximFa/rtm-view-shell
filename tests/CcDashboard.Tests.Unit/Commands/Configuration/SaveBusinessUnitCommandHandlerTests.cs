using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class SaveBusinessUnitCommandHandlerTests
{
    private readonly INgcBusinessUnitRepository _repo = Substitute.For<INgcBusinessUnitRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveBusinessUnitCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 6, 1, 10, 0, 0, DateTimeKind.Utc);

    public SaveBusinessUnitCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserName.Returns("testuser");
        _clock.UtcNow.Returns(Now);
        _handler = new SaveBusinessUnitCommandHandler(_repo, _user, _clock, _apiHook);
    }

    [Fact]
    public async Task Handle_CreateNewBU_ReturnsNewId()
    {
        NgcBusinessUnit? saved = null;
        await _repo.AddAsync(Arg.Do<NgcBusinessUnit>(bu => saved = bu), Arg.Any<CancellationToken>());

        var req = new SaveBusinessUnitRequest(null, "Sales BU", "Sales dept", "SITE-1", ["Q1", "Q2"], [1, 2]);
        var result = await _handler.Handle(new SaveBusinessUnitCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.BusinessUnitName.Should().Be("Sales BU");
        saved.Description.Should().Be("Sales dept");
        saved.SiteId.Should().Be("SITE-1");
        saved.TenantId.Should().Be(TenantId);
        saved.CreatedDatetime.Should().Be(Now);
        saved.CreatedBy.Should().Be("testuser");
        saved.QueueAssignments.Should().HaveCount(2);
        saved.SupergroupAssignments.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_UpdateExistingBU_ReplacesAssignments()
    {
        var existing = new NgcBusinessUnit
        {
            BusinessUnitId = 42,
            TenantId = TenantId,
            BusinessUnitName = "Old Name"
        };
        existing.QueueAssignments.Add(new NgcBusinessUnitQueueClassification { QueueId = "OLD-Q" });
        existing.SupergroupAssignments.Add(new NgcBusinessUnitSupergroup { SupergroupId = 99 });
        _repo.GetByIdAsync(42, TenantId, Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveBusinessUnitRequest(42, "New Name", "New desc", "SITE-2", ["NEW-Q1"], [10, 20]);
        var result = await _handler.Handle(new SaveBusinessUnitCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().Be(42);
        existing.BusinessUnitName.Should().Be("New Name");
        existing.SiteId.Should().Be("SITE-2");
        existing.QueueAssignments.Should().HaveCount(1);
        existing.QueueAssignments.Should().Contain(q => q.QueueId == "NEW-Q1");
        existing.SupergroupAssignments.Should().HaveCount(2);
        _repo.Received(1).Update(existing);
    }

    [Fact]
    public async Task Handle_UpdateNonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync(999, TenantId, Arg.Any<CancellationToken>()).Returns((NgcBusinessUnit?)null);

        var req = new SaveBusinessUnitRequest(999, "Name", null, null, [], []);
        var result = await _handler.Handle(new SaveBusinessUnitCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_TrimsNameAndDescription()
    {
        NgcBusinessUnit? saved = null;
        await _repo.AddAsync(Arg.Do<NgcBusinessUnit>(bu => saved = bu), Arg.Any<CancellationToken>());

        var req = new SaveBusinessUnitRequest(null, "  Trimmed Name  ", "  Trimmed Desc  ", null, [], []);
        await _handler.Handle(new SaveBusinessUnitCommand(req), CancellationToken.None);

        saved!.BusinessUnitName.Should().Be("Trimmed Name");
        saved.Description.Should().Be("Trimmed Desc");
    }

    [Fact]
    public async Task Handle_NotifiesApiHook()
    {
        var req = new SaveBusinessUnitRequest(null, "BU", null, null, [], []);
        await _handler.Handle(new SaveBusinessUnitCommand(req), CancellationToken.None);

        await _apiHook.Received(1).NotifyAsync("BusinessUnit", Arg.Any<object>(), Arg.Any<CancellationToken>());
    }
}
