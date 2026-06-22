using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using UUIDNext;

namespace CcDashboard.Infrastructure.Seeding;

/// <summary>
/// Idempotent seed — runs on every startup but only creates missing data [DATA-07].
/// </summary>
public class DatabaseInitializer(
    AppDbContext db,
    AuditDbContext auditDb,
    BackendEmulationDbContext beDb,
    UserManager<ApplicationUser> userManager,
    RoleManager<ApplicationRole> roleManager,
    ITenantContext tenantContext,
    IConfiguration config,
    IHostEnvironment env,
    ILogger<DatabaseInitializer> logger) : IDatabaseInitializer
{
    private static readonly string[] Roles = ["Superadmin", "Administrator", "Editor", "Viewer"];

    public virtual async Task InitializeAsync(CancellationToken ct = default)
    {
        logger.LogInformation("Running database seed...");

        await db.Database.MigrateAsync(ct);
        await auditDb.Database.MigrateAsync(ct);

        // Apply backend emulation migrations only in dev/test — in production these tables are backend-owned (ADR-007)
        if (env.IsDevelopment() || env.EnvironmentName == "Testing")
        {
            logger.LogInformation("Applying BackendEmulationDbContext migrations (dev/test mode)...");
            await beDb.Database.MigrateAsync(ct);
        }

        await SeedRolesAsync(ct);
        var platformTenant = await SeedPlatformTenantAsync(ct);

        // ARCH-07: startup seed has no HTTP/tenant context — resolve the platform tenant
        // explicitly so AppDbContext Global Query Filters (ITenantContext.TenantId) evaluate.
        tenantContext.Set(platformTenant.Id, platformTenant.Slug);

        await SeedSuperadminAsync(platformTenant, ct);
        await SeedWidgetCatalogAsync(ct);
        await SeedRtsGridMetricsAsync(ct);
        await SeedHistoryMetricsAsync(ct);
        await SeedSampleCcEntitiesAsync(platformTenant, ct);
        await SeedAgentStateDefinitionsAsync(ct);

        // Dev-only: seed RTSData test rows for DayTrend widget
        if (env.IsDevelopment())
        {
            try
            {
                await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
                await SeedDevRtsUserStatusLogAsync(platformTenant.Id, ct);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Dev RTS data seed skipped (non-critical)");
            }
        }

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
            new() { Id = Uuid.NewSequential(), Category = "Queues",          Name = "Queue Grid",                 Description = "Real-time queue metrics table with customizable rows and columns", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents",          Name = "Agent Grid",                 Description = "Real-time agent table with states, durations, metrics and alerts",   IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Data Slot",                  Description = "Single metric display with target comparison",                         IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Day Trend Chart",            Description = "Intraday call volume chart showing configured metrics broken down by time interval (15/30/60 min). Supports line, bar, area, and step chart types.", IsActive = true },
            new() { Id = Guid.Parse("a4d1e3f7-2b8c-4e9a-b1d5-6f3c2a7e0d11"), Category = "Agents", Name = "Agent State Distribution", Description = "Real-time pie/donut/bar chart showing agent distribution across status groups (Available, On Phone, Break, Paperwork, Training) for a selected Business Unit.", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Info Slot", Description = "Message display widget with ticker or sequential mode. Displays messages from a shell-managed Info Slot.", IsActive = true },
        };

        var existingNames = (await db.WidgetCatalogItems
            .Select(w => w.Name)
            .ToListAsync(ct))
            .ToHashSet();

        var newItems = items.Where(i => !existingNames.Contains(i.Name)).ToList();
        if (newItems.Count > 0)
        {
            db.WidgetCatalogItems.AddRange(newItems);
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Seeded {Count} widget catalog items.", newItems.Count);
        }

        // Fix Agent State Distribution GUID if it was seeded with wrong ID
        var asdTargetId = Guid.Parse("a4d1e3f7-2b8c-4e9a-b1d5-6f3c2a7e0d11");
        var existingAsd = await db.WidgetCatalogItems
            .FirstOrDefaultAsync(w => w.Name == "Agent State Distribution", ct);
        if (existingAsd is not null && existingAsd.Id != asdTargetId)
        {
            // Update DashboardWidgets to reference new ID
            var widgets = await db.DashboardWidgets
                .Where(w => w.WidgetCatalogItemId == existingAsd.Id)
                .ToListAsync(ct);
            foreach (var w in widgets)
                w.WidgetCatalogItemId = asdTargetId;

            db.WidgetCatalogItems.Remove(existingAsd);
            db.WidgetCatalogItems.Add(new WidgetCatalogItem
            {
                Id = asdTargetId,
                Category = existingAsd.Category,
                Name = existingAsd.Name,
                Description = existingAsd.Description,
                IsActive = existingAsd.IsActive
            });
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Fixed Agent State Distribution widget GUID");
        }

        // Remove obsolete catalogue entries (no longer implemented)
        var obsoleteNames = new[]
        {
            "Queue Summary", "Queue Trend", "Abandoned Calls", "SLA Bar",
            "Agent Status", "Agent List", "Occupancy Gauge",
            "KPI Scorecard", "Calls Per Hour", "AHT Chart", "Real-time Ticker",
            "Agent Status Distribution (Now)", "Agent Status Duration (Today)"
        };
        var toRemove = await db.WidgetCatalogItems
            .Where(i => obsoleteNames.Contains(i.Name))
            .ToListAsync(ct);
        if (toRemove.Count > 0)
        {
            db.WidgetCatalogItems.RemoveRange(toRemove);
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Removed {Count} obsolete widget catalogue entries", toRemove.Count);
        }
    }

    private async Task SeedSampleCcEntitiesAsync(Tenant tenant, CancellationToken ct)
    {
        // Seed sample CC entities for testing Permission Groups page
        // In production, these would be synced from the external CC system
        // Each block is independent with its own SaveChangesAsync to ensure idempotency

        // Queues (ngc_queues table)
        try
        {
            if (!await beDb.NgcQueues.IgnoreQueryFilters().AnyAsync(q => q.TenantId == tenant.Id, ct))
            {
                beDb.NgcQueues.AddRange(
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q001", Name = "Sales Inbound", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q002", Name = "Support Level 1", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q003", Name = "Support Level 2", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q004", Name = "Billing", IsActive = true },
                    new NgcQueue { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "Q005", Name = "VIP Support", IsActive = true }
                );
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample queues for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "Queues seed skipped (may already exist)"); }

        // Agent Groups (ngc_AgentGroups table)
        try
        {
            if (!await beDb.NgcAgentGroups.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
            {
                beDb.NgcAgentGroups.AddRange(
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG001", Name = "English Agents", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG002", Name = "Spanish Agents", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG003", Name = "Technical Support", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG004", Name = "Sales Team", IsActive = true },
                    new NgcAgentGroup { Id = Uuid.NewSequential(), TenantId = tenant.Id, ExternalId = "AG005", Name = "Billing Experts", IsActive = true }
                );
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample agent groups for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "Agent groups seed skipped (may already exist)"); }

        // NGC Sites (NGC_Site table)
        try
        {
            if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id && s.SiteId == "SITE001", ct))
            {
                beDb.NgcSites.AddRange(
                    new NgcSite { SiteId = "SITE001", TenantId = tenant.Id, SiteName = "Main Office", Description = "Primary contact center", TimeZone = "+03:00", ClearTime = "00:00" },
                    new NgcSite { SiteId = "SITE002", TenantId = tenant.Id, SiteName = "Remote Office", Description = "Secondary location", TimeZone = "+02:00", ClearTime = "00:00" }
                );
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample NGC sites for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC sites seed skipped (may already exist)"); }

        // NGC Business Units (NGC_BusinessUnit table) — granular upsert by name
        try
        {
            var existingBuNames = await beDb.NgcBusinessUnits.IgnoreQueryFilters()
                .Where(b => b.TenantId == tenant.Id)
                .Select(b => b.BusinessUnitName)
                .ToListAsync(ct);
            var existingSet = existingBuNames.ToHashSet(StringComparer.OrdinalIgnoreCase);

            var toAdd = new List<NgcBusinessUnit>();
            if (!existingSet.Contains("Sales Department"))
                toAdd.Add(new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Sales Department", Description = "Sales and marketing team", SiteId = "SITE001", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" });
            if (!existingSet.Contains("Support Department"))
                toAdd.Add(new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Support Department", Description = "Customer support team", SiteId = "SITE001", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" });
            if (!existingSet.Contains("Billing Department"))
                toAdd.Add(new NgcBusinessUnit { TenantId = tenant.Id, BusinessUnitName = "Billing Department", Description = "Billing and accounts", SiteId = "SITE002", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" });

            if (toAdd.Count > 0)
            {
                beDb.NgcBusinessUnits.AddRange(toAdd);
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded {Count} NGC business units for tenant {TenantId}", toAdd.Count, tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC business units seed skipped (may already exist)"); }

        // NGC Supergroups (NGC_Supergroup table)
        try
        {
            if (!await beDb.NgcSupergroups.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
            {
                beDb.NgcSupergroups.AddRange(
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "All Sales Agents", Description = "Supergroup for all sales staff", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "All Support Agents", Description = "Supergroup for all support staff", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" },
                    new NgcSupergroup { TenantId = tenant.Id, SupergroupName = "VIP Handlers", Description = "Supergroup for VIP customer handlers", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" }
                );
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded sample NGC supergroups for tenant {TenantId}", tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "NGC supergroups seed skipped (may already exist)"); }

        // NGC Business Unit Queue Classifications (BU → Queue mapping for DayTrend widget)
        try
        {
            var bus = await beDb.NgcBusinessUnits.IgnoreQueryFilters()
                .Where(b => b.TenantId == tenant.Id)
                .ToListAsync(ct);

            var existingPairs = await beDb.NgcBusinessUnitQueueClassifications.IgnoreQueryFilters()
                .Where(c => c.TenantId == tenant.Id)
                .Select(c => new { c.BusinessUnitId, c.QueueId })
                .ToListAsync(ct);
            var existingSet = existingPairs.Select(p => $"{p.BusinessUnitId}:{p.QueueId}").ToHashSet();

            var salesBu = bus.FirstOrDefault(b => b.BusinessUnitName == "Sales Department");
            var supportBu = bus.FirstOrDefault(b => b.BusinessUnitName == "Support Department");
            var billingBu = bus.FirstOrDefault(b => b.BusinessUnitName == "Billing Department");

            var toAdd = new List<NgcBusinessUnitQueueClassification>();

            void TryAdd(NgcBusinessUnit? bu, string queueId)
            {
                if (bu != null && !existingSet.Contains($"{bu.BusinessUnitId}:{queueId}"))
                    toAdd.Add(new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = bu.BusinessUnitId, QueueId = queueId, ClassificationId = "ALL", CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" });
            }

            TryAdd(salesBu, "Q001");
            TryAdd(supportBu, "Q002");
            TryAdd(supportBu, "Q003");
            TryAdd(supportBu, "Q005");
            TryAdd(billingBu, "Q004");

            if (toAdd.Count > 0)
            {
                beDb.NgcBusinessUnitQueueClassifications.AddRange(toAdd);
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded {Count} BU-Queue classifications for tenant {TenantId}", toAdd.Count, tenant.Id);
            }
        }
        catch (Exception ex) { logger.LogWarning(ex, "BU-Queue classifications seed skipped (may already exist)"); }
    }

    private async Task SeedRtsGridMetricsAsync(CancellationToken ct)
    {
        var metrics = new List<RtsGridMetric>
        {
            new() { MetricId = "MonAgentTalkDuration", Description = "Agent - Cumulative Talk Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentTalkDurationPct", Description = "Agent - Cumlative Talk Duration Percent", DataType = "User", MetricFunction = "TotalStatusGroupPercent", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentActiveInteractionId", Description = "Agent - Active Interction ID", DataType = "User", MetricFunction = "LongestInteractionId", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueNumCompletedCallbacks", Description = "QM - Number of Completed Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Outgoing\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCalls", Description = "QM - Number of Incoming Calls including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCallbacks", Description = "QM - Number of Incoming Callbacks including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineCallsAndCallbacks", Description = "QM - Number of Incoming Calls and Callbacks including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingOnlineChats", Description = "QM - Number of Incoming Chats including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIcomingOnlineInteractions", Description = "QM - Number of Incoming Interactions including Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedCalls", Description = "QM - Number of Abandoned Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedCallbacks", Description = "QM - Number of Abandoned Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedCallsAndCallbacks", Description = "QM - Number of Abandoned Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedChats", Description = "QM - Number of Abandoned Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAbandonedInteractions", Description = "QM - Number of Abandoned Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumCallbackRequests", Description = "QM - Number of Callback Requests", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls", Description = "QM - Number of Answered Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls60sec", Description = "QM - Number of Answered Calls in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsBreakDurationMax", Description = "Agent Group - Max duration of  Break State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupDurationCurMax", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentNumChatsCompleted", Description = "Agent - Number of Answered Chats", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\" && Direction==\"Incoming\" && !IsTalk && !IsInQueue && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueBaseAnsweredPct", Description = "QM - Base Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueExclCallbackReqAnsweredPct", Description = "QM - Excluding Callback Requests Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])==0 ? 0 : ((double)[QueueNumAnsweredCalls]/([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueInclCallbackReqAnsweredPct", Description = "QM - Including Callback Requests Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCallbackRequests])/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueInclCompCallbacksAnsweredPct", Description = "QM - Including Completed Callbacks Answered Percent", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCompletedCallbacks])/[QueueNumIncomingOnlineCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumOnlineChats", Description = "QM - Number of Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UserNumMissedCalls", Description = "Agent - Number of Missed Calls", DataType = "User", MetricFunction = "TotalStatusCount", MetricParameter = "Missed Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueNumIncomingHandledInteractions", Description = "QM - Number of Completed Incoming Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue && !IsAbandoned && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueSLAIn30secFrom80PctInc", Description = "QM - Percent of Answered Calls in 30 sec from 80% Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec ]/([QueueNumIncomingCompletedCalls]*0.8))", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWrapUpAgents", Description = "QM - Number of Wpap Up Agents in Queue Skill", DataType = "Interactions Summary", MetricFunction = "UsersInStatusCount", MetricParameter = "Wrap Up", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueCPH", Description = "QM - Calls per Hour", DataType = "Interactions Summary", MetricFunction = "CPH", MetricParameter = "InteractionType==\"Call\" && Direction == \"Incoming\"", MetricFormat = "F2", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UserCPH", Description = "Agent - Calls per Hour", DataType = "User", MetricFunction = "CPH", MetricParameter = "InteractionType==\"Call\" && Direction == \"Incoming\"", MetricFormat = "F2", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MessagesMaxFirstResponseTime", Description = "QM - Messages Max First Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesMaxFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MessagesAvgFirstResponseTime", Description = "QM - Messages Avg First Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesAvgFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonAgentNumChatsActive", Description = "Agent - Number of Active Chats", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Chat\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MessagesAvgResponseTime", Description = "QM - Messages Avg Response Time", DataType = "Interactions Summary", MetricFunction = "MessagesAvgResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "AgentMessagesAvgResponseTime", Description = "Agent - Messages Avg Response Time", DataType = "User", MetricFunction = "MessagesAvgResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "AgentMessagesAvgFirstResponseTime", Description = "Agent - Messages Avg First Response Time", DataType = "User", MetricFunction = "MessagesAvgFirstResponseTime", MetricParameter = "Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "QueueNumAnsweredCallbacks", Description = "QM - Number of Answered Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks", Description = "QM - Number of Answered Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats", Description = "QM - Number of Answered Chats", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions", Description = "QM - Number of Answered Interactions", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCalls", Description = "QM - Number of Incoming Calls exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCallbacks", Description = "QM - Number of Incoming Callbacks exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedCallsAndCallbacks", Description = "QM - Number of Incoming Calls and Callbacks exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedChats", Description = "QM - Number of Incoming Chats exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue  && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumIncomingCompletedInteractions", Description = "QM - Number of Incoming Interactions exluding Waiting", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue  && !IsCallbackRequest && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCalls", Description = "QM - Number of Waiting Calls", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCallbacks", Description = "QM - Number of Waiting Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingCallsAndCallbacks", Description = "QM - Number of Waiting Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingChats", Description = "QM - Number of Waiting Chats", DataType = "Interactions Summary", MetricFunction = "NumWaitings", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumWaitingInteractions", Description = "QM - Number of Waiting Interactions", DataType = "Interactions Summary", MetricFunction = "NumWaitings", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCalls", Description = "QM - Current Max Wait Time of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCallbacks", Description = "QM - Current Max Wait Time of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeCallsAndCallbacks", Description = "QM - Current Max Wait Time of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeChats", Description = "QM - Current Max Wait Time of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueCurMaxWaitTimeInteractions", Description = "QM - Current Max Wait Time of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationCurMax", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsTotal", Description = "QM - Percent of Answered Calls", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacksTotal", Description = "QM - Percent of Answered Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacksTotal", Description = "QM - Percent of Answered Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChatsTotal", Description = "QM - Percent of Answered Chats", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractionsTotal", Description = "QM - Percent of Answered Interactions", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallsTotal", Description = "QM - Percent of Abandoned Calls", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAbandonedCalls]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallbacksTotal", Description = "QM - Percent of Abandoned Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallbacks]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedCallsAndCallbacksTotal", Description = "QM - Percent of Abandoned Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedInteractionsTotal", Description = "QM - Percent of Abandoned Interactions", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAbandonedInteractions]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAbandonedChatsTotal", Description = "QM - Percent of Abandoned Chats", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAbandonedChats]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls30sec", Description = "QM - Number of Answered Calls in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks30sec", Description = "QM - Number of Answered Callbacks in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks30sec", Description = "QM - Number of Answered Calls and Callbacks in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats30sec", Description = "QM - Number of Answered Chats in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions30sec", Description = "QM - Number of Answered Interactions in 30 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<30 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks60sec", Description = "QM - Number of Answered Calls in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks60sec", Description = "QM - Number of Answered Calls and Callbacks in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats60sec", Description = "QM - Number of Answered Chats in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions60sec", Description = "QM - Number of Answered Interactions in 60 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<60 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCalls120sec", Description = "QM - Number of Answered Calls in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallbacks120sec", Description = "QM - Number of Answered Callbacks in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered  && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredCallsAndCallbacks120sec", Description = "QM - Number of Answered Calls and Callbacks in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredChats120sec", Description = "QM - Number of Answered Chats in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumAnsweredInteractions120sec", Description = "QM - Number of Answered Interactions in 120 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<120 && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCalls", Description = "QM - Average Wait Time of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCallbacks", Description = "QM - Average Wait Time of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeCallsAndCallbacks", Description = "QM - Average Wait Time of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeChats", Description = "QM - Average Wait Time of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgWaitTimeInteractions", Description = "QM - Average Wait Time of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCalls", Description = "QM - Average Time to Aband of Calls in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCallbacks", Description = "QM - Average Time to Aband of Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandCallsAndCallbacks", Description = "QM - Average Time to Aband of Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandChats", Description = "QM - Average Time to Aband of Chats in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTimeToAbandInteractions", Description = "QM - Average Time to Aband of Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "WaitDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsInQueue && IsAbandoned && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveCalls", Description = "QM - Number of Active Calls in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveCallbacks", Description = "QM - Number of Active Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentTelState", Description = "Agent - Active Interaction State", DataType = "User", MetricFunction = "LongestInteractionState", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueNumActiveCallsAndCallbacks", Description = "QM - Number of Active Calls and Callbacks in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\"&& (InteractionType==\"Call\" || InteractionType==\"Callback\")&& IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveChats", Description = "QM - Number of Active Chats in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueNumActiveInteractions", Description = "QM - Number of Active Interactions in Queue", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && IsTalk && (InteractionType==\"Chat\" || InteractionType==\"email\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCalls", Description = "QM - Average Talking Duration of Calls", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCallbacks", Description = "QM - Average Talking Duration of Callbacks", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationCallsAndCallbacks", Description = "QM - Average Talking Duration of Calls and Callbacks", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Call\" || InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationChats", Description = "QM - Average Talking Duration of Chats", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(InteractionType==\"Chat\") && (CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueueAvgTalkingDurationInteractions", Description = "QM - Average Talking Duration of Interactions", DataType = "Interactions Summary", MetricFunction = "TalkDurationAvg", MetricParameter = "(CallType==\"External\")  && Direction == \"Incoming\" && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls30secInc", Description = "QM - Percent of Answered Calls in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks30secInc", Description = "QM - Percent of Answered Callbacks in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks30secInc", Description = "QM - Percent of Answered Calls and Callbacks in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats30secInc", Description = "QM - Percent of Answered Chats in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions30secInc", Description = "QM - Percent of Answered Interactions in 30 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls30secAns", Description = "QM - Percent of Answered Calls in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks30secAns", Description = "QM - Percent of Answered Callbacks in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks30secAns", Description = "QM - Percent of Answered Calls and Callbacks in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats30secAns", Description = "QM - Percent of Answered Chats in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions30secAns", Description = "QM - Percent of Answered Interactions in 30 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls60secInc", Description = "QM - Percent of Answered Calls in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks60secInc", Description = "QM - Percent of Answered Callbacks in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks60secInc", Description = "QM - Percent of Answered Calls and Callbacks in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats60secInc", Description = "QM - Percent of Answered Chats in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions60secInc", Description = "QM - Percent of Answered Interactions in 60 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls60secAns", Description = "QM - Percent of Answered Calls in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks60secAns", Description = "QM - Percent of Answered Callbacks in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks60secAns", Description = "QM - Percent of Answered Calls and Callbacks in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats60secAns", Description = "QM - Percent of Answered Chats in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions60secAns", Description = "QM - Percent of Answered Interactions in 60 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls120secInc", Description = "QM - Percent of Answered Calls in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsInMissedCall", Description = "Agent Group - Number of Agents on Missed Call", DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Missed Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            // CC-009: UsersInStatusCount for standard agent states (By State ASD widget mode)
            new() { MetricId = "StateCountAvailable",  Description = "Agent Group - Number of Agents in Available State",  DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Available",  MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "StateCountOnPhone",    Description = "Agent Group - Number of Agents in On Phone State",   DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "On Phone",   MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "StateCountBreak",      Description = "Agent Group - Number of Agents in Break State",      DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Break",      MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "StateCountPaperwork",  Description = "Agent Group - Number of Agents in Paperwork State",  DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Paperwork",  MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "StateCountTraining",   Description = "Agent Group - Number of Agents in Training State",   DataType = "UsersSummary", MetricFunction = "UsersInStatusCount", MetricParameter = "Training",   MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks120secInc", Description = "QM - Percent of Answered Callbacks in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumIncomingCompletedCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks120secInc", Description = "QM - Percent of Answered Calls and Callbacks in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumIncomingCompletedCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats120secInc", Description = "QM - Percent of Answered Chats in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumIncomingCompletedChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions120secInc", Description = "QM - Percent of Answered Interactions in 120 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumIncomingCompletedInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls120secAns", Description = "QM - Percent of Answered Calls in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumAnsweredCalls])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallbacks120secAns", Description = "QM - Percent of Answered Callbacks in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumAnsweredCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCallsAndCallbacks120secAns", Description = "QM - Percent of Answered Calls and Callbacks in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumAnsweredCallsAndCallbacks])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredChats120secAns", Description = "QM - Percent of Answered Chats in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumAnsweredChats])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredInteractions120secAns", Description = "QM - Percent of Answered Interactions in 120 sec from Answered", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumAnsweredInteractions])", MetricFormat = "##0.0%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentCurrentLoginDuration", Description = "Agent - Current Login Duration", DataType = "User", MetricFunction = "CurLoginDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonSumAgentsAverageCallDuration", Description = "Agent Group - Average Talk Duration in Incoming Calls and Callbacks", DataType = "UsersInteraction", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && (InteractionType == \"Call\" || InteractionType == \"Callback\") && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "UserNumAllIntercom", Description = "Agent - Number of Internal Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"Intercom\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCalls15sec", Description = "Agent - Number of Incoming Calls with Talk Time less than 15 seconds", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" &&  TalkTime<15 && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCalls10Min", Description = "Agent - Number of Incoming Calls with Talk Time more than 10 minutes", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && TalkTime>600 && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsDialer", Description = "Agent Group - Number of Dialer Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Dialer\" && (CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "RemotePhoneNumber", Description = "Agent - Active Interaction Customer Phone Number", DataType = "User", MetricFunction = "LongestInteractionRemoteAddress", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueLoginDataNumAvailableUsers", Description = "Agent Group - Number of Available Agents", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "AVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentAvailableDuration", Description = "Agent - Available State Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "AVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsWithIntercom", Description = "Agent - Number of Incoming External and Internal Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"  && (InteractionType==\"Call\" || InteractionType==\"Callback\")", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentTodayLogin", Description = "Change -ID of a representative who was connected that day", DataType = "User", MetricFunction = "IsTodayLogin", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "QueueLoginDataNumLoggedUsers", Description = "Agent Group - Number of Curently Logged in Users", DataType = "UsersSummary", MetricFunction = "LogedInUsersCount", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueLoginDataNumBreakUsers", Description = "Agent Group - Number of Agents in Break State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueueLoginDataNumPaperworkUsers", Description = "Agent Group - Number of Agents in Paperwork State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "PAPERWORK", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "UsersSumOnCall", Description = "Agent Group - Number of On Call Agents", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentStation", Description = "Agent - Station ID", DataType = "User", MetricFunction = "Station", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentDurationOfCurrentCall", Description = "Agent - Current Incoming Ext Call Duration", DataType = "User", MetricFunction = "CurStatusDuration", MetricParameter = "Incoming Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfInboundCallsOnly", Description = "Agent - Number of Incoming External Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" ||  InteractionType==\"Callback\") && (CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentUserId", Description = "Agent - User ID", DataType = "User", MetricFunction = "UserID", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageMakeCallDuration", Description = "Agent - Average Oubound Call Duration", DataType = "User", MetricFunction = "TotalStatusDurationAvg", MetricParameter = "Out Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageAgentDialerDuration", Description = "Agent - Average Dialer Calls Duration", DataType = "User", MetricFunction = "TotalStatusDurationAvg", MetricParameter = "Campaign Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "AgentLoginName", Description = "Agent - Login Name", DataType = "User", MetricFunction = "DisplayName", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonActiveCampaign", Description = "Agent - Active Interaction Queue Name", DataType = "User", MetricFunction = "LongestInteractionWorkgroup", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonInteractionType", Description = "Agent - Active Interaction Type", DataType = "User", MetricFunction = "LongestInteractionType", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentState", Description = "Agent - Current Satatus", DataType = "User", MetricFunction = "CurStatusTitle", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentDurationOfCalls", Description = "Agent - Cumulative  Incoming Ext Call Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Incoming Ext Call", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageCallDuration", Description = "Agent - Average Handling Duration", DataType = "User", MetricFunction = "TotalStatusGroupDurationAvg", MetricParameter = "ONPHONE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentExtension", Description = "Agent - Extension ID", DataType = "User", MetricFunction = "UserExtension", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDuration", Description = "Agent - Current Status Duration", DataType = "User", MetricFunction = "CurStatusDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentTelStateDuration", Description = "Agent - Active Interaction State Duration", DataType = "User", MetricFunction = "LongestInteractionStateDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfConsultCalls", Description = "Agent - Number of Consultation Calls", DataType = "User", MetricFunction = "TotalStatusCount", MetricParameter = "Consulting Call", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumberOfMakeCalls", Description = "Agent - Number of Outbound Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Call\" && CallType==\"External\" && Direction==\"Outgoing\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentBreakDuration", Description = "Agent - Cumulative Break Group Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "BREAK", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentWrapUpDuration", Description = "Agent - Cumulative Wrap Up Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Wrap Up", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentUnavailableStateDuration", Description = "Agent - Cumulative Unavailable State Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Unavailable", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDesc", Description = "Agent - Current Status Group", DataType = "User", MetricFunction = "CurStatusGroup", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentNumMakeCallsInCompleted", Description = "Agent - Number of Answered Incoming Calls", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\" ||  InteractionType==\"Callback\") && Direction==\"Incoming\" && IsAnswered && !IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentAverageInboundCallDuration", Description = "Agent - Average Call Duration", DataType = "User", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && (InteractionType==\"Call\" || InteractionType==\"Callback\")  && Direction==\"Incoming\" && !IsTalk", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentPaperworkDuration", Description = "Agent - Cumulative Paperwork Group Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "PAPERWORK", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonSumAgentsAnsweredCalls", Description = "Agent Group - Number of Answered Incoming Calls and Callbacks", DataType = "UsersInteraction", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && !IsTalk && !IsInQueue && (InteractionType == \"Call\" || InteractionType == \"Callback\") && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsMakeCalls", Description = "Agent Group - Number of Otbound Calls", DataType = "UsersInteraction", MetricFunction = "InteractionsCount", MetricParameter = "CallType==\"External\" && Direction==\"Outgoing\"", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsAverageChatDuration", Description = "Agent Group - Average Talk Duration in Incoming Chats", DataType = "UsersInteraction", MetricFunction = "TalkDurationAvg", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\" && (InteractionType == \"Chat\") && !IsTalk && !IsInQueue", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsBreakDurationPercent", Description = "Agent Group - Percent of Agents in Break State Group", DataType = "UsersInteraction", MetricFunction = "UsersInStatusGroupDurationPercent", MetricParameter = "BREAK", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsPaperworkDurationPercent", Description = "Agent Group - Percent of Agents in Paperwork State Group", DataType = "UsersInteraction", MetricFunction = "UsersInStatusGroupDurationPercent", MetricParameter = "PAPERWORK", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonSumAgentsLongestCurrentCall", Description = "Agent Group - Current Max Talk Duration", DataType = "UsersInteraction", MetricFunction = "TalkDurationCurMax", MetricParameter = "CallType==\"External\" && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Data" },
            new() { MetricId = "MonAgentOutgoingCallbacksNum", Description = "Agent - Number of Outgoing Callbacks", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Callback\" && Direction==\"Outgoing\" && IsAnswered", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "QueueNumAnsweredCalls360sec", Description = "QM - Number of Answered Calls in 360 sec", DataType = "Interactions Summary", MetricFunction = "InteractionsCount", MetricParameter = "(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAnswered && TimeInQueue<360", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "QueuePctAnsweredCalls360secInc", Description = "QM - Percent of Answered Calls in 360 sec from Incoming", DataType = "Interactions Summary", MetricFunction = "Calc", MetricParameter = "[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls360sec]/[QueueNumIncomingCompletedCalls])", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentMaxCallDuration", Description = "Agent - Max Call Duration", DataType = "User", MetricFunction = "TalkDurationMax", MetricParameter = "CallType==\"External\" && (InteractionType==\"Call\" || InteractionType==\"Callback\") && Direction==\"Incoming\"", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentLoginTime", Description = "Agent - Cumulative Login Duration", DataType = "User", MetricFunction = "TotalLoginDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentStateDescDuration", Description = "Agent - Current Status Group Duration", DataType = "User", MetricFunction = "CurStatusGroupDuration", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentFirstLoginTimeStamp", Description = "Agent - First Login Time Stamp", DataType = "User", MetricFunction = "FirstLoginTimestamp", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentCurrentLoginTimeStamp", Description = "Agent - Current Login Time Stamp", DataType = "User", MetricFunction = "CurLoginTimestamp", MetricParameter = "", MetricFormat = "", DefaultValue = "0", ValueType = "text", MetricType = "Agent" },
            new() { MetricId = "MonAgentProxyCallsNum", Description = "Agent - Number of Incoming Callbacks", DataType = "User", MetricFunction = "InteractionsCount", MetricParameter = "InteractionType==\"Callback\" && Direction==\"Incoming\"  && IsAnswered && !IsCallbackRequest", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonAgentHeldDuration", Description = "Agent - Cumulative Hold Duration", DataType = "User", MetricFunction = "TotalStatusDuration", MetricParameter = "Hold", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "QueueLoginDataNumUnavailableUsers", Description = "Agent Group - Number of Agents in Unavailable State Group", DataType = "UsersSummary", MetricFunction = "UsersInStatusGroupCount", MetricParameter = "UNAVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
            new() { MetricId = "MonAgentUnavailableDuration", Description = "Agent - Cumulative Unavailable Group Duration", DataType = "User", MetricFunction = "TotalStatusGroupDuration", MetricParameter = "UNAVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "time", MetricType = "Agent" },
            new() { MetricId = "MonAgentUnavailableDurationPct", Description = "Agent - Cumulative Unavailable Duration Percent", DataType = "User", MetricFunction = "TotalStatusGroupPercent", MetricParameter = "UNAVAILABLE", MetricFormat = "", DefaultValue = "0", ValueType = "number", MetricType = "Agent" },
            new() { MetricId = "MonSumAgentsUnavailableDurationPercent", Description = "Agent Group - Percent of Agents in Unavailable State Group", DataType = "UsersInteraction", MetricFunction = "UsersInStatusGroupDurationPercent", MetricParameter = "UNAVAILABLE", MetricFormat = "##0.00%", DefaultValue = "0", ValueType = "number", MetricType = "Data" },
        };

        try
        {
            var existingIds = (await beDb.RtsGridMetrics.Select(m => m.MetricId).ToListAsync(ct)).ToHashSet();
            var toAdd = metrics.Where(m => !existingIds.Contains(m.MetricId)).ToList();
            if (toAdd.Count > 0)
            {
                beDb.RtsGridMetrics.AddRange(toAdd);
                await beDb.SaveChangesAsync(ct);
                logger.LogInformation("Seeded {Count} RtsGridMetric entries", toAdd.Count);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "RtsGridMetric seed skipped (may already exist)");
        }
    }

    private async Task SeedHistoryMetricsAsync(CancellationToken ct)
    {
        var metrics = new List<HistoryMetric>
        {
            // --- Interaction metrics (source: RTSData_Interaction) ---
            new() { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.answered_calls",      Description = "Answered Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "answered",                               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",         DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",                              MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.callback_requests",   Description = "Callback Requests",       DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",                      MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",     DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",                     MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.outbound_calls",      Description = "Outbound Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_outgoing",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.transferred_calls",   Description = "Transferred Calls",       DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "transferred",                            MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",           DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.max_wait_time",       Description = "Max Wait Time",           DataType = "decimal", MetricFunction = "MAX_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",           DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon", DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

            // --- Agent status log metrics (source: RTSData_UserStatusLog — interval aggregates) ---
            new() { MetricId = "statuslog.available_agents",      Description = "Available Agents",             DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:AVAILABLE",  MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.onphone_agents",        Description = "On Phone Agents",              DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ONPHONE",    MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.break_agents",          Description = "Agents on Break",              DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:BREAK",      MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.paperwork_agents",      Description = "Paperwork / ACW Agents",       DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:PAPERWORK",  MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.training_agents",       Description = "Training / Back-Office Agents",DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:TRAINING",   MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.total_agents",          Description = "Total Active Agents",          DataType = "int",    MetricFunction = "COUNT_DISTINCT", MetricParameter = "group:ALL",        MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.logged_in_agents",      Description = "Logged-In Agents",             DataType = "int",    MetricFunction = "COUNT_POOL",     MetricParameter = "pool:all",         MetricFormat = "0",     DefaultValue = "0", ValueType = "Number", MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.available_time_ms",     Description = "Available Time",               DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:AVAILABLE",  MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.onphone_time_ms",       Description = "On Phone Time",                DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ONPHONE",    MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.break_time_ms",         Description = "Break Time",                   DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:BREAK",      MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.paperwork_time_ms",     Description = "Paperwork / ACW Time",         DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:PAPERWORK",  MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.training_time_ms",      Description = "Training / Back-Office Time",  DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:TRAINING",   MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },
            new() { MetricId = "statuslog.total_active_time_ms",  Description = "Total Active Time",            DataType = "bigint", MetricFunction = "SUM_OVERLAP_MS", MetricParameter = "group:ALL",        MetricFormat = "mm:ss", DefaultValue = "0", ValueType = "Time",   MetricType = "AgentStatusLog" },

            // --- Agent status daily totals (source: RTSData_UserStatus.TotalDuration — seconds) ---
            new() { MetricId = "agentstatus.available_time",  Description = "Available Time Today",             DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:AVAILABLE",  MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
            new() { MetricId = "agentstatus.onphone_time",    Description = "On Phone Time Today",              DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:ONPHONE",    MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
            new() { MetricId = "agentstatus.break_time",      Description = "On Break Time Today",              DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:BREAK",      MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
            new() { MetricId = "agentstatus.paperwork_time",  Description = "Paperwork / ACW Time Today",       DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:PAPERWORK",  MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
            new() { MetricId = "agentstatus.training_time",   Description = "Training / Back-Office Time Today",DataType = "int", MetricFunction = "SUM_DURATION", MetricParameter = "group:TRAINING",   MetricFormat = "h:mm", DefaultValue = "0", ValueType = "Time", MetricType = "AgentStatus" },
        };

        try
        {
            var existingIds = (await db.HistoryMetrics.Select(m => m.MetricId).ToListAsync(ct)).ToHashSet();
            var toAdd = metrics.Where(m => !existingIds.Contains(m.MetricId)).ToList();
            if (toAdd.Count > 0)
            {
                db.HistoryMetrics.AddRange(toAdd);
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Seeded {Count} HistoryMetric entries", toAdd.Count);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "HistoryMetric seed skipped");
        }
    }

    private async Task SeedDevRtsInteractionsAsync(Guid tenantId, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy");
        if (await beDb.RtsDataInteractions.AnyAsync(r => r.TenantId == tenantId && r.OnDate == today, ct))
            return;

        var rng = new Random(42);
        var now = DateTime.UtcNow;
        var queues = new[] { "Q001", "Q002", "Q003", "Q004", "Q005" };
        var agents = new[] { "agent01", "agent02", "agent03", "agent04", "agent05" };
        var rows = new List<RtsDataInteraction>();
        var seg = 0;

        for (int h = 8; h <= 17; h++)
        {
            foreach (var q in queues)
            {
                int count = rng.Next(3, 12);
                for (int i = 0; i < count; i++)
                {
                    var inQueue = new DateTime(now.Year, now.Month, now.Day, h, rng.Next(0, 59), 0, DateTimeKind.Utc);
                    var answered = rng.NextDouble() > 0.15;
                    rows.Add(new RtsDataInteraction
                    {
                        TenantId = tenantId,
                        InteractionId = Guid.NewGuid().ToString(),
                        Segment = ++seg,
                        ServerId = "SRV01",
                        OnDate = today,
                        InQueueDateTime = inQueue,
                        AnsweredDateTime = answered ? inQueue.AddSeconds(rng.Next(5, 60)) : new DateTime(1753, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                        Workgroup = q,
                        InteractionType = "Call",
                        Direction = "Incoming",
                        IsAnswered = answered,
                        UserId = answered ? agents[rng.Next(agents.Length)] : string.Empty,
                        IsAbandoned = !answered && rng.NextDouble() > 0.3,
                        IsTransferred = answered && rng.NextDouble() < 0.1,
                        IsInQueue = true,
                        TimeInQueue = answered ? rng.Next(5, 120) : rng.Next(10, 180),
                        TalkTime = answered ? rng.Next(30, 600) : 0,
                        UpdateTime = DateTime.UtcNow,
                    });
                }
            }
        }

        beDb.RtsDataInteractions.AddRange(rows);
        await beDb.SaveChangesAsync(ct);
        logger.LogInformation("Seeded {Count} dev RTSData_Interaction rows for {Date}", rows.Count, today);
    }

    private async Task SeedDevRtsUserStatusLogAsync(Guid tenantId, CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy");
        if (await beDb.RtsDataUserStatusLogs.AnyAsync(r => r.TenantId == tenantId && r.OnDate == today, ct))
            return;

        var rng = new Random(42);
        var now = DateTime.UtcNow;
        var agents = new[] { "agent01", "agent02", "agent03", "agent04", "agent05" };
        var groups = new[] { "AVAILABLE", "ONPHONE", "BREAK", "PAPERWORK", "TRAINING" };
        var rows = new List<RtsDataUserStatusLog>();

        foreach (var agent in agents)
        {
            var cursor = new DateTime(now.Year, now.Month, now.Day, 8, 0, 0, DateTimeKind.Utc);
            var endOfDay = new DateTime(now.Year, now.Month, now.Day, 18, 0, 0, DateTimeKind.Utc);
            while (cursor < endOfDay)
            {
                var group = groups[rng.Next(groups.Length)];
                var durationMs = rng.Next(2, 30) * 60 * 1000L;
                var end = cursor.AddMilliseconds(durationMs);
                if (end > endOfDay) end = endOfDay;
                rows.Add(new RtsDataUserStatusLog
                {
                    TenantId = tenantId,
                    UserId = agent,
                    OnDate = today,
                    StatusGroup = group,
                    StatusId = group.ToLower() + "_status",
                    StartTime = cursor,
                    EndTime = end,
                    Duration = (long)(end - cursor).TotalMilliseconds,
                    UpdateTime = DateTime.UtcNow
                });
                cursor = end;
            }
        }

        beDb.RtsDataUserStatusLogs.AddRange(rows);
        await beDb.SaveChangesAsync(ct);
        logger.LogInformation("Seeded {Count} dev RTSData_UserStatusLog rows", rows.Count);
    }

    /// <summary>
    /// Seeds 5 standard agent state definitions for all active tenants (CC-008).
    /// State = display name, Group = CC platform code (used for MetricId lookup).
    /// </summary>
    private async Task SeedAgentStateDefinitionsAsync(CancellationToken ct)
    {
        // State = display name, Group = CC platform code (matches RTSGrid_Metric.MetricParameter)
        var standardDefinitions = new (string State, string Group)[]
        {
            ("Available",  "AVAILABLE"),
            ("On Phone",   "ONPHONE"),
            ("Break",      "BREAK"),
            ("Paperwork",  "PAPERWORK"),
            ("Training",   "TRAINING"),
        };

        var activeTenants = await db.Tenants.IgnoreQueryFilters()
            .Where(t => t.Status == TenantStatus.Active)
            .Select(t => t.Id)
            .ToListAsync(ct);

        foreach (var tenantId in activeTenants)
        {
            // One-time cleanup: delete old seed data with swapped values (v1 bug)
            var oldGroupNames = new[] { "Available", "On Phone", "Break", "Paperwork", "Training" };
            var oldGroups = await db.AgentStateGroups.IgnoreQueryFilters()
                .Where(g => g.TenantId == tenantId && oldGroupNames.Contains(g.GroupName))
                .ToListAsync(ct);
            if (oldGroups.Any())
            {
                var oldGroupIds = oldGroups.Select(g => g.Id).ToList();
                var oldDefs = await db.AgentStateDefinitions.IgnoreQueryFilters()
                    .Where(d => d.TenantId == tenantId && oldGroupIds.Contains(d.AgentStateGroupId))
                    .ToListAsync(ct);
                var oldStateIds = oldDefs.Select(d => d.AgentStateId).ToList();
                var oldStates = await db.AgentStates.IgnoreQueryFilters()
                    .Where(s => s.TenantId == tenantId && oldStateIds.Contains(s.Id))
                    .ToListAsync(ct);

                db.AgentStateDefinitions.RemoveRange(oldDefs);
                db.AgentStates.RemoveRange(oldStates);
                db.AgentStateGroups.RemoveRange(oldGroups);
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Cleaned up old agent state seed data for tenant {TenantId}", tenantId);
            }

            var existingGroups = await db.AgentStateGroups.IgnoreQueryFilters()
                .Where(g => g.TenantId == tenantId)
                .ToDictionaryAsync(g => g.GroupName, g => g, StringComparer.OrdinalIgnoreCase, ct);

            var existingStates = await db.AgentStates.IgnoreQueryFilters()
                .Where(s => s.TenantId == tenantId)
                .ToDictionaryAsync(s => s.AgentStateName, s => s, StringComparer.OrdinalIgnoreCase, ct);

            var now = DateTime.UtcNow;

            foreach (var (stateName, groupName) in standardDefinitions)
            {
                if (!existingGroups.TryGetValue(groupName, out var group))
                {
                    group = new AgentStateGroup
                    {
                        Id = Uuid.NewSequential(),
                        TenantId = tenantId,
                        GroupName = groupName,
                        IsActive = true,
                        CreatedAt = now,
                        UpdatedAt = now
                    };
                    db.AgentStateGroups.Add(group);
                    existingGroups[groupName] = group;
                }

                if (!existingStates.TryGetValue(stateName, out var state))
                {
                    state = new AgentState
                    {
                        Id = Uuid.NewSequential(),
                        TenantId = tenantId,
                        AgentStateName = stateName,
                        IsActive = true,
                        CreatedAt = now,
                        UpdatedAt = now
                    };
                    db.AgentStates.Add(state);
                    existingStates[stateName] = state;
                }

                var existingDef = await db.AgentStateDefinitions.IgnoreQueryFilters()
                    .FirstOrDefaultAsync(d => d.TenantId == tenantId && d.AgentStateId == state.Id, ct);

                if (existingDef == null)
                {
                    db.AgentStateDefinitions.Add(new AgentStateDefinition
                    {
                        Id = Uuid.NewSequential(),
                        TenantId = tenantId,
                        AgentStateId = state.Id,
                        AgentStateGroupId = group.Id,
                        IsActive = true,
                        CreatedAt = now,
                        UpdatedAt = now
                    });
                }
            }

            await db.SaveChangesAsync(ct);
        }

        logger.LogInformation("Seeded agent state definitions for {Count} tenants", activeTenants.Count);
    }
}
