using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
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
        await SeedSuperadminAsync(platformTenant, ct);
        await SeedWidgetCatalogAsync(ct);
        await SeedRtsGridMetricsAsync(ct);
        await SeedSampleCcEntitiesAsync(platformTenant, ct);

        // Dev-only: seed RTSData test rows for DayTrend widget
        if (env.IsDevelopment())
        {
            await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
            await SeedDevRtsUserStatusLogAsync(platformTenant.Id, ct);
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
            new() { Id = Uuid.NewSequential(), Category = "Queues",          Name = "Queue Grid",       Description = "Real-time queue metrics table with customizable rows and columns", IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "Agents",          Name = "Agent Grid",       Description = "Real-time agent table with states, durations, metrics and alerts",   IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Data Slot",        Description = "Single metric display with target comparison",                         IsActive = true },
            new() { Id = Uuid.NewSequential(), Category = "General metrics", Name = "Day Trend Chart",  Description = "Intraday call volume chart showing configured metrics broken down by time interval (15/30/60 min). Supports line, bar, area, and step chart types.", IsActive = true },
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

        // Remove obsolete catalogue entries (no longer implemented)
        var obsoleteNames = new[]
        {
            "Queue Summary", "Queue Trend", "Abandoned Calls", "SLA Bar",
            "Agent Status", "Agent List", "Occupancy Gauge",
            "KPI Scorecard", "Calls Per Hour", "AHT Chart", "Real-time Ticker"
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
            if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))
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
                    toAdd.Add(new NgcBusinessUnitQueueClassification { TenantId = tenant.Id, BusinessUnitId = bu.BusinessUnitId, QueueId = queueId, CreatedDatetime = DateTime.UtcNow, CreatedBy = "system" });
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
            // Interaction metrics (MetricType = "Interaction")
            new() { MetricId = "interaction.incoming_calls",      Description = "Incoming Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_incoming",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.answered_calls",      Description = "Answered Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "answered",                               MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.abandoned_calls",     Description = "Abandoned Calls",          DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "abandoned",                              MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.callback_requests",   Description = "Callback Requests",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_incoming",                      MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.completed_callbacks", Description = "Completed Callbacks",      DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "callback_completed",                     MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.outbound_calls",      Description = "Outbound Calls",           DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "call_outgoing",                          MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.transferred_calls",   Description = "Transferred Calls",        DataType = "int",     MetricFunction = "COUNT_FILTER", MetricParameter = "transferred",                            MetricFormat = "0",        DefaultValue = "0", ValueType = "Number", MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_wait_time",       Description = "Avg Wait Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.max_wait_time",       Description = "Max Wait Time",            DataType = "decimal", MetricFunction = "MAX_FIELD",    MetricParameter = "TimeInQueue:answered",                   MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_talk_time",       Description = "Avg Talk Time",            DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TalkTime:answered",                      MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },
            new() { MetricId = "interaction.avg_abandon_wait",    Description = "Avg Wait Before Abandon",  DataType = "decimal", MetricFunction = "AVG_FIELD",    MetricParameter = "TimeInQueue:abandoned",                  MetricFormat = "mm:ss",    DefaultValue = "0", ValueType = "Time",   MetricType = "Interaction" },

            // Agent status log interval metrics (MetricType = "AgentStatusLog")
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
}
