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
    public DbSet<DashboardWidget> DashboardWidgets => Set<DashboardWidget>();
    public DbSet<WidgetCatalogItem> WidgetCatalogItems => Set<WidgetCatalogItem>();
    public DbSet<Queue> Queues => Set<Queue>();
    public DbSet<Skill> Skills => Set<Skill>();
    public DbSet<AgentSupergroup> AgentSupergroups => Set<AgentSupergroup>();
    public DbSet<BusinessUnit> BusinessUnits => Set<BusinessUnit>();
    public DbSet<PgQueue> PgQueues => Set<PgQueue>();
    public DbSet<PgSkill> PgSkills => Set<PgSkill>();
    public DbSet<PgAgentSupergroup> PgAgentSupergroups => Set<PgAgentSupergroup>();
    public DbSet<PgBusinessUnit> PgBusinessUnits => Set<PgBusinessUnit>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<TwoFactorCode> TwoFactorCodes => Set<TwoFactorCode>();
    public DbSet<UserPasswordHistory> UserPasswordHistories => Set<UserPasswordHistory>();

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
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId && !x.IsDeleted);
        });

        mb.Entity<DashboardWidget>(e =>
        {
            e.ToTable("dashboard_widgets");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.PositionJson).HasColumnType("jsonb");
            e.Property(x => x.ConfigJson).HasColumnType("jsonb");
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

        // Reference tables
        ConfigureReferenceTable<Queue>(mb, "queues");
        ConfigureReferenceTable<Skill>(mb, "skills");
        ConfigureReferenceTable<AgentSupergroup>(mb, "agent_supergroups");
        ConfigureReferenceTable<BusinessUnit>(mb, "business_units");

        // PG resource tables
        ConfigurePgTable<PgQueue>(mb, "pg_queues");
        ConfigurePgTable<PgSkill>(mb, "pg_skills");
        ConfigurePgTable<PgAgentSupergroup>(mb, "pg_agent_supergroups");
        ConfigurePgTable<PgBusinessUnit>(mb, "pg_business_units");

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
    }

    private static void ConfigureReferenceTable<T>(ModelBuilder mb, string table) where T : class
    {
        mb.Entity<T>(e =>
        {
            e.ToTable(table);
        });
    }

    private static void ConfigurePgTable<T>(ModelBuilder mb, string table) where T : class
    {
        mb.Entity<T>(e =>
        {
            e.ToTable(table);
        });
    }
}
