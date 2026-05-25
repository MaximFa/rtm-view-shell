using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using UUIDNext;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Tests for DashboardWidget lifecycle (WGT-04).
/// </summary>
[Collection("Postgres")]
public class DashboardWidgetTests(PostgresFixture postgres)
{
    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveDashboardWidget_NewWidgetOnOwnDashboard_Succeeds()
    {
        // Arrange
        var userAccessor = CreateUserAccessor(postgres.UserAId, postgres.TenantAId, "Editor");
        var clock = new TestDateTimeProvider();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var dashboards = new DashboardRepository(db);
        var unitOfWork = new UnitOfWork(db);

        var widgetId = Uuid.NewSequential();
        var widgetDto = new DashboardWidgetDto(
            Id: widgetId,
            GridId: 0,
            DashboardId: postgres.DashboardAId,
            WidgetCatalogItemId: postgres.WidgetCatalogItemId,
            PositionJson: """{"x":0,"y":0,"w":4,"h":3}""",
            ConfigJson: """{"title":"Test"}""");

        var handler = new SaveDashboardWidgetCommandHandler(dashboards, unitOfWork, userAccessor, clock);

        // Act
        var gridId = await handler.Handle(
            new SaveDashboardWidgetCommand(postgres.DashboardAId, widgetDto), CancellationToken.None);

        // Assert
        gridId.Should().BeGreaterThan(0);

        // Verify in DB
        await using var verifyDb = postgres.CreateDbContext(postgres.TenantAId);
        var widget = await verifyDb.DashboardWidgets.FirstOrDefaultAsync(w => w.Id == widgetId);
        widget.Should().NotBeNull();
        widget!.DashboardId.Should().Be(postgres.DashboardAId);
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveDashboardWidget_CrossTenantDashboard_ThrowsNotFoundException()
    {
        // Arrange: User from tenant A trying to add widget to tenant B's dashboard
        var userAccessor = CreateUserAccessor(postgres.UserAId, postgres.TenantAId, "Editor");
        var clock = new TestDateTimeProvider();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var dashboards = new DashboardRepository(db);
        var unitOfWork = new UnitOfWork(db);

        var widgetDto = new DashboardWidgetDto(
            Id: Uuid.NewSequential(),
            GridId: 0,
            DashboardId: postgres.DashboardBId,
            WidgetCatalogItemId: postgres.WidgetCatalogItemId,
            PositionJson: "{}",
            ConfigJson: "{}");

        var handler = new SaveDashboardWidgetCommandHandler(dashboards, unitOfWork, userAccessor, clock);

        // Act & Assert: Should throw because dashboard B is not visible to tenant A
        await handler.Invoking(h => h.Handle(
            new SaveDashboardWidgetCommand(postgres.DashboardBId, widgetDto), CancellationToken.None))
            .Should().ThrowAsync<NotFoundException>();
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveDashboardWidget_UpdateExistingWidget_UpdatesFields()
    {
        // Arrange: Create a widget first
        var userAccessor = CreateUserAccessor(postgres.UserAId, postgres.TenantAId, "Editor");
        var clock = new TestDateTimeProvider();
        var widgetId = Uuid.NewSequential();

        await using (var setupDb = postgres.CreateDbContext(postgres.TenantAId))
        {
            setupDb.DashboardWidgets.Add(new DashboardWidget
            {
                Id = widgetId,
                DashboardId = postgres.DashboardAId,
                TenantId = postgres.TenantAId,
                WidgetCatalogItemId = postgres.WidgetCatalogItemId,
                PositionJson = """{"x":0}""",
                ConfigJson = """{"old":true}""",
                IsDeleted = false
            });
            await setupDb.SaveChangesAsync();
        }

        var db = postgres.CreateDbContext(postgres.TenantAId);
        var dashboards = new DashboardRepository(db);
        var unitOfWork = new UnitOfWork(db);

        var updatedDto = new DashboardWidgetDto(
            Id: widgetId,
            GridId: 0,
            DashboardId: postgres.DashboardAId,
            WidgetCatalogItemId: postgres.WidgetCatalogItemId,
            PositionJson: """{"x":10,"y":20}""",
            ConfigJson: """{"updated":true}""");

        var handler = new SaveDashboardWidgetCommandHandler(dashboards, unitOfWork, userAccessor, clock);

        // Act
        await handler.Handle(new SaveDashboardWidgetCommand(postgres.DashboardAId, updatedDto), CancellationToken.None);

        // Assert
        await using var verifyDb = postgres.CreateDbContext(postgres.TenantAId);
        var widget = await verifyDb.DashboardWidgets.FirstOrDefaultAsync(w => w.Id == widgetId);
        widget.Should().NotBeNull();
        widget!.PositionJson.Should().Contain("10"); // Contains the updated x value
        widget.ConfigJson.Should().Contain("updated");
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task DashboardWidget_SoftDelete_SetsIsDeletedFlag()
    {
        // Arrange: Create a widget
        var widgetId = Uuid.NewSequential();
        await using (var setupDb = postgres.CreateDbContext(postgres.TenantAId))
        {
            setupDb.DashboardWidgets.Add(new DashboardWidget
            {
                Id = widgetId,
                DashboardId = postgres.DashboardAId,
                TenantId = postgres.TenantAId,
                WidgetCatalogItemId = postgres.WidgetCatalogItemId,
                PositionJson = "{}",
                ConfigJson = "{}",
                IsDeleted = false
            });
            await setupDb.SaveChangesAsync();
        }

        // Act: Soft delete
        await using (var db = postgres.CreateDbContext(postgres.TenantAId))
        {
            var widget = await db.DashboardWidgets
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(w => w.Id == widgetId);
            widget!.IsDeleted = true;
            await db.SaveChangesAsync();
        }

        // Assert: Widget not visible via normal query (GQF filters IsDeleted)
        await using var verifyDb = postgres.CreateDbContext(postgres.TenantAId);
        var visibleWidget = await verifyDb.DashboardWidgets.FirstOrDefaultAsync(w => w.Id == widgetId);
        visibleWidget.Should().BeNull("Soft-deleted widget should be filtered by GQF");

        // But visible with IgnoreQueryFilters
        var hiddenWidget = await verifyDb.DashboardWidgets
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(w => w.Id == widgetId);
        hiddenWidget.Should().NotBeNull();
        hiddenWidget!.IsDeleted.Should().BeTrue();
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveDashboardWidget_WithPreassignedGridId_ReturnsPreassignedValue()
    {
        // Arrange
        var userAccessor = CreateUserAccessor(postgres.UserAId, postgres.TenantAId, "Editor");
        var clock = new TestDateTimeProvider();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var dashboards = new DashboardRepository(db);
        var unitOfWork = new UnitOfWork(db);

        var widgetId = Uuid.NewSequential();
        var preassignedGridId = 12345;
        var widgetDto = new DashboardWidgetDto(
            Id: widgetId,
            GridId: 0,
            DashboardId: postgres.DashboardAId,
            WidgetCatalogItemId: postgres.WidgetCatalogItemId,
            PositionJson: "{}",
            ConfigJson: "{}");

        var handler = new SaveDashboardWidgetCommandHandler(dashboards, unitOfWork, userAccessor, clock);

        // Act
        var returnedGridId = await handler.Handle(
            new SaveDashboardWidgetCommand(postgres.DashboardAId, widgetDto, PreassignedGridId: preassignedGridId),
            CancellationToken.None);

        // Assert
        returnedGridId.Should().Be(preassignedGridId);

        // Verify in DB
        await using var verifyDb = postgres.CreateDbContext(postgres.TenantAId);
        var widget = await verifyDb.DashboardWidgets.FirstOrDefaultAsync(w => w.Id == widgetId);
        widget.Should().NotBeNull();
        widget!.GridId.Should().Be(preassignedGridId);
    }

    // ── Helper methods ───────────────────────────────────────────────────────────

    private static ICurrentUserAccessor CreateUserAccessor(Guid userId, Guid tenantId, string role)
    {
        var accessor = Substitute.For<ICurrentUserAccessor>();
        accessor.UserId.Returns(userId);
        accessor.TenantId.Returns(tenantId);
        accessor.UserName.Returns("test-user");
        accessor.Role.Returns(role);
        accessor.IsAuthenticated.Returns(true);
        return accessor;
    }

    private class UnitOfWork(AppDbContext db) : IUnitOfWork
    {
        public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
    }
}
