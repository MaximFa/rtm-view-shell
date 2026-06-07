-- ============================================================================
-- RTSData_* PL/pgSQL Functions for RTM Backend Migration
-- Output of RTM-M4 task
--
-- These functions handle real-time data writes and reads from RTM/RTM/DBMng.cs.
-- UPSERT conflict keys differ from EF PK for some tables — see comments.
--
-- All identifiers are double-quoted (PostgreSQL case-sensitivity).
-- ============================================================================

-- ============================================================================
-- 1. RTSData_SetInteraction
--    UPSERT using ON CONFLICT on 3-col UNIQUE index (InteractionId, Segment, ServerId)
--    NOT the 5-col EF PK (InteractionId, Segment, OnDate, ServerId, Workgroup)
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetInteraction"(
    text, integer, text, text, text, text,
    text, text, text, text, text,
    boolean, boolean, boolean, boolean, boolean,
    integer, integer, timestamptz, timestamptz, timestamptz,
    text, text, boolean, text, boolean, text
);

CREATE OR REPLACE FUNCTION "RTSData_SetInteraction"(
    p_interaction_id text,
    p_segment integer,
    p_on_date text,
    p_server_id text,
    p_workgroup text,
    p_user_id text,
    p_classification_code text,
    p_interaction_type text,
    p_call_type text,
    p_direction text,
    p_custom_call_data text,
    p_is_transferred boolean,
    p_is_answered boolean,
    p_is_in_queue boolean,
    p_is_talk boolean,
    p_is_abandoned boolean,
    p_time_in_queue integer,
    p_talk_time integer,
    p_in_queue_date_time timestamptz,
    p_answered_date_time timestamptz,
    p_update_time timestamptz,
    p_last_user_id text,
    p_last_workgroup text,
    p_is_messaging boolean,
    p_remote_address text,
    p_is_callback_request boolean,
    p_time_zone text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_Interaction" (
        "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "UserId",
        "ClassificationCode", "InteractionType", "CallType", "Direction", "CustomCallData",
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone",
        "TenantId"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue, p_talk_time, p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address, p_is_callback_request, p_time_zone,
        p_tenant_id
    )
    ON CONFLICT ("InteractionId", "Segment", "ServerId")
    DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "Workgroup" = EXCLUDED."Workgroup",
        "UserId" = EXCLUDED."UserId",
        "ClassificationCode" = EXCLUDED."ClassificationCode",
        "InteractionType" = EXCLUDED."InteractionType",
        "CallType" = EXCLUDED."CallType",
        "Direction" = EXCLUDED."Direction",
        "CustomCallData" = EXCLUDED."CustomCallData",
        "IsTransferred" = EXCLUDED."IsTransferred",
        "IsAnswered" = EXCLUDED."IsAnswered",
        "IsInQueue" = EXCLUDED."IsInQueue",
        "IsTalk" = EXCLUDED."IsTalk",
        "IsAbandoned" = EXCLUDED."IsAbandoned",
        "TimeInQueue" = EXCLUDED."TimeInQueue",
        "TalkTime" = EXCLUDED."TalkTime",
        "InQueueDateTime" = EXCLUDED."InQueueDateTime",
        "AnsweredDateTime" = EXCLUDED."AnsweredDateTime",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "LastUserId" = EXCLUDED."LastUserId",
        "LastWorkgroup" = EXCLUDED."LastWorkgroup",
        "IsMessaging" = EXCLUDED."IsMessaging",
        "RemoteAddress" = EXCLUDED."RemoteAddress",
        "IsCallbackRequest" = EXCLUDED."IsCallbackRequest",
        "TimeZone" = EXCLUDED."TimeZone",
        "TenantId" = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 2. RTSData_SetUserStatus  (PROCEDURE, 15 params — matches RTM DBMng C# call)
--    (a) APPEND history row to RTSData_UserStatusLog  [restored MSSQL behaviour;
--        fn_daytrendagentstatus reads agent history ONLY from this table]
--    (b) UPSERT current state into RTSData_UserStatus (ON CONFLICT 4-col PK)
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
-- 3. RTSData_SetChatMessage
--    UPSERT using ON CONFLICT on 2-col UNIQUE index (MessageId, ServerId)
--    NOT the 3-col EF PK (MessageId, ServerId, OnDate)
--    Note: C# entity uses MsgTimeStamp but DB column is "TimeStamp"
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetChatMessage"(
    text, text, integer, text, text, text,
    text, text, text, text, timestamptz, text, timestamptz
);

