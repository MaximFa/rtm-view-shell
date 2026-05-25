using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Users;
using CcDashboard.Contracts.DTOs.Users;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using MediatR;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UUIDNext;

namespace CcDashboard.Tests.Security.UserManagement;

/// <summary>
/// Integration tests for user list pagination and filtering (DoD-A9).
/// Covers USR-13, USR-14.
/// </summary>
[Collection("Postgres")]
public class UserListTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _sp = null!;

    public UserListTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => Task.CompletedTask;
    public Task DisposeAsync() => Task.CompletedTask;

    private IServiceProvider BuildServiceProvider(Guid userId, Guid tenantId, string role)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<ICurrentUserAccessor>(
            new TestCurrentUserAccessor(userId, tenantId, "TestUser", role, null));

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(_fixture.ConnectionString));

        services.AddIdentity<ApplicationUser, ApplicationRole>()
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped<IUserRepository, UserRepository>();

        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(GetUsersQuery).Assembly));

        services.AddLogging();

        return services.BuildServiceProvider();
    }

    private async Task<List<Guid>> SeedUsersAsync(Guid tenantId, int count, bool inactive = false)
    {
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var ids = new List<Guid>();
        for (int i = 0; i < count; i++)
        {
            var user = new ApplicationUser
            {
                Id = Uuid.NewSequential(),
                TenantId = tenantId,
                UserName = $"listuser_{Uuid.NewSequential():N}@local",
                Email = $"listuser_{Uuid.NewSequential():N}@local",
                NormalizedUserName = $"LISTUSER_{Uuid.NewSequential():N}@LOCAL",
                NormalizedEmail = $"LISTUSER_{Uuid.NewSequential():N}@LOCAL",
                EmailConfirmed = true,
                FirstName = "List",
                LastName = $"User{i}",
                IsActive = !inactive,
                PermissionGroupId = tenantId == _fixture.TenantAId ? _fixture.PgAId : _fixture.PgBId
            };
            await um.CreateAsync(user, "Test@12345678");
            await um.AddToRoleAsync(user, "Viewer");
            ids.Add(user.Id);
        }
        return ids;
    }

    [Fact]
    [Trait("Req", "USR-13")]
    public async Task GetUsers_Page1of2_ReturnsCorrectSubset()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var seeded = await SeedUsersAsync(_fixture.TenantAId, 5);
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, null, null, Page: 1, PageSize: 3)));

        result.Items.Should().HaveCount(3);
        result.TotalCount.Should().BeGreaterThanOrEqualTo(5);
        result.Page.Should().Be(1);
        result.PageSize.Should().Be(3);
    }

    [Fact]
    [Trait("Req", "USR-13")]
    public async Task GetUsers_FilterByIsActive_ReturnsOnlyInactive()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        await SeedUsersAsync(_fixture.TenantAId, 3, inactive: true);
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, null, IsActive: false, Page: 1, PageSize: 50)));

        result.Items.Should().OnlyContain(u => !u.IsActive);
        result.Items.Count.Should().BeGreaterThanOrEqualTo(3);
    }

    [Fact]
    [Trait("Req", "USR-13")]
    public async Task GetUsers_FilterByPG_ReturnsOnlyMatchingPG()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, PermissionGroupId: _fixture.PgAId, null, Page: 1, PageSize: 50)));

        result.Items.Should().OnlyContain(u => u.PermissionGroupId == _fixture.PgAId);
    }

    [Fact]
    [Trait("Req", "USR-14")]
    public async Task Admin_SeesOnlyOwnTenant()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        await SeedUsersAsync(_fixture.TenantAId, 2);
        await SeedUsersAsync(_fixture.TenantBId, 2);
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, null, null, Page: 1, PageSize: 100)));

        result.Items.Should().OnlyContain(u => u.TenantId == _fixture.TenantAId,
            "Admin sees only own tenant users");
    }

    [Fact]
    [Trait("Req", "USR-14")]
    public async Task Superadmin_WithNullTenantId_SeesAllTenants()
    {
        _sp = BuildServiceProvider(_fixture.SuperadminId, _fixture.PlatformTenantId, "Superadmin");
        await SeedUsersAsync(_fixture.TenantAId, 2);
        await SeedUsersAsync(_fixture.TenantBId, 2);
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, null, null, Page: 1, PageSize: 100),
            TenantId: null));

        var tenantIds = result.Items.Select(u => u.TenantId).Distinct().ToList();
        tenantIds.Should().Contain(_fixture.TenantAId);
        tenantIds.Should().Contain(_fixture.TenantBId);
    }

    [Fact]
    [Trait("Req", "USR-14")]
    public async Task Superadmin_WithExplicitTenantFilter_SeesOnlyThatTenant()
    {
        _sp = BuildServiceProvider(_fixture.SuperadminId, _fixture.PlatformTenantId, "Superadmin");
        await SeedUsersAsync(_fixture.TenantAId, 2);
        await SeedUsersAsync(_fixture.TenantBId, 2);
        var sender = _sp.GetRequiredService<ISender>();

        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(null, null, null, null, Page: 1, PageSize: 100),
            TenantId: _fixture.TenantBId));

        result.Items.Should().OnlyContain(u => u.TenantId == _fixture.TenantBId);
    }

    [Fact]
    [Trait("Req", "USR-13")]
    public async Task GetUsers_SearchByEmail_ReturnsMatches()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var searchEmail = $"searchme_{Uuid.NewSequential():N}@local";
        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantAId,
            UserName = searchEmail,
            Email = searchEmail,
            NormalizedUserName = searchEmail.ToUpperInvariant(),
            NormalizedEmail = searchEmail.ToUpperInvariant(),
            EmailConfirmed = true,
            FirstName = "Search",
            LastName = "Test",
            IsActive = true,
            PermissionGroupId = _fixture.PgAId
        };
        await um.CreateAsync(user, "Test@12345678");
        await um.AddToRoleAsync(user, "Viewer");

        var sender = _sp.GetRequiredService<ISender>();
        var result = await sender.Send(new GetUsersQuery(
            new UserListRequest(Search: "searchme", null, null, null, Page: 1, PageSize: 50)));

        result.Items.Should().Contain(u => u.Email.Contains("searchme"));
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
