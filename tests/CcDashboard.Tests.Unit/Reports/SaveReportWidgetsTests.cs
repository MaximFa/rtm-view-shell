using CcDashboard.Application.Reports.Commands;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using DomainValidationException = CcDashboard.Domain.Exceptions.ValidationException;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Reports;

/// <summary>
/// Tests for SaveReportWidgetsCommand — Edit permission, ConfigJson validation, soft-remove dropped.
/// Updated 2026-07-02: GetByIdWithWidgetsAsync signature (bool bypassTenantFilter, CancellationToken ct).
/// </summary>
public class SaveReportWidgetsTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid PgId = Guid.NewGuid();
    private static readonly Guid ScreenId = Guid.NewGuid();

    private readonly IReportScreenRepository _repo = Substitute.For<IReportScreenRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();

    public SaveReportWidgetsTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(UserId);
        _user.PermissionGroupId.Returns(PgId);
        _user.Role.Returns("Editor");
        _clock.UtcNow.Returns(new DateTime(2026, 6, 24, 12, 0, 0, DateTimeKind.Utc));
    }

    [Fact]
    public async Task SaveWidgets_RequiresEditPermission()
    {
        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>()
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(1); // View only

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>());

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Edit*");
    }

    [Fact]
    public async Task SaveWidgets_ValidatesConfigJson()
    {
        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>()
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(3); // View + Edit

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
        {
            new(null, ReportWidgetType.EndOfShiftQueues, "{}", "{ invalid json }", false)
        });

        var act = () => handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<DomainValidationException>()
            .WithMessage("*ConfigJson*");
    }

    [Fact]
    public async Task SaveWidgets_ValidConfigJson_PassesValidation()
    {
        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>()
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(3);

        var validConfigJson = """
        {
            "scope": { "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 25
        }
        """;

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
        {
            new(null, ReportWidgetType.EndOfShiftQueues, "{}", validConfigJson, false)
        });

        var result = await handler.Handle(cmd, CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].WidgetType.Should().Be(ReportWidgetType.EndOfShiftQueues);
    }

    [Fact]
    public async Task SaveWidgets_SoftDeletesDroppedWidgets()
    {
        var existingWidget = new ReportWidget
        {
            Id = Guid.NewGuid(),
            ReportScreenId = ScreenId,
            TenantId = TenantId,
            WidgetType = ReportWidgetType.QueueInterval,
            IsDeleted = false
        };
        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget> { existingWidget },
            UpdatedByUserId = UserId,
            UpdatedAt = _clock.UtcNow.AddDays(-1)
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(7);

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        // Empty widgets list = drop the existing widget
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>());

        await handler.Handle(cmd, CancellationToken.None);

        existingWidget.IsDeleted.Should().BeTrue();
        _repo.Received().UpdateWidget(existingWidget);
    }

    [Fact]
    public async Task SaveWidgets_UpdatesExistingWidgets()
    {
        var existingWidget = new ReportWidget
        {
            Id = Guid.NewGuid(),
            ReportScreenId = ScreenId,
            TenantId = TenantId,
            WidgetType = ReportWidgetType.EndOfShiftAgents,
            PositionJson = "{}",
            ConfigJson = "{}",
            IsDeleted = false
        };
        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget> { existingWidget },
            UpdatedByUserId = UserId,
            UpdatedAt = _clock.UtcNow.AddDays(-1)
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>())
            .Returns(7);

        var newPositionJson = """{"x":10,"y":20}""";

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
        {
            new(existingWidget.Id, ReportWidgetType.EndOfShiftQueues, newPositionJson, null, false)
        });

        var result = await handler.Handle(cmd, CancellationToken.None);

        result.Should().HaveCount(1);
        existingWidget.WidgetType.Should().Be(ReportWidgetType.EndOfShiftQueues);
        existingWidget.PositionJson.Should().Be(newPositionJson);
    }

    [Fact]
    public async Task SaveWidgets_Superadmin_BypassesPermission()
    {
        _user.Role.Returns("Superadmin");

        var screen = new ReportScreen
        {
            Id = ScreenId,
            TenantId = TenantId,
            Name = "Test",
            IsPublic = false,
            Widgets = new List<ReportWidget>(),
            UpdatedByUserId = UserId,
            UpdatedAt = _clock.UtcNow.AddDays(-1)
        };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);

        var handler = new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
        var cmd = new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>());

        await handler.Handle(cmd, CancellationToken.None);

        // No permission check expected
        await _repo.DidNotReceive().GetUserAccessLevelAsync(Arg.Any<Guid>(), Arg.Any<Guid?>(), Arg.Any<bool>(), Arg.Any<bool>(), Arg.Any<CancellationToken>());
    }

    // FEAT-REPORT-EOS-CONFIGURABLE-01: retired report types cannot be added to a screen or switched to.
    private SaveReportWidgetsCommandHandler RetiredScreen(params ReportWidget[] existing)
    {
        var screen = new ReportScreen { Id = ScreenId, TenantId = TenantId, Name = "Test", IsPublic = false,
            Widgets = existing.ToList(), UpdatedByUserId = UserId, UpdatedAt = _clock.UtcNow.AddDays(-1) };
        _repo.GetByIdWithWidgetsAsync(ScreenId, It.IsAny<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        _repo.GetUserAccessLevelAsync(ScreenId, PgId, false, false, Arg.Any<CancellationToken>()).Returns(7);
        return new SaveReportWidgetsCommandHandler(_repo, _user, _clock);
    }

    [Theory]
    [InlineData(ReportWidgetType.QueueInterval)]
    [InlineData(ReportWidgetType.QueueWaitTime)]
    [InlineData(ReportWidgetType.Distribution)]
    public async Task SaveWidgets_NewRetiredWidget_IsRefused(ReportWidgetType retired)
    {
        var handler = RetiredScreen();
        var act = () => handler.Handle(new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
            { new(null, retired, "{}", null, false) }), CancellationToken.None);

        await act.Should().ThrowAsync<DomainValidationException>().WithMessage("*retired*");
        await _repo.DidNotReceiveWithAnyArgs().AddWidgetAsync(default!, default);
    }

    [Fact]
    public async Task SaveWidgets_SwitchingExistingWidgetToRetiredType_IsRefused()
    {
        var w = new ReportWidget { Id = Guid.NewGuid(), ReportScreenId = ScreenId, TenantId = TenantId,
            WidgetType = ReportWidgetType.EndOfShiftQueues, PositionJson = "{}", ConfigJson = "{}" };
        var handler = RetiredScreen(w);
        var act = () => handler.Handle(new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
            { new(w.Id, ReportWidgetType.QueueInterval, "{}", null, false) }), CancellationToken.None);

        await act.Should().ThrowAsync<DomainValidationException>().WithMessage("*retired*");
        w.WidgetType.Should().Be(ReportWidgetType.EndOfShiftQueues);
    }

    [Fact]
    public async Task SaveWidgets_ExistingRetiredWidgetKeptAsIs_IsAllowed()
    {
        // Negative half: a screen that already holds a retired widget can still be saved (it shows "retired").
        var w = new ReportWidget { Id = Guid.NewGuid(), ReportScreenId = ScreenId, TenantId = TenantId,
            WidgetType = ReportWidgetType.Distribution, PositionJson = "{}", ConfigJson = "{}" };
        var handler = RetiredScreen(w);
        var result = await handler.Handle(new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
            { new(w.Id, ReportWidgetType.Distribution, """{"x":1}""", null, false) }), CancellationToken.None);

        result.Should().HaveCount(1);
        w.PositionJson.Should().Be("""{"x":1}""");
    }

    [Fact]
    public async Task SaveWidgets_DefaultStep_IsKeptOnTheQueuesReport_AndRefusedOnAnother()
    {
        const string cfg = """{ "scope": { "businessUnitIds": [1] }, "defaultStep": "month" }""";
        var handler = RetiredScreen();
        var saved = await handler.Handle(new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
            { new(null, ReportWidgetType.EndOfShiftQueues, "{}", cfg, false) }), CancellationToken.None);
        saved.Should().HaveCount(1);
        await _repo.Received(1).AddWidgetAsync(Arg.Is<ReportWidget>(w => w.ConfigJson == cfg), Arg.Any<CancellationToken>());

        var refused = () => RetiredScreen().Handle(new SaveReportWidgetsCommand(ScreenId, new List<SaveReportWidgetRequest>
            { new(null, ReportWidgetType.AgentPerformance, "{}", """{ "scope": { "businessUnitIds": [1] }, "mode": "summary", "defaultStep": "month" }""", false) }),
            CancellationToken.None);
        await refused.Should().ThrowAsync<DomainValidationException>().WithMessage("*default interval step*");
    }
}

// NSubstitute helper for It.IsAny<T>() pattern (Moq-style)
internal static class It
{
    public static T IsAny<T>() => Arg.Any<T>();
}
