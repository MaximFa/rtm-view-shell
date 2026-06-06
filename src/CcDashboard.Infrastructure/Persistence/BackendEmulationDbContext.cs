using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// DbContext for backend-owned tables (NGC_*, RTSGrid_*, RTSUserGrid_*).
/// Migrations from this context run only in dev/test environments — in production
/// these tables are created and maintained by the backend team's deployment.
/// ADR-007: Database boundary — shell tables vs backend tables.
/// </summary>
public class BackendEmulationDbContext(DbContextOptions<BackendEmulationDbContext> options)
    : DbContext(options)
{
    // NGC Configuration tables
    public DbSet<NgcSite> NgcSites => Set<NgcSite>();
    public DbSet<NgcBusinessUnit> NgcBusinessUnits => Set<NgcBusinessUnit>();
    public DbSet<NgcSupergroup> NgcSupergroups => Set<NgcSupergroup>();
    public DbSet<NgcQueue> NgcQueues => Set<NgcQueue>();
    public DbSet<NgcAgentGroup> NgcAgentGroups => Set<NgcAgentGroup>();

    // NGC junction tables
    public DbSet<NgcBusinessUnitQueueClassification> NgcBusinessUnitQueueClassifications => Set<NgcBusinessUnitQueueClassification>();
    public DbSet<NgcBusinessUnitSupergroup> NgcBusinessUnitSupergroups => Set<NgcBusinessUnitSupergroup>();
    public DbSet<NgcSupergroupAgentgroup> NgcSupergroupAgentgroups => Set<NgcSupergroupAgentgroup>();

    // RTS Grid metrics (cross-tenant)
    public DbSet<RtsGridMetric> RtsGridMetrics => Set<RtsGridMetric>();
    public DbSet<RtsGridMetricTranslation> RtsGridMetricTranslations => Set<RtsGridMetricTranslation>();

    // RTS UserGrid tables (compatibility with external SignalR server - Agent Grid)
    public DbSet<RtsUserGridGrid> RtsUserGridGrids => Set<RtsUserGridGrid>();
    public DbSet<RtsUserGridColumnsSet> RtsUserGridColumnsSets => Set<RtsUserGridColumnsSet>();
    public DbSet<RtsUserGridColumn> RtsUserGridColumns => Set<RtsUserGridColumn>();

    // RTS Grid tables (compatibility with external SignalR server - Queue Grid)
    public DbSet<RtsGridGrid> RtsGridGrids => Set<RtsGridGrid>();
    public DbSet<RtsGridColumn> RtsGridColumns => Set<RtsGridColumn>();
    public DbSet<RtsGridRow> RtsGridRows => Set<RtsGridRow>();
    public DbSet<RtsGridCell> RtsGridCells => Set<RtsGridCell>();

    // RTSData tables — read-only; written by CC backend / external system
    public DbSet<RtsDataInteraction> RtsDataInteractions => Set<RtsDataInteraction>();
    public DbSet<RtsDataUserStatus> RtsDataUserStatuses => Set<RtsDataUserStatus>();
    public DbSet<RtsDataUserStatusLog> RtsDataUserStatusLogs => Set<RtsDataUserStatusLog>();

    // RTSData tables - RTM-M1 additions
    public DbSet<RtsDataChatMessage> RtsDataChatMessages => Set<RtsDataChatMessage>();

    // RTSGrid tables - RTM-M1 additions
    public DbSet<RtsGridStatistic> RtsGridStatistics => Set<RtsGridStatistic>();
    public DbSet<RtsGridUserStatus> RtsGridUserStatuses => Set<RtsGridUserStatus>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        base.OnModelCreating(mb);

        // NGC Configuration tables — NO Global Query Filters (backend-owned)
        mb.Entity<NgcSite>(e =>
        {
            e.ToTable("NGC_Site");
            e.HasKey(x => x.SiteId);
            e.Property(x => x.SiteId).HasMaxLength(50);
            e.Property(x => x.SiteName).HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.TimeZone).HasMaxLength(10);
            e.Property(x => x.ClearTime).HasMaxLength(5);
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
        });

        mb.Entity<NgcSupergroup>(e =>
        {
            e.ToTable("NGC_Supergroup");
            e.HasKey(x => x.SupergroupId);
            e.Property(x => x.SupergroupId).UseIdentityAlwaysColumn();
            e.Property(x => x.SupergroupName).HasMaxLength(200);
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
        });

        // Reference tables (tenant-scoped in shell, but no GQF here for backend emulation)
        mb.Entity<NgcQueue>(e =>
        {
            e.ToTable("NGC_Queues");
            e.Property<Guid>("Id").ValueGeneratedNever();
            e.HasKey("Id");
            e.Property<string>("ExternalId").HasMaxLength(100).IsRequired();
            e.Property<string>("Name").HasMaxLength(200).IsRequired();
        });

        mb.Entity<NgcAgentGroup>(e =>
        {
            e.ToTable("NGC_AgentGroups");
            e.Property<Guid>("Id").ValueGeneratedNever();
            e.HasKey("Id");
            e.Property<string>("ExternalId").HasMaxLength(100).IsRequired();
            e.Property<string>("Name").HasMaxLength(200).IsRequired();
        });

        // NGC junction tables
        mb.Entity<NgcBusinessUnitQueueClassification>(e =>
        {
            e.ToTable("NGC_BusinessUnitQueueClassification");
            e.HasKey(x => new { x.BusinessUnitId, x.QueueId });
            e.Property(x => x.QueueId).HasMaxLength(100);
            e.Property(x => x.ClassificationId).HasMaxLength(100);
            e.Property(x => x.CreatedBy).HasMaxLength(100);
            e.HasOne(x => x.BusinessUnit).WithMany(x => x.QueueAssignments)
                .HasForeignKey(x => x.BusinessUnitId);
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
        });

        // RTS Grid metrics (cross-tenant)
        mb.Entity<RtsGridMetric>(e =>
        {
            e.ToTable("RTSGrid_Metric");
            e.HasKey(x => x.MetricId);
            e.Property(x => x.MetricId).HasMaxLength(100);
            e.Property(x => x.DataType).HasMaxLength(50).IsRequired();
            e.Property(x => x.MetricFunction).HasMaxLength(200).IsRequired();
            e.Property(x => x.MetricParameter).HasMaxLength(200).IsRequired();
            e.Property(x => x.MetricFormat).HasMaxLength(100);
            e.Property(x => x.DefaultValue).HasMaxLength(100);
            e.Property(x => x.ValueType).HasMaxLength(20).HasDefaultValue("String");
            e.Property(x => x.MetricType).HasMaxLength(20).HasDefaultValue("Agent");

            // Catalogue — editorial
            e.Property(x => x.DisplayName).HasMaxLength(200);
            e.Property(x => x.ShortDescription).HasMaxLength(500);
            e.Property(x => x.LongDescription).HasColumnType("text");
            e.Property(x => x.Comparison).HasColumnType("text");
            e.Property(x => x.StandardKpi).HasMaxLength(100);
            e.Property(x => x.StandardRef).HasMaxLength(200);

            // Catalogue — taxonomy
            e.Property(x => x.CatalogCategory).HasMaxLength(20);
            e.Property(x => x.Family).HasMaxLength(100);
            e.Property(x => x.Channel).HasMaxLength(20);
            // ThresholdSec int? — default mapping is fine

            // Catalogue — lifecycle
            e.Property(x => x.CatalogStatus).HasMaxLength(20);
            e.Property(x => x.CatalogNotes).HasColumnType("text");
        });

        // RTS Grid metric translations (cross-tenant, per-locale)
        mb.Entity<RtsGridMetricTranslation>(e =>
        {
            e.ToTable("RTSGrid_MetricTranslation");
            e.HasKey(x => new { x.MetricId, x.Locale });
            e.Property(x => x.MetricId).HasMaxLength(100);
            e.Property(x => x.Locale).HasMaxLength(10);
            e.Property(x => x.DisplayName).HasMaxLength(200);
            e.Property(x => x.ShortDescription).HasMaxLength(500);
            e.Property(x => x.LongDescription).HasColumnType("text");
            e.Property(x => x.Comparison).HasColumnType("text");
        });

        // RTS UserGrid tables
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

        // RTS Grid tables (Queue Grid)
        mb.Entity<RtsGridGrid>(e =>
        {
            e.ToTable("RTSGrid_Grid");
            e.HasKey(x => x.GridId);
            e.Property(x => x.GridId).UseIdentityAlwaysColumn();
            e.Property(x => x.Title).HasMaxLength(100).IsRequired();
            e.Property(x => x.ThresholdScript).HasColumnType("text");
        });

        mb.Entity<RtsGridColumn>(e =>
        {
            e.ToTable("RTSGrid_Column");
            e.HasKey(x => x.ColumnId);
            e.Property(x => x.ColumnId).UseIdentityAlwaysColumn();
        });

        mb.Entity<RtsGridRow>(e =>
        {
            e.ToTable("RTSGrid_Row");
            e.HasKey(x => x.RowId);
            e.Property(x => x.RowId).UseIdentityAlwaysColumn();
            e.Property(x => x.ThresholdScript).HasColumnType("text");
        });

        mb.Entity<RtsGridCell>(e =>
        {
            e.ToTable("RTSGrid_Cell");
            e.HasKey(x => x.CellId);
            e.Property(x => x.CellId).UseIdentityAlwaysColumn();
            e.Property(x => x.CellType).HasMaxLength(50);
            e.Property(x => x.Value).HasMaxLength(500);
            e.Property(x => x.Tooltip).HasMaxLength(500);
            e.Property(x => x.OnClick).HasMaxLength(500);
        });

        // --- RTSData tables (read-only, no Global Query Filter) ---

        mb.Entity<RtsDataInteraction>(e =>
        {
            e.ToTable("RTSData_Interaction");
            e.HasKey(x => new { x.InteractionId, x.Segment, x.OnDate, x.ServerId, x.Workgroup });
            e.Property(x => x.InteractionId).HasMaxLength(50);
            e.Property(x => x.OnDate).HasMaxLength(50);
            e.Property(x => x.ServerId).HasMaxLength(50);
            e.Property(x => x.Workgroup).HasMaxLength(100);
            e.Property(x => x.UserId).HasMaxLength(50);
            e.Property(x => x.InteractionType).HasMaxLength(50);
            e.Property(x => x.CallType).HasMaxLength(50);
            e.Property(x => x.Direction).HasMaxLength(50);
            e.Property(x => x.RemoteAddress).HasMaxLength(50);
            e.Property(x => x.LastUserId).HasMaxLength(50);
            e.Property(x => x.LastWorkgroup).HasMaxLength(100);
            e.Property(x => x.TimeZone).HasMaxLength(10);
            // UPSERT conflict key is (InteractionId, Segment, ServerId) - 3 cols, not the 5-col PK
            e.HasIndex(x => new { x.InteractionId, x.Segment, x.ServerId })
                .IsUnique()
                .HasDatabaseName("IX_RTSData_Interaction_UpsertKey");
            // No Global Query Filter: RTSData tables are backend-owned cross-tenant tables.
            // Shell filters by TenantId explicitly in every query.
        });

        mb.Entity<RtsDataUserStatus>(e =>
        {
            e.ToTable("RTSData_UserStatus");
            e.HasKey(x => new { x.UserId, x.StatusId, x.ServerId, x.OnDate });
            e.Property(x => x.UserId).HasMaxLength(100);
            e.Property(x => x.StatusId).HasMaxLength(100);
            e.Property(x => x.ServerId).HasMaxLength(50);
            e.Property(x => x.OnDate).HasMaxLength(50);
            e.Property(x => x.StatusName).HasMaxLength(100);
            e.Property(x => x.StatusGroup).HasMaxLength(100);
            e.Property(x => x.DisplayName).HasMaxLength(100);
            e.Property(x => x.TimeZone).HasMaxLength(10);
        });

        mb.Entity<RtsDataUserStatusLog>(e =>
        {
            e.ToTable("RTSData_UserStatusLog");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).UseIdentityAlwaysColumn();
            e.Property(x => x.UserId).HasMaxLength(100);
            e.Property(x => x.StatusId).HasMaxLength(100);
            e.Property(x => x.StatusGroup).HasMaxLength(50);   // NEW column
            e.Property(x => x.ServerId).HasMaxLength(50);
            e.Property(x => x.OnDate).HasMaxLength(50);
            e.Property(x => x.TimeZone).HasMaxLength(10);
            e.Property(x => x.Duration).HasColumnType("bigint"); // milliseconds
        });

        // --- RTM-M1: 4 new entities for RTM stored procedures ---

        mb.Entity<RtsDataChatMessage>(e =>
        {
            e.ToTable("RTSData_ChatMessage");
            e.HasKey(x => new { x.MessageId, x.ServerId, x.OnDate });
            e.Property(x => x.MessageId).HasMaxLength(100);
            e.Property(x => x.ServerId).HasMaxLength(50);
            e.Property(x => x.OnDate).HasMaxLength(50);
            e.Property(x => x.InteractionId).HasMaxLength(100);
            e.Property(x => x.UserId).HasMaxLength(100);
            e.Property(x => x.MsgDirection).HasMaxLength(50);
            e.Property(x => x.Sender).HasMaxLength(200);
            e.Property(x => x.Recipient).HasMaxLength(200);
            e.Property(x => x.Body).HasColumnType("text");
            e.Property(x => x.DeliveryStatus).HasMaxLength(50);
            e.Property(x => x.MsgTimeStamp).HasColumnName("TimeStamp");
            // UPSERT conflict key is (MessageId, ServerId) - 2 cols, not the 3-col PK
            e.HasIndex(x => new { x.MessageId, x.ServerId }).IsUnique();
        });

        mb.Entity<RtsGridStatistic>(e =>
        {
            e.ToTable("RTSGrid_Statistic");
            e.HasKey(x => x.StatisticId);
            e.Property(x => x.StatisticId).ValueGeneratedOnAdd();
            e.Property(x => x.Category).HasMaxLength(100);
            e.Property(x => x.Definition).HasMaxLength(500);
            e.Property(x => x.ParamType1).HasMaxLength(100);
            e.Property(x => x.ParamValue1).HasMaxLength(500);
            e.Property(x => x.ParamType2).HasMaxLength(100);
            e.Property(x => x.ParamValue2).HasMaxLength(500);
            e.Property(x => x.ParamType3).HasMaxLength(100);
            e.Property(x => x.ParamValue3).HasMaxLength(500);
            e.Property(x => x.ParamType4).HasMaxLength(100);
            e.Property(x => x.ParamValue4).HasMaxLength(500);
            e.Property(x => x.ParamType5).HasMaxLength(100);
            e.Property(x => x.ParamValue5).HasMaxLength(500);
            e.Property(x => x.ParamType6).HasMaxLength(100);
            e.Property(x => x.ParamValue6).HasMaxLength(500);
            e.Property(x => x.ParamType7).HasMaxLength(100);
            e.Property(x => x.ParamValue7).HasMaxLength(500);
            e.Property(x => x.ParamType8).HasMaxLength(100);
            e.Property(x => x.ParamValue8).HasMaxLength(500);
            e.Property(x => x.ParamType9).HasMaxLength(100);
            e.Property(x => x.ParamValue9).HasMaxLength(500);
            e.Property(x => x.ParamType10).HasMaxLength(100);
            e.Property(x => x.ParamValue10).HasMaxLength(500);
        });

        mb.Entity<RtsGridUserStatus>(e =>
        {
            e.ToTable("RTSGrid_UserStatus");
            e.HasKey(x => new { x.UserId, x.StatusId });
            e.Property(x => x.UserId).HasMaxLength(100);
            e.Property(x => x.StatusId).HasMaxLength(100);
            e.Property(x => x.StatusName).HasMaxLength(100);
            e.Property(x => x.StatusGroup).HasMaxLength(100);
            e.Property(x => x.SourceServer).HasMaxLength(50);
            e.Property(x => x.OnDate).HasMaxLength(50);
        });
    }
}