CREATE OR REPLACE FUNCTION "RTSData_SetChatMessage"(
    p_message_id text,
    p_interaction_id text,
    p_segment_id integer,
    p_user_id text,
    p_msg_direction text,
    p_sender text,
    p_recipient text,
    p_body text,
    p_delivery_status text,
    p_server_id text,
    p_update_time timestamptz,
    p_on_date text,
    p_time_stamp timestamptz,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_ChatMessage" (
        "MessageId", "ServerId", "OnDate",
        "InteractionId", "SegmentId", "UserId", "MsgDirection",
        "Sender", "Recipient", "Body", "DeliveryStatus",
        "UpdateTime", "TimeStamp", "TenantId"
    )
    VALUES (
        p_message_id, p_server_id, p_on_date,
        p_interaction_id, p_segment_id, p_user_id, p_msg_direction,
        p_sender, p_recipient, p_body, p_delivery_status,
        p_update_time, p_time_stamp, p_tenant_id
    )
    ON CONFLICT ("MessageId", "ServerId")
    DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "InteractionId" = EXCLUDED."InteractionId",
        "SegmentId" = EXCLUDED."SegmentId",
        "UserId" = EXCLUDED."UserId",
        "MsgDirection" = EXCLUDED."MsgDirection",
        "Sender" = EXCLUDED."Sender",
        "Recipient" = EXCLUDED."Recipient",
        "Body" = EXCLUDED."Body",
        "DeliveryStatus" = EXCLUDED."DeliveryStatus",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "TimeStamp" = EXCLUDED."TimeStamp",
        "TenantId" = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 4. RTSData_MidnightClear
--    CRITICAL: Function name is "RTSData_MidnightClear" (NOT "_1" suffix)
--    Clears Interaction and UserStatus tables — ChatMessage is NOT cleared
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- [RTM-SEC-001] CRITICAL: Must scope DELETE by TenantId to prevent cross-tenant data loss
    DELETE FROM "RTSData_Interaction" WHERE "TenantId" = p_tenant_id;
    DELETE FROM "RTSData_UserStatus" WHERE "TenantId" = p_tenant_id;
    -- RTSData_ChatMessage is intentionally NOT cleared per production behavior
END;
$$;

-- ============================================================================
-- 5. RTSData_GetInteractions
--    Returns all columns from RTSData_Interaction
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "InteractionId" text,
    "Segment" integer,
    "OnDate" text,
    "ServerId" text,
    "Workgroup" text,
    "UserId" text,
    "ClassificationCode" text,
    "InteractionType" text,
    "CallType" text,
    "Direction" text,
    "CustomCallData" text,
    "IsTransferred" boolean,
    "IsAnswered" boolean,
    "IsInQueue" boolean,
    "IsTalk" boolean,
    "IsAbandoned" boolean,
    "TimeInQueue" integer,
    "TalkTime" integer,
    "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz,
    "UpdateTime" timestamptz,
    "LastUserId" text,
    "LastWorkgroup" text,
    "IsMessaging" boolean,
    "RemoteAddress" text,
    "IsCallbackRequest" boolean,
    "TimeZone" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        i."TenantId",
        i."InteractionId"::text,
        i."Segment",
        i."OnDate"::text,
        i."ServerId"::text,
        i."Workgroup"::text,
        i."UserId"::text,
        i."ClassificationCode"::text,
        i."InteractionType"::text,
        i."CallType"::text,
        i."Direction"::text,
        i."CustomCallData"::text,
        i."IsTransferred",
        i."IsAnswered",
        i."IsInQueue",
        i."IsTalk",
        i."IsAbandoned",
        i."TimeInQueue",
        i."TalkTime",
        i."InQueueDateTime",
        i."AnsweredDateTime",
        i."UpdateTime",
        i."LastUserId"::text,
        i."LastWorkgroup"::text,
        i."IsMessaging",
        i."RemoteAddress"::text,
        i."IsCallbackRequest",
        i."TimeZone"::text
    FROM "RTSData_Interaction" i
    WHERE i."TenantId" = p_tenant_id;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "InteractionId" text,
    "Segment" integer,
    "OnDate" text,
    "ServerId" text,
    "Workgroup" text,
    "UserId" text,
    "ClassificationCode" text,
    "InteractionType" text,
    "CallType" text,
    "Direction" text,
    "CustomCallData" text,
    "IsTransferred" boolean,
    "IsAnswered" boolean,
    "IsInQueue" boolean,
    "IsTalk" boolean,
    "IsAbandoned" boolean,
    "TimeInQueue" integer,
    "TalkTime" integer,
    "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz,
    "UpdateTime" timestamptz,
    "LastUserId" text,
    "LastWorkgroup" text,
    "IsMessaging" boolean,
    "RemoteAddress" text,
    "IsCallbackRequest" boolean,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetInteractions"(p_tenant_id); $$;

