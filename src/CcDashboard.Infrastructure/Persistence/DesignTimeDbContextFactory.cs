using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// Used by EF Core CLI tools at design time (dotnet ef migrations add ...).
/// Reads connection string from src/CcDashboard.Web/appsettings.json so you don't
/// need the full DI container or a live Redis/tenant context to generate migrations.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(),
                "..", "CcDashboard.Web"))
            .AddJsonFile("appsettings.json", optional: false)
            .Build();

        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(config.GetConnectionString("Default"),
            npg => npg.MigrationsHistoryTable("__ef_migrations_history", "public"));

        return new AppDbContext(optionsBuilder.Options, new DesignTimeTenantContext());
    }
}

public class AuditDbContextFactory : IDesignTimeDbContextFactory<AuditDbContext>
{
    public AuditDbContext CreateDbContext(string[] args)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(),
                "..", "CcDashboard.Web"))
            .AddJsonFile("appsettings.json", optional: false)
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
