using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class DeleteDashboardCommandHandlerTests
{
    private readonly IDashboardRepository _repo = Substitute.For<IDashboardRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly DeleteDashboardCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 2, 1, 12, 0, 0, DateTimeKind.Utc);

    public DeleteDashboardCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _clock.UtcNow.Returns(Now);
        _handler = new DeleteDashboardCommandHandler(_repo, _user, _clock);
    }

    [Fact]
    public async Task Handle_ExistingDashboard_SoftDeletes()
    {
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "To Delete",
            IsDeleted = false
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        await _handler.Handle(new DeleteDashboardCommand(id), CancellationToken.None);

        dashboard.IsDeleted.Should().BeTrue();
        dashboard.DeletedAt.Should().Be(Now);
        dashboard.DeletedByUserId.Should().Be(UserId);
        _repo.Received(1).Update(dashboard);
    }

    [Fact]
    public async Task Handle_DashboardNotFound_ThrowsNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Dashboard?)null);

        var act = () => _handler.Handle(new DeleteDashboardCommand(id), CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*Dashboard*");
    }

    [Fact]
    public async Task Handle_AlreadyDeleted_StillProcesses()
    {
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Already Deleted",
            IsDeleted = true,
            DeletedAt = Now.AddDays(-1)
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        await _handler.Handle(new DeleteDashboardCommand(id), CancellationToken.None);

        dashboard.DeletedAt.Should().Be(Now);
        dashboard.DeletedByUserId.Should().Be(UserId);
    }
}
