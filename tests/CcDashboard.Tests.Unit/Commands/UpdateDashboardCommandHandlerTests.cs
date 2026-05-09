using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class UpdateDashboardCommandHandlerTests
{
    private readonly IDashboardRepository _repo = Substitute.For<IDashboardRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly UpdateDashboardCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 1, 15, 10, 30, 0, DateTimeKind.Utc);

    public UpdateDashboardCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _clock.UtcNow.Returns(Now);
        _handler = new UpdateDashboardCommandHandler(_repo, _user, _clock);
    }

    [Fact]
    public async Task Handle_ExistingDashboard_UpdatesAllFields()
    {
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Old Name",
            Description = "Old desc",
            Status = DashboardStatus.Draft,
            IsPublic = false,
            CreatedAt = Now.AddDays(-10),
            UpdatedAt = Now.AddDays(-5)
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        var req = new UpdateDashboardRequest(id, "New Name", "New desc", DashboardStatus.Published, true, 0);
        var result = await _handler.Handle(new UpdateDashboardCommand(req), CancellationToken.None);

        result.Name.Should().Be("New Name");
        result.Description.Should().Be("New desc");
        result.Status.Should().Be(DashboardStatus.Published);
        result.IsPublic.Should().BeTrue();
        result.UpdatedAt.Should().Be(Now);
        dashboard.UpdatedByUserId.Should().Be(UserId);
        _repo.Received(1).Update(dashboard);
    }

    [Fact]
    public async Task Handle_TrimsWhitespace()
    {
        var id = Guid.NewGuid();
        var dashboard = new Dashboard { Id = id, TenantId = TenantId, Name = "X" };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        var req = new UpdateDashboardRequest(id, "  Trimmed Name  ", "  Trimmed Desc  ", DashboardStatus.Draft, false, 0);
        await _handler.Handle(new UpdateDashboardCommand(req), CancellationToken.None);

        dashboard.Name.Should().Be("Trimmed Name");
        dashboard.Description.Should().Be("Trimmed Desc");
    }

    [Fact]
    public async Task Handle_DashboardNotFound_ThrowsNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Dashboard?)null);

        var req = new UpdateDashboardRequest(id, "Name", null, DashboardStatus.Draft, false, 0);
        var act = () => _handler.Handle(new UpdateDashboardCommand(req), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*Dashboard*");
    }

    [Fact]
    public async Task Handle_NullDescription_SetsNull()
    {
        var id = Guid.NewGuid();
        var dashboard = new Dashboard { Id = id, TenantId = TenantId, Name = "X", Description = "Has desc" };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        var req = new UpdateDashboardRequest(id, "Name", null, DashboardStatus.Draft, false, 0);
        var result = await _handler.Handle(new UpdateDashboardCommand(req), CancellationToken.None);

        result.Description.Should().BeNull();
    }
}
