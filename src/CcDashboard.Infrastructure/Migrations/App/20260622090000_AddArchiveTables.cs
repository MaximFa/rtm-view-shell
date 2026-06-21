using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App;

/// <summary>
/// Historical Reports v1 data architecture: tier-2 RAW archive tables + tier-3 aggregate indexes.
/// Per Reports_v1_DataArch.md: arch_rtsdata_* (4 partitioned tables), arch_watermark, +2 agg indexes.
/// NOTE: EF-app migrations are tracked by __ef_migrations_history, NOT db_patch_history (§38a).
/// </summary>
public partial class AddArchiveTables : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // T1: Add composite indexes for tier-3 aggregates (serve v1 reports queue/agent+range filters)
        migrationBuilder.Sql("""
            -- T1: +2 composite indexes for tier-3 aggregates (partition-local)
            CREATE INDEX IF NOT EXISTS ix_hist_queue_intervals_tenant_workgroup_interval
                ON public.hist_queue_intervals ("TenantId", "Workgroup", "IntervalStart");

            CREATE INDEX IF NOT EXISTS ix_hist_agent_intervals_tenant_agent_interval
                ON public.hist_agent_intervals ("TenantId", "AgentExternalId", "IntervalStart");
            """);

        // T1: TenantSettings.SlThresholdSeconds
        migrationBuilder.AddColumn<int>(
            name: "SlThresholdSeconds",
            table: "tenant_settings",
            type: "integer",
            nullable: true);

        // T2.1: arch_rtsdata_interaction (partitioned by PartTime monthly)
        migrationBuilder.Sql("""
            CREATE TABLE public.arch_rtsdata_interaction (
                "InteractionId" varchar(50) NOT NULL,
                "Segment" int NOT NULL,
                "OnDate" varchar(50) NOT NULL,
                "ServerId" varchar(50) NOT NULL,
                "Workgroup" varchar(100) NOT NULL,
                "PartTime" timestamptz NOT NULL,
                "ArchivedAt" timestamptz NOT NULL DEFAULT now(),
                "TenantId" uuid,
                "UserId" varchar(50) NOT NULL DEFAULT '',
                "ClassificationCode" text,
                "InteractionType" varchar(50),
                "CallType" varchar(50),
                "Direction" varchar(50),
                "CustomCallData" text,
                "IsTransferred" boolean,
                "IsAnswered" boolean,
                "IsInQueue" boolean,
                "IsTalk" boolean,
                "IsAbandoned" boolean,
                "TimeInQueue" int,
                "TalkTime" int,
                "InQueueDateTime" timestamptz,
                "AnsweredDateTime" timestamptz,
                "UpdateTime" timestamptz,
                "LastUserId" varchar(50),
                "LastWorkgroup" varchar(100),
                "IsMessaging" boolean,
                "RemoteAddress" varchar(50),
                "IsCallbackRequest" boolean,
                "TimeZone" varchar(10),
                "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text,
                "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text,
                "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text,
                "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text,
                "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text,
                PRIMARY KEY ("InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "PartTime")
            ) PARTITION BY RANGE ("PartTime");

            CREATE INDEX ix_arch_interaction_tenant_parttime ON public.arch_rtsdata_interaction ("TenantId", "PartTime");
            CREATE INDEX ix_arch_interaction_tenant_workgroup_parttime ON public.arch_rtsdata_interaction ("TenantId", "Workgroup", "PartTime");
            CREATE TABLE public.arch_rtsdata_interaction_default PARTITION OF public.arch_rtsdata_interaction DEFAULT;
            """);

        // T2.1: arch_rtsdata_userstatuslog (partitioned by PartTime monthly)
        migrationBuilder.Sql("""
            CREATE TABLE public.arch_rtsdata_userstatuslog (
                "Id" int NOT NULL,
                "PartTime" timestamptz NOT NULL,
                "ArchivedAt" timestamptz NOT NULL DEFAULT now(),
                "TenantId" uuid,
                "UserId" varchar(100),
                "StatusId" varchar(100),
                "ServerId" varchar(50),
                "OnDate" varchar(50),
                "StartTime" timestamptz,
                "EndTime" timestamptz,
                "Duration" bigint,
                "UpdateTime" timestamptz,
                "TimeZone" varchar(10),
                "StatusGroup" varchar(50),
                PRIMARY KEY ("Id", "PartTime")
            ) PARTITION BY RANGE ("PartTime");

            CREATE INDEX ix_arch_userstatuslog_tenant_parttime ON public.arch_rtsdata_userstatuslog ("TenantId", "PartTime");
            CREATE INDEX ix_arch_userstatuslog_tenant_statusgroup_starttime ON public.arch_rtsdata_userstatuslog ("TenantId", "StatusGroup", "StartTime");
            CREATE TABLE public.arch_rtsdata_userstatuslog_default PARTITION OF public.arch_rtsdata_userstatuslog DEFAULT;
            """);

        // T2.1: arch_rtsdata_chatmessage (partitioned by PartTime monthly)
        migrationBuilder.Sql("""
            CREATE TABLE public.arch_rtsdata_chatmessage (
                "MessageId" varchar(100) NOT NULL,
                "ServerId" varchar(50) NOT NULL,
                "OnDate" varchar(50) NOT NULL,
                "PartTime" timestamptz NOT NULL,
                "ArchivedAt" timestamptz NOT NULL DEFAULT now(),
                "TenantId" uuid,
                "InteractionId" varchar(100),
                "SegmentId" int,
                "UserId" varchar(100),
                "MsgDirection" varchar(50),
                "Sender" varchar(200),
                "Recipient" varchar(200),
                "Body" text,
                "DeliveryStatus" varchar(50),
                "UpdateTime" timestamptz,
                "TimeStamp" timestamptz,
                PRIMARY KEY ("MessageId", "ServerId", "OnDate", "PartTime")
            ) PARTITION BY RANGE ("PartTime");

            CREATE INDEX ix_arch_chatmessage_tenant_parttime ON public.arch_rtsdata_chatmessage ("TenantId", "PartTime");
            CREATE TABLE public.arch_rtsdata_chatmessage_default PARTITION OF public.arch_rtsdata_chatmessage DEFAULT;
            """);

        // T2.1: arch_rtsdata_userstatus (partitioned by PartTime monthly)
        migrationBuilder.Sql("""
            CREATE TABLE public.arch_rtsdata_userstatus (
                "UserId" varchar(100) NOT NULL,
                "StatusId" varchar(100) NOT NULL,
                "ServerId" varchar(50) NOT NULL,
                "OnDate" varchar(50) NOT NULL,
                "PartTime" timestamptz NOT NULL,
                "ArchivedAt" timestamptz NOT NULL DEFAULT now(),
                "TenantId" uuid,
                "StatusName" varchar(100),
                "StatusGroup" varchar(100),
                "TotalDuration" int,
                "MaxDuraction" int,
                "TotalCount" int,
                "UpdateTime" timestamptz,
                "DisplayName" varchar(100),
                "TimeZone" varchar(10),
                PRIMARY KEY ("UserId", "StatusId", "ServerId", "OnDate", "PartTime")
            ) PARTITION BY RANGE ("PartTime");

            CREATE INDEX ix_arch_userstatus_tenant_parttime ON public.arch_rtsdata_userstatus ("TenantId", "PartTime");
            CREATE TABLE public.arch_rtsdata_userstatus_default PARTITION OF public.arch_rtsdata_userstatus DEFAULT;
            """);

        // T2.2: arch_watermark (tracks archive progress per table+tenant)
        migrationBuilder.Sql("""
            CREATE TABLE public.arch_watermark (
                "TableName" text NOT NULL,
                "TenantId" uuid NOT NULL,
                "ArchivedThrough" timestamptz NOT NULL,
                PRIMARY KEY ("TableName", "TenantId")
            );
            """);

        // Create initial partitions for arch tables (current + next 2 + prior month)
        migrationBuilder.Sql("""
            DO $$
            DECLARE
                curr_month date := date_trunc('month', CURRENT_DATE);
                m date;
                part_name text;
                tables text[] := ARRAY['arch_rtsdata_interaction', 'arch_rtsdata_userstatuslog',
                                       'arch_rtsdata_chatmessage', 'arch_rtsdata_userstatus'];
                t text;
            BEGIN
                FOREACH t IN ARRAY tables LOOP
                    FOR i IN -1..2 LOOP
                        m := curr_month + (i || ' months')::interval;
                        part_name := t || '_' || to_char(m, 'YYYY_MM');
                        EXECUTE format(
                            'CREATE TABLE IF NOT EXISTS public.%I PARTITION OF public.%I
                             FOR VALUES FROM (%L) TO (%L)',
                            part_name, t, m, m + '1 month'::interval
                        );
                    END LOOP;
                END LOOP;
            END $$;
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            DROP TABLE IF EXISTS public.arch_watermark;
            DROP TABLE IF EXISTS public.arch_rtsdata_userstatus CASCADE;
            DROP TABLE IF EXISTS public.arch_rtsdata_chatmessage CASCADE;
            DROP TABLE IF EXISTS public.arch_rtsdata_userstatuslog CASCADE;
            DROP TABLE IF EXISTS public.arch_rtsdata_interaction CASCADE;
            DROP INDEX IF EXISTS public.ix_hist_agent_intervals_tenant_agent_interval;
            DROP INDEX IF EXISTS public.ix_hist_queue_intervals_tenant_workgroup_interval;
            """);

        migrationBuilder.DropColumn(
            name: "SlThresholdSeconds",
            table: "tenant_settings");
    }
}
