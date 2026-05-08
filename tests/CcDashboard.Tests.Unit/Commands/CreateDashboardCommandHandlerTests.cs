using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class CreateDashboardCommandHandlerTests
{
    private readonly IDashboardRepository _dashboards = Substitute.For<IDashboardRepository>();
    private readonly IPermissionGroupRepository _pgRepo = Substitute.For<IPermissionGroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly CreateDashboardCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid PgId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public CreateDashboardCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _user.PermissionGroupId.Returns(PgId);
        _clock.UtcNow.Returns(Now);
        _handler = new CreateDashboardCommandHandler(_dashboards, _user, _clock);
    }

    [Fact]
    public async Task Handle_WithPermissionGroup_CreatesWithFullAccess()
    {
        var req = new CreateDashboardRequest("My Dashboard", "desc", false);
        Dashboard? saved = null;
        await _dashboards.AddAsync(Arg.Do<Dashboard>(d => saved = d), Arg.Any<CancellationToken>());

        var result = await _handler.Handle(new CreateDashboardCommand(req), CancellationToken.None);

        result.Should().NotBeNull();
        result.Name.Should().Be("My Dashboard");
        result.TenantId.Should().Be(TenantId);
        saved.Should().NotBeNull();

        // [PG-01] creator's PG gets Full access (mask 7)
        saved!.Permissions.Should().ContainSingle(p =>
            p.PermissionGroupId == PgId &&
            p.AccessLevel == 7 &&
            p.DashboardId == saved.Id);
    }

    [Fact]
    public async Task Handle_WithoutPermissionGroup_NoPgPermissionAdded()
    {
        _user.PermissionGroupId.Returns((Guid?)null);
        var req = new CreateDashboardRequest("Public Screen", null, true);

        var result = await _handler.Handle(new CreateDashboardCommand(req), CancellationToken.None);

        result.IsPublic.Should().BeTrue();
        // AddAsync was still called — verify via received calls
        await _dashboards.Received(1).AddAsync(
            Arg.Is<Dashboard>(d => d.Permissions.Count == 0),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_SetsTimestampsAndOwnership()
    {
        var req = new CreateDashboardRequest("Dashboard", null, false);

        var result = await _handler.Handle(new CreateDashboardCommand(req), CancellationToken.None);

        result.CreatedAt.Should().Be(Now);
        result.UpdatedAt.Should().Be(Now);
        result.CreatedByUserId.Should().Be(UserId);
    }
}
