using System.Collections.Concurrent;
using System.Reflection;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Seeding;
using CcDashboard.Web.Middleware;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using StackExchange.Redis;
using Testcontainers.PostgreSql;
using Testcontainers.Redis;
using UUIDNext;

namespace CcDashboard.Tests.Security.Fixtures;

/// <summary>
/// WebApplicationFactory-based fixture for golden-path auth tests.
/// Per MC-C1: WebApplicationFactory&lt;Program&gt; with ConfigureWebHost overriding data-layer registrations.
/// Per MC-C2: CreateClient with HandleCookies=true (default).
/// Per MC-C3: CookieAuthenticationOptions.SecurePolicy = None for HTTP tests.
/// Per MC-C4: Composes PostgresFixture + RedisFixture internally (one Testcontainer each, shared via ICollectionFixture).
///
/// Note: This fixture tests against the real ASP.NET Core pipeline with cookie authentication.
/// Production composition (middleware order, options binding, auth handlers) is NOT re-implemented —
/// only data-layer registrations (Postgres/Redis) are swapped to Testcontainers.
/// </summary>
public class WebFixture : IAsyncLifetime
{
    private WebApplicationFactory<Program>? _factory;
    private readonly PostgreSqlContainer _postgresContainer;
    private readonly RedisContainer _redisContainer;
    private IConnectionMultiplexer? _redisConnection;

    public WebApplicationFactory<Program> Factory => _factory
        ?? throw new InvalidOperationException("WebFixture not initialized.");

    public string PostgresConnectionString { get; private set; } = null!;
    public string RedisConnectionString { get; private set; } = null!;
    public IConnectionMultiplexer RedisConnection => _redisConnection
        ?? throw new InvalidOperationException("WebFixture not initialized.");

    // Seed tenant IDs for test isolation
    public Guid TenantAId { get; } = Uuid.NewSequential();
    public Guid TenantBId { get; } = Uuid.NewSequential();
    public Guid PlatformTenantId { get; } = Uuid.NewSequential();

    // Seed user IDs
    public Guid UserAId { get; } = Uuid.NewSequential();
    public Guid UserBId { get; } = Uuid.NewSequential();
    public Guid SuperadminId { get; } = Uuid.NewSequential();

    // Permission group IDs
    public Guid PgAId { get; } = Uuid.NewSequential();
    public Guid PgBId { get; } = Uuid.NewSequential();

    public WebFixture()
    {
        _postgresContainer = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("ccdashboard_web_test")
            .WithUsername("test")
            .WithPassword("test")
            .Build();

        _redisContainer = new RedisBuilder()
            .WithImage("redis:7-alpine")
            .Build();
    }

