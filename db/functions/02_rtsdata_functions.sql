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
-- 1. RTSData_SetInteraction (PROCEDURE, 48 params — matches RTM DBMng C# call)
--    UPSERT using ON CONFLICT on 3-col UNIQUE index (InteractionId, Segment, ServerId)
--    NOT the 5-col EF PK (InteractionId, Segment, OnDate, ServerId, Workgroup)
-- ============================================================================
-- Kind-agnostic DROP: drop ANY existing FUNCTION or PROCEDURE of this name
DO $drop_setinteraction$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS sig, prokind
        FROM pg_proc
        WHERE proname = 'RTSData_SetInteraction'
    LOOP
        IF r.prokind = 'p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                   EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
    END LOOP;
END
$drop_setinteraction$;

CREATE OR REPLACE PROCEDURE "RTSData_SetInteraction"(
    IN p_interaction_id text,
    IN p_segment integer,
    IN p_workgroup text,
    IN p_classification_code text,
    IN p_interaction_type text,
    IN p_call_type text,
    IN p_direction text,
    IN p_custom_call_data text,
    IN p_remote_address text,
    IN p_user_id text,
    IN p_is_transferred boolean,
    IN p_is_answered boolean,
    IN p_is_in_queue boolean,
    IN p_is_talk boolean,
    IN p_is_abandoned boolean,
    IN p_is_messaging boolean,
    IN p_time_in_queue double precision,
    IN p_talk_time double precision,
    IN p_in_queue_date_time timestamp with time zone,
    IN p_answered_date_time timestamp with time zone,
    IN p_last_user_id text,
    IN p_last_workgroup text,
    IN p_custom_call_data1 text,
    IN p_custom_call_data2 text,
    IN p_custom_call_data3 text,
    IN p_custom_call_data4 text,
    IN p_custom_call_data5 text,
    IN p_custom_call_data6 text,
    IN p_custom_call_data7 text,
    IN p_custom_call_data8 text,
    IN p_custom_call_data9 text,
    IN p_custom_call_data10 text,
    IN p_custom_call_data11 text,
    IN p_custom_call_data12 text,
    IN p_custom_call_data13 text,
    IN p_custom_call_data14 text,
    IN p_custom_call_data15 text,
    IN p_custom_call_data16 text,
    IN p_custom_call_data17 text,
    IN p_custom_call_data18 text,
    IN p_custom_call_data19 text,
    IN p_custom_call_data20 text,
    IN p_is_callback_request boolean,
    IN p_time_zone text,
    IN p_server_id text,
    IN p_update_time timestamp with time zone,
    IN p_on_date text,
    IN p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_Interaction" (
        "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "UserId",
        "ClassificationCode", "InteractionType", "CallType", "Direction", "CustomCallData",
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "TimeInQueue", "TalkTime",
        "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress",
        "CustomCallData1",  "CustomCallData2",  "CustomCallData3",  "CustomCallData4",
        "CustomCallData5",  "CustomCallData6",  "CustomCallData7",  "CustomCallData8",
        "CustomCallData9",  "CustomCallData10", "CustomCallData11", "CustomCallData12",
        "CustomCallData13", "CustomCallData14", "CustomCallData15", "CustomCallData16",
        "CustomCallData17", "CustomCallData18", "CustomCallData19", "CustomCallData20",
        "IsCallbackRequest", "TimeZone", "TenantId"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue::integer, p_talk_time::integer,
        p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address,
        p_custom_call_data1,  p_custom_call_data2,  p_custom_call_data3,  p_custom_call_data4,
        p_custom_call_data5,  p_custom_call_data6,  p_custom_call_data7,  p_custom_call_data8,
        p_custom_call_data9,  p_custom_call_data10, p_custom_call_data11, p_custom_call_data12,
        p_custom_call_data13, p_custom_call_data14, p_custom_call_data15, p_custom_call_data16,
        p_custom_call_data17, p_custom_call_data18, p_custom_call_data19, p_custom_call_data20,
        p_is_callback_request, p_time_zone, p_tenant_id
    )
    ON CONFLICT ("InteractionId", "Segment", "ServerId")
    DO UPDATE SET
        "OnDate"              = EXCLUDED."OnDate",
        "Workgroup"           = EXCLUDED."Workgroup",
        "UserId"              = EXCLUDED."UserId",
        "ClassificationCode"  = EXCLUDED."ClassificationCode",
        "InteractionType"     = EXCLUDED."InteractionType",
        "CallType"            = EXCLUDED."CallType",
        "Direction"           = EXCLUDED."Direction",
        "CustomCallData"      = EXCLUDED."CustomCallData",
        "IsTransferred"       = EXCLUDED."IsTransferred",
        "IsAnswered"          = EXCLUDED."IsAnswered",
        "IsInQueue"           = EXCLUDED."IsInQueue",
        "IsTalk"              = EXCLUDED."IsTalk",
        "IsAbandoned"         = EXCLUDED."IsAbandoned",
        "TimeInQueue"         = EXCLUDED."TimeInQueue",
        "TalkTime"            = EXCLUDED."TalkTime",
        "InQueueDateTime"     = EXCLUDED."InQueueDateTime",
        "AnsweredDateTime"    = EXCLUDED."AnsweredDateTime",
        "UpdateTime"          = EXCLUDED."UpdateTime",
        "LastUserId"          = EXCLUDED."LastUserId",
        "LastWorkgroup"       = EXCLUDED."LastWorkgroup",
        "IsMessaging"         = EXCLUDED."IsMessaging",
        "RemoteAddress"       = EXCLUDED."RemoteAddress",
        "CustomCallData1"     = EXCLUDED."CustomCallData1",
        "CustomCallData2"     = EXCLUDED."CustomCallData2",
        "CustomCallData3"     = EXCLUDED."CustomCallData3",
        "CustomCallData4"     = EXCLUDED."CustomCallData4",
        "CustomCallData5"     = EXCLUDED."CustomCallData5",
        "CustomCallData6"     = EXCLUDED."CustomCallData6",
        "CustomCallData7"     = EXCLUDED."CustomCallData7",
        "CustomCallData8"     = EXCLUDED."CustomCallData8",
        "CustomCallData9"     = EXCLUDED."CustomCallData9",
        "CustomCallData10"    = EXCLUDED."CustomCallData10",
        "CustomCallData11"    = EXCLUDED."CustomCallData11",
        "CustomCallData12"    = EXCLUDED."CustomCallData12",
        "CustomCallData13"    = EXCLUDED."CustomCallData13",
        "CustomCallData14"    = EXCLUDED."CustomCallData14",
        "CustomCallData15"    = EXCLUDED."CustomCallData15",
        "CustomCallData16"    = EXCLUDED."CustomCallData16",
        "CustomCallData17"    = EXCLUDED."CustomCallData17",
        "CustomCallData18"    = EXCLUDED."CustomCallData18",
        "CustomCallData19"    = EXCLUDED."CustomCallData19",
        "CustomCallData20"    = EXCLUDED."CustomCallData20",
        "IsCallbackRequest"   = EXCLUDED."IsCallbackRequest",
        "TimeZone"            = EXCLUDED."TimeZone",
        "TenantId"            = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 2. RTSData_SetUserStatus  (PROCEDURE, 15 params — matches RTM DBMng C# call)
-- ============================================================================
DO $drop_setuserstatus$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname = 'RTSData_SetUserStatus' LOOP
        IF r.prokind = 'p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                   EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
    END LOOP;
END $drop_setuserstatus$;

CREATE OR REPLACE PROCEDURE "RTSData_SetUserStatus"(
    p_user_id text, p_status_id text, p_server_id text, p_on_date text,
    p_status_name text, p_status_group text,
    p_total_duration double precision, p_max_duration double precision,
    p_total_count integer, p_display_name text,
    p_start_time timestamptz, p_end_time timestamptz,
    p_time_zone text, p_update_time timestamptz, p_tenant_id uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL AND p_end_time > p_start_time THEN
        INSERT INTO "RTSData_UserStatusLog" (
            "TenantId","UserId","StatusId","ServerId","OnDate",
            "StartTime","EndTime","Duration","UpdateTime","TimeZone","StatusGroup"
        ) VALUES (
            p_tenant_id, p_user_id, p_status_id, p_server_id, p_on_date,
            p_start_time, p_end_time,
            (EXTRACT(EPOCH FROM (p_end_time - p_start_time)) * 1000)::integer,
            p_update_time, p_time_zone, p_status_group
        );
    END IF;
    INSERT INTO "RTSData_UserStatus" (
        "UserId","StatusId","ServerId","OnDate",
        "StatusName","StatusGroup","TotalDuration","MaxDuraction",
        "TotalCount","UpdateTime","DisplayName","TimeZone","TenantId"
    ) VALUES (
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
END; $$;

-- ============================================================================
-- 3. RTSData_SetChatMessage (PROCEDURE)
-- ============================================================================
DO $drop_setchatmessage$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname = 'RTSData_SetChatMessage' LOOP
        IF r.prokind = 'p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                   EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
    END LOOP;
END $drop_setchatmessage$;

CREATE OR REPLACE PROCEDURE "RTSData_SetChatMessage"(
    IN p_message_id text, IN p_interaction_id text, IN p_segment_id integer,
    IN p_user_id text, IN p_msg_direction text, IN p_sender text, IN p_recipient text,
    IN p_body text, IN p_delivery_status text, IN p_server_id text,
    IN p_update_time timestamptz, IN p_on_date text, IN p_time_stamp timestamptz, IN p_tenant_id uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "RTSData_ChatMessage" (
        "MessageId", "ServerId", "OnDate", "InteractionId", "SegmentId", "UserId", "MsgDirection",
        "Sender", "Recipient", "Body", "DeliveryStatus", "UpdateTime", "TimeStamp", "TenantId"
    ) VALUES (
        p_message_id, p_server_id, p_on_date, p_interaction_id, p_segment_id, p_user_id, p_msg_direction,
        p_sender, p_recipient, p_body, p_delivery_status, p_update_time, p_time_stamp, p_tenant_id
    )
    ON CONFLICT ("MessageId", "ServerId")
    DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate", "InteractionId" = EXCLUDED."InteractionId",
        "SegmentId" = EXCLUDED."SegmentId", "UserId" = EXCLUDED."UserId",
        "MsgDirection" = EXCLUDED."MsgDirection", "Sender" = EXCLUDED."Sender",
        "Recipient" = EXCLUDED."Recipient", "Body" = EXCLUDED."Body",
        "DeliveryStatus" = EXCLUDED."DeliveryStatus", "UpdateTime" = EXCLUDED."UpdateTime",
        "TimeStamp" = EXCLUDED."TimeStamp", "TenantId" = EXCLUDED."TenantId";
END; $$;

-- ============================================================================
-- 4. RTSData_MidnightClear
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"(p_tenant_id uuid) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "RTSData_Interaction" WHERE "TenantId" = p_tenant_id;
    DELETE FROM "RTSData_UserStatus" WHERE "TenantId" = p_tenant_id;
END; $$;

-- ============================================================================
-- 5. RTSData_GetInteractions — AUTHORITATIVE overload set
--    Arity-1: (uuid) + Arity-2: (text, uuid) — DBMng passes @OnDate, @TenantId
-- ============================================================================
DO $drop_getinteractions$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc
             WHERE proname IN ('RTSData_GetInteractions', 'RTSData_getInteractions') LOOP
        IF r.prokind = 'p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                   EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
    END LOOP;
END $drop_getinteractions$;

-- Arity-1
CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid, "InteractionId" text, "Segment" integer, "OnDate" text, "ServerId" text,
    "Workgroup" text, "UserId" text, "ClassificationCode" text, "InteractionType" text,
    "CallType" text, "Direction" text, "CustomCallData" text, "IsTransferred" boolean,
    "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean,
    "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz, "UpdateTime" timestamptz, "LastUserId" text,
    "LastWorkgroup" text, "IsMessaging" boolean, "RemoteAddress" text,
    "IsCallbackRequest" boolean, "TimeZone" text
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT i."TenantId", i."InteractionId"::text, i."Segment", i."OnDate"::text,
        i."ServerId"::text, i."Workgroup"::text, i."UserId"::text, i."ClassificationCode"::text,
        i."InteractionType"::text, i."CallType"::text, i."Direction"::text, i."CustomCallData"::text,
        i."IsTransferred", i."IsAnswered", i."IsInQueue", i."IsTalk", i."IsAbandoned",
        i."TimeInQueue", i."TalkTime", i."InQueueDateTime", i."AnsweredDateTime", i."UpdateTime",
        i."LastUserId"::text, i."LastWorkgroup"::text, i."IsMessaging", i."RemoteAddress"::text,
        i."IsCallbackRequest", i."TimeZone"::text
    FROM "RTSData_Interaction" i WHERE i."TenantId" = p_tenant_id;
END; $$;

-- Arity-2: filtered by OnDate (DBMng.getIntercations caller passes @OnDate, @TenantId)
CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_on_date text, p_tenant_id uuid)
RETURNS TABLE(
    "InteractionId" text, "Segment" integer, "Workgroup" text, "ClassificationCode" text,
    "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text,
    "RemoteAddress" text, "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean,
    "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "IsMessaging" boolean,
    "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp without time zone,
    "AnsweredDateTime" timestamp without time zone, "LastUserId" text, "LastWorkgroup" text,
    "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text,
    "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text,
    "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text,
    "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text,
    "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text,
    "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text
)
LANGUAGE sql AS $$
    SELECT "InteractionId"::text, "Segment", "Workgroup"::text, "ClassificationCode"::text,
        "InteractionType"::text, "CallType"::text, "Direction"::text, "CustomCallData"::text,
        "RemoteAddress"::text, "UserId"::text, "IsTransferred", "IsAnswered", "IsInQueue",
        "IsTalk", "IsAbandoned", "IsMessaging", "TimeInQueue", "TalkTime",
        ("InQueueDateTime" AT TIME ZONE 'UTC'), ("AnsweredDateTime" AT TIME ZONE 'UTC'),
        "LastUserId"::text, "LastWorkgroup"::text,
        "CustomCallData1"::text, "CustomCallData2"::text, "CustomCallData3"::text, "CustomCallData4"::text,
        "CustomCallData5"::text, "CustomCallData6"::text, "CustomCallData7"::text, "CustomCallData8"::text,
        "CustomCallData9"::text, "CustomCallData10"::text, "CustomCallData11"::text, "CustomCallData12"::text,
        "CustomCallData13"::text, "CustomCallData14"::text, "CustomCallData15"::text, "CustomCallData16"::text,
        "CustomCallData17"::text, "CustomCallData18"::text, "CustomCallData19"::text, "CustomCallData20"::text,
        "IsCallbackRequest", "TimeZone"::text, "ServerId"::text, "OnDate"::text
    FROM "RTSData_Interaction"
    WHERE "TenantId" = p_tenant_id
      AND (
            ("UpdateTime" AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          = (now()        AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

-- Lowercase aliases
CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_tenant_id uuid)
RETURNS TABLE("TenantId" uuid, "InteractionId" text, "Segment" integer, "OnDate" text,
    "ServerId" text, "Workgroup" text, "UserId" text, "ClassificationCode" text,
    "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text,
    "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean,
    "IsAbandoned" boolean, "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz, "UpdateTime" timestamptz, "LastUserId" text,
    "LastWorkgroup" text, "IsMessaging" boolean, "RemoteAddress" text,
    "IsCallbackRequest" boolean, "TimeZone" text)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetInteractions"(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_on_date text, p_tenant_id uuid)
RETURNS TABLE("InteractionId" text, "Segment" integer, "Workgroup" text, "ClassificationCode" text,
    "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text,
    "RemoteAddress" text, "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean,
    "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "IsMessaging" boolean,
    "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp without time zone,
    "AnsweredDateTime" timestamp without time zone, "LastUserId" text, "LastWorkgroup" text,
    "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text,
    "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text,
    "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text,
    "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text,
    "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text,
    "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetInteractions"(p_on_date, p_tenant_id); $$;

-- ============================================================================
-- 6. RTSData_GetUsersStatuses — AUTHORITATIVE overload set
--    Arity-1: (uuid) + Arity-2: (text, uuid) — DBMng passes @OnDate, @TenantId
-- ============================================================================
DO $drop_getusersstatuses$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc
             WHERE proname IN ('RTSData_GetUsersStatuses', 'RTSData_getUsersStatuses') LOOP
        IF r.prokind = 'p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                   EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
    END LOOP;
END $drop_getusersstatuses$;

-- Arity-1
CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_tenant_id uuid)
RETURNS TABLE("TenantId" uuid, "UserId" text, "StatusId" text, "ServerId" text, "OnDate" text,
    "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer,
    "TotalCount" integer, "UpdateTime" timestamptz, "DisplayName" text, "TimeZone" text)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT s."TenantId", s."UserId"::text, s."StatusId"::text, s."ServerId"::text,
        s."OnDate"::text, s."StatusName"::text, s."StatusGroup"::text, s."TotalDuration",
        s."MaxDuraction", s."TotalCount", s."UpdateTime", s."DisplayName"::text, s."TimeZone"::text
    FROM "RTSData_UserStatus" s WHERE s."TenantId" = p_tenant_id;
END; $$;

-- Arity-2: filtered by OnDate (DBMng.getUsersStatuses caller passes @OnDate, @TenantId)
CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_on_date text, p_tenant_id uuid)
RETURNS TABLE("UserId" text, "StatusId" text, "StatusName" text, "StatusGroup" text,
    "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "DisplayName" text,
    "TimeZone" text, "UpdateTime" timestamp without time zone, "ServerId" text)
LANGUAGE sql AS $$
    SELECT "UserId"::text, "StatusId"::text, "StatusName"::text, "StatusGroup"::text,
        "TotalDuration", "MaxDuraction", "TotalCount", "DisplayName"::text, "TimeZone"::text,
        ("UpdateTime" AT TIME ZONE 'UTC'), "ServerId"::text
    FROM "RTSData_UserStatus" WHERE "OnDate" = p_on_date AND "TenantId" = p_tenant_id
    ORDER BY "UpdateTime" DESC;
$$;

-- Lowercase aliases
CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_tenant_id uuid)
RETURNS TABLE("TenantId" uuid, "UserId" text, "StatusId" text, "ServerId" text, "OnDate" text,
    "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer,
    "TotalCount" integer, "UpdateTime" timestamptz, "DisplayName" text, "TimeZone" text)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_on_date text, p_tenant_id uuid)
RETURNS TABLE("UserId" text, "StatusId" text, "StatusName" text, "StatusGroup" text,
    "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "DisplayName" text,
    "TimeZone" text, "UpdateTime" timestamp without time zone, "ServerId" text)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_on_date, p_tenant_id); $$;

-- ============================================================================
-- 7. fn_daytrendagentstatus — BU-scoped agent status metrics for DayTrend widget
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_daytrendagentstatus(uuid, character varying, text[], integer);

CREATE OR REPLACE FUNCTION public.fn_daytrendagentstatus(
    p_tenantid uuid, p_ondate character varying, p_businessunitid integer, p_intervalmin integer)
RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
LANGUAGE sql STABLE AS $$
    WITH bu_supergroups AS (
        SELECT bus."SupergroupId" FROM "NGC_BusinessUnitSupergroup" bus
        WHERE bus."BusinessUnitId" = p_businessunitid AND bus."TenantId" = p_tenantid
    ),
    sg_ag_total AS (
        SELECT sa."SupergroupId", COUNT(DISTINCT sa."AgentgroupId") AS total_ag
        FROM "NGC_SupergroupAgentgroup" sa JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        WHERE sa."TenantId" = p_tenantid GROUP BY sa."SupergroupId"
    ),
    supergroup_agents AS (
        SELECT ua."UserId", sa."SupergroupId"
        FROM "NGC_SupergroupAgentgroup" sa JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        JOIN "NGC_UserAgentgroup" ua ON ua."AgentgroupId" = sa."AgentgroupId" AND ua."TenantId" = sa."TenantId"
        WHERE sa."TenantId" = p_tenantid GROUP BY ua."UserId", sa."SupergroupId"
        HAVING COUNT(DISTINCT sa."AgentgroupId") = (SELECT t.total_ag FROM sg_ag_total t WHERE t."SupergroupId" = sa."SupergroupId")
    ),
    agents_in_bu AS (SELECT DISTINCT "UserId" FROM supergroup_agents),
    status_rows AS (
        SELECT usl."UserId", usl."StatusGroup", usl."StartTime", COALESCE(usl."EndTime", now()) AS end_time
        FROM "RTSData_UserStatusLog" usl JOIN agents_in_bu a ON a."UserId" = usl."UserId"
        WHERE usl."TenantId" = p_tenantid AND usl."OnDate" = p_ondate AND usl."StatusGroup" IS NOT NULL AND usl."StartTime" IS NOT NULL
    ),
    span AS (
        SELECT date_trunc('hour', MIN("StartTime")) + (FLOOR(EXTRACT(MINUTE FROM MIN("StartTime")) / p_intervalmin) * (p_intervalmin || ' minutes')::interval) AS first_start, MAX(end_time) AS last_end FROM status_rows
    ),
    intervals AS (SELECT gs AS interval_start FROM span, generate_series(span.first_start, span.last_end, (p_intervalmin || ' minutes')::interval) AS gs WHERE span.first_start IS NOT NULL),
    agent_status AS (
        SELECT iv.interval_start, sr."UserId", sr."StatusGroup",
            GREATEST(0, EXTRACT(EPOCH FROM (LEAST(sr.end_time, iv.interval_start + (p_intervalmin || ' minutes')::interval) - GREATEST(sr."StartTime", iv.interval_start)))::bigint * 1000) AS overlap_ms
        FROM intervals iv JOIN status_rows sr ON sr."StartTime" < iv.interval_start + (p_intervalmin || ' minutes')::interval AND sr.end_time > iv.interval_start
    ),
    pool_summary AS (SELECT interval_start, COUNT(DISTINCT "UserId") AS logged_in_agents FROM agent_status GROUP BY interval_start),
    status_summary AS (
        SELECT interval_start,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='AVAILABLE') AS available_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='ONPHONE') AS onphone_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='BREAK') AS break_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='PAPERWORK') AS paperwork_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='TRAINING') AS training_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='UNAVAILABLE') AS unavailable_agents,
            COUNT(DISTINCT "UserId") AS total_agents,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='AVAILABLE'),0) AS available_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='ONPHONE'),0) AS onphone_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='BREAK'),0) AS break_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='PAPERWORK'),0) AS paperwork_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='TRAINING'),0) AS training_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='UNAVAILABLE'),0) AS unavailable_time_ms,
            COALESCE(SUM(overlap_ms),0) AS total_active_time_ms
        FROM agent_status GROUP BY interval_start
    )
    SELECT ps.interval_start, 'statuslog.logged_in_agents', ps.logged_in_agents::double precision FROM pool_summary ps
    UNION ALL SELECT ss.interval_start,'statuslog.available_agents', ss.available_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_agents', ss.onphone_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_agents', ss.break_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_agents', ss.paperwork_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_agents', ss.training_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_agents', ss.unavailable_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_agents', ss.total_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.available_time_ms', ss.available_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_time_ms', ss.onphone_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_time_ms', ss.break_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_time_ms', ss.paperwork_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_time_ms', ss.training_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_time_ms', ss.unavailable_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_active_time_ms', ss.total_active_time_ms::double precision FROM status_summary ss
    ORDER BY 1, 2;
