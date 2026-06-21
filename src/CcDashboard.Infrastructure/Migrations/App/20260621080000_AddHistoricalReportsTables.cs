using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App;

/// <summary>
/// Historical Reports data layer: partitioned tables and management functions.
/// Per CC-HIST-001: hist_queue_intervals, hist_agent_intervals (monthly RANGE partitions),
/// user_reports (config table), hist_aggregation_watermarks, partition management functions.
/// </summary>
public partial class AddHistoricalReportsTables : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Partitioned tables must be created via raw SQL - EF Core 8 cannot express native PG partitioning
        migrationBuilder.Sql("""
            -- hist_queue_intervals: monthly RANGE partition by IntervalStart
            CREATE TABLE public.hist_queue_intervals (
                "Id" uuid NOT NULL,
                "TenantId" uuid NOT NULL,
                "IntervalStart" timestamptz NOT NULL,
                "Workgroup" varchar(100) NOT NULL,
                "QueueId" uuid NULL,
                "Offered" int NOT NULL DEFAULT 0,
                "Answered" int NOT NULL DEFAULT 0,
                "Abandoned" int NOT NULL DEFAULT 0,
                "AnsweredInSl" int NOT NULL DEFAULT 0,
                "SumWaitAnswered" bigint NOT NULL DEFAULT 0,
                "SumTalk" bigint NOT NULL DEFAULT 0,
                "CreatedAt" timestamptz NOT NULL DEFAULT now(),
                "UpdatedAt" timestamptz NOT NULL DEFAULT now(),
                PRIMARY KEY ("Id", "IntervalStart")
            ) PARTITION BY RANGE ("IntervalStart");

            -- UNIQUE constraint (partition key must be in all unique constraints)
            CREATE UNIQUE INDEX ix_hist_queue_intervals_tenant_interval_workgroup
                ON public.hist_queue_intervals ("TenantId", "IntervalStart", "Workgroup");

            -- Query index
            CREATE INDEX ix_hist_queue_intervals_tenant_interval
                ON public.hist_queue_intervals ("TenantId", "IntervalStart");

            -- hist_agent_intervals: monthly RANGE partition by IntervalStart
            CREATE TABLE public.hist_agent_intervals (
                "Id" uuid NOT NULL,
                "TenantId" uuid NOT NULL,
                "IntervalStart" timestamptz NOT NULL,
                "AgentExternalId" varchar(100) NOT NULL,
                "AgentDisplayName" varchar(200) NULL,
                "SumAvailableMs" bigint NOT NULL DEFAULT 0,
                "SumOnphoneMs" bigint NOT NULL DEFAULT 0,
                "SumHoldMs" bigint NOT NULL DEFAULT 0,
                "SumPaperworkMs" bigint NOT NULL DEFAULT 0,
                "SumBreakMs" bigint NOT NULL DEFAULT 0,
                "SumTrainingMs" bigint NOT NULL DEFAULT 0,
                "SumUnavailableMs" bigint NOT NULL DEFAULT 0,
                "SumLoggedInMs" bigint NOT NULL DEFAULT 0,
                "Handled" int NOT NULL DEFAULT 0,
                "CreatedAt" timestamptz NOT NULL DEFAULT now(),
                "UpdatedAt" timestamptz NOT NULL DEFAULT now(),
                PRIMARY KEY ("Id", "IntervalStart")
            ) PARTITION BY RANGE ("IntervalStart");

            -- UNIQUE constraint
            CREATE UNIQUE INDEX ix_hist_agent_intervals_tenant_interval_agent
                ON public.hist_agent_intervals ("TenantId", "IntervalStart", "AgentExternalId");

            -- Query index
            CREATE INDEX ix_hist_agent_intervals_tenant_interval
                ON public.hist_agent_intervals ("TenantId", "IntervalStart");

            -- user_reports: NOT partitioned (small config table)
            CREATE TABLE public.user_reports (
                "Id" uuid PRIMARY KEY NOT NULL,
                "TenantId" uuid NOT NULL,
                "Name" varchar(200) NOT NULL,
                "Description" varchar(500) NULL,
                "IsSystem" boolean NOT NULL DEFAULT false,
                "IsPublic" boolean NOT NULL DEFAULT false,
                "OwnerUserId" uuid NULL,
                "Config" jsonb NULL,
                "CreatedAt" timestamptz NOT NULL DEFAULT now(),
                "UpdatedAt" timestamptz NOT NULL DEFAULT now(),
                "CreatedByUserId" uuid NOT NULL,
                "UpdatedByUserId" uuid NOT NULL
            );

            CREATE UNIQUE INDEX ix_user_reports_tenant_name
                ON public.user_reports ("TenantId", "Name");

            -- hist_aggregation_watermarks: tracks aggregation progress per tenant
            CREATE TABLE public.hist_aggregation_watermarks (
                "TenantId" uuid PRIMARY KEY NOT NULL,
                "AggregatedThrough" timestamptz NOT NULL,
                "LastRunAt" timestamptz NOT NULL DEFAULT now()
            );

            -- DEFAULT partitions as safety net for any window not pre-created
            -- OPS NOTE: if ensure_partitions lapses >window AND rows land in the DEFAULT partition for a month,
            -- a later CREATE ... PARTITION OF ... FOR VALUES for that month will ERROR (PG won't auto-move DEFAULT
            -- rows). Recovery: detach+drain the DEFAULT partition for that month before creating the monthly one.
            CREATE TABLE public.hist_queue_intervals_default
                PARTITION OF public.hist_queue_intervals DEFAULT;

            CREATE TABLE public.hist_agent_intervals_default
                PARTITION OF public.hist_agent_intervals DEFAULT;

            -- Create partitions for prior month + current + next 2 months
            -- (covers 24h startup lookback near month boundary)
            DO $$
            DECLARE
                curr_month date := date_trunc('month', CURRENT_DATE);
                m date;
                part_name text;
            BEGIN
                -- Prior month, current month, next 2 months = 4 partitions
                FOR i IN -1..2 LOOP
                    m := curr_month + (i || ' months')::interval;

                    -- Queue partitions
                    part_name := 'hist_queue_intervals_' || to_char(m, 'YYYY_MM');
                    EXECUTE format(
                        'CREATE TABLE IF NOT EXISTS public.%I PARTITION OF public.hist_queue_intervals
                         FOR VALUES FROM (%L) TO (%L)',
                        part_name, m, m + '1 month'::interval
                    );

                    -- Agent partitions
                    part_name := 'hist_agent_intervals_' || to_char(m, 'YYYY_MM');
                    EXECUTE format(
                        'CREATE TABLE IF NOT EXISTS public.%I PARTITION OF public.hist_agent_intervals
                         FOR VALUES FROM (%L) TO (%L)',
                        part_name, m, m + '1 month'::interval
                    );
                END LOOP;
            END $$;
            """);

        // Partition management functions (FUNCTION not PROCEDURE per §33.8 - Shell calls via SELECT)
        migrationBuilder.Sql("""
            -- fn_hist_ensure_partitions: ensures partitions exist for the specified window
            -- Called daily by BackgroundService with back=1, ahead=2
            CREATE OR REPLACE FUNCTION fn_hist_ensure_partitions(
                p_table text,
                p_months_back int DEFAULT 1,
                p_months_ahead int DEFAULT 2
            ) RETURNS void
            LANGUAGE plpgsql
            AS $$
            DECLARE
                curr_month date := date_trunc('month', CURRENT_DATE);
                m date;
                part_name text;
                full_table text := 'public.' || p_table;
            BEGIN
                FOR i IN -p_months_back..p_months_ahead LOOP
                    m := curr_month + (i || ' months')::interval;
                    part_name := p_table || '_' || to_char(m, 'YYYY_MM');

                    -- Check if partition exists
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_class c
                        JOIN pg_namespace n ON n.oid = c.relnamespace
                        WHERE n.nspname = 'public' AND c.relname = part_name
                    ) THEN
                        EXECUTE format(
                            'CREATE TABLE public.%I PARTITION OF %s
                             FOR VALUES FROM (%L) TO (%L)',
                            part_name, full_table, m, m + '1 month'::interval
                        );
                        RAISE NOTICE 'Created partition %', part_name;
                    END IF;
                END LOOP;
            END $$;

            -- fn_hist_drop_aged: drops partitions older than p_keep_months
            -- Default keep ~84 months (7 years) per retention policy
            CREATE OR REPLACE FUNCTION fn_hist_drop_aged(
                p_table text,
                p_keep_months int DEFAULT 84
            ) RETURNS void
            LANGUAGE plpgsql
            AS $$
            DECLARE
                cutoff_month date := date_trunc('month', CURRENT_DATE) - (p_keep_months || ' months')::interval;
                part_rec record;
            BEGIN
                FOR part_rec IN
                    SELECT c.relname AS partition_name
                    FROM pg_inherits i
                    JOIN pg_class c ON c.oid = i.inhrelid
                    JOIN pg_class p ON p.oid = i.inhparent
                    JOIN pg_namespace n ON n.oid = p.relnamespace
                    WHERE n.nspname = 'public'
                      AND p.relname = p_table
                      AND c.relname ~ (p_table || '_\d{4}_\d{2}')
                LOOP
                    -- Extract year and month from partition name
                    DECLARE
                        part_date date;
                    BEGIN
                        part_date := to_date(
                            substring(part_rec.partition_name from (p_table || '_(\d{4}_\d{2})') ),
                            'YYYY_MM'
                        );
                        IF part_date < cutoff_month THEN
                            EXECUTE format('DROP TABLE IF EXISTS public.%I', part_rec.partition_name);
                            RAISE NOTICE 'Dropped aged partition %', part_rec.partition_name;
                        END IF;
                    EXCEPTION WHEN OTHERS THEN
                        RAISE WARNING 'fn_hist_drop_aged: skipped partition % (%)', part_rec.partition_name, SQLERRM;
                    END;
                END LOOP;
            END $$;
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            DROP FUNCTION IF EXISTS fn_hist_drop_aged(text, int);
            DROP FUNCTION IF EXISTS fn_hist_ensure_partitions(text, int, int);
            DROP TABLE IF EXISTS public.hist_aggregation_watermarks;
            DROP TABLE IF EXISTS public.user_reports;
            DROP TABLE IF EXISTS public.hist_agent_intervals CASCADE;
            DROP TABLE IF EXISTS public.hist_queue_intervals CASCADE;
            """);
    }
}
