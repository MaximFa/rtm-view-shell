using CcDashboard.Application.Interfaces;
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
/// Integration tests for password reset flows (DoD-A8).
/// Covers USR-11, USR-12, BFP-03.
/// </summary>
[Collection("Postgres")]
public class PasswordResetTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private IServiceProvider _sp = null!;
    private Mock<IEmailSender> _emailMock = null!;

    public PasswordResetTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => Task.CompletedTask;
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
                options.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultProvider;
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddLogging();

        return services.BuildServiceProvider();
    }

    private async Task<Guid> CreateTestUserAsync(Guid tenantId, string email)
    {
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            UserName = email,
            Email = email,
            NormalizedUserName = email.ToUpperInvariant(),
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = true,
            FirstName = "Reset",
            LastName = "Test",
            IsActive = true
        };
        await um.CreateAsync(user, "Test@12345678");
        await um.AddToRoleAsync(user, "Editor");
        return user.Id;
    }

    [Fact]
    [Trait("Req", "USR-11")]
    public async Task AdminResetPassword_SendsEmail_WithToken()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var email = $"adminreset_{Uuid.NewSequential():N}@local";
        var userId = await CreateTestUserAsync(_fixture.TenantAId, email);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.AdminResetPasswordAsync(userId, "https://app.local/reset");

        ok.Should().BeTrue(err);
        _emailMock.Verify(e => e.SendAsync(
            email,
            It.Is<string>(s => s.Contains("Reset")),
            It.Is<string>(body =>
                body.Contains("https://app.local/reset") &&
                body.Contains("token=")),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    [Trait("Req", "USR-11")]
    [Trait("Req", "GAP-T6-02")]
    public async Task AdminResetPassword_CrossTenant_Rejected()
    {
        _sp = BuildServiceProvider(_fixture.UserAId, _fixture.TenantAId, "Administrator");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var (ok, err) = await svc.AdminResetPasswordAsync(_fixture.UserBId, "https://app.local/reset");

        ok.Should().BeFalse("cross-tenant admin reset blocked");
        err.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "USR-12")]
    public async Task RequestPasswordReset_KnownEmail_SendsEmail()
    {
        _sp = BuildServiceProvider(Guid.Empty, _fixture.TenantAId, "");
        var email = $"selfreset_{Uuid.NewSequential():N}@local";
        await CreateTestUserAsync(_fixture.TenantAId, email);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        await svc.RequestPasswordResetAsync(_fixture.TenantAId, email, "https://app.local/reset");

        _emailMock.Verify(e => e.SendAsync(
            email,
            It.IsAny<string>(),
            It.Is<string>(body => body.Contains("https://app.local/reset")),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    [Trait("Req", "USR-12")]
    [Trait("Req", "BFP-03")]
    public async Task RequestPasswordReset_UnknownEmail_NoException_NoEmail()
    {
        _sp = BuildServiceProvider(Guid.Empty, _fixture.TenantAId, "");
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var act = async () => await svc.RequestPasswordResetAsync(
            _fixture.TenantAId,
            $"nonexistent_{Uuid.NewSequential():N}@local",
            "https://app.local/reset");

        await act.Should().NotThrowAsync("uniform response regardless of email existence");
        _emailMock.Verify(e => e.SendAsync(
            It.IsAny<string>(),
            It.IsAny<string>(),
            It.IsAny<string>(),
            It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    [Trait("Req", "USR-12")]
    public async Task ResetPasswordWithToken_ValidToken_ChangesPassword()
    {
        _sp = BuildServiceProvider(Guid.Empty, _fixture.TenantAId, "");
        var email = $"tokenreset_{Uuid.NewSequential():N}@local";
        var userId = await CreateTestUserAsync(_fixture.TenantAId, email);
        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await um.FindByIdAsync(userId.ToString());
        var token = await um.GeneratePasswordResetTokenAsync(user!);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var result = await svc.ResetPasswordWithTokenAsync(
            _fixture.TenantAId, email, token, "NewPass@12345678");

        result.Succeeded.Should().BeTrue(result.Error);

        var canLogin = await um.CheckPasswordAsync(user!, "NewPass@12345678");
        canLogin.Should().BeTrue();
    }

    [Fact]
    [Trait("Req", "USR-12")]
    public async Task ResetPasswordWithToken_InvalidToken_Fails()
    {
        _sp = BuildServiceProvider(Guid.Empty, _fixture.TenantAId, "");
        var email = $"badtoken_{Uuid.NewSequential():N}@local";
        await CreateTestUserAsync(_fixture.TenantAId, email);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var result = await svc.ResetPasswordWithTokenAsync(
            _fixture.TenantAId, email, "invalid-token", "NewPass@12345678");

        result.Succeeded.Should().BeFalse();
        result.Error.Should().NotBeNullOrEmpty();
    }

    [Fact]
    [Trait("Req", "USR-12")]
    public async Task ResetPasswordWithToken_ClearsMustChangePasswordAt()
    {
        _sp = BuildServiceProvider(Guid.Empty, _fixture.TenantAId, "");
        var email = $"clearmust_{Uuid.NewSequential():N}@local";
        var userId = await CreateTestUserAsync(_fixture.TenantAId, email);

        var um = _sp.GetRequiredService<UserManager<ApplicationUser>>();
        var user = await um.FindByIdAsync(userId.ToString());
        user!.MustChangePasswordAt = DateTime.UtcNow;
        await um.UpdateAsync(user);

        var token = await um.GeneratePasswordResetTokenAsync(user);
        var svc = _sp.GetRequiredService<IUserManagementService>();

        var result = await svc.ResetPasswordWithTokenAsync(
            _fixture.TenantAId, email, token, "NewPass@12345678");

        result.Succeeded.Should().BeTrue();

        user = await um.FindByIdAsync(userId.ToString());
        user!.MustChangePasswordAt.Should().BeNull("MustChangePasswordAt cleared after reset");
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
    public bool IsAuthenticated => role != "";
}
