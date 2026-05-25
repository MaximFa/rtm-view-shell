using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class InitialBackendSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Use raw SQL with IF NOT EXISTS to handle both fresh databases
            // and databases where AppDbContext migrations already created these tables.
            // ADR-007: Backend-owned tables - shell only emulates in dev/test.

            migrationBuilder.Sql(@"
                CREATE TABLE IF NOT EXISTS ""NGC_AgentGroups"" (
                    ""Id"" uuid NOT NULL,
                    ""TenantId"" uuid NOT NULL,
                    ""ExternalId"" character varying(100) NOT NULL,
                    ""Name"" character varying(200) NOT NULL,
                    ""IsActive"" boolean NOT NULL,
                    CONSTRAINT ""PK_NGC_AgentGroups"" PRIMARY KEY (""Id"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_Queues"" (
                    ""Id"" uuid NOT NULL,
                    ""TenantId"" uuid NOT NULL,
                    ""ExternalId"" character varying(100) NOT NULL,
                    ""Name"" character varying(200) NOT NULL,
                    ""IsActive"" boolean NOT NULL,
                    CONSTRAINT ""PK_NGC_Queues"" PRIMARY KEY (""Id"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_Site"" (
                    ""SiteId"" character varying(50) NOT NULL,
                    ""TenantId"" uuid NOT NULL,
                    ""SiteName"" character varying(200),
                    ""Description"" character varying(500),
                    ""TimeZone"" character varying(10),
                    ""ClearTime"" character varying(5),
                    CONSTRAINT ""PK_NGC_Site"" PRIMARY KEY (""SiteId"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_Supergroup"" (
                    ""SupergroupId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""TenantId"" uuid NOT NULL,
                    ""SupergroupName"" character varying(200),
                    ""Description"" character varying(500),
                    ""CreatedDatetime"" timestamp with time zone,
                    ""CreatedBy"" character varying(100),
                    ""SupergroupIdOld"" integer,
                    CONSTRAINT ""PK_NGC_Supergroup"" PRIMARY KEY (""SupergroupId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSGrid_Metric"" (
                    ""MetricId"" character varying(100) NOT NULL,
                    ""Description"" text,
                    ""DataType"" character varying(50) NOT NULL,
                    ""MetricFunction"" character varying(200) NOT NULL,
                    ""MetricParameter"" character varying(200) NOT NULL,
                    ""MetricFormat"" character varying(100),
                    ""DefaultValue"" character varying(100),
                    ""ValueType"" character varying(20) NOT NULL DEFAULT 'String',
                    ""MetricType"" character varying(20) NOT NULL DEFAULT 'Agent',
                    CONSTRAINT ""PK_RTSGrid_Metric"" PRIMARY KEY (""MetricId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSUserGrid_Column"" (
                    ""ColumnId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""ColumnsSetId"" integer NOT NULL,
                    ""Title"" character varying(100) NOT NULL,
                    ""MetricId"" character varying(100),
                    ""StyleId"" integer,
                    ""ColumnsOrder"" integer NOT NULL,
                    CONSTRAINT ""PK_RTSUserGrid_Column"" PRIMARY KEY (""ColumnId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSUserGrid_ColumnsSet"" (
                    ""ColumnsSetId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""Title"" character varying(100) NOT NULL,
                    ""Description"" text,
                    ""Direction"" character varying(10),
                    CONSTRAINT ""PK_RTSUserGrid_ColumnsSet"" PRIMARY KEY (""ColumnsSetId"")
                );

                CREATE TABLE IF NOT EXISTS ""RTSUserGrid_Grid"" (
                    ""GridId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""UnionId"" integer,
                    ""StyleId"" integer,
                    ""Title"" character varying(100) NOT NULL,
                    ""RowsFilter"" character varying(300),
                    ""PageSize"" integer,
                    ""ColumnsSetId"" integer,
                    ""ThresholdScript"" text,
                    ""RowsFilterNew"" character varying(300),
                    ""NoRecordsText"" text,
                    ""AllowPaging"" boolean,
                    ""AllowScroll"" boolean,
                    ""TextDirection"" character varying(5),
                    CONSTRAINT ""PK_RTSUserGrid_Grid"" PRIMARY KEY (""GridId"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_BusinessUnit"" (
                    ""BusinessUnitId"" integer GENERATED ALWAYS AS IDENTITY,
                    ""TenantId"" uuid NOT NULL,
                    ""BusinessUnitName"" character varying(100),
                    ""Description"" text,
                    ""CreatedDatetime"" timestamp with time zone,
                    ""CreatedBy"" character varying(100),
                    ""SiteId"" character varying(50),
                    CONSTRAINT ""PK_NGC_BusinessUnit"" PRIMARY KEY (""BusinessUnitId"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_SupergroupAgentgroup"" (
                    ""Id"" integer GENERATED ALWAYS AS IDENTITY,
                    ""SupergroupId"" integer,
                    ""AgentgroupId"" character varying(100),
                    ""TenantId"" uuid NOT NULL,
                    ""CreatedDatetime"" timestamp with time zone,
                    ""CreatedBy"" character varying(100),
                    CONSTRAINT ""PK_NGC_SupergroupAgentgroup"" PRIMARY KEY (""Id"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_BusinessUnitQueueClassification"" (
                    ""BusinessUnitId"" integer NOT NULL,
                    ""QueueId"" character varying(100) NOT NULL,
                    ""TenantId"" uuid NOT NULL,
                    ""ClassificationId"" character varying(100),
                    ""CreatedDatetime"" timestamp with time zone,
                    ""CreatedBy"" character varying(100),
                    CONSTRAINT ""PK_NGC_BusinessUnitQueueClassification"" PRIMARY KEY (""BusinessUnitId"", ""QueueId"")
                );

                CREATE TABLE IF NOT EXISTS ""NGC_BusinessUnitSupergroup"" (
                    ""BusinessUnitId"" integer NOT NULL,
                    ""SupergroupId"" integer NOT NULL,
                    ""TenantId"" uuid NOT NULL,
                    ""CreatedDatetime"" timestamp with time zone,
                    ""CreatedBy"" character varying(100),
                    CONSTRAINT ""PK_NGC_BusinessUnitSupergroup"" PRIMARY KEY (""BusinessUnitId"", ""SupergroupId"")
                );
            ");

            // Add foreign keys only if they don't exist (using DO block)
            migrationBuilder.Sql(@"
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_NGC_BusinessUnit_NGC_Site_SiteId') THEN
                        ALTER TABLE ""NGC_BusinessUnit"" ADD CONSTRAINT ""FK_NGC_BusinessUnit_NGC_Site_SiteId""
                            FOREIGN KEY (""SiteId"") REFERENCES ""NGC_Site""(""SiteId"") ON DELETE SET NULL;
                    END IF;

                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_NGC_SupergroupAgentgroup_NGC_Supergroup_SupergroupId') THEN
                        ALTER TABLE ""NGC_SupergroupAgentgroup"" ADD CONSTRAINT ""FK_NGC_SupergroupAgentgroup_NGC_Supergroup_SupergroupId""
                            FOREIGN KEY (""SupergroupId"") REFERENCES ""NGC_Supergroup""(""SupergroupId"");
                    END IF;

                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_NGC_BusinessUnitQueueClassification_NGC_BusinessUnit_Busine~') THEN
                        ALTER TABLE ""NGC_BusinessUnitQueueClassification"" ADD CONSTRAINT ""FK_NGC_BusinessUnitQueueClassification_NGC_BusinessUnit_Busine~""
                            FOREIGN KEY (""BusinessUnitId"") REFERENCES ""NGC_BusinessUnit""(""BusinessUnitId"") ON DELETE CASCADE;
                    END IF;

                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_NGC_BusinessUnitSupergroup_NGC_BusinessUnit_BusinessUnitId') THEN
                        ALTER TABLE ""NGC_BusinessUnitSupergroup"" ADD CONSTRAINT ""FK_NGC_BusinessUnitSupergroup_NGC_BusinessUnit_BusinessUnitId""
                            FOREIGN KEY (""BusinessUnitId"") REFERENCES ""NGC_BusinessUnit""(""BusinessUnitId"") ON DELETE CASCADE;
                    END IF;

                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'FK_NGC_BusinessUnitSupergroup_NGC_Supergroup_SupergroupId') THEN
                        ALTER TABLE ""NGC_BusinessUnitSupergroup"" ADD CONSTRAINT ""FK_NGC_BusinessUnitSupergroup_NGC_Supergroup_SupergroupId""
                            FOREIGN KEY (""SupergroupId"") REFERENCES ""NGC_Supergroup""(""SupergroupId"") ON DELETE CASCADE;
                    END IF;
                END $$;
            ");

            // Create indexes if not exist
            migrationBuilder.Sql(@"
                CREATE INDEX IF NOT EXISTS ""IX_NGC_BusinessUnit_SiteId"" ON ""NGC_BusinessUnit"" (""SiteId"");
                CREATE INDEX IF NOT EXISTS ""IX_NGC_BusinessUnitSupergroup_SupergroupId"" ON ""NGC_BusinessUnitSupergroup"" (""SupergroupId"");
                CREATE INDEX IF NOT EXISTS ""IX_NGC_SupergroupAgentgroup_SupergroupId"" ON ""NGC_SupergroupAgentgroup"" (""SupergroupId"");
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                DROP TABLE IF EXISTS ""NGC_BusinessUnitQueueClassification"";
                DROP TABLE IF EXISTS ""NGC_BusinessUnitSupergroup"";
                DROP TABLE IF EXISTS ""NGC_SupergroupAgentgroup"";
                DROP TABLE IF EXISTS ""NGC_BusinessUnit"";
                DROP TABLE IF EXISTS ""NGC_Supergroup"";
                DROP TABLE IF EXISTS ""NGC_Site"";
                DROP TABLE IF EXISTS ""NGC_Queues"";
                DROP TABLE IF EXISTS ""NGC_AgentGroups"";
                DROP TABLE IF EXISTS ""RTSGrid_Metric"";
                DROP TABLE IF EXISTS ""RTSUserGrid_Column"";
                DROP TABLE IF EXISTS ""RTSUserGrid_ColumnsSet"";
                DROP TABLE IF EXISTS ""RTSUserGrid_Grid"";
            ");
        }
    }
}
