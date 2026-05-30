-- ============================================================================
-- Combined PL/pgSQL Functions for RTM Backend PostgreSQL Staging
-- Auto-generated: 2026-05-31
--
-- This file combines all 37 functions from:
--   - 01_ngc_functions.sql (18 functions)
--   - 02_rtsdata_functions.sql (8 functions including aliases)
--   - 03_rtsgrid_read_functions.sql (8 functions)
--   - 04_missing_functions.sql (3 functions)
--
-- Run AFTER EF migrations (BackendEmulationDbContext) to create tables.
-- All varchar columns cast to ::text for RETURNS TABLE compatibility.
-- ============================================================================

-- ============================================================================
-- SOURCE: 01_ngc_functions.sql
-- ============================================================================

-- ============================================================================
-- NGC_* PL/pgSQL Functions for RTM Backend Migration
-- Output of RTM-M3 task
--
-- These functions replace SQL Server stored procedures called from
-- RTM/RTM/BusinessUnitData.cs via DBAdapter.
--
-- All identifiers are double-quoted (PostgreSQL case-sensitivity).
-- SERIAL columns use RETURNING for insert functions.
-- ============================================================================

-- ============================================================================
-- 1. NGC_GetBusinessUnitTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitTable"()
RETURNS TABLE(
    "BusinessUnitId" integer,
    "TenantId" uuid,
    "BusinessUnitName" text,
    "Description" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text,
    "SiteId" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bu."BusinessUnitId",
        bu."TenantId",
        bu."BusinessUnitName"::text,
        bu."Description"::text,
        bu."CreatedDatetime",
        bu."CreatedBy"::text,
        bu."SiteId"::text
    FROM "NGC_BusinessUnit" bu
    ORDER BY bu."BusinessUnitId";
END;
$$;

-- ============================================================================
-- 2. NGC_GetSupergroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupTable"()
RETURNS TABLE(
    "SupergroupId" integer,
    "TenantId" uuid,
    "SupergroupName" text,
    "Description" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text,
    "SupergroupIdOld" integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sg."SupergroupId",
        sg."TenantId",
        sg."SupergroupName"::text,
        sg."Description"::text,
        sg."CreatedDatetime",
        sg."CreatedBy"::text,
        sg."SupergroupIdOld"
    FROM "NGC_Supergroup" sg
    ORDER BY sg."SupergroupId";
END;
$$;

-- ============================================================================
-- 3. NGC_GetBusinessUnitQueueClassificationTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitQueueClassificationTable"()
RETURNS TABLE(
    "BusinessUnitId" integer,
    "QueueId" text,
    "TenantId" uuid,
    "ClassificationId" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bq."BusinessUnitId",
        bq."QueueId"::text,
        bq."TenantId",
        bq."ClassificationId"::text,
        bq."CreatedDatetime",
        bq."CreatedBy"::text
    FROM "NGC_BusinessUnitQueueClassification" bq;
END;
$$;

-- ============================================================================
-- 4. NGC_GetBusinessUnitSupergroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitSupergroupTable"()
RETURNS TABLE(
    "BusinessUnitId" integer,
    "SupergroupId" integer,
    "TenantId" uuid,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bs."BusinessUnitId",
        bs."SupergroupId",
        bs."TenantId",
        bs."CreatedDatetime",
        bs."CreatedBy"::text
    FROM "NGC_BusinessUnitSupergroup" bs;
END;
$$;

-- ============================================================================
-- 5. NGC_GetSupergroupAgentgroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupAgentgroupTable"()
RETURNS TABLE(
    "Id" integer,
    "SupergroupId" integer,
    "AgentgroupId" text,
    "TenantId" uuid,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa."Id",
        sa."SupergroupId",
        sa."AgentgroupId"::text,
        sa."TenantId",
        sa."CreatedDatetime",
        sa."CreatedBy"::text
    FROM "NGC_SupergroupAgentgroup" sa;
END;
$$;

-- ============================================================================
-- 6. NGC_GetSiteTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSiteTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSiteTable"()
RETURNS TABLE(
    "SiteId" text,
    "TenantId" uuid,
    "SiteName" text,
    "Description" text,
    "TimeZone" text,
    "ClearTime" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s."SiteId"::text,
        s."TenantId",
        s."SiteName"::text,
        s."Description"::text,
        s."TimeZone"::text,
        s."ClearTime"::text
    FROM "NGC_Site" s;
END;
$$;

-- ============================================================================
-- 7. NGC_CreateBusinessUnit
--    Returns generated BusinessUnitId (SERIAL)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,
    p_description text
)
RETURNS TABLE("BusinessUnitId" integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_BusinessUnit" ("BusinessUnitName", "Description", "CreatedDatetime")
    VALUES (p_business_unit_name, p_description, NOW())
    RETURNING "NGC_BusinessUnit"."BusinessUnitId";
END;
$$;

-- ============================================================================
-- 8. NGC_ModifyBusinessUnit
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text);

CREATE OR REPLACE FUNCTION "NGC_ModifyBusinessUnit"(
    p_business_unit_id integer,
    p_business_unit_name text,
    p_description text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "NGC_BusinessUnit"
    SET "BusinessUnitName" = p_business_unit_name,
        "Description" = p_description
    WHERE "BusinessUnitId" = p_business_unit_id;
END;
$$;

-- ============================================================================
-- 9. NGC_DeleteBusinessUnit
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id;
END;
$$;

-- ============================================================================
-- 10. NGC_CreateSupergroup
--     Returns generated SupergroupId (SERIAL)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description text
)
RETURNS TABLE("SupergroupId" integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime")
    VALUES (p_supergroup_name, p_description, NOW())
    RETURNING "NGC_Supergroup"."SupergroupId";
END;
$$;

-- ============================================================================
-- 11. NGC_ModifySupergroup
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text);

CREATE OR REPLACE FUNCTION "NGC_ModifySupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "NGC_Supergroup"
    SET "SupergroupName" = p_supergroup_name,
        "Description" = p_description
    WHERE "SupergroupId" = p_supergroup_id;
END;
$$;

-- ============================================================================
-- 12. NGC_DeleteSupergroup
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroup"(
    p_supergroup_id integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id;
END;
$$;

-- ============================================================================
-- 13. NGC_CreateBusinessUnitQueueClassificationMapping
--     UPSERT: ON CONFLICT DO NOTHING (idempotent create)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId", "QueueId", "CreatedDatetime")
    VALUES (p_business_unit_id, p_queue_id, NOW())
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 14. NGC_DeleteBusinessUnitQueueClassificationMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "QueueId" = p_queue_id;
END;
$$;

-- ============================================================================
-- 15. NGC_CreateBusinessUnitSupergroupMapping
--     UPSERT: ON CONFLICT DO NOTHING (idempotent create)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "CreatedDatetime")
    VALUES (p_business_unit_id, p_supergroup_id, NOW())
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 16. NGC_DeleteBusinessUnitSupergroupMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId" = p_supergroup_id;
END;
$$;

-- ============================================================================
-- 17. NGC_CreateSupergroupAgentgroupMapping
--     Note: NGC_SupergroupAgentgroup has surrogate PK "Id" (SERIAL).
--     The logical uniqueness is (SupergroupId, AgentgroupId) but EF model
--     doesn't define a unique constraint on it. We use ON CONFLICT DO NOTHING
--     on the surrogate PK which means duplicates are possible.
--     If business logic requires uniqueness, add:
--       CREATE UNIQUE INDEX IF NOT EXISTS "IX_NGC_SupergroupAgentgroup_Logical"
--       ON "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId");
--     For now, simple INSERT matching original T-SQL behavior.
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "CreatedDatetime")
    VALUES (p_supergroup_id, p_agentgroup_id, NOW());
END;
$$;

-- ============================================================================
-- 18. NGC_DeleteSupergroupAgentgroupMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id;
END;
$$;

-- ============================================================================
-- End of NGC_* functions (18 total)
-- ============================================================================


-- ============================================================================
-- SOURCE: 02_rtsdata_functions.sql
-- ============================================================================

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


-- ============================================================================
-- SOURCE: 03_rtsgrid_read_functions.sql
-- ============================================================================

-- ============================================================================
-- RTSGrid_* and RTSUserGrid_* Read Functions for RTM Backend Migration
-- Output of RTM-M5 task
--
-- These functions are called from RTM/RTM/RealtimeData.cs.
-- C# reads columns BY INDEX — column ORDER must match original T-SQL SELECT.
-- All identifiers are double-quoted (PostgreSQL case-sensitivity).
--
-- CRITICAL DEPENDENCY: Functions 1-2 require RTSGrid_TemplateCell table from RTM-M1.
-- ============================================================================

-- ============================================================================
-- 1. RTSGrid_GetDataCells
--    Returns data cells with grid/row/column info for rendering.
--    Column order fixed per original T-SQL.
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetDataCells"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetDataCells"()
RETURNS TABLE(
    "CellId" integer,
    "CellType" text,
    "GridId" integer,
    "ColumnId" integer,
    "RowId" integer,
    "UnionId" integer,
    "GridUnionId" integer,
    "RowUnionId" integer,
    "Metric" text,
    "ColumnMetric" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c."CellId",
        c."CellType"::text,
        g."GridId",
        o."ColumnId",
        r."RowId",
        c."UnionId",
        g."UnionId" AS "GridUnionId",
        r."UnionId" AS "RowUnionId",
        c."Value"::text AS "Metric",
        t."Value"::text AS "ColumnMetric"
    FROM "RTSGrid_Grid" g, "RTSGrid_Row" r, "RTSGrid_Cell" c,
         "RTSGrid_Column" o, "RTSGrid_TemplateCell" t
    WHERE g."GridId" = r."GridId"
      AND c."RowId" = r."RowId"
      AND c."ColumnId" = o."ColumnId"
      AND o."CellTemplateId" = t."CellTemplateId"
      AND (c."CellType" = 'Data' OR (c."CellType" = 'None' AND t."CellType" = 'Data'));
END;
$$;

-- ============================================================================
-- 2. RTSGrid_GetStatisticCells
--    Returns statistic cells for grids.
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetStatisticCells"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetStatisticCells"()
RETURNS TABLE(
    "CellId" integer,
    "GridId" integer,
    "Title" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c."CellId",
        g."GridId",
        c."Value"::text AS "Title"
    FROM "RTSGrid_Grid" g, "RTSGrid_Row" r, "RTSGrid_Cell" c
    WHERE g."GridId" = r."GridId"
      AND c."RowId" = r."RowId"
      AND c."CellType" = 'Statistic';
END;
$$;

-- ============================================================================
-- 3. NGC_GetSiteTable — SKIP
--    Already defined in RTM-M3 (01_ngc_functions.sql). Do NOT duplicate.
-- ============================================================================

-- ============================================================================
-- 4. RTSGrid_GetAllUnionQueueClassifications
--    Returns queue classifications with site timezone info.
--    Column order matches original T-SQL: BusinessUnitID, QueueID,
--    ClassificationID, TimeZone, ClearTime
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionQueueClassifications"()
RETURNS TABLE(
    "BusinessUnitID" integer,
    "QueueID" text,
    "ClassificationID" text,
    "TimeZone" text,
    "ClearTime" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u."BusinessUnitId" AS "BusinessUnitID",
        u."QueueId"::text AS "QueueID",
        u."ClassificationId"::text AS "ClassificationID",
        s."TimeZone"::text,
        s."ClearTime"::text
    FROM "NGC_BusinessUnitQueueClassification" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" s
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND b."SiteId" = s."SiteId";
END;
$$;

-- ============================================================================
-- 5. RTSGrid_GetAllUnionUserGroups
--    Returns user groups (agentgroups) mapped to business units with site info.
--    Column order: BusinessUnitID, SupergroupID, AgentgroupID, TimeZone, ClearTime
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionUserGroups"()
RETURNS TABLE(
    "BusinessUnitID" integer,
    "SupergroupID" integer,
    "AgentgroupID" text,
    "TimeZone" text,
    "ClearTime" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u."BusinessUnitId" AS "BusinessUnitID",
        s."SupergroupId" AS "SupergroupID",
        s."AgentgroupId"::text AS "AgentgroupID",
        t."TimeZone"::text,
        t."ClearTime"::text
    FROM "NGC_SupergroupAgentgroup" s,
         "NGC_BusinessUnitSupergroup" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" t
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND s."SupergroupId" = u."SupergroupId"
      AND b."SiteId" = t."SiteId";
END;
$$;

-- ============================================================================
-- 6. RTSGrid_GetAllMetrics
--    Returns all metric definitions with fallback for empty Description.
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllMetrics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllMetrics"()
RETURNS TABLE(
    "MetricId" text,
    "Description" text,
    "DataType" text,
    "MetricFunction" text,
    "MetricParameter" text,
    "MetricFormat" text,
    "DefaultValue" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m."MetricId"::text,
        CASE WHEN m."Description" IS NULL OR m."Description" = ''
             THEN m."MetricId"::text
             ELSE m."Description"::text
        END AS "Description",
        m."DataType"::text,
        m."MetricFunction"::text,
        m."MetricParameter"::text,
        m."MetricFormat"::text,
        m."DefaultValue"::text
    FROM "RTSGrid_Metric" m;
END;
$$;

-- ============================================================================
-- 7. RTSGrid_GetAllStatistics
--    Returns all statistic definitions (23 columns).
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllStatistics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllStatistics"()
RETURNS TABLE(
    "StatisticId" integer,
    "Category" text,
    "Definition" text,
    "ParamType1" text,
    "ParamValue1" text,
    "ParamType2" text,
    "ParamValue2" text,
    "ParamType3" text,
    "ParamValue3" text,
    "ParamType4" text,
    "ParamValue4" text,
    "ParamType5" text,
    "ParamValue5" text,
    "ParamType6" text,
    "ParamValue6" text,
    "ParamType7" text,
    "ParamValue7" text,
    "ParamType8" text,
    "ParamValue8" text,
    "ParamType9" text,
    "ParamValue9" text,
    "ParamType10" text,
    "ParamValue10" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s."StatisticId",
        s."Category"::text,
        s."Definition"::text,
        s."ParamType1"::text,
        s."ParamValue1"::text,
        s."ParamType2"::text,
        s."ParamValue2"::text,
        s."ParamType3"::text,
        s."ParamValue3"::text,
        s."ParamType4"::text,
        s."ParamValue4"::text,
        s."ParamType5"::text,
        s."ParamValue5"::text,
        s."ParamType6"::text,
        s."ParamValue6"::text,
        s."ParamType7"::text,
        s."ParamValue7"::text,
        s."ParamType8"::text,
        s."ParamValue8"::text,
        s."ParamType9"::text,
        s."ParamValue9"::text,
        s."ParamType10"::text,
        s."ParamValue10"::text
    FROM "RTSGrid_Statistic" s;
END;
$$;

-- ============================================================================
-- 8. RTSGrid_GetUnionUsersMetrics
--    Returns distinct UnionId/MetricId pairs from user grids.
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetUnionUsersMetrics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetUnionUsersMetrics"()
RETURNS TABLE(
    "UnionId" integer,
    "MetricId" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        g."UnionId",
        c."MetricId"::text
    FROM "RTSUserGrid_Column" c, "RTSUserGrid_Grid" g
    WHERE c."ColumnsSetId" = g."ColumnsSetId"
    ORDER BY g."UnionId";
END;
$$;

-- ============================================================================
-- 9. RTSUserGrid_GetAllGrids
--    Returns all user grid definitions.
--    Column order matches original T-SQL: GridId, UnionId, CSS, Title,
--    RowsFilterNew, PageSize, ThresholdScript
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSUserGrid_GetAllGrids"();

CREATE OR REPLACE FUNCTION "RTSUserGrid_GetAllGrids"()
RETURNS TABLE(
    "GridId" integer,
    "UnionId" integer,
    "CSS" integer,
    "Title" text,
    "RowsFilterNew" text,
    "PageSize" integer,
    "ThresholdScript" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        g."GridId",
        g."UnionId",
        g."StyleId" AS "CSS",
        g."Title"::text,
        g."RowsFilterNew"::text,
        g."PageSize",
        g."ThresholdScript"::text
    FROM "RTSUserGrid_Grid" g;
END;
$$;

-- ============================================================================
-- End of RTSGrid/RTSUserGrid read functions (8 total)
-- Note: NGC_GetSiteTable is in 01_ngc_functions.sql
-- ============================================================================


-- ============================================================================
-- SOURCE: 04_missing_functions.sql
-- ============================================================================

-- ============================================================================
-- Missing Functions — Reverse-Engineered from C# + DNN Stub
-- Output of RTM-M6 task
--
-- OPEN QUESTIONS:
-- OQ-01: RTSUserView_GetHTMLSettings is a stub. The C# caller (RealtimeData.cs:475)
--        reads HTML settings from DNN ModuleSettings. Decide: stub / port table / move to config.
-- OQ-03: NGC_GetDataGrid and NGC_GetCellsByDataGrid were absent from H_RTM.sql dump.
--        Functions below are reverse-engineered from C# column-index access patterns.
--        Validate against production SQL Server before go-live.
--
-- All identifiers are double-quoted (PostgreSQL case-sensitivity).
-- ============================================================================

-- ============================================================================
-- 1. NGC_GetDataGrid(p_grid_id integer)
--    Called from RealtimeData.cs lines 335-360.
--    C# accesses 7 columns BY INDEX:
--      row[0] → title (string)
--      row[1] → businessUnitID (int)      → maps to RTSGrid_Grid.UnionId
--      row[2] → cssStyleID (int)          → maps to RTSGrid_Grid.StyleId
--      row[3] → thresholdID (int)         → NOT in table; return NULL
--      row[4] → thresholdScript (string)  → maps to RTSGrid_Grid.ThresholdScript
--      row[5] → isToggle (bool)           → NOT in table; return false
--      row[6] → toggleDefault (bool)      → NOT in table; return false
--
--    NOTE: RTSGrid_Grid only has: GridId, UnionId, StyleId, Title, ThresholdScript.
--    ThresholdId, IsToggle, ToggleDefault are absent from SQL Server DDL.
--    Returning NULL/false defaults — validate against production behavior.
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetDataGrid"(integer);

CREATE OR REPLACE FUNCTION "NGC_GetDataGrid"(p_grid_id integer)
RETURNS TABLE(
    "Title" text,
    "BusinessUnitID" integer,
    "CssStyleID" integer,
    "ThresholdID" integer,
    "ThresholdScript" text,
    "IsToggle" boolean,
    "ToggleDefault" boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        g."Title"::text,
        g."UnionId" AS "BusinessUnitID",
        g."StyleId" AS "CssStyleID",
        NULL::integer AS "ThresholdID",          -- Column not in RTSGrid_Grid DDL
        COALESCE(g."ThresholdScript", '')::text AS "ThresholdScript",
        false AS "IsToggle",                      -- Column not in RTSGrid_Grid DDL
        false AS "ToggleDefault"                  -- Column not in RTSGrid_Grid DDL
    FROM "RTSGrid_Grid" g
    WHERE g."GridId" = p_grid_id;
END;
$$;

-- ============================================================================
-- 2. NGC_GetCellsByDataGrid(p_grid_id integer)
--    Called from RealtimeData.cs lines 371-398.
--    C# accesses 11 columns BY INDEX:
--      row[0]  → cellID (int)             → RTSGrid_Cell.CellId
--      row[1]  → (unused in C#)           → RTSGrid_Cell.ColumnId (filler)
--      row[2]  → rowNumber (int)          → RTSGrid_Row.RowNumber
--      row[3]  → (unused in C#)           → RTSGrid_Row.RowId (filler)
--      row[4]  → cssStyleID (int)         → RTSGrid_Cell.StyleId
--      row[5]  → gridStyleId (int)        → RTSGrid_Grid.StyleId
--      row[6]  → rowStyleId (int)         → RTSGrid_Row.StyleId
--      row[7]  → cellType (string)        → RTSGrid_Cell.CellType
--      row[8]  → value (string)           → RTSGrid_Cell.Value
--      row[9]  → tooltip (string)         → RTSGrid_TemplateCell.Tooltip (via Column)
--      row[10] → onClick (string)         → RTSGrid_TemplateCell.OnClick (via Column)
--
--    Columns 1 and 3 (row[1], row[3]) are not used in C# but must be present
--    for index alignment. Using ColumnId and RowId as logical fillers.
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetCellsByDataGrid"(integer);

CREATE OR REPLACE FUNCTION "NGC_GetCellsByDataGrid"(p_grid_id integer)
RETURNS TABLE(
    "CellID" integer,
    "ColumnId" integer,
    "RowNumber" integer,
    "RowId" integer,
    "CssStyleID" integer,
    "GridStyleId" integer,
    "RowStyleId" integer,
    "CellType" text,
    "Value" text,
    "Tooltip" text,
    "OnClick" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c."CellId" AS "CellID",
        c."ColumnId",
        r."RowNumber",
        r."RowId",
        c."StyleId" AS "CssStyleID",
        g."StyleId" AS "GridStyleId",
        r."StyleId" AS "RowStyleId",
        COALESCE(c."CellType", '')::text AS "CellType",
        COALESCE(c."Value", '')::text AS "Value",
        COALESCE(t."Tooltip", '')::text AS "Tooltip",
        COALESCE(t."OnClick", '')::text AS "OnClick"
    FROM "RTSGrid_Cell" c
    JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
    JOIN "RTSGrid_Grid" g ON r."GridId" = g."GridId"
    LEFT JOIN "RTSGrid_Column" o ON c."ColumnId" = o."ColumnId"
    LEFT JOIN "RTSGrid_TemplateCell" t ON o."CellTemplateId" = t."CellTemplateId"
    WHERE g."GridId" = p_grid_id;
END;
$$;

-- ============================================================================
-- 3. RTSUserView_GetHTMLSettings()
--    STUB: Original SP reads from DNN ModuleSettings (portal CMS table).
--    DNN is not migrated to PostgreSQL. Returns empty result set.
--    TODO (OQ-01): Replace with appsettings.json config read in C#.
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSUserView_GetHTMLSettings"();

CREATE OR REPLACE FUNCTION "RTSUserView_GetHTMLSettings"()
RETURNS TABLE("SettingValue" text)
LANGUAGE plpgsql
AS $$
BEGIN
    -- STUB: Original SP reads from DNN ModuleSettings (portal CMS table).
    -- DNN is not migrated to PostgreSQL. Returns empty result set.
    -- TODO: Replace with appsettings.json config read in C# (OQ-01).
    RETURN;
END;
$$;

-- ============================================================================
-- End of missing functions (3 total)
-- ============================================================================