$$;


-- ============================================================================
-- 8. fn_daytrendinteractions — Queue-scoped interaction metrics for DayTrend widget
--    Moved from schema.sql (R0d single-source)
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_daytrendinteractions(uuid, character varying, text[], integer);

CREATE OR REPLACE FUNCTION public.fn_daytrendinteractions(
    p_tenantid uuid, p_ondate character varying, p_queuelist text[], p_intervalmin integer)
RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
LANGUAGE sql STABLE AS $$
    WITH base AS (
        SELECT
            DATE_TRUNC('hour', "InQueueDateTime") +
                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                 * (p_intervalmin || ' minutes')::interval)  AS interval_start,
            "InteractionType",
            "Direction",
            "CallType",
            "IsAnswered",
            "IsAbandoned",
            "IsTransferred",
            "IsCallbackRequest",
            "IsInQueue",
            "IsTalk",
            "TimeInQueue",
            "TalkTime"
        FROM "RTSData_Interaction"
        WHERE "TenantId"  = p_tenantid
          AND "OnDate"    = p_ondate
          AND "Workgroup" = ANY(p_queuelist)
          AND "InQueueDateTime" IS NOT NULL
    ),
    agg AS (
        SELECT
            interval_start,
            -- QueueNumIncomingOnlineCalls: Call + External + Incoming
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                               AND "CallType"        = 'External'
                               AND "Direction"       = 'Incoming')                            AS incoming_calls,
            -- QueueNumAnsweredCalls: Call + External + Incoming + IsAnswered
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                               AND "CallType"        = 'External'
                               AND "Direction"       = 'Incoming'
                               AND "IsAnswered"      = true)                                  AS answered_calls,
            -- QueueNumAbandonedCalls: Call + External + Incoming + IsAbandoned + !IsCallbackRequest
            COUNT(*) FILTER (WHERE "InteractionType"    = 'Call'
                               AND "CallType"           = 'External'
                               AND "Direction"          = 'Incoming'
                               AND "IsAbandoned"        = true
                               AND "IsCallbackRequest"  = false)                              AS abandoned_calls,
            -- QueueNumCallbackRequests: IsCallbackRequest + Incoming + External
            COUNT(*) FILTER (WHERE "IsCallbackRequest" = true
                               AND "CallType"          = 'External'
                               AND "Direction"         = 'Incoming')                          AS callback_requests,
            -- QueueNumCompletedCallbacks: Callback + External + Outgoing + IsAnswered
            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                               AND "CallType"        = 'External'
                               AND "Direction"       = 'Outgoing'
                               AND "IsAnswered"      = true)                                  AS completed_callbacks,
            -- QueueNumOutboundCalls: Call + External + Outgoing
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                               AND "CallType"        = 'External'
                               AND "Direction"       = 'Outgoing')                            AS outbound_calls,
            -- QueueNumTransferredCalls: Call + External + Incoming + IsTransferred
            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                               AND "CallType"        = 'External'
                               AND "Direction"       = 'Incoming'
                               AND "IsTransferred"   = true)                                  AS transferred_calls,
            -- QueueAvgWaitTimeCalls: Call + External + Incoming + completed (!IsInQueue)
            AVG("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                         AND "CallType"        = 'External'
                                         AND "Direction"       = 'Incoming'
                                         AND "IsInQueue"       = false
                                         AND "IsAnswered"      = true)                        AS avg_wait_time,
            -- QueueCurMaxWaitTimeCalls: Call + External + Incoming
            MAX("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                         AND "CallType"        = 'External'
                                         AND "Direction"       = 'Incoming'
                                         AND "IsAnswered"      = true)                        AS max_wait_time,
            -- QueueAvgTalkingDurationCalls: Call + External + Incoming + !IsTalk + !IsInQueue
            AVG("TalkTime")    FILTER (WHERE "InteractionType" = 'Call'
                                         AND "CallType"        = 'External'
                                         AND "Direction"       = 'Incoming'
                                         AND "IsAnswered"      = true
                                         AND "IsTalk"          = false
                                         AND "IsInQueue"       = false)                       AS avg_talk_time,
            -- QueueAvgTimeToAbandCalls: Call + External + Incoming + !IsInQueue + IsAbandoned
            AVG("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                         AND "CallType"        = 'External'
                                         AND "Direction"       = 'Incoming'
                                         AND "IsAbandoned"     = true
                                         AND "IsInQueue"       = false)                       AS avg_abandon_wait
        FROM base
        GROUP BY interval_start
    )
    SELECT interval_start, 'interaction.incoming_calls',      incoming_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.answered_calls',      answered_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.abandoned_calls',     abandoned_calls::double precision     FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.callback_requests',   callback_requests::double precision   FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.completed_callbacks', completed_callbacks::double precision FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.outbound_calls',      outbound_calls::double precision      FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.transferred_calls',   transferred_calls::double precision   FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_wait_time',       avg_wait_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.max_wait_time',       max_wait_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_talk_time',       avg_talk_time                         FROM agg
    UNION ALL
    SELECT interval_start, 'interaction.avg_abandon_wait',    avg_abandon_wait                      FROM agg
    ORDER BY 1, 2;
$$;

-- ============================================================================
-- End of RTSData_* functions
-- ============================================================================
