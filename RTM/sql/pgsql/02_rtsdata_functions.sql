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
    p_time_zone text
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
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue, p_talk_time, p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address, p_is_callback_request, p_time_zone
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
        "TimeZone" = EXCLUDED."TimeZone";
END;
$$;

-- ============================================================================
-- 2. RTSData_SetUserStatus
--    UPSERT using ON CONFLICT on 4-col PK (UserId, StatusId, ServerId, OnDate)
--    No mismatch between EF PK and UPSERT key
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text
);

CREATE OR REPLACE FUNCTION "RTSData_SetUserStatus"(
    p_user_id text,
    p_status_id text,
    p_status_name text,
    p_status_group text,
    p_total_duration integer,
    p_max_duration integer,
    p_total_count integer,
    p_source_server text,
    p_on_date text,
    p_update_time timestamptz,
    p_display_name text,
    p_time_zone text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_UserStatus" (
        "UserId", "StatusId", "ServerId", "OnDate",
        "StatusName", "StatusGroup", "TotalDuration", "MaxDuration",
        "TotalCount", "UpdateTime", "DisplayName", "TimeZone"
    )
    VALUES (
        p_user_id, p_status_id, p_source_server, p_on_date,
        p_status_name, p_status_group, p_total_duration, p_max_duration,
        p_total_count, p_update_time, p_display_name, p_time_zone
    )
    ON CONFLICT ("UserId", "StatusId", "ServerId", "OnDate")
    DO UPDATE SET
        "StatusName" = EXCLUDED."StatusName",
        "StatusGroup" = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuration" = EXCLUDED."MaxDuration",
        "TotalCount" = EXCLUDED."TotalCount",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "DisplayName" = EXCLUDED."DisplayName",
        "TimeZone" = EXCLUDED."TimeZone";
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
    p_time_stamp timestamptz
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_ChatMessage" (
        "MessageId", "ServerId", "OnDate",
        "InteractionId", "SegmentId", "UserId", "MsgDirection",
        "Sender", "Recipient", "Body", "DeliveryStatus",
        "UpdateTime", "TimeStamp"
    )
    VALUES (
        p_message_id, p_server_id, p_on_date,
        p_interaction_id, p_segment_id, p_user_id, p_msg_direction,
        p_sender, p_recipient, p_body, p_delivery_status,
        p_update_time, p_time_stamp
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
        "TimeStamp" = EXCLUDED."TimeStamp";
END;
$$;

-- ============================================================================
-- 4. RTSData_MidnightClear
--    CRITICAL: Function name is "RTSData_MidnightClear" (NOT "_1" suffix)
--    Clears Interaction and UserStatus tables — ChatMessage is NOT cleared
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "RTSData_Interaction";
    DELETE FROM "RTSData_UserStatus";
    -- RTSData_ChatMessage is intentionally NOT cleared per production behavior
END;
$$;

-- ============================================================================
-- 5. RTSData_GetInteractions
--    Returns all columns from RTSData_Interaction
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"()
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
    FROM "RTSData_Interaction" i;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"()
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
AS $$ SELECT * FROM "RTSData_GetInteractions"(); $$;

-- ============================================================================
-- 6. RTSData_GetUsersStatuses
--    Returns all columns from RTSData_UserStatus
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"()
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuration" integer,
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
        s."MaxDuration",
        s."TotalCount",
        s."UpdateTime",
        s."DisplayName"::text,
        s."TimeZone"::text
    FROM "RTSData_UserStatus" s;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"()
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuration" integer,
    "TotalCount" integer,
    "UpdateTime" timestamptz,
    "DisplayName" text,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(); $$;

-- ============================================================================
-- End of RTSData_* functions (6 main + 2 lowercase aliases = 8 total)
-- ============================================================================
