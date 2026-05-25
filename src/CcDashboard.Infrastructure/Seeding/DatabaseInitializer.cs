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

    public virtual async Task InitializeAsync(CancellationToken ct = default)
    {
        logger.LogInformation("Running database seed...");

        await db.Database.MigrateAsync(ct);
        await auditDb.Database.MigrateAsync(ct);

        await SeedRolesAsync(ct);
        var platformTenant = await SeedPlatformTenantAsync(ct);
        await SeedSuperadminAsync(platformTenant, ct);
        await SeedWidgetCatalogAsync(ct);
        await SeedSampleCcEntitiesAsync(platformTenant, ct);

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

        var settings = await db.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == tenant.Id, ct);

        if (settings == null)
        {
            settings = new TenantSettings { TenantId = tenant.Id };
            db.TenantSettings.Add(settings);
        }

        // Seed default color palettes if not set
        if (string.IsNullOrEmpty(settings.BackgroundColorPalette))
        {
            // Enterprise palette: Widget backgrounds + Status badge backgrounds
            settings.BackgroundColorPalette = """
            [
                "#FFFFFF", "#F8F9FA", "#F5F5F5", "#EEEEEE", "#E0E0E0",
                "#1A237E", "#0D47A1", "#01579B", "#006064", "#004D40",
                "#1B5E20", "#33691E", "#827717", "#F57F17", "#E65100",
                "#BF360C", "#3E2723", "#263238", "#212121", "#000000",
                "#E8F5E9", "#E3F2FD", "#FFF8E1", "#E0F7FA", "#ECEFF1",
                "#FFEBEE", "#F3E5F5", "#EDE7F6"
            ]
            """;
        }

        if (string.IsNullOrEmpty(settings.FontColorPalette))
        {
            // Enterprise palette: Text colors + Status badge text colors
            settings.FontColorPalette = """
            [
                "#212121", "#424242", "#616161", "#757575", "#9E9E9E",
                "#FFFFFF", "#F5F5F5", "#EEEEEE",
                "#2E7D32", "#1565C0", "#F57F17", "#00838F", "#5D4037",
                "#C62828", "#6A1B9A", "#283593"
            ]
            """;
        }

        await db.SaveChangesAsync(ct);

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
        var items = new List<WidgetCatalogItem>
        {
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Queue Summary", Description = "Real-time queue metrics snapshot", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Queue Trend", Description = "Historical queue volume trend chart", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Abandoned Calls", Description = "Abandoned call count and rate", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "SLA Bar", Description = "Service level agreement gauge", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Agent Status", Description = "Live agent state distribution", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Agent Grid", Description = "Real-time agent table with states, durations, metrics and alerts", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Queues", Name = "Queue Grid", Description = "Real-time queue metrics table with customizable rows and columns", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Agent List", Description = "Filterable agent roster with states", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents", Name = "Occupancy Gauge", Description = "Agent occupancy percentage gauge", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "KPI Scorecard", Description = "Key performance indicators tile set", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Calls Per Hour", Description = "Hourly call volume bar chart", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "AHT Chart", Description = "Average handle time trend", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Real-time Ticker", Description = "Live event ticker feed", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Data Slot", Description = "Single metric display with target comparison", IsActive = true },
        };

        var existingNames = (await db.WidgetCatalogItems
            .Select(w => w.Name)
            .ToListAsync(ct))
            .ToHashSet();

        var newItems = items.Where(i => !existingNames.Contains(i.Name)).ToList();
        if (newItems.Count == 0) return;

        db.WidgetCatalogItems.AddRange(newItems);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Seeded {Count} widget catalog items.", newItems.Count);
    }

    private async Task SeedSampleCcEntitiesAsync(Tenant tenant, CancellationToken ct)
    {
        // Seed sample CC entities for testing Permission Groups page
        // In production, these would be synced from the external CC system
        // Each block is independent with its own SaveChangesAsync to ensure idempotency

        // Queues (ngc_queues table)
        try
        {
            if (!await db.NgcQueues.IgnoreQueryFilters().AnyAsync(q => q.TenantId == tenant.Id, ct))
            {
                db.NgcQueues.AddRange(
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q001", Name = "Sales Inbound", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q002", Name = "Support Level 1", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q003", Name = "Support Level 2", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q004", Name = "Billing", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q005", Name = "VIP Support", IsActive = true }
                );
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample queues for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "Queues seed skipped (may already exist)"); }

        // Agent Groups (ngc_AgentGroups table)
        try
        {
            if (!await db.NgcAgentGroups.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
            {
                db.NgcAgentGroups.AddRange(
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG001", Name = "English Agents", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG002", Name = "Spanish Agents", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG003", Name = "Technical Support", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG004", Name = "Sales Team", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG005", Name = "Billing Experts", IsActive = true }
                );
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample agent groups for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "Agent groups seed skipped (may already exist)"); }

        // NGC Sites (NGC_Site table)
        try
        {
            if (!await db.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
            {
                db.NgcSites.AddRange(
                    new NgcSite { SiteId = "SITE001", TenantId = tenant.Id, SiteName = "Main Office", Description = "Primary contact center", TimeZone = "+03:00", ClearTime = "00:00" },
                    new NgcSite { SiteId = "SITE002", TenantId = tenant.Id, SiteName = "Remote Office", Description = "Secondary location", TimeZone = "+02:00", ClearTime = "00:00" }
                );
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample NGC sites for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC sites seed skipped (may already exist)"); }

        // NGC Business Units (NGC_BusinessUnit table)
        try
        {
            if (!await db.NgcBusinessUnits.IgnoreQueryFilters().AnyAsync(b => b.TenantId == tenant.Id, ct))
            {
                db.NgcBusinessUnits.AddRange(
                    new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Sales Department", Description = "Sales and marketing team", SiteId = "SITE001", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Support Department", Description = "Customer support team", SiteId = "SITE001", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Billing Department", Description = "Billing and accounts", SiteId = "SITE002", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" }
                );
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample NGC business units for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC business units seed skipped (may already exist)"); }

        // NGC Supergroups (NGC_Supergroup table)
        try
        {
            if (!await db.NgcSupergroups.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
            {
                db.NgcSupergroups.AddRange(
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "All Sales Agents", Description = "Supergroup for all sales staff", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "All Support Agents", Description = "Supergroup for all support staff", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "VIP Handlers", Description = "Supergroup for VIP customer handlers", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" }
                );
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample NGC supergroups for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC supergroups seed skipped (may already exist)"); }
    }
}
