using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Caching;
using CcDashboard.Infrastructure.Email;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Infrastructure.Services;
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

        services.AddDbContext<AuditDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(config.GetConnectionString("Default"), npg =>
            {
                npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
            });
        });

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
        .AddDefaultTokenProviders();

        // Redis
        var redisConn = config.GetConnectionString("Redis") ?? "localhost:6379";
        services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisConn));
        services.AddScoped<ICacheService, RedisCacheService>();

        // Audit
        services.AddScoped<IAuditService, AuditService>();

        // Repositories
        services.AddScoped<IDashboardRepository, DashboardRepository>();
        services.AddScoped<IPermissionGroupRepository, PermissionGroupRepository>();
        services.AddScoped<ITenantRepository, TenantRepository>();
        services.AddScoped<IWidgetCatalogRepository, WidgetCatalogRepository>();
        services.AddScoped<IUserRepository, UserRepository>();

        return services;
    }
}
