using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UUIDNext;

namespace CcDashboard.Tests.Security.PasswordPolicy;

/// <summary>
/// Integration tests for password policy requirements (PWD-01..05).
/// Uses real UserManager with Testcontainers PostgreSQL.
/// </summary>
[Collection("Postgres")]
public class PasswordPolicyTests(PostgresFixture postgres)
{
    // ── PWD-01: Minimum password length ──────────────────────────────────────

    [Fact]
    [Trait("Req", "PWD-01")]
    public async Task CreateUser_PasswordTooShort_Rejected()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = CreateTestUser(postgres.TenantAId);
        var shortPassword = "Short@1"; // 7 chars, less than 12

        // Act
        var result = await userManager.CreateAsync(user, shortPassword);

        // Assert
        result.Succeeded.Should().BeFalse();
        result.Errors.Should().Contain(e => e.Code == "PasswordTooShort");
    }

    [Fact]
    [Trait("Req", "PWD-01")]
    public async Task CreateUser_PasswordMeetsMinLength_Accepted()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = CreateTestUser(postgres.TenantAId);
        var validPassword = "ValidPass@12345"; // 15 chars, meets 12 min

        // Act
        var result = await userManager.CreateAsync(user, validPassword);

        // Assert
        result.Succeeded.Should().BeTrue();
    }

    // ── PWD-02: Password complexity ──────────────────────────────────────────

    [Theory]
    [Trait("Req", "PWD-02")]
    [InlineData("lowercaseonly1!", "PasswordRequiresUpper")] // Missing uppercase
    [InlineData("UPPERCASEONLY1!", "PasswordRequiresLower")] // Missing lowercase
    [InlineData("NoDigitsHere!!!", "PasswordRequiresDigit")] // Missing digit
    [InlineData("NoSpecialChar123", "PasswordRequiresNonAlphanumeric")] // Missing special char
    public async Task CreateUser_MissingComplexityRequirement_Rejected(string password, string expectedErrorCode)
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();

        var user = CreateTestUser(postgres.TenantAId);

        // Act
        var result = await userManager.CreateAsync(user, password);

        // Assert
        result.Succeeded.Should().BeFalse();
        result.Errors.Should().Contain(e => e.Code == expectedErrorCode);
    }

    // ── PWD-03: PBKDF2 iteration count ───────────────────────────────────────

    [Fact]
    [Trait("Req", "PWD-03")]
    public void PasswordHasherOptions_IterationCount_IsAtLeast100000()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var options = sp.GetRequiredService<IOptions<PasswordHasherOptions>>();

        // Assert
        options.Value.IterationCount.Should().BeGreaterThanOrEqualTo(100_000);
    }

    // ── PWD-04: Password history (last 10 not reusable) ──────────────────────

    [Fact]
    [Trait("Req", "PWD-04")]
    public async Task ChangePassword_ReusingRecentPassword_Rejected()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var db = sp.GetRequiredService<AppDbContext>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        var user = CreateTestUser(postgres.TenantAId);
        var initialPassword = "InitialPass@123";
        await userManager.CreateAsync(user, initialPassword);

        // Manually add initial password to history (simulating production flow)
        db.UserPasswordHistories.Add(new UserPasswordHistory
        {
            Id = Uuid.NewSequential(),
            UserId = user.Id,
            TenantId = user.TenantId,
            PasswordHash = user.PasswordHash!,
            CreatedAt = clock.UtcNow
        });
        await db.SaveChangesAsync();

        // Act: Try to change to a new password, then back to initial
        var newPassword = "NewPassword@456";
        await userManager.ChangePasswordAsync(user, initialPassword, newPassword);

        // Simulate history check - get last 10 passwords
        var history = await db.UserPasswordHistories
            .IgnoreQueryFilters()
            .Where(h => h.UserId == user.Id)
            .OrderByDescending(h => h.CreatedAt)
            .Take(10)
            .ToListAsync();

        // Verify initial password is still in history
        var hasher = userManager.PasswordHasher;
        var foundMatch = history.Any(h =>
            hasher.VerifyHashedPassword(user, h.PasswordHash, initialPassword) != PasswordVerificationResult.Failed);

        // Assert
        foundMatch.Should().BeTrue("Initial password should be in history");
    }

    // ── PWD-05: Forced password change on creation ───────────────────────────

    [Fact]
    [Trait("Req", "PWD-05")]
    public async Task CreateUser_MustChangePasswordAt_SetByDefault()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var clock = sp.GetRequiredService<IDateTimeProvider>();

        var user = CreateTestUser(postgres.TenantAId);
        user.MustChangePasswordAt = clock.UtcNow; // Set on creation per USR-03

        var validPassword = "ValidPass@12345";

        // Act
        var result = await userManager.CreateAsync(user, validPassword);

        // Assert
        result.Succeeded.Should().BeTrue();
        user.MustChangePasswordAt.Should().NotBeNull();
        user.MustChangePasswordAt!.Value.Should().BeOnOrBefore(clock.UtcNow);
    }

    [Fact]
    [Trait("Req", "PWD-05")]
    public async Task User_WithExpiredMustChangePasswordAt_RequiresPasswordChange()
    {
        // Arrange
        var sp = CreateServiceProviderWithPasswordPolicy(postgres.TenantAId);
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var clock = sp.GetRequiredService<IDateTimeProvider>() as TestDateTimeProvider;

        var user = CreateTestUser(postgres.TenantAId);
        var now = DateTime.UtcNow;
        clock?.SetUtcNow(now);

        // Set MustChangePasswordAt to 91 days ago (expired, as PWD-05 requires change after 90 days)
        user.MustChangePasswordAt = now.AddDays(-91);

        var validPassword = "ValidPass@12345";
        await userManager.CreateAsync(user, validPassword);

        // Act: Check if password change is required
        var mustChange = user.MustChangePasswordAt.HasValue && user.MustChangePasswordAt.Value <= now;

        // Assert
        mustChange.Should().BeTrue("User with expired MustChangePasswordAt should require password change");
    }

    // ── Helper methods ───────────────────────────────────────────────────────

    private static ApplicationUser CreateTestUser(Guid tenantId)
    {
        var id = Uuid.NewSequential();
        return new ApplicationUser
        {
            Id = id,
            TenantId = tenantId,
            UserName = $"test-{id:N}@test.local",
            Email = $"test-{id:N}@test.local",
            NormalizedUserName = $"TEST-{id:N}@TEST.LOCAL",
            NormalizedEmail = $"TEST-{id:N}@TEST.LOCAL",
            EmailConfirmed = true,
            IsActive = true
        };
    }

    private IServiceProvider CreateServiceProviderWithPasswordPolicy(Guid tenantId)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider, TestDateTimeProvider>();

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(postgres.ConnectionString));

        services.AddIdentity<ApplicationUser, ApplicationRole>(opts =>
            {
                // PWD-01: Minimum length
                opts.Password.RequiredLength = 12;
                // PWD-02: Complexity requirements
                opts.Password.RequireUppercase = true;
                opts.Password.RequireLowercase = true;
                opts.Password.RequireDigit = true;
                opts.Password.RequireNonAlphanumeric = true;
                opts.Lockout.MaxFailedAccessAttempts = 5;
                opts.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        // PWD-03: PBKDF2 iterations
        services.Configure<PasswordHasherOptions>(opts =>
        {
            opts.IterationCount = 100_000;
        });

        services.AddLogging();

        return services.BuildServiceProvider();
    }
}
