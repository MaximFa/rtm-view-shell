using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class PurgeDashboardCommandHandlerTests
{
    private readonly IDashboardRepository _repo = Substitute.For<IDashboardRepository>();
    private readonly IRtsRepository _rtsRepo = Substitute.For<IRtsRepository>();
    private readonly IPermissionService _permService = Substitute.For<IPermissionService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly PurgeDashboardCommandHandler _handler;

    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid PermissionGroupId = Guid.NewGuid();

    public PurgeDashboardCommandHandlerTests()
    {
        _user.UserId.Returns(UserId);
        _user.TenantId.Returns(TenantId);
        _user.PermissionGroupId.Returns(PermissionGroupId);
        _user.Role.Returns("Editor");
        _handler = new PurgeDashboardCommandHandler(_repo, _rtsRepo, _permService, _user);
    }

    [Fact]
    public async Task Handle_SoftDeletedDashboard_RemovesCalled()
    {
        // Arrange: a soft-deleted dashboard
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Trash Dashboard",
            IsDeleted = true,
            DeletedAt = DateTime.UtcNow.AddDays(-1)
        };
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);
        _permService.HasDashboardAccessAsync(PermissionGroupId, TenantId, id, 4, Arg.Any<CancellationToken>())
            .Returns(true);

        // Act
        await _handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert: Remove was called on the dashboard (cascade delete handled by DB)
        _repo.Received(1).Remove(dashboard);
    }

    [Fact]
    public async Task Handle_NotSoftDeleted_ThrowsDomainException()
    {
        // Arrange: a non-deleted dashboard (should not happen but guard enforces)
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Active Dashboard",
            IsDeleted = false
        };
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        // Act
        var act = () => _handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*soft-deleted*");
        _repo.DidNotReceive().Remove(Arg.Any<Dashboard>());
    }

    [Fact]
    public async Task Handle_NoDeletePermission_ThrowsForbiddenException()
    {
        // Arrange: user lacks Delete permission (level 4)
        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Trash Dashboard",
            IsDeleted = true
        };
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);
        _permService.HasDashboardAccessAsync(PermissionGroupId, TenantId, id, 4, Arg.Any<CancellationToken>())
            .Returns(false);

        // Act
        var act = () => _handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Delete permission*");
        _repo.DidNotReceive().Remove(Arg.Any<Dashboard>());
    }

    [Fact]
    public async Task Handle_Superadmin_BypassesPermissionCheck()
    {
        // Arrange: Superadmin user
        _user.Role.Returns("Superadmin");
        var handler = new PurgeDashboardCommandHandler(_repo, _rtsRepo, _permService, _user);

        var id = Guid.NewGuid();
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Trash Dashboard",
            IsDeleted = true
        };
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        // Act
        await handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert: Permission service was never called, but Remove was
        await _permService.DidNotReceive().HasDashboardAccessAsync(
            Arg.Any<Guid?>(), Arg.Any<Guid>(), Arg.Any<Guid>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
        _repo.Received(1).Remove(dashboard);
    }

    [Fact]
    public async Task Handle_NotFound_ThrowsNotFoundException()
    {
        // Arrange: dashboard not found (different tenant or doesn't exist)
        var id = Guid.NewGuid();
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Dashboard?)null);

        // Act
        var act = () => _handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*Dashboard*");
    }

    [Fact]
    public async Task Handle_WidgetWithGridId_AttemptsRtsSweep()
    {
        // Arrange: dashboard with an AgentGrid widget having GridId
        var id = Guid.NewGuid();
        var widgetCatalogItem = new WidgetCatalogItem { Id = Guid.NewGuid(), Name = "Agent Grid Widget" };
        var widget = new DashboardWidget
        {
            Id = Guid.NewGuid(),
            GridId = 42,
            CatalogItem = widgetCatalogItem,
            IsDeleted = false
        };
        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = TenantId,
            Name = "Trash Dashboard",
            IsDeleted = true,
            Widgets = new List<DashboardWidget> { widget }
        };
        _repo.GetDeletedByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);
        _permService.HasDashboardAccessAsync(PermissionGroupId, TenantId, id, 4, Arg.Any<CancellationToken>())
            .Returns(true);
        _rtsRepo.GetColumnsSetIdByGridIdAsync(42, Arg.Any<CancellationToken>()).Returns(100);

        // Act
        await _handler.Handle(new PurgeDashboardCommand(id), CancellationToken.None);

        // Assert: RTS sweep was attempted
        await _rtsRepo.Received(1).GetColumnsSetIdByGridIdAsync(42, Arg.Any<CancellationToken>());
        await _rtsRepo.Received(1).DeleteGridAsync(42, Arg.Any<CancellationToken>());
        await _rtsRepo.Received(1).DeleteColumnsSetAsync(100, Arg.Any<CancellationToken>());
        _repo.Received(1).Remove(dashboard);
    }
}
