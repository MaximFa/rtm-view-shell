using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// Used by EF Core CLI tools at design time (dotnet ef migrations add ...).
/// Reads appsettings.json + appsettings.Development.json + User Secrets from
/// CcDashboard.Web so the real connection string is picked up without needing
/// to hard-code credentials here.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var config = BuildConfig();
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(config.GetConnectionString("Default"),
            npg => npg.MigrationsHistoryTable("__ef_migrations_history", "public"));
        return new AppDbContext(optionsBuilder.Options, new DesignTimeTenantContext());
    }

    private static IConfiguration BuildConfig()
    {
        var webDir = Path.Combine(Directory.GetCurrentDirectory(), "..", "CcDashboard.Web");
        return new ConfigurationBuilder()
            .SetBasePath(webDir)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddUserSecrets("c21f2e9c-4d36-4980-a0cd-d777ce1c9e3f")
            .Build();
    }
}

public class AuditDbContextFactory : IDesignTimeDbContextFactory<AuditDbContext>
{
    public AuditDbContext CreateDbContext(string[] args)
    {
        var webDir = Path.Combine(Directory.GetCurrentDirectory(), "..", "CcDashboard.Web");
        var config = new ConfigurationBuilder()
            .SetBasePath(webDir)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddUserSecrets("c21f2e9c-4d36-4980-a0cd-d777ce1c9e3f")
            .Build();

        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(config.GetConnectionString("Default"),
            npg => npg.MigrationsHistoryTable("__ef_migrations_history", "audit"));
        return new AuditDbContext(optionsBuilder.Options);
    }
}

/// <summary>
/// Stub tenant context for design-time migrations — no real tenant resolution needed.
/// </summary>
internal sealed class DesignTimeTenantContext : ITenantContext
{
    public Guid TenantId => Guid.Empty;
    public string TenantSlug => "__design_time__";
    public bool IsResolved => true;
    public void Set(Guid tenantId, string tenantSlug) { }
}