-- ============================================================================
-- 6. RTSData_GetUsersStatuses
--    Returns all columns from RTSData_UserStatus
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "UpdateTime" timestamptz,
    "DisplayName" text,
    "TimeZone" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s."TenantId",
        s."UserId"::text,
        s."StatusId"::text,
        s."ServerId"::text,
        s."OnDate"::text,
        s."StatusName"::text,
        s."StatusGroup"::text,
        s."TotalDuration",
        s."MaxDuraction",
        s."TotalCount",
        s."UpdateTime",
        s."DisplayName"::text,
        s."TimeZone"::text
    FROM "RTSData_UserStatus" s
    WHERE s."TenantId" = p_tenant_id;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "UpdateTime" timestamptz,
    "DisplayName" text,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_tenant_id); $$;

-- ============================================================================
-- 7. fn_daytrendagentstatus — BU-scoped agent status metrics for DayTrend widget
--    Uses NGC_UserAgentgroup (P1/P2) for agent↔BU membership.
--    Signature: (p_tenantid, p_ondate, p_businessunitid, p_intervalmin)
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_daytrendagentstatus(uuid, character varying, text[], integer);

CREATE OR REPLACE FUNCTION public.fn_daytrendagentstatus(
    p_tenantid uuid, p_ondate character varying, p_businessunitid integer, p_intervalmin integer)
RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
LANGUAGE sql STABLE
AS $$
    -- Agents scoped to the BU via persisted membership (NGC_UserAgentgroup, P1/P2),
    -- NOT via calls. Intervals generated from the day's status span (no interaction dependency).
    -- BU agent scope. Membership semantics (operator-confirmed 2026-06-06):
    --   * SG -> AgentGroup = AND: an agent belongs to a Supergroup ONLY IF it is a member of
    --     ALL of that Supergroup's agent groups (intersection).
    --   * BU -> Supergroup = OR: an agent is in the BU if it belongs to ANY of the BU's supergroups.
    WITH bu_supergroups AS (
        SELECT bus."SupergroupId"
        FROM "NGC_BusinessUnitSupergroup" bus
        WHERE bus."BusinessUnitId" = p_businessunitid AND bus."TenantId" = p_tenantid
    ),
    sg_ag_total AS (   -- total agent groups per supergroup (BU's supergroups only)
        SELECT sa."SupergroupId", COUNT(DISTINCT sa."AgentgroupId") AS total_ag
        FROM "NGC_SupergroupAgentgroup" sa
        JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        WHERE sa."TenantId" = p_tenantid
        GROUP BY sa."SupergroupId"
    ),
    supergroup_agents AS (   -- AND: agent must be in ALL of the SG's agent groups
        SELECT ua."UserId", sa."SupergroupId"
        FROM "NGC_SupergroupAgentgroup" sa
        JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        JOIN "NGC_UserAgentgroup" ua
          ON ua."AgentgroupId" = sa."AgentgroupId" AND ua."TenantId" = sa."TenantId"
        WHERE sa."TenantId" = p_tenantid
        GROUP BY ua."UserId", sa."SupergroupId"
        HAVING COUNT(DISTINCT sa."AgentgroupId")
             = (SELECT t.total_ag FROM sg_ag_total t WHERE t."SupergroupId" = sa."SupergroupId")
    ),
    agents_in_bu AS (   -- OR across the BU's supergroups
        SELECT DISTINCT "UserId" FROM supergroup_agents
    ),
    status_rows AS (
        SELECT usl."UserId", usl."StatusGroup", usl."StartTime",
               COALESCE(usl."EndTime", now()) AS end_time
        FROM "RTSData_UserStatusLog" usl
        JOIN agents_in_bu a ON a."UserId" = usl."UserId"
        WHERE usl."TenantId" = p_tenantid
          AND usl."OnDate"   = p_ondate
          AND usl."StatusGroup" IS NOT NULL
          AND usl."StartTime"  IS NOT NULL
    ),
    span AS (
        SELECT date_trunc('hour', MIN("StartTime"))
                 + (FLOOR(EXTRACT(MINUTE FROM MIN("StartTime")) / p_intervalmin)
                    * (p_intervalmin || ' minutes')::interval) AS first_start,
               MAX(end_time) AS last_end
        FROM status_rows
    ),
    intervals AS (
        SELECT gs AS interval_start
        FROM span,
             generate_series(span.first_start, span.last_end,
                             (p_intervalmin || ' minutes')::interval) AS gs
        WHERE span.first_start IS NOT NULL
    ),
    agent_status AS (
        SELECT iv.interval_start, sr."UserId", sr."StatusGroup",
               GREATEST(0, EXTRACT(EPOCH FROM (
                   LEAST(sr.end_time, iv.interval_start + (p_intervalmin || ' minutes')::interval)
                   - GREATEST(sr."StartTime", iv.interval_start)))::bigint * 1000) AS overlap_ms
        FROM intervals iv
        JOIN status_rows sr
          ON sr."StartTime" < iv.interval_start + (p_intervalmin || ' minutes')::interval
         AND sr.end_time   > iv.interval_start
    ),
    pool_summary AS (
        SELECT interval_start, COUNT(DISTINCT "UserId") AS logged_in_agents
        FROM agent_status GROUP BY interval_start
    ),
    status_summary AS (
        SELECT interval_start,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='AVAILABLE')   AS available_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='ONPHONE')     AS onphone_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='BREAK')       AS break_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='PAPERWORK')   AS paperwork_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='TRAINING')    AS training_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='UNAVAILABLE') AS unavailable_agents,
            COUNT(DISTINCT "UserId")                                            AS total_agents,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='AVAILABLE'),0)   AS available_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='ONPHONE'),0)     AS onphone_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='BREAK'),0)       AS break_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='PAPERWORK'),0)   AS paperwork_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='TRAINING'),0)    AS training_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='UNAVAILABLE'),0) AS unavailable_time_ms,
            COALESCE(SUM(overlap_ms),0)                                           AS total_active_time_ms
        FROM agent_status GROUP BY interval_start
    )
    SELECT ps.interval_start, 'statuslog.logged_in_agents',     ps.logged_in_agents::double precision     FROM pool_summary ps
    UNION ALL SELECT ss.interval_start,'statuslog.available_agents',   ss.available_agents::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_agents',     ss.onphone_agents::double precision     FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_agents',       ss.break_agents::double precision       FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_agents',   ss.paperwork_agents::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_agents',    ss.training_agents::double precision    FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_agents', ss.unavailable_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_agents',       ss.total_agents::double precision       FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.available_time_ms',  ss.available_time_ms::double precision  FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_time_ms',    ss.onphone_time_ms::double precision    FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_time_ms',      ss.break_time_ms::double precision      FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_time_ms',  ss.paperwork_time_ms::double precision  FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_time_ms',   ss.training_time_ms::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_time_ms',ss.unavailable_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_active_time_ms',ss.total_active_time_ms::double precision FROM status_summary ss
    ORDER BY 1, 2;
$$;

-- ============================================================================
-- End of RTSData_* functions (6 main + 2 lowercase aliases + 1 DayTrend = 9 total)
-- ============================================================================
