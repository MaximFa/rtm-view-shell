using CcDashboard.Application.Reports.Commands;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Reports;

/// <summary>
/// Tests for CloneReportScreenCommand — deep copy screen + widgets.
/// Updated 2026-07-02: GetByIdWithWidgetsAsync signature (bool bypassTenantFilter, CancellationToken ct).
/// </summary>
public class CloneReportScreenCommandTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid PgId = Guid.NewGuid();
    private static readonly Guid SourceScreenId = Guid.NewGuid();

    private readonly IReportScreenRepository _repo = Substitute.For<IReportScreenRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();

    public CloneReportScreenCommandTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(UserId);
        _user.PermissionGroupId.Returns(PgId);
        _user.Role.Returns("Editor");
        _clock.UtcNow.Returns(new DateTime(2026, 6, 25, 12, 0, 0, DateTimeKind.Utc));
    }

    private ReportScreen CreateSourceScreen(bool withWidgets = true, bool withDeletedWidget = false)
    {
        var widgets = new List<ReportWidget>();
        if (withWidgets)
        {
            widgets.Add(new ReportWidget
            {
                Id = Guid.NewGuid(),
                ReportScreenId = SourceScreenId,
                TenantId = TenantId,
                WidgetType = ReportWidgetType.QueueInterval,
                PositionJson = """{"x":0,"y":0,"w":4,"h":3}""",
                ConfigJson = """{"scope":{"businessUnitIds":[1]},"columns":["Offered"],"pageSize":25}""",
                IsDeleted = false
            });
            widgets.Add(new ReportWidget
            {
                Id = Guid.NewGuid(),
                ReportScreenId = SourceScreenId,
                TenantId = TenantId,
                WidgetType = ReportWidgetType.AgentMonthly,
                PositionJson = """{"x":4,"y":0,"w":4,"h":3}""",
                ConfigJson = """{"scope":{"businessUnitIds":[1],"agentAxis":"detail"},"columns":["SumAvailableMs"],"pageSize":50}""",
                IsDeleted = false
            });
        }
        if (withDeletedWidget)
        {
            widgets.Add(new ReportWidget
            {
                Id = Guid.NewGuid(),
                ReportScreenId = SourceScreenId,
                TenantId = TenantId,
                WidgetType = ReportWidgetType.Distribution,
                IsDeleted = true // Should NOT be copied
            });
        }

        return new ReportScreen
        {
            Id = SourceScreenId,
            TenantId = TenantId,
            Name = "Original Report",
            Description = "Test description",
            CategoryId = Guid.NewGuid(),
            IsPublic = true,
            IsDarkMode = true,
            LayoutJson = """{"columns":12}""",
            Status = ReportScreenStatus.Published,
            CreatedByUserId = Guid.NewGuid(),
            UpdatedByUserId = Guid.NewGuid(),
            CreatedAt = _clock.UtcNow.AddDays(-10),
            UpdatedAt = _clock.UtcNow.AddDays(-1),
            Widgets = widgets
        };
    }

    [Fact]
    public async Task Clone_CopiesScreenFields_WithDraftStatus()
    {
        var source = CreateSourceScreen(withWidgets: false);
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);
        _repo.GetUserAccessLevelAsync(SourceScreenId, PgId, true, false, Arg.Any<CancellationToken>())
            .Returns(1); // View

        ReportScreen? captured = null;
        _repo.AddAsync(Arg.Do<ReportScreen>(s => captured = s), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        var result = await handler.Handle(cmd, CancellationToken.None);

        // New screen should have copied fields
        captured.Should().NotBeNull();
        captured!.Id.Should().NotBe(SourceScreenId);
        captured.Name.Should().EndWith("(copy)");
        captured.Description.Should().Be(source.Description);
        captured.CategoryId.Should().Be(source.CategoryId);
        captured.IsPublic.Should().Be(source.IsPublic);
        captured.IsDarkMode.Should().Be(source.IsDarkMode);
        captured.LayoutJson.Should().Be(source.LayoutJson);
        captured.Status.Should().Be(ReportScreenStatus.Draft); // Always Draft
        captured.CreatedByUserId.Should().Be(UserId);
        captured.UpdatedByUserId.Should().Be(UserId);
    }

    [Fact]
    public async Task Clone_CopiesNonDeletedWidgets_WithNewIds()
    {
        var source = CreateSourceScreen(withWidgets: true, withDeletedWidget: true);
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);
        _repo.GetUserAccessLevelAsync(SourceScreenId, PgId, true, false, Arg.Any<CancellationToken>())
            .Returns(1); // View

        var addedWidgets = new List<ReportWidget>();
        _repo.AddWidgetAsync(Arg.Do<ReportWidget>(w => addedWidgets.Add(w)), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        await handler.Handle(cmd, CancellationToken.None);

        // Should copy only non-deleted widgets (2, not 3)
        addedWidgets.Should().HaveCount(2);

        // Widgets should have new IDs but same config
        var sourceWidgetIds = source.Widgets.Where(w => !w.IsDeleted).Select(w => w.Id).ToHashSet();
        foreach (var widget in addedWidgets)
        {
            widget.Id.Should().NotBeEmpty();
            sourceWidgetIds.Should().NotContain(widget.Id);
            widget.IsDeleted.Should().BeFalse();
        }

        // Verify configs are preserved
        var sourceConfigs = source.Widgets.Where(w => !w.IsDeleted).Select(w => w.ConfigJson).ToHashSet();
        foreach (var widget in addedWidgets)
        {
            sourceConfigs.Should().Contain(widget.ConfigJson);
        }
    }

    [Fact]
    public async Task Clone_PG01_ClonerPgGetsFull()
    {
        var source = CreateSourceScreen(withWidgets: false);
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);
        _repo.GetUserAccessLevelAsync(SourceScreenId, PgId, true, false, Arg.Any<CancellationToken>())
            .Returns(1); // View

        ReportScreen? captured = null;
        _repo.AddAsync(Arg.Do<ReportScreen>(s => captured = s), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        var result = await handler.Handle(cmd, CancellationToken.None);

        captured.Should().NotBeNull();
        captured!.Permissions.Should().HaveCount(1);
        captured.Permissions.First().PermissionGroupId.Should().Be(PgId);
        captured.Permissions.First().AccessLevel.Should().Be(7); // Full
        result.AccessLevel.Should().Be(7);
    }

    [Fact]
    public async Task Clone_RequiresViewOnSource_DeniesWhenNoAccess()
    {
        var source = CreateSourceScreen(withWidgets: false);
        source.IsPublic = false; // Not public
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);
        _repo.GetUserAccessLevelAsync(SourceScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(0); // No access

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*View*");
    }

    [Fact]
    public async Task Clone_SuperadminCanCloneAny()
    {
        _user.Role.Returns("Superadmin");

        var source = CreateSourceScreen(withWidgets: false);
        source.IsPublic = false;
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);

        ReportScreen? captured = null;
        _repo.AddAsync(Arg.Do<ReportScreen>(s => captured = s), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        var result = await handler.Handle(cmd, CancellationToken.None);

        // Should succeed without permission check
        captured.Should().NotBeNull();
        await _repo.DidNotReceive().GetUserAccessLevelAsync(
            Arg.Any<Guid>(), Arg.Any<Guid?>(), Arg.Any<bool>(), Arg.Any<bool>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Clone_TenantIsolation_CannotCloneOtherTenantScreen()
    {
        var otherTenantId = Guid.NewGuid();
        var source = CreateSourceScreen(withWidgets: false);
        source.TenantId = otherTenantId; // Different tenant

        // GQF would normally filter this out, but simulating bypass
        _repo.GetByIdWithWidgetsAsync(SourceScreenId, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(source);

        var handler = new CloneReportScreenCommandHandler(_repo, _user, _clock);
        var cmd = new CloneReportScreenCommand(SourceScreenId);

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>();
    }
}
