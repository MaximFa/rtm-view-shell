using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NSubstitute;
using Testcontainers.PostgreSql;
using UUIDNext;

namespace CcDashboard.Tests.Security.Fixtures;

/// <summary>
/// xUnit collection fixture that manages a shared PostgreSQL Testcontainer.
/// Per MC-1: real Postgres required for GQF, inet, xmin, jsonb, pg_trgm.
/// Per MC-6: ICollectionFixture with transactional rollback per test.
/// </summary>
public class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container;

    public string ConnectionString { get; private set; } = null!;

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

    // Dashboard IDs
    public Guid DashboardAId { get; } = Uuid.NewSequential();
    public Guid DashboardBId { get; } = Uuid.NewSequential();

    // Widget catalog item ID (seeded cross-tenant)
    public Guid WidgetCatalogItemId { get; } = Uuid.NewSequential();

    public PostgresFixture()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("ccdashboard_test")
            .WithUsername("test")
            .WithPassword("test")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        // Create initial schema and seed data
        await InitializeDatabaseAsync();
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }

    private async Task InitializeDatabaseAsync()
    {
        var services = new ServiceCollection();

        // Register a no-tenant context for initial migration
        services.AddSingleton<ITenantContext>(new TestTenantContext(PlatformTenantId));

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(ConnectionString));

        services.AddDbContext<AuditDbContext>(options =>
            options.UseNpgsql(ConnectionString));

        // Backend emulation context for T3/T5 test seeding (ADR-007)
        services.AddDbContext<BackendEmulationDbContext>(options =>
            options.UseNpgsql(ConnectionString, npg =>
                npg.MigrationsHistoryTable("__BackendEmulationMigrationsHistory", "public")));

        services.AddIdentityCore<ApplicationUser>()
            .AddRoles<ApplicationRole>()
            .AddEntityFrameworkStores<AppDbContext>();

        var sp = services.BuildServiceProvider();

        await using var scope = sp.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var auditDb = scope.ServiceProvider.GetRequiredService<AuditDbContext>();
        var beDb = scope.ServiceProvider.GetRequiredService<BackendEmulationDbContext>();

        // Apply migrations for all contexts
        await db.Database.MigrateAsync();
        await auditDb.Database.MigrateAsync();
        // ADR-007: Backend tables now owned by BackendEmulationDbContext
        await beDb.Database.MigrateAsync();

        // Seed test data
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

        // Seed users using UserManager to ensure proper password hashing
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

        // Seed permission groups
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

        // Seed dashboards
        var dashA = new Dashboard
        {
            Id = DashboardAId,
            TenantId = TenantAId,
            Name = "Dashboard A",
            Status = DashboardStatus.Published,
            IsPublic = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = UserAId,
            UpdatedByUserId = UserAId
        };

        var dashB = new Dashboard
        {
            Id = DashboardBId,
            TenantId = TenantBId,
            Name = "Dashboard B",
            Status = DashboardStatus.Published,
            IsPublic = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = UserBId,
            UpdatedByUserId = UserBId
        };

        db.Dashboards.AddRange(dashA, dashB);
        await db.SaveChangesAsync();

        // Seed cross-tenant entity: WidgetCatalogItem
        db.WidgetCatalogItems.Add(new WidgetCatalogItem
        {
            Id = WidgetCatalogItemId,
            Category = "Agents",
            Name = "Agent Grid",
            Description = "Real-time agent status grid",
            IsActive = true
        });

        await db.SaveChangesAsync();

        // Seed cross-tenant entity: RtsGridMetric (in BackendEmulationDbContext)
        await using var beDbForMetric = CreateBackendEmulationDbContext();
        beDbForMetric.RtsGridMetrics.Add(new RtsGridMetric
        {
            MetricId = "agent_name",
            Description = "Agent Name",
            MetricType = "Agent",
            ValueType = "String",
            DataType = "string",
            MetricFunction = "value",
            MetricParameter = "agent.name"
        });
        await beDbForMetric.SaveChangesAsync();
    }

    /// <summary>
    /// Creates Queue Grid tables (RTSGrid_*) using raw SQL.
    /// These are in BE context but not in App migrations.
    /// </summary>
    private static async Task CreateQueueGridTablesAsync(BackendEmulationDbContext beDb)
    {
        var sql = @"
            CREATE TABLE IF NOT EXISTS ""RTSGrid_Grid"" (
                ""GridId"" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                ""UnionId"" integer,
                ""StyleId"" integer,
                ""Title"" varchar(100) NOT NULL,
                ""ThresholdScript"" text
            );

            CREATE TABLE IF NOT EXISTS ""RTSGrid_Column"" (
                ""ColumnId"" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                ""GridId"" integer NOT NULL,
                ""ColumnNumber"" integer NOT NULL,
                ""CellTemplateId"" integer
            );

            CREATE TABLE IF NOT EXISTS ""RTSGrid_Row"" (
                ""RowId"" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                ""GridId"" integer NOT NULL,
                ""RowNumber"" integer NOT NULL,
                ""UnionId"" integer,
                ""StyleId"" integer,
                ""ThresholdScript"" text,
                ""OldRowId"" integer
            );

            CREATE TABLE IF NOT EXISTS ""RTSGrid_Cell"" (
                ""CellId"" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                ""RowId"" integer NOT NULL,
                ""ColumnId"" integer NOT NULL,
                ""ColNumber"" integer,
                ""UnionId"" integer,
                ""StyleId"" integer,
                ""CellType"" varchar(50),
                ""Value"" varchar(500),
                ""Tooltip"" varchar(500),
                ""OnClick"" varchar(500),
                ""ThresholdSetId"" integer,
                ""NewRowId"" integer,
                ""OldRowId"" integer
            );
        ";

        await beDb.Database.ExecuteSqlRawAsync(sql);
    }

    /// <summary>
    /// Creates a new DbContext with the specified tenant context.
    /// Use this in tests to simulate queries from different tenants.
    /// </summary>
    public AppDbContext CreateDbContext(Guid tenantId)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(ConnectionString);
        return new AppDbContext(optionsBuilder.Options, new TestTenantContext(tenantId));
    }

    /// <summary>
    /// Creates a new AuditDbContext for reading audit logs in tests.
    /// </summary>
    public AuditDbContext CreateAuditDbContext()
    {
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(ConnectionString);
        return new AuditDbContext(optionsBuilder.Options);
    }

    /// <summary>
    /// Creates a new BackendEmulationDbContext for seeding backend-owned tables in tests (T3/T5).
    /// </summary>
    public BackendEmulationDbContext CreateBackendEmulationDbContext()
    {
        var optionsBuilder = new DbContextOptionsBuilder<BackendEmulationDbContext>();
        optionsBuilder.UseNpgsql(ConnectionString);
        return new BackendEmulationDbContext(optionsBuilder.Options);
    }

    /// <summary>
    /// Alias for CreateBackendEmulationDbContext() per DoD-5.
    /// </summary>
    public BackendEmulationDbContext BeDb => CreateBackendEmulationDbContext();


    /// <summary>
    /// Creates a mock IDbContextFactory that returns DbContext instances for the specified tenant.
    /// Used by handlers that require IDbContextFactory injection.
    /// </summary>
    public IDbContextFactory<AppDbContext> CreateDbContextFactory(Guid tenantId)
    {
        var factory = Substitute.For<IDbContextFactory<AppDbContext>>();
        factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(_ => Task.FromResult(CreateDbContext(tenantId)));
        factory.CreateDbContext()
            .Returns(_ => CreateDbContext(tenantId));
        return factory;
    }

    /// <summary>
    /// Creates a ServiceProvider with Identity and DbContext configured for testing.
    /// </summary>
    public IServiceProvider CreateServiceProvider(Guid tenantId)
    {
        var services = new ServiceCollection();

        services.AddSingleton<ITenantContext>(new TestTenantContext(tenantId));
        services.AddSingleton<IDateTimeProvider, TestDateTimeProvider>();

        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(ConnectionString));

        services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
            {
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
                options.Lockout.AllowedForNewUsers = true;
            })
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders();

        services.AddLogging();

        return services.BuildServiceProvider();
    }
}

/// <summary>
/// Test implementation of ITenantContext.
/// </summary>
public class TestTenantContext(Guid tenantId, string tenantSlug = "test") : ITenantContext
{
    private Guid _tenantId = tenantId;
    private string _tenantSlug = tenantSlug;

    public Guid TenantId => _tenantId;
    public string TenantSlug => _tenantSlug;
    public bool IsResolved => true;

    public void Set(Guid tenantId, string tenantSlug)
    {
        _tenantId = tenantId;
        _tenantSlug = tenantSlug;
    }
}

/// <summary>
/// Test implementation of IDateTimeProvider.
/// </summary>
public class TestDateTimeProvider : IDateTimeProvider
{
    private DateTime? _fixed;

    public DateTime UtcNow => _fixed ?? DateTime.UtcNow;

    public void SetUtcNow(DateTime dt) => _fixed = dt;
    public void Reset() => _fixed = null;
}

/// <summary>
/// xUnit collection definition for sharing PostgresFixture across test classes.
/// </summary>
[CollectionDefinition("Postgres")]
public class PostgresCollection : ICollectionFixture<PostgresFixture>
{
}
