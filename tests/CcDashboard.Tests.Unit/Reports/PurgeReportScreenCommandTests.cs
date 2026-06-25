using CcDashboard.Application.Reports.Commands;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Reports;

/// <summary>
/// Tests for PurgeReportScreenCommand — permanent deletion of soft-deleted (Trash) screens.
/// </summary>
public class PurgeReportScreenCommandTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid PgId = Guid.NewGuid();

    private readonly IReportScreenRepository _repo = Substitute.For<IReportScreenRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();

    public PurgeReportScreenCommandTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(UserId);
        _user.PermissionGroupId.Returns(PgId);
        _user.Role.Returns("Editor");
    }

    [Fact]
    public async Task Purge_SoftDeletedScreen_RemovesAllEntities()
    {
        var screenId = Guid.NewGuid();
        var widgets = new List<ReportWidget>
        {
            new() { Id = Guid.NewGuid(), ReportScreenId = screenId, TenantId = TenantId, IsDeleted = true },
            new() { Id = Guid.NewGuid(), ReportScreenId = screenId, TenantId = TenantId, IsDeleted = true }
        };
        var permissions = new List<ReportPermission>
        {
            new() { PermissionGroupId = PgId, ReportScreenId = screenId, TenantId = TenantId, AccessLevel = 7 }
        };
        var schedules = new List<ReportSchedule>
        {
            new() { Id = Guid.NewGuid(), ReportScreenId = screenId, TenantId = TenantId, IsActive = false }
        };
        var screen = new ReportScreen
        {
            Id = screenId,
            TenantId = TenantId,
            Name = "Deleted Report",
            IsDeleted = true,
            DeletedAt = DateTime.UtcNow.AddDays(-1),
            IsPublic = false,
            Widgets = widgets,
            Permissions = permissions,
            Schedules = schedules
        };

        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screenId, PgId, false, false, Arg.Any<CancellationToken>()).Returns(7);

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        await handler.Handle(cmd, CancellationToken.None);

        await _repo.Received(1).PurgeAsync(screen, Arg.Any<CancellationToken>());
        cmd.AuditDetails.Should().BeEquivalentTo(new
        {
            Id = screenId,
            Name = "Deleted Report",
            WidgetCount = 2,
            ScheduleCount = 1,
            PermissionCount = 1
        });
    }

    [Fact]
    public async Task Purge_LiveScreen_Rejected()
    {
        var screenId = Guid.NewGuid();
        var screen = new ReportScreen
        {
            Id = screenId,
            TenantId = TenantId,
            Name = "Live Report",
            IsDeleted = false,
            IsPublic = false,
            Widgets = new List<ReportWidget>(),
            Permissions = new List<ReportPermission>(),
            Schedules = new List<ReportSchedule>()
        };

        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>()).Returns(screen);

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*soft-delete*");
        await _repo.DidNotReceive().PurgeAsync(Arg.Any<ReportScreen>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Purge_WithoutDeletePermission_Forbidden()
    {
        var screenId = Guid.NewGuid();
        var screen = new ReportScreen
        {
            Id = screenId,
            TenantId = TenantId,
            Name = "Deleted Report",
            IsDeleted = true,
            IsPublic = false,
            Widgets = new List<ReportWidget>(),
            Permissions = new List<ReportPermission>(),
            Schedules = new List<ReportSchedule>()
        };

        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(3); // View + Edit, but not Delete

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Delete*");
        await _repo.DidNotReceive().PurgeAsync(Arg.Any<ReportScreen>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Purge_Superadmin_BypassesPermissionCheck()
    {
        _user.Role.Returns("Superadmin");
        _user.PermissionGroupId.Returns((Guid?)null);

        var screenId = Guid.NewGuid();
        var screen = new ReportScreen
        {
            Id = screenId,
            TenantId = TenantId,
            Name = "Deleted Report",
            IsDeleted = true,
            IsPublic = false,
            Widgets = new List<ReportWidget>(),
            Permissions = new List<ReportPermission>(),
            Schedules = new List<ReportSchedule>()
        };

        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>()).Returns(screen);

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        await handler.Handle(cmd, CancellationToken.None);

        await _repo.Received(1).PurgeAsync(screen, Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().GetUserAccessLevelAsync(
            Arg.Any<Guid>(), Arg.Any<Guid?>(), Arg.Any<bool>(), Arg.Any<bool>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Purge_AnotherTenantScreen_NotFound()
    {
        var screenId = Guid.NewGuid();
        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>())
            .Returns((ReportScreen?)null);

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    public async Task Purge_AuditEvent_CapturesCounts()
    {
        var screenId = Guid.NewGuid();
        var screen = new ReportScreen
        {
            Id = screenId,
            TenantId = TenantId,
            Name = "Report With Data",
            IsDeleted = true,
            IsPublic = false,
            Widgets = new List<ReportWidget>
            {
                new() { Id = Guid.NewGuid(), TenantId = TenantId },
                new() { Id = Guid.NewGuid(), TenantId = TenantId },
                new() { Id = Guid.NewGuid(), TenantId = TenantId }
            },
            Permissions = new List<ReportPermission>
            {
                new() { PermissionGroupId = Guid.NewGuid(), TenantId = TenantId, AccessLevel = 7 },
                new() { PermissionGroupId = Guid.NewGuid(), TenantId = TenantId, AccessLevel = 1 }
            },
            Schedules = new List<ReportSchedule>
            {
                new() { Id = Guid.NewGuid(), TenantId = TenantId },
                new() { Id = Guid.NewGuid(), TenantId = TenantId },
                new() { Id = Guid.NewGuid(), TenantId = TenantId },
                new() { Id = Guid.NewGuid(), TenantId = TenantId }
            }
        };

        _repo.GetByIdForPurgeAsync(screenId, TenantId, Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(screenId, PgId, false, false, Arg.Any<CancellationToken>()).Returns(7);

        var handler = new PurgeReportScreenCommandHandler(_repo, _user);
        var cmd = new PurgeReportScreenCommand(screenId);

        await handler.Handle(cmd, CancellationToken.None);

        cmd.AuditEventType.Should().Be("ReportScreen.PermanentlyDeleted");
        cmd.AuditDetails.Should().BeEquivalentTo(new
        {
            Id = screenId,
            Name = "Report With Data",
            WidgetCount = 3,
            ScheduleCount = 4,
            PermissionCount = 2
        });
    }
}
