-- ============================================================================
-- Fix RTSData_SetUserStatus — correct 14-param signature, PROCEDURE
-- C# DBMng.cs sends params in positional order; DateTime.SpecifyKind(Utc) applied.
-- Table RTSData_UserStatus has no StartTime/EndTime columns — accepted but ignored.
-- MaxDuraction column has a typo (from SQL Server original) — preserved as-is.
-- Deploy: psql -U ccdashboard_user -d rtmviewdb -h 127.0.0.1 -f fix_set_userstatus.sql
-- ============================================================================

DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text
);

DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, text, text,
    double precision, double precision, integer, text,
    timestamp without time zone, timestamp without time zone,
    text, timestamp with time zone
);

DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, text, text,
    double precision, double precision, integer, text,
    timestamptz, timestamptz, text, timestamptz
);

DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus";

CREATE OR REPLACE PROCEDURE "RTSData_SetUserStatus"(
    p_user_id           text,               -- @UserId
    p_status_id         text,               -- @StatusId
    p_server_id         text,               -- @ServerId
    p_on_date           text,               -- @OnDate
    p_status_name       text,               -- @StatusName
    p_status_group      text,               -- @StatusGroup
    p_total_duration    double precision,   -- @TotalDuration (TotalSeconds)
    p_max_duration      double precision,   -- @MaxDuration (TotalSeconds)
    p_total_count       integer,            -- @TotalCount
    p_display_name      text,               -- @DisplayName
    p_start_time        timestamptz,        -- @StartTime (accepted, not stored)
    p_end_time          timestamptz,        -- @EndTime (accepted, not stored)
    p_time_zone         text,               -- @TimeZone
    p_update_time       timestamptz,        -- @UpdateTime
    p_tenant_id         uuid                -- @TenantId
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_UserStatus" (
        "UserId", "StatusId", "ServerId", "OnDate",
        "StatusName", "StatusGroup",
        "TotalDuration", "MaxDuraction", "TotalCount",
        "UpdateTime", "DisplayName", "TimeZone", "TenantId"
    )
    VALUES (
        p_user_id, p_status_id, p_server_id, p_on_date,
        p_status_name, p_status_group,
        p_total_duration::integer, p_max_duration::integer, p_total_count,
        p_update_time, p_display_name, p_time_zone, p_tenant_id
    )
    ON CONFLICT ("UserId", "StatusId", "ServerId", "OnDate")
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
