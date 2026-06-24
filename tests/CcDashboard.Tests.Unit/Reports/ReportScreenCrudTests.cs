using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.Commands;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Application.Reports.Queries;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Reports;

/// <summary>
/// Tests for ReportScreen CRUD operations — permissions, PG-01 creator-Full, PG-scoped queries.
/// </summary>
public class ReportScreenCrudTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid PgId = Guid.NewGuid();

    private readonly IReportScreenRepository _repo = Substitute.For<IReportScreenRepository>();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();

    public ReportScreenCrudTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(UserId);
        _user.PermissionGroupId.Returns(PgId);
        _user.Role.Returns("Editor");
        _clock.UtcNow.Returns(new DateTime(2026, 6, 24, 12, 0, 0, DateTimeKind.Utc));
    }

    #region Create

    [Fact]
    public async Task Create_SetsCreatorPgFull_PG01()
    {
        ReportScreen? captured = null;
        _repo.AddAsync(Arg.Do<ReportScreen>(s => captured = s), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CreateReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CreateReportScreenCommand(new CreateReportScreenRequest("Test Screen"));

        var result = await handler.Handle(cmd, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.Permissions.Should().HaveCount(1);
        captured.Permissions.First().PermissionGroupId.Should().Be(PgId);
        captured.Permissions.First().AccessLevel.Should().Be(7); // Full
        result.AccessLevel.Should().Be(7);
    }

    [Fact]
    public async Task Create_Superadmin_NoPg_NoPermissionCreated()
    {
        _user.Role.Returns("Superadmin");
        _user.PermissionGroupId.Returns((Guid?)null);

        ReportScreen? captured = null;
        _repo.AddAsync(Arg.Do<ReportScreen>(s => captured = s), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CreateReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CreateReportScreenCommand(new CreateReportScreenRequest("Test Screen"));

        await handler.Handle(cmd, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.Permissions.Should().BeEmpty();
    }

    #endregion

    #region Update

    [Fact]
    public async Task Update_RequiresEditPermission()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Old Name",
            IsPublic = false
        };
        _repo.GetByIdAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(1); // View only

        var handler = new UpdateReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new UpdateReportScreenCommand(new UpdateReportScreenRequest(
            screen.Id, "New Name", null, null, ReportScreenStatus.Published, false, false, null, 0));

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Edit*");
    }

    [Fact]
    public async Task Update_WithEditPermission_Succeeds()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Old Name",
            IsPublic = false,
            CreatedByUserId = UserId,
            UpdatedByUserId = UserId,
            CreatedAt = _clock.UtcNow.AddDays(-1),
            UpdatedAt = _clock.UtcNow.AddDays(-1)
        };
        _repo.GetByIdAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(3); // View + Edit

        var handler = new UpdateReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new UpdateReportScreenCommand(new UpdateReportScreenRequest(
            screen.Id, "New Name", null, null, ReportScreenStatus.Published, false, false, null, 0));

        var result = await handler.Handle(cmd, CancellationToken.None);

        result.Name.Should().Be("New Name");
        screen.Name.Should().Be("New Name");
        screen.Status.Should().Be(ReportScreenStatus.Published);
    }

    [Fact]
    public async Task Update_Superadmin_BypassesPermissionCheck()
    {
        _user.Role.Returns("Superadmin");

        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Old Name",
            IsPublic = false,
            CreatedByUserId = UserId,
            UpdatedByUserId = UserId,
            CreatedAt = _clock.UtcNow.AddDays(-1),
            UpdatedAt = _clock.UtcNow.AddDays(-1)
        };
        _repo.GetByIdAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);

        var handler = new UpdateReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new UpdateReportScreenCommand(new UpdateReportScreenRequest(
            screen.Id, "New Name", null, null, ReportScreenStatus.Published, false, false, null, 0));

        var result = await handler.Handle(cmd, CancellationToken.None);

        result.Name.Should().Be("New Name");
        // No GetUserAccessLevelAsync call expected
        await _repo.DidNotReceive().GetUserAccessLevelAsync(Arg.Any<Guid>(), Arg.Any<Guid?>(), Arg.Any<bool>(), Arg.Any<bool>(), Arg.Any<CancellationToken>());
    }

    #endregion

    #region Delete

    [Fact]
    public async Task Delete_RequiresDeletePermission()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>()
        };
        _repo.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(3); // View + Edit, but not Delete

        var handler = new DeleteReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new DeleteReportScreenCommand(screen.Id);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Delete*");
    }

    [Fact]
    public async Task Delete_SoftDeletesScreen()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>
            {
                new() { Id = Guid.NewGuid(), TenantId = TenantId, IsDeleted = false }
            }
        };
        _repo.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(7); // Full

        var handler = new DeleteReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new DeleteReportScreenCommand(screen.Id);

        await handler.Handle(cmd, CancellationToken.None);

        screen.IsDeleted.Should().BeTrue();
        screen.DeletedAt.Should().Be(_clock.UtcNow);
        screen.DeletedByUserId.Should().Be(UserId);
        screen.Widgets.All(w => w.IsDeleted).Should().BeTrue();
    }

    #endregion

    #region Get (View permission)

    [Fact]
    public async Task Get_RequiresViewPermission()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            CreatedByUserId = UserId,
            UpdatedByUserId = UserId,
            Widgets = new List<ReportWidget>(),
            Permissions = new List<ReportPermission>()
        };
        _repo.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(0); // No access

        var handler = new GetReportScreenQueryHandler(_repo, _users, _user);
        var query = new GetReportScreenQuery(screen.Id);

        var act = () => handler.Handle(query, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*View*");
    }

    [Fact]
    public async Task Get_PublicScreen_NoExplicitPerm_ViewAllowed()
    {
        var screen = new ReportScreen
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            Name = "Test",
            IsPublic = true,
            CreatedByUserId = UserId,
            UpdatedByUserId = UserId,
            Widgets = new List<ReportWidget>(),
            Permissions = new List<ReportPermission>()
        };
        _repo.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screen.Id, PgId, true, false, Arg.Any<CancellationToken>())
            .Returns(1); // View via IsPublic

        var handler = new GetReportScreenQueryHandler(_repo, _users, _user);
        var query = new GetReportScreenQuery(screen.Id);

        var result = await handler.Handle(query, CancellationToken.None);

        result.Should().NotBeNull();
        result.AccessLevel.Should().Be(1);
    }

    #endregion

    #region GQF tenant isolation

    [Fact]
    public async Task Get_NotFound_ThrowsNotFoundException()
    {
        _repo.GetByIdWithWidgetsAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>())
            .Returns((ReportScreen?)null);

        var handler = new GetReportScreenQueryHandler(_repo, _users, _user);
        var query = new GetReportScreenQuery(Guid.NewGuid());

        var act = () => handler.Handle(query, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    #endregion
}
