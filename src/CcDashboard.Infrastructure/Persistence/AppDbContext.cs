using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence;

public class AppDbContext(
    DbContextOptions<AppDbContext> options,
    ITenantContext tenantContext)
    : IdentityDbContext<ApplicationUser, ApplicationRole, Guid>(options)
{
    public DbSet<Tenant> Tenants => Set<Tenant>();
    public DbSet<TenantSettings> TenantSettings => Set<TenantSettings>();
    public DbSet<SsoConfiguration> SsoConfigurations => Set<SsoConfiguration>();
    public DbSet<PermissionGroup> PermissionGroups => Set<PermissionGroup>();
    public DbSet<MenuPermission> MenuPermissions => Set<MenuPermission>();
    public DbSet<DashboardPermission> DashboardPermissions => Set<DashboardPermission>();
    public DbSet<Dashboard> Dashboards => Set<Dashboard>();
    public DbSet<DashboardCategory> DashboardCategories => Set<DashboardCategory>();
    public DbSet<DashboardWidget> DashboardWidgets => Set<DashboardWidget>();
    public DbSet<WidgetCatalogItem> WidgetCatalogItems => Set<WidgetCatalogItem>();
    public DbSet<WidgetTemplate> WidgetTemplates => Set<WidgetTemplate>();
    // Reference tables (ngc_queues, ngc_AgentGroups)
    public DbSet<NgcQueue> NgcQueues => Set<NgcQueue>();
    public DbSet<NgcAgentGroup> NgcAgentGroups => Set<NgcAgentGroup>();
    // PG permission join tables
    public DbSet<PgQueue> PgQueues => Set<PgQueue>();
    public DbSet<PgSkill> PgSkills => Set<PgSkill>();
    public DbSet<PgBusinessUnit> PgBusinessUnits => Set<PgBusinessUnit>();
    public DbSet<PgSupergroup> PgSupergroups => Set<PgSupergroup>();
    // NGC Configuration tables
    public DbSet<NgcSite> NgcSites => Set<NgcSite>();
    public DbSet<NgcBusinessUnit> NgcBusinessUnits => Set<NgcBusinessUnit>();
    public DbSet<NgcSupergroup> NgcSupergroups => Set<NgcSupergroup>();
    public DbSet<NgcBusinessUnitQueueClassification> NgcBusinessUnitQueueClassifications => Set<NgcBusinessUnitQueueClassification>();
    public DbSet<NgcBusinessUnitSupergroup> NgcBusinessUnitSupergroups => Set<NgcBusinessUnitSupergroup>();
    public DbSet<NgcSupergroupAgentgroup> NgcSupergroupAgentgroups => Set<NgcSupergroupAgentgroup>();
    public DbSet<RtsGridMetric> RtsGridMetrics => Set<RtsGridMetric>();
    // RTS UserGrid tables (compatibility with external SignalR server)
    public DbSet<RtsUserGridGrid> RtsUserGridGrids => Set<RtsUserGridGrid>();
    public DbSet<RtsUserGridColumnsSet> RtsUserGridColumnsSets => Set<RtsUserGridColumnsSet>();
    public DbSet<RtsUserGridColumn> RtsUserGridColumns => Set<RtsUserGridColumn>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<TwoFactorCode> TwoFactorCodes => Set<TwoFactorCode>();
    public DbSet<UserPasswordHistory> UserPasswordHistories => Set<UserPasswordHistory>();
    public DbSet<UserSession> UserSessions => Set<UserSession>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        base.OnModelCreating(mb);

        mb.HasPostgresExtension("pgcrypto");
        mb.HasPostgresExtension("pg_trgm");

        // Move Identity tables to identity schema
        mb.Entity<ApplicationUser>().ToTable("users", "identity");
        mb.Entity<ApplicationRole>().ToTable("roles", "identity");
        mb.Entity<Microsoft.AspNetCore.Identity.IdentityUserRole<Guid>>().ToTable("user_roles", "identity");
        mb.Entity<Microsoft.AspNetCore.Identity.IdentityUserClaim<Guid>>().ToTable("user_claims", "identity");
        mb.Entity<Microsoft.AspNetCore.Identity.IdentityUserLogin<Guid>>().ToTable("user_logins", "identity");
        mb.Entity<Microsoft.AspNetCore.Identity.IdentityRoleClaim<Guid>>().ToTable("role_claims", "identity");
        mb.Entity<Microsoft.AspNetCore.Identity.IdentityUserToken<Guid>>().ToTable("user_tokens", "identity");

        // ApplicationUser extensions
        mb.Entity<ApplicationUser>(e =>
        {
            e.HasIndex(x => new { x.NormalizedEmail, x.TenantId }).IsUnique().HasFilter("\"IsActive\" = true");
            e.Property(x => x.FirstName).HasMaxLength(100);
            e.Property(x => x.LastName).HasMaxLength(100);
            e.Property(x => x.PreferredLocale).HasMaxLength(10).HasDefaultValue("en-US");
        });

        // Tenants
        mb.Entity<Tenant>(e =>
        {
            e.ToTable("tenants");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Slug).HasMaxLength(100).IsRequired();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            e.HasIndex(x => x.Slug).IsUnique();
        });

        mb.Entity<TenantSettings>(e =>
        {
            e.ToTable("tenant_settings");
            e.HasKey(x => x.TenantId);
            e.HasOne(x => x.Tenant).WithOne(x => x.Settings).HasForeignKey<TenantSettings>(x => x.TenantId);
        });

        mb.Entity<SsoConfiguration>(e =>
        {
            e.ToTable("sso_configurations");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Provider).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.ClaimMappings).HasColumnType("jsonb");
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // PermissionGroups
        mb.Entity<PermissionGroup>(e =>
        {
            e.ToTable("permission_groups");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.RowVersion).IsRowVersion().HasColumnName("xmin").HasColumnType("xid");
            e.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<MenuPermission>(e =>
        {
            e.ToTable("menu_permissions");
            e.HasKey(x => new { x.PermissionGroupId, x.MenuKey });
            e.Property(x => x.MenuKey).HasMaxLength(100);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<DashboardPermission>(e =>
        {
            e.ToTable("dashboard_permissions");
            e.HasKey(x => new { x.PermissionGroupId, x.DashboardId });
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // Dashboard Categories
        mb.Entity<DashboardCategory>(e =>
        {
            e.ToTable("dashboard_categories");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(500);
            e.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // Dashboards
        mb.Entity<Dashboard>(e =>
        {
            e.ToTable("dashboards");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.LayoutJson).HasColumnType("jsonb");
            e.Property(x => x.RowVersion).IsRowVersion().HasColumnName("xmin").HasColumnType("xid");
            e.HasIndex(x => new { x.TenantId, x.Name });
            e.HasOne(x => x.Category)
                .WithMany(x => x.Dashboards)
                .HasForeignKey(x => x.CategoryId)
                .OnDelete(DeleteBehavior.SetNull);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId && !x.IsDeleted);
        });

        mb.Entity<DashboardWidget>(e =>
        {
            e.ToTable("dashboard_widgets");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.GridId).UseIdentityByDefaultColumn();  // BY DEFAULT allows explicit insert from RTS save
            e.Property(x => x.PositionJson).HasColumnType("jsonb");
            e.Property(x => x.ConfigJson).HasColumnType("jsonb");
            // Match the parent Dashboard GQF so widgets are never orphaned by the soft-delete filter
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId && !x.IsDeleted);
        });

        // Widget catalog (cross-tenant)
        mb.Entity<WidgetCatalogItem>(e =>
        {
            e.ToTable("widget_catalog");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Category).HasMaxLength(100).IsRequired();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
        });

        // Widget templates (tenant-scoped)
        mb.Entity<WidgetTemplate>(e =>
        {
            e.ToTable("widget_templates");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.ConfigJson).HasColumnType("jsonb");
            e.HasOne(x => x.CatalogItem).WithMany().HasForeignKey(x => x.WidgetCatalogItemId);
            e.HasOne(x => x.Tenant).WithMany().HasForeignKey(x => x.TenantId);
            e.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // Reference tables (tenant-scoped resource catalogue synced from CC platform)
        ConfigureReferenceTable<NgcQueue>(mb, "ngc_queues");
        ConfigureReferenceTable<NgcAgentGroup>(mb, "ngc_AgentGroups");

        // PG resource join tables
        mb.Entity<PgQueue>(e => { e.ToTable("pg_queues"); e.HasKey(x => new { x.PermissionGroupId, x.ObjectId }); e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId); });
        mb.Entity<PgSkill>(e => { e.ToTable("pg_skills"); e.HasKey(x => new { x.PermissionGroupId, x.ObjectId }); e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId); });
        mb.Entity<PgBusinessUnit>(e => { e.ToTable("pg_business_units"); e.HasKey(x => new { x.PermissionGroupId, x.BusinessUnitId }); e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId); });
        mb.Entity<PgSupergroup>(e => { e.ToTable("pg_supergroups"); e.HasKey(x => new { x.PermissionGroupId, x.SupergroupId }); e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId); });

        // Identity auth tables
        mb.Entity<RefreshToken>(e =>
        {
            e.ToTable("refresh_tokens", "identity");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<TwoFactorCode>(e =>
        {
            e.ToTable("two_factor_codes", "identity");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.CodeHash).HasMaxLength(64).IsRequired();
            e.Property(x => x.Salt).HasMaxLength(32).IsRequired();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<UserPasswordHistory>(e =>
        {
            e.ToTable("user_password_history", "identity");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<UserSession>(e =>
        {
            e.ToTable("user_sessions", "identity");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.IpAddress).HasMaxLength(45);
            e.Property(x => x.UserAgent).HasMaxLength(500);
            e.HasIndex(x => new { x.UserId, x.IsRevoked, x.ExpiresAt });
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // NGC Configuration tables
        mb.Entity<NgcSite>(e =>
        {
            e.ToTable("NGC_Site");
            e.HasKey(x => x.SiteId);
            e.Property(x => x.SiteId).HasMaxLength(50);
            e.Property(x => x.SiteName).HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.TimeZone).HasMaxLength(10);
            e.Property(x => x.ClearTime).HasMaxLength(5);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<NgcBusinessUnit>(e =>
        {
            e.ToTable("NGC_BusinessUnit");
            e.HasKey(x => x.BusinessUnitId);
            e.Property(x => x.BusinessUnitId).UseIdentityAlwaysColumn();
            e.Property(x => x.BusinessUnitName).HasMaxLength(100);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.Property(x => x.SiteId).HasMaxLength(50);
            e.HasOne(x => x.Site)
                .WithMany(x => x.BusinessUnits)
                .HasForeignKey(x => x.SiteId)
                .HasPrincipalKey(x => x.SiteId)
                .IsRequired(false)
                .OnDelete(DeleteBehavior.SetNull);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<NgcSupergroup>(e =>
        {
            e.ToTable("NGC_Supergroup");
            e.HasKey(x => x.SupergroupId);
            e.Property(x => x.SupergroupId).UseIdentityAlwaysColumn();
            e.Property(x => x.SupergroupName).HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<NgcBusinessUnitQueueClassification>(e =>
        {
            e.ToTable("NGC_BusinessUnitQueueClassification");
            e.HasKey(x => new { x.BusinessUnitId, x.QueueId });
            e.Property(x => x.QueueId).HasMaxLength(100);
            e.Property(x => x.ClassificationId).HasMaxLength(100);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.HasOne(x => x.BusinessUnit).WithMany(x => x.QueueAssignments)
                .HasForeignKey(x => x.BusinessUnitId);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<NgcBusinessUnitSupergroup>(e =>
        {
            e.ToTable("NGC_BusinessUnitSupergroup");
            e.HasKey(x => new { x.BusinessUnitId, x.SupergroupId });
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.HasOne(x => x.BusinessUnit).WithMany(x => x.SupergroupAssignments)
                .HasForeignKey(x => x.BusinessUnitId);
            e.HasOne(x => x.Supergroup).WithMany(x => x.BusinessUnitAssignments)
                .HasForeignKey(x => x.SupergroupId);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<NgcSupergroupAgentgroup>(e =>
        {
            e.ToTable("NGC_SupergroupAgentgroup");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).UseIdentityAlwaysColumn();
            e.Property(x => x.AgentgroupId).HasMaxLength(100);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.HasOne(x => x.Supergroup).WithMany(x => x.AgentGroupAssignments)
                .HasForeignKey(x => x.SupergroupId);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        mb.Entity<RtsGridMetric>(e =>
        {
            e.ToTable("rtsgrid_metric");
            e.HasKey(x => x.MetricId);
            e.Property(x => x.MetricId).HasMaxLength(100);
            e.Property(x => x.DataType).HasMaxLength(50).IsRequired();
            e.Property(x => x.MetricFunction).HasMaxLength(200).IsRequired();
            e.Property(x => x.MetricParameter).HasMaxLength(200).IsRequired();
            e.Property(x => x.MetricFormat).HasMaxLength(100);
            e.Property(x => x.DefaultValue).HasMaxLength(100);
            e.Property(x => x.ValueType).HasMaxLength(20).HasDefaultValue("String");
            e.Property(x => x.MetricType).HasMaxLength(20).HasDefaultValue("Agent");
            // Cross-tenant entity: no GQF, metrics are shared across all tenants
        });

        // RTS UserGrid tables (compatibility with external SignalR server)
        mb.Entity<RtsUserGridGrid>(e =>
        {
            e.ToTable("RTSUserGrid_Grid");
            e.HasKey(x => x.GridId);
            e.Property(x => x.GridId).UseIdentityAlwaysColumn();
            e.Property(x => x.Title).HasMaxLength(100).IsRequired();
            e.Property(x => x.RowsFilter).HasMaxLength(300);
            e.Property(x => x.RowsFilterNew).HasMaxLength(300);
            e.Property(x => x.TextDirection).HasMaxLength(5);
            e.Property(x => x.ThresholdScript).HasColumnType("text");
            e.Property(x => x.NoRecordsText).HasColumnType("text");
        });

        mb.Entity<RtsUserGridColumnsSet>(e =>
        {
            e.ToTable("RTSUserGrid_ColumnsSet");
            e.HasKey(x => x.ColumnsSetId);
            e.Property(x => x.ColumnsSetId).UseIdentityAlwaysColumn();
            e.Property(x => x.Title).HasMaxLength(100).IsRequired();
            e.Property(x => x.Description).HasColumnType("text");
            e.Property(x => x.Direction).HasMaxLength(10);
        });

        mb.Entity<RtsUserGridColumn>(e =>
        {
            e.ToTable("RTSUserGrid_Column");
            e.HasKey(x => x.ColumnId);
            e.Property(x => x.ColumnId).UseIdentityAlwaysColumn();
            e.Property(x => x.Title).HasMaxLength(100).IsRequired();
            e.Property(x => x.MetricId).HasMaxLength(100);
        });
    }

    private void ConfigureReferenceTable<T>(ModelBuilder mb, string table)
        where T : class, new()
    {
        mb.Entity<T>(e =>
        {
            e.ToTable(table);
            e.Property<Guid>("Id").ValueGeneratedNever();
            e.HasKey("Id");
            e.Property<string>("ExternalId").HasMaxLength(100).IsRequired();
            e.Property<string>("Name").HasMaxLength(200).IsRequired();
            e.HasQueryFilter(x => EF.Property<Guid>(x, "TenantId") == tenantContext.TenantId);
        });
    }
}
