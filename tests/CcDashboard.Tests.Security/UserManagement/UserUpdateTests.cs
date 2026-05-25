using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.UserManagement;

/// <summary>
/// Integration tests for user update operations (DoD-A5, DoD-A6).
/// Covers USR-06, USR-07, USR-08, GAP-T6-01, GAP-T6-02, GAP-T6-03.
/// </summary>
[Collection("Postgres")]
public class UserUpdateTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _sp = null!;

    public UserUpdateTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        await using var auditDb = _fixture.CreateAuditDbContext();
        await auditDb.AuditLogs
            .Where(l => l.EventType.StartsWith("User."))
            .ExecuteDeleteAsync();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    private IServiceProvider BuildServiceProvider(Guid userId, Guid tenantId, string role)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider>(new TestDateTimeProvider());
        services.AddSingleton<ICurrentUserAccessor>(
            new TestCurrentUserAccessor(userId, tenantId, "TestUser", role, null));

        var emailMock = new Mock<IEmailSender>();
        services.AddSingleton(emailMock.Object);

        var envMock = new Mock<IHostEnvironment>();
        envMock.Setup(e => e.EnvironmentName).Returns("Development");
        services.AddSingleton(envMock.Object);

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));
        services.AddDbContext<AuditDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));

        services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
            {
                options.Password.RequiredLength = 12;
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddLogging();

        return services.BuildServiceProvider();
    }

    private async Task<Guid> CreateTestUserAsync(Guid tenantId, string role = "Editor", Guid? pgId = null)
    {
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            UserName = $"testuser_{Uuid.NewSequential():N}@local",
            Email = $"testuser_{Uuid.NewSequential():N}@local",
            NormalizedUserName = $"TESTUSER_{Uuid.NewSequential():N}@LOCAL",
            NormalizedEmail = $"TESTUSER_{Uuid.NewSequential():N}@LOCAL",
            EmailConfirmed = true,
            FirstName = "Test",
            LastName = "User",
            IsActive = true,
            PermissionGroupId = pgId ?? _fixture.PgAId
        };
        await um.CreateAsync(user, "Test@12345678");
        await um.AddToRoleAsync(user, role);
        return user.Id;
    }

    private async Task<List<AuditLog>> GetAuditLogsForUserAsync(Guid userId)
    {
        await using var auditDb = _fixture.CreateAuditDbContext();
        var logs = await auditDb.AuditLogs
            .OrderByDescending(l => l.CreatedAt)
            .Take(50)
            .ToListAsync();
        return logs.Where(l => l.Details != null && l.Details.Contains(userId.ToString())).ToList();
    }

    [Fact]
    [Trait("Req", "USR-06")]
    public async Task UpdateUser_NonRoleFields_OnlyUserUpdated()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var userId = await CreateTestUserAsync(_fixture.TenantAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var req = new UpdateUserRequest(
            Id: userId,
            FirstName: "Updated",
            LastName: "Name",
            Email: $"updated_{Uuid.NewSequential():N}@local",
            Role: "Editor",
            PermissionGroupId: _fixture.PgAId,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "ru-RU");

        var (ok, err) = await svc.UpdateAsync(req);
        ok.Should().BeTrue(err);

        var events = await GetAuditLogsForUserAsync(userId);
        events.Should().Contain(e => e.EventType == "User.Updated");
        events.Should().NotContain(e => e.EventType == "User.RoleChanged", "role did not change");
        events.Should().NotContain(e => e.EventType == "User.PermissionGroupChanged", "PG did not change");
    }

    [Fact]
    [Trait("Req", "USR-07")]
    [Trait("Req", "GAP-T6-01")]
    public async Task UpdateUser_RoleChange_EmitsRoleChangedEvent()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var userId = await CreateTestUserAsync(_fixture.TenantAId, "Editor");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var req = new UpdateUserRequest(
            Id: userId,
            FirstName: "Role",
            LastName: "Changed",
            Email: $"rolechange_{Uuid.NewSequential():N}@local",
            Role: "Viewer",
            PermissionGroupId: _fixture.PgAId,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        var (ok, err) = await svc.UpdateAsync(req);
        ok.Should().BeTrue(err);

        var events = await GetAuditLogsForUserAsync(userId);
        var roleEvent = events.FirstOrDefault(e => e.EventType == "User.RoleChanged");

        roleEvent.Should().NotBeNull("User.RoleChanged audit event must be emitted");
        roleEvent!.Details.Should().Contain("Editor", "old role in Details");
        roleEvent.Details.Should().Contain("Viewer", "new role in Details");
    }

    [Fact]
    [Trait("Req", "GAP-T6-01")]
    public async Task UpdateUser_PermissionGroupChange_EmitsPGChangedEvent()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var userId = await CreateTestUserAsync(_fixture.TenantAId, pgId: _fixture.PgAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var newPgId = Uuid.NewSequential();
        await using (var db = _fixture.CreateDbContext(_fixture.TenantAId))
        {
            db.PermissionGroups.Add(new CcDashboard.Domain.Domain.PermissionGroup
            {
                Id = newPgId,
                TenantId = _fixture.TenantAId,
                Name = $"NewPG_{newPgId:N}",
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = _fixture.UserAId,
                UpdatedByUserId = _fixture.UserAId
            });
            await db.SaveChangesAsync();
        }

        var req = new UpdateUserRequest(
            Id: userId,
            FirstName: "PG",
            LastName: "Changed",
            Email: $"pgchange_{Uuid.NewSequential():N}@local",
            Role: "Editor",
            PermissionGroupId: newPgId,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        var (ok, err) = await svc.UpdateAsync(req);
        ok.Should().BeTrue(err);

        var events = await GetAuditLogsForUserAsync(userId);
        var pgEvent = events.FirstOrDefault(e => e.EventType == "User.PermissionGroupChanged");

        pgEvent.Should().NotBeNull("User.PermissionGroupChanged audit event must be emitted");
        pgEvent!.Details.Should().Contain(_fixture.PgAId.ToString(), "old PG in Details");
        pgEvent.Details.Should().Contain(newPgId.ToString(), "new PG in Details");
    }

    [Fact]
    [Trait("Req", "USR-08")]
    [Trait("Req", "GAP-T6-03")]
    public async Task Admin_CannotChangeOwnRole()
    {
        var adminId = Uuid.NewSequential();
        var services = new ServiceCollection();
        services.AddSingleton<ITenantContext>(new TestTenantContext(_fixture.TenantAId));
        services.AddSingleton<IDateTimeProvider>(new TestDateTimeProvider());
        services.AddSingleton<ICurrentUserAccessor>(
            new TestCurrentUserAccessor(adminId, _fixture.TenantAId, "SelfAdmin", "Administrator", null));
        services.AddSingleton(new Mock<IEmailSender>().Object);
        var envMock = new Mock<IHostEnvironment>();
        envMock.Setup(e => e.EnvironmentName).Returns("Development");
        services.AddSingleton(envMock.Object);
        services.AddDbContext<AppDbContext>(o => o.UseNpgsql(_fixture.ConnectionString));
        services.AddDbContext<AuditDbContext>(o => o.UseNpgsql(_fixture.ConnectionString));
        services.AddIdentity<ApplicationUser, ApplicationRole>()
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddLogging();
        _sp = services.BuildServiceProvider();

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var adminUser = new ApplicationUser
        {
            Id = adminId,
            TenantId = _fixture.TenantAId,
            UserName = $"selfadmin_{Uuid.NewSequential():N}@local",
            Email = $"selfadmin_{Uuid.NewSequential():N}@local",
            NormalizedUserName = $"SELFADMIN_{Uuid.NewSequential():N}@LOCAL",
            NormalizedEmail = $"SELFADMIN_{Uuid.NewSequential():N}@LOCAL",
            EmailConfirmed = true,
            FirstName = "Self",
            LastName = "Admin",
            IsActive = true
        };
        await um.CreateAsync(adminUser, "Admin@12345678");
        await um.AddToRoleAsync(adminUser, "Administrator");

        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new UpdateUserRequest(
            Id: adminId,
            FirstName: "Self",
            LastName: "Admin",
            Email: adminUser.Email,
            Role: "Superadmin",
            PermissionGroupId: null,
            IsActive: true,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        var (ok, err) = await svc.UpdateAsync(req);

        ok.Should().BeFalse("Admin cannot change own role");
        err.Should().Contain("Cannot change own role");
    }

    [Fact]
    [Trait("Req", "GAP-T6-02")]
    public async Task Update_CrossTenant_Rejected()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var req = new UpdateUserRequest(
            Id: _fixture.UserBId,
            FirstName: "Hacked",
            LastName: "User",
            Email: "hacked@local",
            Role: "Editor",
            PermissionGroupId: _fixture.PgBId,
            IsActive: false,
            Is2faEnabled: false,
            PreferredLocale: "en-US");

        var (ok, err) = await svc.UpdateAsync(req);

        ok.Should().BeFalse("cross-tenant update blocked");
        err.Should().Contain("not found", "returns generic error to prevent enumeration");
    }

    [Fact]
    [Trait("Req", "GAP-T6-02")]
    public async Task Superadmin_Update_CrossTenant_Allowed()
    {
        _sp = BuildServiceProvider(_fixture.SuperadminId, _fixture.PlatformTenantId, "Superadmin");

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var crossTenantUser = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantBId,
            UserName = $"crosstenantuser_{Uuid.NewSequential():N}@local",
            Email = $"crosstenantuser_{Uuid.NewSequential():N}@local",
            NormalizedUserName = $"CROSSTENANTUSER_{Uuid.NewSequential():N}@LOCAL",
            NormalizedEmail = $"CROSSTENANTUSER_{Uuid.NewSequential():N}@LOCAL",
            EmailConfirmed = true,
            FirstName = "CrossTenant",
            LastName = "User",
            IsActive = true,
            PermissionGroupId = _fixture.PgBId
        };
        await um.CreateAsync(crossTenantUser, "Test@12345678");
        await um.AddToRoleAsync(crossTenantUser, "Editor");

        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new UpdateUserRequest(
            Id: crossTenantUser.Id,
            FirstName: "SAUpdated",
            LastName: crossTenantUser.LastName,
            Email: crossTenantUser.Email!,
            Role: "Editor",
            PermissionGroupId: crossTenantUser.PermissionGroupId,
            IsActive: crossTenantUser.IsActive,
            Is2faEnabled: crossTenantUser.Is2faEnabled,
            PreferredLocale: crossTenantUser.PreferredLocale);

        var (ok, err) = await svc.UpdateAsync(req);

        ok.Should().BeTrue(err ?? "Superadmin should update cross-tenant");

        var updated = await um.FindByIdAsync(crossTenantUser.Id.ToString());
        updated!.FirstName.Should().Be("SAUpdated");
    }
}

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