    public async Task InitializeAsync()
    {
        // Start containers in parallel
        await Task.WhenAll(
            _postgresContainer.StartAsync(),
            _redisContainer.StartAsync());

        PostgresConnectionString = _postgresContainer.GetConnectionString();
        RedisConnectionString = _redisContainer.GetConnectionString();
        _redisConnection = await ConnectionMultiplexer.ConnectAsync($"{RedisConnectionString},allowAdmin=true");

        // [Backlog #14] Clear LoginRateLimitMiddleware static state to prevent rate-limit
        // exhaustion when multiple test collections run sequentially. The middleware uses
        // a static ConcurrentDictionary keyed by IP; all WAF tests share loopback IP,
        // so without clearing, tests fail with 429 after ~10 cumulative logins.
        ClearLoginRateLimitState();

        // Initialize database schema and seed data
        await InitializeDatabaseAsync();

        // Create WebApplicationFactory
        _factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");

                builder.ConfigureAppConfiguration((context, config) =>
                {
                    var settings = new Dictionary<string, string?>
                    {
                        ["ConnectionStrings:Default"] = PostgresConnectionString,
                        ["ConnectionStrings:Redis"] = RedisConnectionString,
                        ["Jwt:SecretKey"] = "dev-only-test-secret-key-that-is-at-least-32-bytes-long",
                        ["Jwt:Issuer"] = "CcDashboard.Tests",
                        ["Jwt:Audience"] = "CcDashboard.Tests",
                        // Default to tenant-a for test requests; use host header for others
                        ["DefaultTenantSlug"] = "tenant-a",
                    };
                    config.AddInMemoryCollection(settings);
                });

                builder.ConfigureTestServices(services =>
                {
                    // MC-C3: Override CookieAuthenticationOptions.SecurePolicy = None for HTTP tests.
                    services.PostConfigure<CookieAuthenticationOptions>(
                        WebIdentityConstants.ApplicationScheme,
                        options =>
                        {
                            options.Cookie.SecurePolicy = CookieSecurePolicy.None;
                        });

                    services.PostConfigure<CookieAuthenticationOptions>(
                        WebIdentityConstants.TwoFactorUserIdScheme,
                        options =>
                        {
                            options.Cookie.SecurePolicy = CookieSecurePolicy.None;
                        });

                    // Replace Redis connection with test container
                    var redisDescriptor = services.SingleOrDefault(
                        d => d.ServiceType == typeof(IConnectionMultiplexer));
                    if (redisDescriptor != null)
                        services.Remove(redisDescriptor);

                    services.AddSingleton<IConnectionMultiplexer>(_redisConnection!);

                    // Replace DatabaseInitializer with no-op to prevent duplicate migrations.
                    // The fixture has already migrated and seeded the database.
                    services.RemoveAll<DatabaseInitializer>();
                    services.AddScoped<DatabaseInitializer, NoOpDatabaseInitializer>();
                });
            });
    }

    public async Task DisposeAsync()
    {
        if (_factory != null)
            await _factory.DisposeAsync();

        _redisConnection?.Dispose();

        await Task.WhenAll(
            _postgresContainer.DisposeAsync().AsTask(),
            _redisContainer.DisposeAsync().AsTask());
    }

    private async Task InitializeDatabaseAsync()
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(PlatformTenantId));

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(PostgresConnectionString));

        // Also add AuditDbContext for audit schema
        services.AddDbContext<AuditDbContext>(options =>
            options.UseNpgsql(PostgresConnectionString));

        services.AddIdentityCore<ApplicationUser>()
            .AddRoles<ApplicationRole>()
            .AddEntityFrameworkStores<AppDbContext>();

        var sp = services.BuildServiceProvider();

        await using var scope = sp.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var auditDb = scope.ServiceProvider.GetRequiredService<AuditDbContext>();

        // Migrate both contexts (main data + audit schema)
        await db.Database.MigrateAsync();
        await auditDb.Database.MigrateAsync();

        await SeedTestDataAsync(db, scope.ServiceProvider);
    }

    private async Task SeedTestDataAsync(AppDbContext db, IServiceProvider sp)
    {
        var userManager = sp.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = sp.GetRequiredService<RoleManager<ApplicationRole>>();
        var now = DateTime.UtcNow;

        // Seed roles
        var roles = new[] { "Superadmin", "Administrator", "Editor", "Viewer" };
        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new ApplicationRole(role) { Id = Uuid.NewSequential() });
        }

        // Seed tenants
        var platformTenant = new Tenant
        {
            Id = PlatformTenantId,
            Slug = "platform",
            Name = "Platform",
            Status = TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        };

        var tenantA = new Tenant
        {
            Id = TenantAId,
            Slug = "tenant-a",
            Name = "Tenant A",
            Status = TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        };

        var tenantB = new Tenant
        {
            Id = TenantBId,
            Slug = "tenant-b",
            Name = "Tenant B",
            Status = TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        };

        db.Tenants.AddRange(platformTenant, tenantA, tenantB);
        await db.SaveChangesAsync();

        // Seed tenant settings
        db.TenantSettings.AddRange(
            new TenantSettings { TenantId = PlatformTenantId, DefaultLocale = "en-US" },
            new TenantSettings { TenantId = TenantAId, DefaultLocale = "en-US" },
            new TenantSettings { TenantId = TenantBId, DefaultLocale = "en-US" }
        );
        await db.SaveChangesAsync();

        // Seed permission groups first (needed for user FK)
        var pgA = new PermissionGroup
        {
            Id = PgAId,
            TenantId = TenantAId,
            Name = "Editors A",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = UserAId,
            UpdatedByUserId = UserAId
        };

        var pgB = new PermissionGroup
        {
            Id = PgBId,
            TenantId = TenantBId,
            Name = "Editors B",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = UserBId,
            UpdatedByUserId = UserBId
        };

        db.PermissionGroups.AddRange(pgA, pgB);
        await db.SaveChangesAsync();

        // Seed users
        var userA = new ApplicationUser
        {
            Id = UserAId,
            TenantId = TenantAId,
            UserName = "user.a@tenant-a.local",
            Email = "user.a@tenant-a.local",
            NormalizedUserName = "USER.A@TENANT-A.LOCAL",
            NormalizedEmail = "USER.A@TENANT-A.LOCAL",
            EmailConfirmed = true,
            FirstName = "User",
            LastName = "A",
            IsActive = true,
            PermissionGroupId = PgAId
        };
        await userManager.CreateAsync(userA, "Test@123456");
        await userManager.AddToRoleAsync(userA, "Editor");

        var userB = new ApplicationUser
        {
            Id = UserBId,
            TenantId = TenantBId,
            UserName = "user.b@tenant-b.local",
            Email = "user.b@tenant-b.local",
            NormalizedUserName = "USER.B@TENANT-B.LOCAL",
            NormalizedEmail = "USER.B@TENANT-B.LOCAL",
            EmailConfirmed = true,
            FirstName = "User",
            LastName = "B",
            IsActive = true,
            PermissionGroupId = PgBId
        };
        await userManager.CreateAsync(userB, "Test@123456");
        await userManager.AddToRoleAsync(userB, "Editor");

        var superadmin = new ApplicationUser
        {
            Id = SuperadminId,
            TenantId = PlatformTenantId,
            UserName = "superadmin@platform.local",
            Email = "superadmin@platform.local",
            NormalizedUserName = "SUPERADMIN@PLATFORM.LOCAL",
            NormalizedEmail = "SUPERADMIN@PLATFORM.LOCAL",
            EmailConfirmed = true,
            FirstName = "Super",
            LastName = "Admin",
            IsActive = true
        };
        await userManager.CreateAsync(superadmin, "Admin@123456");
        await userManager.AddToRoleAsync(superadmin, "Superadmin");
    }

    /// <summary>
    /// Clears the static rate-limit state in LoginRateLimitMiddleware [Backlog #14].
    /// The middleware uses a static ConcurrentDictionary to track login attempts per IP.
    /// Because all WebApplicationFactory tests share the loopback IP (127.0.0.1 / ::1),
    /// cumulative logins across tests exhaust the 10-per-minute budget and cause 429 errors.
    /// This method uses reflection to clear that dictionary, ensuring test isolation.
    /// </summary>
    public static void ClearLoginRateLimitState()
    {
        var middlewareType = typeof(LoginRateLimitMiddleware);
        var entriesField = middlewareType.GetField("_entries", BindingFlags.NonPublic | BindingFlags.Static);
        if (entriesField?.GetValue(null) is System.Collections.IDictionary dict)
        {
            dict.Clear();
        }
    }

    /// <summary>
    /// Creates an HttpClient with cookies enabled (default behavior per MC-C2).
    /// Each test should call this to get a fresh client.
    /// </summary>
    public HttpClient CreateClient() => Factory.CreateClient(new WebApplicationFactoryClientOptions
    {
        HandleCookies = true,
        AllowAutoRedirect = true,
    });

    /// <summary>
    /// Creates an HttpClient that does not follow redirects.
    /// Useful for testing redirect responses directly.
    /// </summary>
    public HttpClient CreateClientNoRedirect() => Factory.CreateClient(new WebApplicationFactoryClientOptions
    {
        HandleCookies = true,
        AllowAutoRedirect = false,
    });

    /// <summary>
    /// Creates a new DbContext with the specified tenant context for direct DB operations in tests.
    /// </summary>
    public AppDbContext CreateDbContext(Guid tenantId)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(PostgresConnectionString);
        return new AppDbContext(optionsBuilder.Options, new TestTenantContext(tenantId));
    }

    /// <summary>
    /// Performs a full login through the ASP.NET Core pipeline.
    /// Returns the HttpClient with cookies set after successful authentication.
    /// </summary>
    /// <param name="username">The username to login with.</param>
    /// <param name="password">The password.</param>
    /// <param name="tenantSlug">Optional tenant slug. Uses default tenant-a if not specified.</param>
    /// <returns>A tuple containing the HttpClient (with cookies), the login response, and whether a redirect occurred.</returns>
    public async Task<LoginResult> LoginAsync(string username, string password, string? tenantSlug = null)
    {
        // [Backlog #14] Clear rate-limit state before each login to prevent 429 errors
        // when multiple tests use LoginAsync within the same test run.
        ClearLoginRateLimitState();

        var client = CreateClientNoRedirect();

        // Set host header if a specific tenant is requested
        if (!string.IsNullOrEmpty(tenantSlug))
        {
            client.DefaultRequestHeaders.Host = $"{tenantSlug}.localhost";
        }

        // 1. GET the login page to retrieve antiforgery token
        var loginPageResponse = await client.GetAsync("/login");
        var loginHtml = await loginPageResponse.Content.ReadAsStringAsync();

        // Extract antiforgery token from the hidden input
        var tokenMatch = System.Text.RegularExpressions.Regex.Match(
            loginHtml,
            @"<input[^>]*name=""__RequestVerificationToken""[^>]*value=""([^""]+)""",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        var antiforgeryToken = tokenMatch.Success ? tokenMatch.Groups[1].Value : string.Empty;

        // 2. POST login credentials
        // Blazor 8 SSR forms require "_handler" field to identify the form (from @formname)
        var formContent = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Model.UserName"] = username,
            ["Model.Password"] = password,
            ["__RequestVerificationToken"] = antiforgeryToken,
            ["_handler"] = "login",  // Must match @formname="login" in LoginPage.razor
        });

        var loginResponse = await client.PostAsync("/login", formContent);

        // Get the location header (may be absolute or relative URL)
        var locationStr = loginResponse.Headers.Location?.ToString() ?? "";

        // Check if we got redirected to success destination
        // Handle both absolute (http://tenant-a.localhost/screens) and relative (/screens) URLs
        var isRedirect = loginResponse.StatusCode == System.Net.HttpStatusCode.Redirect
                         || loginResponse.StatusCode == System.Net.HttpStatusCode.Found;
        var isSuccessRedirect = isRedirect
            && (locationStr.Contains("/screens") || locationStr.Contains("/change-password"));

        var is2faRequired = isRedirect && locationStr.Contains("/login/2fa");

        // Check for session limit exceeded (look for error message in content if not redirected)
        var isSessionLimitExceeded = false;
        if (!isRedirect && loginResponse.StatusCode == System.Net.HttpStatusCode.OK)
        {
            var content = await loginResponse.Content.ReadAsStringAsync();
            isSessionLimitExceeded = content.Contains("SessionLimitExceeded")
                                     || content.Contains("session limit")
                                     || content.Contains("concurrent connections");
        }

        return new LoginResult(client, loginResponse, isSuccessRedirect, is2faRequired, isSessionLimitExceeded);
    }

    /// <summary>
    /// Performs a full login with a custom IP address (via X-Forwarded-For header).
    /// Useful for testing LICENSE-SESSION concurrent connection limits.
    /// </summary>
    public async Task<LoginResult> LoginAsync(string username, string password, string? tenantSlug, string ipAddress)
    {
        // [Backlog #14] Clear rate-limit state before each login to prevent 429 errors
        // when multiple tests use LoginAsync within the same test run.
        ClearLoginRateLimitState();

        var client = CreateClientNoRedirect();

        // Set host header if a specific tenant is requested
        if (!string.IsNullOrEmpty(tenantSlug))
        {
            client.DefaultRequestHeaders.Host = $"{tenantSlug}.localhost";
        }

        // Set X-Forwarded-For to simulate specific client IP
        client.DefaultRequestHeaders.Add("X-Forwarded-For", ipAddress);

        // 1. GET the login page to retrieve antiforgery token
        var loginPageResponse = await client.GetAsync("/login");
        var loginHtml = await loginPageResponse.Content.ReadAsStringAsync();

        // Extract antiforgery token from the hidden input
        var tokenMatch = System.Text.RegularExpressions.Regex.Match(
            loginHtml,
            @"<input[^>]*name=""__RequestVerificationToken""[^>]*value=""([^""]+)""",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        var antiforgeryToken = tokenMatch.Success ? tokenMatch.Groups[1].Value : string.Empty;

        // 2. POST login credentials
        var formContent = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Model.UserName"] = username,
            ["Model.Password"] = password,
            ["__RequestVerificationToken"] = antiforgeryToken,
            ["_handler"] = "login",
        });

        var loginResponse = await client.PostAsync("/login", formContent);

        // Get the location header (may be absolute or relative URL)
        var locationStr = loginResponse.Headers.Location?.ToString() ?? "";

        // Check if we got redirected to success destination
        var isRedirect = loginResponse.StatusCode == System.Net.HttpStatusCode.Redirect
                         || loginResponse.StatusCode == System.Net.HttpStatusCode.Found;
        var isSuccessRedirect = isRedirect
            && (locationStr.Contains("/screens") || locationStr.Contains("/change-password"));

        var is2faRequired = isRedirect && locationStr.Contains("/login/2fa");

        // Check for session limit exceeded
        var isSessionLimitExceeded = false;
        if (!isRedirect && loginResponse.StatusCode == System.Net.HttpStatusCode.OK)
        {
            var content = await loginResponse.Content.ReadAsStringAsync();
            isSessionLimitExceeded = content.Contains("SessionLimitExceeded")
                                     || content.Contains("session limit")
                                     || content.Contains("concurrent connections");
        }

        return new LoginResult(client, loginResponse, isSuccessRedirect, is2faRequired, isSessionLimitExceeded);
    }

    /// <summary>
    /// Sets the MaxConcurrentConnections limit for a tenant.
    /// </summary>
    public async Task SetMaxConcurrentConnectionsAsync(Guid tenantId, int limit)
    {
        await using var db = CreateDbContext(tenantId);
        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == tenantId);

        if (settings != null)
        {
            settings.MaxConcurrentConnections = limit;
            await db.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Clears all user sessions for a specific user.
    /// </summary>
    public async Task ClearUserSessionsAsync(Guid userId)
    {
        await using var db = CreateDbContext(PlatformTenantId);
        var sessions = await db.UserSessions.IgnoreQueryFilters()
            .Where(s => s.UserId == userId)
            .ToListAsync();
        db.UserSessions.RemoveRange(sessions);
        await db.SaveChangesAsync();
    }

    /// <summary>
    /// Creates a user session for testing purposes.
    /// </summary>
    public async Task CreateUserSessionAsync(Guid userId, Guid tenantId, string ipAddress, bool expired = false, bool revoked = false)
    {
        await using var db = CreateDbContext(PlatformTenantId);
        var now = DateTime.UtcNow;
        db.UserSessions.Add(new UserSession
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = tenantId,
            IpAddress = ipAddress,
            UserAgent = "TestAgent",
            CreatedAt = now.AddHours(-1),
            ExpiresAt = expired ? now.AddHours(-1) : now.AddHours(8),
            IsRevoked = revoked
        });
        await db.SaveChangesAsync();
    }
}

