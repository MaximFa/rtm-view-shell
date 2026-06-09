-- Migration: 20260606_002_fix_userstatuslog_write
-- Fix: Restore RTSData_UserStatusLog write in RTSData_SetUserStatus
-- Root cause: MSSQL->PG port dropped the log INSERT; fn_daytrendagentstatus
--             reads agent history ONLY from RTSData_UserStatusLog.
-- Date: 2026-06-06

-- Drop stale 13-param FUNCTION (if exists from older deployments)
DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text, uuid
);

-- Drop current 15-param PROCEDURE to recreate with log write
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

-- Verify: should return 'RTSData_SetUserStatus' as procedure
SELECT proname, prokind FROM pg_proc WHERE proname = 'RTSData_SetUserStatus';
