using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Infrastructure.Services;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Integration tests for audit events on PG lifecycle [DoD-10].
/// Per CLAUDE.md §16: AuditBehavior writes PermissionGroup.Created / Updated / Deleted / PermissionChanged.
/// </summary>
[Collection("Postgres")]
public class PermissionGroupAuditTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _serviceProvider = null!;

    public PermissionGroupAuditTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        // Clear any existing audit logs for clean tests
        await using var auditDb = _fixture.CreateAuditDbContext();
        await auditDb.AuditLogs
            .Where(l => l.EventType.StartsWith("PermissionGroup."))
            .ExecuteDeleteAsync();

        // Set up service provider with full MediatR pipeline
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(_fixture.TenantAId));
        services.AddSingleton<IDateTimeProvider>(new TestDateTimeProvider());
        services.AddSingleton<ICurrentUserAccessor>(new TestCurrentUserAccessor(
            _fixture.UserAId, _fixture.TenantAId, "User A", "Editor", _fixture.PgAId));

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));
        services.AddDbContext<AuditDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));
        services.AddDbContext<BackendEmulationDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));

        services.AddScoped<IPermissionGroupRepository, PermissionGroupRepository>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IConfigurationApiHook, NoOpConfigurationApiHook>();

        // Mock cache service for UpdatePermissionGroupCommand
        var cacheMock = new Mock<ICacheService>();
        services.AddSingleton(cacheMock.Object);

        services.AddLogging();

        // Add MediatR with AuditBehavior only (skip others for focused testing)
        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(typeof(CreatePermissionGroupCommand).Assembly);
            cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(AuditBehavior<,>));
        });

        _serviceProvider = services.BuildServiceProvider();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task CreatePermissionGroup_WritesAuditLog()
    {
        // Arrange
        var sender = _serviceProvider.GetRequiredService<ISender>();
        var request = new CreatePermissionGroupRequest(
            Name: $"Audit Test Group {Guid.NewGuid():N}",
            Description: "Test description",
            MenuPermissions: ["menu.dashboards"],
            AllowedQueueIds: null,
            AllowedAgentGroupIds: null,
            AllowedSupergroupIds: null,
            AllowedBusinessUnitIds: null,
            AllowedDashboardIds: null);

        var command = new CreatePermissionGroupCommand(request, _fixture.TenantAId);

        // Act
        var result = await sender.Send(command);

        // Assert
        result.IsSuccess.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.EventType == "PermissionGroup.Created")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Audit log should be created for PermissionGroup.Created");
        auditLog!.EventResult.Should().Be(AuditEventResult.Success);
        auditLog.TenantId.Should().Be(_fixture.TenantAId);
        auditLog.UserId.Should().Be(_fixture.UserAId);
        auditLog.Details.Should().Contain(request.Name);
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task UpdatePermissionGroup_WritesAuditLog()
    {
        // Arrange - first create a PG
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var pgId = Uuid.NewSequential();
        var pg = new PermissionGroup
        {
            Id = pgId,
            TenantId = _fixture.TenantAId,
            Name = "Update Test PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };
        db.PermissionGroups.Add(pg);
        await db.SaveChangesAsync();

        var sender = _serviceProvider.GetRequiredService<ISender>();
        var request = new UpdatePermissionGroupRequest(
            Id: pgId,
            Name: "Updated Name",
            Description: "Updated description",
            IsActive: true,
            MenuPermissions: ["menu.dashboards", "menu.users"],
            RowVersion: 0,
            AllowedQueueIds: null,
            AllowedAgentGroupIds: null,
            AllowedSupergroupIds: null,
            AllowedBusinessUnitIds: null,
            AllowedDashboardIds: null);

        var command = new UpdatePermissionGroupCommand(request);

        // Act
        var result = await sender.Send(command);

        // Assert
        result.IsSuccess.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.EventType == "PermissionGroup.Updated")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Audit log should be created for PermissionGroup.Updated");
        auditLog!.EventResult.Should().Be(AuditEventResult.Success);
        auditLog.TenantId.Should().Be(_fixture.TenantAId);
        auditLog.UserId.Should().Be(_fixture.UserAId);
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task DeletePermissionGroup_WithNoUsers_WritesAuditLog()
    {
        // Arrange - create a PG with no users
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var pgId = Uuid.NewSequential();
        var pg = new PermissionGroup
        {
            Id = pgId,
            TenantId = _fixture.TenantAId,
            Name = "Delete Test PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };
        db.PermissionGroups.Add(pg);
        await db.SaveChangesAsync();

        var sender = _serviceProvider.GetRequiredService<ISender>();
        var command = new DeletePermissionGroupCommand(pgId);

        // Act
        var result = await sender.Send(command);

        // Assert
        result.IsSuccess.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.EventType == "PermissionGroup.Deleted")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Audit log should be created for PermissionGroup.Deleted");
        auditLog!.EventResult.Should().Be(AuditEventResult.Success);
        auditLog.TenantId.Should().Be(_fixture.TenantAId);
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task UpdatePermissionGroup_PermissionsChanged_WritesAuditLog()
    {
        // Arrange - create a PG with initial permissions
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var pgId = Uuid.NewSequential();
        var pg = new PermissionGroup
        {
            Id = pgId,
            TenantId = _fixture.TenantAId,
            Name = "Permission Change Test PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };
        pg.MenuPermissions.Add(new MenuPermission
        {
            PermissionGroupId = pgId,
            MenuKey = "menu.dashboards",
            TenantId = _fixture.TenantAId
        });
        db.PermissionGroups.Add(pg);
        await db.SaveChangesAsync();

        var sender = _serviceProvider.GetRequiredService<ISender>();

        // Change permissions by adding more menu items
        var request = new UpdatePermissionGroupRequest(
            Id: pgId,
            Name: "Permission Change Test PG",
            Description: null,
            IsActive: true,
            MenuPermissions: ["menu.dashboards", "menu.users", "menu.permissionGroups"],
            RowVersion: 0,
            AllowedQueueIds: null,
            AllowedAgentGroupIds: null,
            AllowedSupergroupIds: null,
            AllowedBusinessUnitIds: null,
            AllowedDashboardIds: null);

        var command = new UpdatePermissionGroupCommand(request);

        // Act
        var result = await sender.Send(command);

        // Assert
        result.IsSuccess.Should().BeTrue();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLog = await auditDb.AuditLogs
            .Where(l => l.EventType == "PermissionGroup.Updated")
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Audit log should be created for permission change");
        auditLog!.EventResult.Should().Be(AuditEventResult.Success);
    }
}

/// <summary>
/// Test implementation of ICurrentUserAccessor.
/// </summary>
file class TestCurrentUserAccessor(
    Guid userId, Guid tenantId, string userName, string role, Guid? pgId) : ICurrentUserAccessor
{
    public Task InitAsync() => Task.CompletedTask;
    public Guid? UserId => userId;
    public Guid? TenantId => tenantId;
    public string? UserName => userName;
    public string? Role => role;
    public Guid? PermissionGroupId => pgId;
    public string PreferredLocale => "en-US";
    public bool IsAuthenticated => true;
}