/// <summary>
/// Result of a login attempt through WebFixture.
/// </summary>
public record LoginResult(
    HttpClient Client,
    HttpResponseMessage Response,
    bool IsSuccessRedirect,
    bool Is2faRequired,
    bool IsSessionLimitExceeded = false) : IDisposable
{
    public void Dispose() => Client.Dispose();
}

/// <summary>
/// Marker class for Identity scheme names in test code.
/// </summary>
internal static class WebIdentityConstants
{
    public const string ApplicationScheme = "Identity.Application";
    public const string TwoFactorUserIdScheme = "Identity.TwoFactorUserId";
}

/// <summary>
/// xUnit collection definition for WebFixture tests.
/// </summary>
[CollectionDefinition("Web")]
public class WebCollection : ICollectionFixture<WebFixture>
{
}

/// <summary>
/// No-op DatabaseInitializer for tests.
/// The WebFixture has already migrated and seeded the database,
/// so we skip the app's startup initialization to avoid duplicate migrations.
/// </summary>
internal class NoOpDatabaseInitializer : DatabaseInitializer
{
    public NoOpDatabaseInitializer()
        : base(null!, null!, null!, null!, null!, null!)
    {
    }

    public override Task InitializeAsync(CancellationToken ct = default)
    {
        return Task.CompletedTask;
    }
}
