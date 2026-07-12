using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <summary>
    /// Design B (ADR-007): backend tables are owned by db/schema.sql, NOT the App context.
    /// The App chain historically created stale versions (e.g. RTSGrid_Metric without CatalogCategory);
    /// SeparateBackendTablesToBeDb excluded them from the model snapshot but never dropped them.
    /// This migration drops all schema.sql-owned backend tables so `migrate` = shell-only.
    /// Prod: schema.sql creates the real ones next.
    /// Dev/Test: beDb.MigrateAsync runs AFTER App migrations and recreates them.
    /// </summary>
    public partial class DropAppOwnedBackendTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Drop backend tables owned by db/schema.sql (25 tables total).
            // Order: children first (FK constraints), parents last.
            // CASCADE handles dependent objects (constraints, indexes).

            // RTSGrid family (depends on RTSGrid_Metric, RTSGrid_Grid)
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Cell"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Column"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Row"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Grid"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_MetricTranslation"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Metric"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Statistic"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_UserStatus"" CASCADE;");

            // RTSUserGrid family
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSUserGrid_Column"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSUserGrid_ColumnsSet"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSUserGrid_Grid"" CASCADE;");

            // RTSData tables
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSData_ChatMessage"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSData_Interaction"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSData_UserStatus"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""RTSData_UserStatusLog"" CASCADE;");

            // NGC family (depends on NGC_Site, NGC_BusinessUnit, NGC_Supergroup)
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_BusinessUnitQueueClassification"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_BusinessUnitSupergroup"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_SupergroupAgentgroup"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_UserAgentgroup"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_AgentGroups"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_Queues"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_Supergroup"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_BusinessUnit"" CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS ""NGC_Site"" CASCADE;");

            // Utility tables
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS public.db_patch_history CASCADE;");
            migrationBuilder.Sql(@"DROP TABLE IF EXISTS public.metric_deploy_log CASCADE;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Forward-only migration. Backend tables are recreated by:
            // - Dev/Test: beDb.MigrateAsync (runs after App migrations)
            // - Prod: db/schema.sql (applied by operator)
            // Do not attempt to recreate stale table definitions here.
        }
    }
}
