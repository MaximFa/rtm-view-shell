using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using UUIDNext;

namespace CcDashboard.Infrastructure.Seeding;

/// <summary>
/// Idempotent seed — runs on every startup but only creates missing data [DATA-07].
/// </summary>
public class DatabaseInitializer(
    AppDbContext db,
    AuditDbContext auditDb,
    UserManager<ApplicationUser> userManager,
    RoleManager<ApplicationRole> roleManager,
    IConfiguration config,
    ILogger<DatabaseInitializer> logger)
{
    private static readonly string[] Roles = ["Superadmin", "Administrator", "Editor", "Viewer"];

    public async Task InitializeAsync(CancellationToken ct = default)
    {
        logger.LogInformation("Running database seed...");

        await db.Database.MigrateAsync(ct);
        await auditDb.Database.MigrateAsync(ct);

        await SeedRolesAsync(ct);
        var platformTenant = await SeedPlatformTenantAsync(ct);
        await SeedSuperadminAsync(platformTenant, ct);
        await SeedWidgetCatalogAsync(ct);

        logger.LogInformation("Database seed complete.");
    }

    private async Task SeedRolesAsync(CancellationToken ct)
    {
        foreach (var role in Roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                var result = await roleManager.CreateAsync(new ApplicationRole(role));
                if (result.Succeeded)
                    logger.LogInformation("Created role: {Role}", role);
                else
                    logger.LogError("Failed to create role {Role}: {Errors}", role,
                        string.Join(", ", result.Errors.Select(e => e.Description)));
            }
        }
    }

    private async Task<Tenant> SeedPlatformTenantAsync(CancellationToken ct)
    {
        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Slug == "platform", ct);

        if (tenant == null)
        {
            tenant = new Tenant
            {
                Id = Uuid.NewSequential(),
                Slug = "platform",
                Name = "Platform",
                Status = TenantStatus.Active,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Tenants.Add(tenant);
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Created platform tenant: {Id}", tenant.Id);
        }

        var hasSettings = await db.TenantSettings.IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == tenant.Id, ct);
        if (!hasSettings)
        {
            db.TenantSettings.Add(new TenantSettings { TenantId = tenant.Id });
            await db.SaveChangesAsync(ct);
        }

        return tenant;
    }

    private async Task SeedSuperadminAsync(Tenant platformTenant, CancellationToken ct)
    {
        var email = config["Seed:SuperadminEmail"] ?? "admin@platform.local";

        // Search ignoring tenant GQF
        var existing = await db.Set<ApplicationUser>()
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.TenantId == platformTenant.Id &&
                                      u.NormalizedEmail == email.ToUpperInvariant(), ct);
        if (existing != null) return;

        var password = config["Seed:SuperadminPassword"];
        if (string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning("Seed:SuperadminPassword not configured — superadmin will not be created.");
            return;
        }

        var user = new ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = platformTenant.Id,
            UserName = "admin",
            NormalizedUserName = "ADMIN",
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = true,
            IsActive = true,
            FirstName = "System",
            LastName = "Administrator",
            PreferredLocale = "en-US",
            MustChangePasswordAt = DateTime.UtcNow  // force password change on first login
        };

        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
        {
            logger.LogError("Failed to create superadmin: {Errors}",
                string.Join(", ", result.Errors.Select(e => e.Description)));
            return;
        }

        await userManager.AddToRoleAsync(user, "Superadmin");
        logger.LogInformation("Created superadmin user: {Email}", email);
    }

    private async Task SeedWidgetCatalogAsync(CancellationToken ct)
    {
        if (await db.WidgetCatalogItems.AnyAsync(ct)) return;

        var items = new List<WidgetCatalogItem>
        {
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Queue Summary", Description = "Real-time queue metrics snapshot", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Queue Trend", Description = "Historical queue volume trend chart", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Abandoned Calls", Description = "Abandoned call count and rate", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "SLA Bar", Description = "Service level agreement gauge", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Agent Status", Description = "Live agent state distribution", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Agent List", Description = "Filterable agent roster with states", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Occupancy Gauge", Description = "Agent occupancy percentage gauge", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "KPI Scorecard", Description = "Key performance indicators tile set", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Calls Per Hour", Description = "Hourly call volume bar chart", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "AHT Chart", Description = "Average handle time trend", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Real-time Ticker", Description = "Live event ticker feed", IsActive = true },
        };

        db.WidgetCatalogItems.AddRange(items);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Seeded {Count} widget catalog items.", items.Count);
    }
}
