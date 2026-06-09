-- ============================================================================
-- Migration: Add StatusGroup column to RTSData_UserStatusLog
-- Date: 2026-06-06
--
-- Root cause: RTSData_UserStatusLog originally lacked "StatusGroup" column
-- (MSSQL never had it; pgloader migration didn't add it; patch_origin_v2.sql
-- added catalogue columns but NOT this one). The deployed RTSData_SetUserStatus
-- procedure writes StatusGroup into the Log -> INSERT fails on missing column
-- -> Log stays empty -> fn_daytrendagentstatus (filters usl."StatusGroup")
-- returns nothing -> DayTrend Agent Metrics are empty.
--
-- Fix: Add the column + supporting index, then re-assert the procedure so
-- column and writer are consistent.
-- ============================================================================

-- 1. Add StatusGroup column (idempotent)
ALTER TABLE "RTSData_UserStatusLog"
  ADD COLUMN IF NOT EXISTS "StatusGroup" varchar(50);

-- 2. Index definition (copied from db/schema.sql:3525)
CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
  ON "RTSData_UserStatusLog" USING btree ("TenantId", "StatusGroup", "StartTime", "EndTime");

-- ============================================================================
-- 3. Re-assert RTSData_SetUserStatus procedure
--    Copied VERBATIM from db/functions/02_rtsdata_functions.sql section 2
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text, uuid
);
DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, text, text,
    double precision, double precision, integer, text,
    timestamptz, timestamptz, text, timestamptz, uuid
);

CREATE PROCEDURE "RTSData_SetUserStatus"(
    p_user_id        text,
    p_status_id      text,
    p_server_id      text,
    p_on_date        text,
    p_status_name    text,
    p_status_group   text,
    p_total_duration double precision,
    p_max_duration   double precision,
    p_total_count    integer,
    p_display_name   text,
    p_start_time     timestamptz,
    p_end_time       timestamptz,
    p_time_zone      text,
    p_update_time    timestamptz,
    p_tenant_id      uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- (a) Append-only history (powers DayTrend agent metrics). StatusGroup + TenantId
    --     are required by fn_daytrendagentstatus and exist on the PG table.
    IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL
       AND p_end_time > p_start_time THEN
        INSERT INTO "RTSData_UserStatusLog" (
            "TenantId","UserId","StatusId","ServerId","OnDate",
            "StartTime","EndTime","Duration","UpdateTime","TimeZone","StatusGroup"
        )
        VALUES (
            p_tenant_id, p_user_id, p_status_id, p_server_id, p_on_date,
            p_start_time, p_end_time,
            (EXTRACT(EPOCH FROM (p_end_time - p_start_time)) * 1000)::integer,
            p_update_time, p_time_zone, p_status_group
        );
    END IF;

    -- (b) Current-state upsert (unchanged behaviour).
    INSERT INTO "RTSData_UserStatus" (
        "UserId","StatusId","ServerId","OnDate",
        "StatusName","StatusGroup","TotalDuration","MaxDuraction",
        "TotalCount","UpdateTime","DisplayName","TimeZone","TenantId"
    )
    VALUES (
        p_user_id, p_status_id, p_server_id, p_on_date,
        p_status_name, p_status_group, p_total_duration::integer, p_max_duration::integer,
        p_total_count, p_update_time, p_display_name, p_time_zone, p_tenant_id
    )
    ON CONFLICT ("UserId","StatusId","ServerId","OnDate")
    DO UPDATE SET
        "StatusName"    = EXCLUDED."StatusName",
        "StatusGroup"   = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuraction"  = EXCLUDED."MaxDuraction",
        "TotalCount"    = EXCLUDED."TotalCount",
        "UpdateTime"    = EXCLUDED."UpdateTime",
        "DisplayName"   = EXCLUDED."DisplayName",
        "TimeZone"      = EXCLUDED."TimeZone",
        "TenantId"      = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- End of migration
-- ============================================================================
