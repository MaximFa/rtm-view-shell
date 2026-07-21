using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.Export;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.BackgroundServices;
using CcDashboard.Infrastructure.Caching;
using CcDashboard.Infrastructure.Email;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Infrastructure.Security;
using CcDashboard.Infrastructure.Seeding;
using CcDashboard.Infrastructure.Reports.Export;
using CcDashboard.Infrastructure.Services;
using CcDashboard.Infrastructure.Wfm;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace CcDashboard.Infrastructure.Extensions;

public static class InfrastructureServiceExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        // Core services
        services.AddScoped<ITenantContext, TenantContext>();
        services.AddSingleton<IDateTimeProvider, DateTimeProvider>();
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddTransient<IEmailSender, SmtpEmailSender>();

        // Database
        services.AddDbContext<AppDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(config.GetConnectionString("Default"), npg =>
            {
                npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                npg.MigrationsHistoryTable("__ef_migrations_history", "public");
            });
        });

        // Factory for Blazor components that need short-lived DbContext instances
        services.AddDbContextFactory<AppDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(config.GetConnectionString("Default"), npg =>
            {
                npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                npg.MigrationsHistoryTable("__ef_migrations_history", "public");
            });
        }, ServiceLifetime.Scoped);

        services.AddDbContext<AuditDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(config.GetConnectionString("Default"), npg =>
            {
                npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                npg.MigrationsHistoryTable("__ef_migrations_history", "audit");
            });
        });

        // Backend emulation context — same database, separate migration history (ADR-007)
        // Migrations run only in dev/test; in production these tables are backend-owned.
        services.AddDbContextFactory<BackendEmulationDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(config.GetConnectionString("Default"), npg =>
            {
                npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
                npg.MigrationsHistoryTable("__BackendEmulationMigrationsHistory", "public");
            });
        });

        // ADR-009: Interface abstractions for handlers in Application
        services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());
        services.AddScoped<IAppDbContextFactory, AppDbContextAbstractionFactory>();
        services.AddScoped<IBackendEmulationDbContext>(sp =>
        {
            var factory = sp.GetRequiredService<IDbContextFactory<BackendEmulationDbContext>>();
            return factory.CreateDbContext();
        });
        services.AddSingleton<IBackendEmulationDbContextFactory, BackendEmulationDbContextFactory>();

        // ASP.NET Core Identity
        services.AddIdentity<ApplicationUser, ApplicationRole>(opts =>
        {
            opts.Password.RequiredLength = 12;
            opts.Password.RequireUppercase = true;
            opts.Password.RequireLowercase = true;
            opts.Password.RequireDigit = true;
            opts.Password.RequireNonAlphanumeric = true;
            opts.Lockout.MaxFailedAccessAttempts = 5;
            opts.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            opts.Lockout.AllowedForNewUsers = true;
            opts.User.RequireUniqueEmail = false; // unique per tenant enforced manually
        })
        .AddEntityFrameworkStores<AppDbContext>()
        .AddDefaultTokenProviders()
        .AddClaimsPrincipalFactory<CustomClaimsPrincipalFactory>();

        // [PWD-03] PBKDF2 with increased iterations
        services.Configure<PasswordHasherOptions>(opts =>
        {
            opts.IterationCount = 100_000;
        });

        // Auth and user management services
        services.AddScoped<IIdentityAuthService, IdentityAuthService>();
        services.AddScoped<IUserManagementService, UserManagementService>();
        services.AddScoped<ITwoFactorService, TwoFactorService>();
        services.AddScoped<ITokenService, TokenService>();

        // Required for IHttpContextAccessor in IdentityAuthService
        services.AddHttpContextAccessor();

        // Seeding
        services.AddScoped<IDatabaseInitializer, DatabaseInitializer>();

        // Redis — abortConnect=false so startup does not throw when Redis is unavailable
        var redisConn = config.GetConnectionString("Redis") ?? "localhost:6379";
        services.AddSingleton<IConnectionMultiplexer>(_ =>
            ConnectionMultiplexer.Connect(ConfigurationOptions.Parse(redisConn + ",abortConnect=false")));
        services.AddScoped<ICacheService, RedisCacheService>();

        // Permission service [PG-04, PG-07]
        services.AddScoped<IPermissionService, PermissionService>();

        // Audit
        services.AddScoped<IAuditService, AuditService>();

        // Repositories
        services.AddScoped<IDashboardRepository, DashboardRepository>();
        services.AddScoped<IDashboardCategoryRepository, DashboardCategoryRepository>();
        services.AddScoped<IPermissionGroupRepository, PermissionGroupRepository>();
        services.AddScoped<ITenantRepository, TenantRepository>();
        services.AddScoped<IWidgetCatalogRepository, WidgetCatalogRepository>();
        services.AddScoped<IWidgetTemplateRepository, WidgetTemplateRepository>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IAuditLogRepository, AuditLogRepository>();
        services.AddScoped<ITenantSettingsRepository, TenantSettingsRepository>();

        // NGC Configuration repositories
        services.AddScoped<INgcSiteRepository, NgcSiteRepository>();
        services.AddScoped<INgcBusinessUnitRepository, NgcBusinessUnitRepository>();
        services.AddScoped<INgcSupergroupRepository, NgcSupergroupRepository>();
        services.AddScoped<IRtsGridMetricRepository, RtsGridMetricRepository>();
        services.AddScoped<INgcQueueRepository, NgcQueueRepository>();
        services.AddScoped<INgcAgentGroupRepository, NgcAgentGroupRepository>();

        // RTS repositories
        services.AddScoped<IRtsRepository, RtsRepository>();

        // Historical Reports (CC-HIST-001)
        services.AddScoped<IHistoricalReportRepository, HistoricalReportRepository>();
        services.AddScoped<IReportScopeResolver, ReportScopeResolver>();
        services.AddScoped<IBuMembershipResolver, BuMembershipResolver>();
        services.AddScoped<IReportWidgetScopeService, ReportWidgetScopeService>();
        services.AddHostedService<HistoricalAggregationService>();
        services.AddHostedService<ArchiverService>();

        // Report screen CRUD (CC-HIST-F5a)
        services.AddScoped<IReportScreenRepository, ReportScreenRepository>();

        // Report export (CC-HIST-F6)
        services.AddScoped<IReportExporter, ClosedXmlReportExporter>();

        // API hook (no-op until CC-platform API is available)
        services.AddScoped<IConfigurationApiHook, RtmConfigurationApiHook>();
        services.AddHttpClient("RtmServer", client =>
        {
            client.Timeout = TimeSpan.FromSeconds(5);
        });

        // NOTE: MediatR handlers moved to Application per ADR-009 (R2).
        // Application assembly is scanned by Web/Api Program.cs, not here.

        // WFM Phase 1: Erlang calculator (pure math, no I/O)
        services.AddScoped<IErlangCalculatorService, ErlangCalculatorService>();

        return services;
    }
}
