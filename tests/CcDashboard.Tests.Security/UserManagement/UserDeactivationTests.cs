using CcDashboard.Application.Interfaces;
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
/// Integration tests for user deactivation and force logout (DoD-A7).
/// Covers USR-09.
/// </summary>
[Collection("Postgres")]
public class UserDeactivationTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _sp = null!;

    public UserDeactivationTests(PostgresFixture fixture)
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

        services.AddIdentity<ApplicationUser, ApplicationRole>()
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddLogging();

        return services.BuildServiceProvider();
    }

    private async Task<(Guid Id, string OriginalStamp)> CreateTestUserAsync(Guid tenantId)
    {
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            UserName = $"deact_{Uuid.NewSequential():N}@local",
            Email = $"deact_{Uuid.NewSequential():N}@local",
            NormalizedUserName = $"DEACT_{Uuid.NewSequential():N}@LOCAL",
            NormalizedEmail = $"DEACT_{Uuid.NewSequential():N}@LOCAL",
            EmailConfirmed = true,
            FirstName = "Deact",
            LastName = "Test",
            IsActive = true
        };
        await um.CreateAsync(user, "Test@12345678");
        await um.AddToRoleAsync(user, "Editor");
        return (user.Id, user.SecurityStamp!);
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
    [Trait("Req", "USR-09")]
    public async Task SetActive_False_SetsIsActive_RotatesSecurityStamp()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var (userId, originalStamp) = await CreateTestUserAsync(_fixture.TenantAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.SetActiveAsync(userId, false);

        ok.Should().BeTrue(err);

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await um.FindByIdAsync(userId.ToString());
        user!.IsActive.Should().BeFalse();
        user.SecurityStamp.Should().NotBe(originalStamp, "SecurityStamp rotated on deactivation");

        var auditLogs = await GetAuditLogsForUserAsync(userId);
        auditLogs.Should().Contain(l => l.EventType == "User.Deactivated", "User.Deactivated audit event written");
    }

    [Fact]
    [Trait("Req", "USR-09")]
    public async Task SetActive_True_EmitsActivatedEvent()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var (userId, _) = await CreateTestUserAsync(_fixture.TenantAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        await svc.SetActiveAsync(userId, false);
        var (ok, err) = await svc.SetActiveAsync(userId, true);

        ok.Should().BeTrue(err);

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await um.FindByIdAsync(userId.ToString());
        user!.IsActive.Should().BeTrue();

        var auditLogs = await GetAuditLogsForUserAsync(userId);
        auditLogs.Should().Contain(l => l.EventType == "User.Activated", "User.Activated audit event written");
    }

    [Fact]
    [Trait("Req", "USR-09")]
    public async Task ForceLogout_RotatesSecurityStamp()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var (userId, originalStamp) = await CreateTestUserAsync(_fixture.TenantAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        await svc.ForceLogoutAsync(userId);

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await um.FindByIdAsync(userId.ToString());
        user!.SecurityStamp.Should().NotBe(originalStamp, "SecurityStamp rotated on force logout");
    }

    [Fact]
    [Trait("Req", "GAP-T6-02")]
    public async Task SetActive_CrossTenant_Rejected()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.SetActiveAsync(_fixture.UserBId, false);

        ok.Should().BeFalse("cross-tenant deactivation blocked");
        err.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "GAP-T6-02")]
    public async Task Delete_CrossTenant_Rejected()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.DeleteAsync(_fixture.UserBId);

        ok.Should().BeFalse("cross-tenant delete blocked");
        err.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "GAP-T6-02")]
    public async Task ForceLogout_CrossTenant_Ignored()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");

        await using var db = _fixture.CreateDbContext(_fixture.TenantBId);
        var userB = await db.Users.IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == _fixture.UserBId);
        var originalStamp = userB?.SecurityStamp;

        var svc = _sp.GetRequiredService<IUserManagementService>();
        await svc.ForceLogoutAsync(_fixture.UserBId);

        await using var db2 = _fixture.CreateDbContext(_fixture.TenantBId);
        var userBAfter = await db2.Users.IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == _fixture.UserBId);
        userBAfter?.SecurityStamp.Should().Be(originalStamp, "cross-tenant force logout ignored");
    }

    [Fact]
    [Trait("Req", "USR-09")]
    public async Task Delete_WritesAuditEvent()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var (userId, _) = await CreateTestUserAsync(_fixture.TenantAId);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.DeleteAsync(userId);

        ok.Should().BeTrue(err);

        var auditLogs = await GetAuditLogsForUserAsync(userId);
        auditLogs.Should().Contain(l => l.EventType == "User.Deleted", "User.Deleted audit event written");
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
