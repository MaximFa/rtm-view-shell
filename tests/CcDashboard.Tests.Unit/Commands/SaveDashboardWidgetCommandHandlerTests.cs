using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class SaveDashboardWidgetCommandHandlerTests
{
    private readonly IDashboardRepository _repo = Substitute.For<IDashboardRepository>();
    private readonly IUnitOfWork _uow = Substitute.For<IUnitOfWork>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly SaveDashboardWidgetCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Now = new(2026, 5, 14, 10, 30, 0, DateTimeKind.Utc);

    public SaveDashboardWidgetCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Administrator");
        _clock.UtcNow.Returns(Now);
        _handler = new SaveDashboardWidgetCommandHandler(_repo, _uow, _user, _clock);
    }

    [Fact]
    public async Task Handle_NewWidget_WithoutPreassignedGridId_CreatesWidget()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var catalogItemId = Guid.NewGuid();

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = TenantId,
            Name = "Test Dashboard",
            Widgets = new List<DashboardWidget>()
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, 0, dashboardId, catalogItemId,
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto);
        var result = await _handler.Handle(cmd, CancellationToken.None);

        dashboard.Widgets.Should().HaveCount(1);
        var widget = dashboard.Widgets.First();
        widget.Id.Should().Be(widgetId);
        widget.WidgetCatalogItemId.Should().Be(catalogItemId);
        widget.TenantId.Should().Be(TenantId);
        dashboard.UpdatedAt.Should().Be(Now);
        dashboard.UpdatedByUserId.Should().Be(UserId);
        _repo.Received(1).Update(dashboard);
        await _uow.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_NewWidget_WithPreassignedGridId_UsesPreassignedId()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var catalogItemId = Guid.NewGuid();
        const int preassignedGridId = 42;

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = TenantId,
            Name = "Test Dashboard",
            Widgets = new List<DashboardWidget>()
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, 0, dashboardId, catalogItemId,
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto, preassignedGridId);
        var result = await _handler.Handle(cmd, CancellationToken.None);

        dashboard.Widgets.Should().HaveCount(1);
        var widget = dashboard.Widgets.First();
        widget.GridId.Should().Be(preassignedGridId);
    }

    [Fact]
    public async Task Handle_ExistingWidget_WithoutPreassignedGridId_KeepsOriginalGridId()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var catalogItemId = Guid.NewGuid();
        const int originalGridId = 7;

        var existingWidget = new DashboardWidget
        {
            Id = widgetId,
            GridId = originalGridId,
            DashboardId = dashboardId,
            TenantId = TenantId,
            WidgetCatalogItemId = catalogItemId,
            PositionJson = "{}",
            ConfigJson = "{}"
        };

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = TenantId,
            Name = "Test Dashboard",
            Widgets = new List<DashboardWidget> { existingWidget }
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, originalGridId, dashboardId, catalogItemId,
            "{\"x\":1}", "{\"title\":\"Test\"}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto);
        var result = await _handler.Handle(cmd, CancellationToken.None);

        result.Should().Be(originalGridId);
        existingWidget.GridId.Should().Be(originalGridId);
        existingWidget.PositionJson.Should().Be("{\"x\":1}");
        existingWidget.ConfigJson.Should().Be("{\"title\":\"Test\"}");
    }

    [Fact]
    public async Task Handle_ExistingWidget_WithPreassignedGridId_UpdatesGridId()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var catalogItemId = Guid.NewGuid();
        const int originalGridId = 0;
        const int newGridId = 15;

        var existingWidget = new DashboardWidget
        {
            Id = widgetId,
            GridId = originalGridId,
            DashboardId = dashboardId,
            TenantId = TenantId,
            WidgetCatalogItemId = catalogItemId,
            PositionJson = "{}",
            ConfigJson = "{}"
        };

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = TenantId,
            Name = "Test Dashboard",
            Widgets = new List<DashboardWidget> { existingWidget }
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, originalGridId, dashboardId, catalogItemId,
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto, newGridId);
        var result = await _handler.Handle(cmd, CancellationToken.None);

        result.Should().Be(newGridId);
        existingWidget.GridId.Should().Be(newGridId);
    }

    [Fact]
    public async Task Handle_ExistingWidget_WithZeroPreassignedGridId_KeepsOriginalGridId()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var catalogItemId = Guid.NewGuid();
        const int originalGridId = 7;

        var existingWidget = new DashboardWidget
        {
            Id = widgetId,
            GridId = originalGridId,
            DashboardId = dashboardId,
            TenantId = TenantId,
            WidgetCatalogItemId = catalogItemId
        };

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = TenantId,
            Name = "Test Dashboard",
            Widgets = new List<DashboardWidget> { existingWidget }
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, originalGridId, dashboardId, catalogItemId,
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto, 0);
        var result = await _handler.Handle(cmd, CancellationToken.None);

        existingWidget.GridId.Should().Be(originalGridId);
    }

    [Fact]
    public async Task Handle_DashboardNotFound_ThrowsNotFoundException()
    {
        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();

        _repo.GetByIdWithWidgetsAsync(dashboardId, Arg.Any<bool>(), Arg.Any<CancellationToken>())
            .Returns((Dashboard?)null);

        var widgetDto = new DashboardWidgetDto(
            widgetId, 0, dashboardId, Guid.NewGuid(),
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto);
        var act = () => _handler.Handle(cmd, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*Dashboard*");
    }

    [Fact]
    public async Task Handle_Superadmin_BypassesTenantFilter()
    {
        _user.Role.Returns("Superadmin");

        var dashboardId = Guid.NewGuid();
        var widgetId = Guid.NewGuid();
        var otherTenantId = Guid.NewGuid();

        var dashboard = new Dashboard
        {
            Id = dashboardId,
            TenantId = otherTenantId,
            Name = "Other Tenant Dashboard",
            Widgets = new List<DashboardWidget>()
        };

        _repo.GetByIdWithWidgetsAsync(dashboardId, true, Arg.Any<CancellationToken>())
            .Returns(dashboard);

        var widgetDto = new DashboardWidgetDto(
            widgetId, 0, dashboardId, Guid.NewGuid(),
            "{}", "{}");

        var cmd = new SaveDashboardWidgetCommand(dashboardId, widgetDto);
        await _handler.Handle(cmd, CancellationToken.None);

        await _repo.Received(1).GetByIdWithWidgetsAsync(dashboardId, true, Arg.Any<CancellationToken>());
    }
}
