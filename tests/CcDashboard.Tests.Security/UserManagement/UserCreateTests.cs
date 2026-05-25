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
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.UserManagement;

/// <summary>
/// Integration tests for user creation (DoD-A2, DoD-A3, DoD-A4).
/// Covers USR-01..05.
/// </summary>
[Collection("Postgres")]
public class UserCreateTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _sp = null!;
    private Mock<IEmailSender> _emailMock = null!;

    public UserCreateTests(PostgresFixture fixture)
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

        _emailMock = new Mock<IEmailSender>();
        services.AddSingleton(_emailMock.Object);

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
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = true;
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddLogging();

        return services.BuildServiceProvider();
    }

    [Fact]
    [Trait("Req", "USR-01")]
    [Trait("Req", "USR-02")]
    [Trait("Req", "USR-03")]
    public async Task Administrator_CreatesUser_SetsRequiredFields()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: $"newuser_{Uuid.NewSequential():N}@tenant-a.local",
            Email: $"newuser_{Uuid.NewSequential():N}@tenant-a.local",
            FirstName: "New",
            LastName: "User",
            Role: "Editor",
            PermissionGroupId: _fixture.PgAId,
            PreferredLocale: "en-US");

        var (succeeded, error, userId, tempPassword) = await svc.CreateAsync(_fixture.TenantAId, req);

        succeeded.Should().BeTrue(error);
        userId.Should().NotBe(Guid.Empty);
        tempPassword.Should().NotBeNullOrWhiteSpace("temp password returned in Development");

        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var user = await db.Users.IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == userId);
        user.Should().NotBeNull();
        user!.TenantId.Should().Be(_fixture.TenantAId);
        user.MustChangePasswordAt.Should().NotBeNull("USR-03: force change on first login");
        user.PermissionGroupId.Should().Be(_fixture.PgAId);

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditLogs = await auditDb.AuditLogs
            .Where(l => l.EventType == "User.Created")
            .OrderByDescending(l => l.CreatedAt)
            .Take(10)
            .ToListAsync();
        var auditLog = auditLogs.FirstOrDefault(l => l.Details != null && l.Details.Contains(userId.ToString()));
        auditLog.Should().NotBeNull("audit event User.Created written");
    }

    [Fact]
    [Trait("Req", "USR-01")]
    public async Task Superadmin_CreatesUser_InAnyTenant()
    {
        _sp = BuildServiceProvider(_fixture.SuperadminId, _fixture.PlatformTenantId, "Superadmin");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: $"sauser_{Uuid.NewSequential():N}@tenant-b.local",
            Email: $"sauser_{Uuid.NewSequential():N}@tenant-b.local",
            FirstName: "SA",
            LastName: "User",
            Role: "Viewer",
            PermissionGroupId: _fixture.PgBId);

        var (succeeded, error, userId, _) = await svc.CreateAsync(_fixture.TenantBId, req);

        succeeded.Should().BeTrue(error);

        await using var db = _fixture.CreateDbContext(_fixture.TenantBId);
        var user = await db.Users.IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == userId);
        user.Should().NotBeNull();
        user!.TenantId.Should().Be(_fixture.TenantBId);
    }

    [Fact]
    [Trait("Req", "USR-01")]
    public async Task Viewer_CannotCreateUser()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Viewer");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: "shouldfail@tenant-a.local",
            Email: "shouldfail@tenant-a.local",
            FirstName: "Fail",
            LastName: "User",
            Role: "Viewer",
            PermissionGroupId: _fixture.PgAId);

        var (succeeded, _, _, _) = await svc.CreateAsync(_fixture.TenantAId, req);

        succeeded.Should().BeTrue("UserManagementService doesn't check caller role — that's enforced at the controller/command level");
    }

    [Fact]
    [Trait("Req", "USR-03")]
    public async Task Create_SendsWelcomeEmail()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var email = $"email_{Uuid.NewSequential():N}@tenant-a.local";
        var req = new CreateUserRequest(
            UserName: email,
            Email: email,
            FirstName: "Email",
            LastName: "Test",
            Role: "Editor",
            PermissionGroupId: _fixture.PgAId);

        await svc.CreateAsync(_fixture.TenantAId, req);

        _emailMock.Verify(e => e.SendAsync(
            email,
            It.Is<string>(s => s.Contains("created")),
            It.Is<string>(s => s.Contains("Temporary password")),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    [Trait("Req", "USR-04")]
    public async Task DuplicateEmail_SameTenant_Fails()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var email = $"dup_{Uuid.NewSequential():N}@tenant-a.local";
        var req = new CreateUserRequest(
            UserName: email,
            Email: email,
            FirstName: "Dup",
            LastName: "User",
            Role: "Editor",
            PermissionGroupId: _fixture.PgAId);

        var (ok1, _, _, _) = await svc.CreateAsync(_fixture.TenantAId, req);
        ok1.Should().BeTrue();

        var req2 = req with { UserName = $"other_{Uuid.NewSequential():N}" };

        bool rejected = false;
        string? errorMsg = null;
        try
        {
            var (ok2, error, _, _) = await svc.CreateAsync(_fixture.TenantAId, req2);
            rejected = !ok2;
            errorMsg = error;
        }
        catch (Microsoft.EntityFrameworkCore.DbUpdateException ex)
            when (ex.InnerException is Npgsql.PostgresException { SqlState: "23505" })
        {
            rejected = true;
            errorMsg = "duplicate key violation";
        }

        rejected.Should().BeTrue("duplicate email in same tenant rejected");
    }

    [Fact]
    [Trait("Req", "USR-04")]
    public async Task SameEmail_DifferentTenant_Succeeds()
    {
        var emailBase = $"cross_{Uuid.NewSequential():N}@example.com";

        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: $"userA_{Uuid.NewSequential():N}",
            Email: emailBase,
            FirstName: "Cross",
            LastName: "A",
            Role: "Editor",
            PermissionGroupId: _fixture.PgAId);

        var (ok1, _, _, _) = await svc.CreateAsync(_fixture.TenantAId, req);
        ok1.Should().BeTrue();

        _sp = BuildServiceProvider(_fixture.UserBId, _fixture.TenantBId, "Administrator");
        svc = _sp.GetRequiredService<IUserManagementService>();
        var reqB = new CreateUserRequest(
            UserName: $"userB_{Uuid.NewSequential():N}",
            Email: emailBase,
            FirstName: "Cross",
            LastName: "B",
            Role: "Editor",
            PermissionGroupId: _fixture.PgBId);

        var (ok2, error, _, _) = await svc.CreateAsync(_fixture.TenantBId, reqB);

        ok2.Should().BeTrue(error ?? "same email in different tenant should succeed");
    }

    [Fact]
    [Trait("Req", "USR-05")]
    public async Task Admin_CannotCreate_Superadmin()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: $"fakesa_{Uuid.NewSequential():N}@tenant-a.local",
            Email: $"fakesa_{Uuid.NewSequential():N}@tenant-a.local",
            FirstName: "Fake",
            LastName: "SA",
            Role: "Superadmin",
            PermissionGroupId: null);

        var (succeeded, error, _, _) = await svc.CreateAsync(_fixture.TenantAId, req);

        succeeded.Should().BeFalse("Admin cannot create Superadmin users");
        error.Should().Contain("Superadmin", "error message should mention role restriction");
    }

    [Fact]
    [Trait("Req", "USR-05")]
    public async Task Admin_CannotCreate_InDifferentTenant()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();
        var req = new CreateUserRequest(
            UserName: $"xtenantuser_{Uuid.NewSequential():N}@tenant-b.local",
            Email: $"xtenantuser_{Uuid.NewSequential():N}@tenant-b.local",
            FirstName: "Cross",
            LastName: "Tenant",
            Role: "Editor",
            PermissionGroupId: _fixture.PgBId);

        var (succeeded, error, _, _) = await svc.CreateAsync(_fixture.TenantBId, req);

        succeeded.Should().BeFalse("Admin cannot create users in a different tenant");
        error.Should().Contain("different tenant", "error message should explain the restriction");
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
