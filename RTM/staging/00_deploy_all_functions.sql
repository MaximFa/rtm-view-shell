-- ============================================================================
-- RTM Backend PostgreSQL Migration — Combined Function Deployment Script
--
-- This script deploys all 37 PL/pgSQL functions for the RTM backend.
-- Idempotent: safe to re-run (uses CREATE OR REPLACE FUNCTION).
--
-- Contents:
--   Section 1: NGC_* functions (18) — Business Unit / Supergroup management
--   Section 2: RTSData_* functions (8) — Real-time data UPSERT and reads
--   Section 3: RTSGrid_* read functions (8) — Grid configuration reads
--   Section 4: Missing/stub functions (3) — Reverse-engineered + DNN stub
--
-- Usage:
--   psql -U cc_rtm_app -d cc_rtm_staging -f 00_deploy_all_functions.sql
--
-- Prerequisites:
--   - EF migrations applied (tables must exist)
--   - BackendEmulationDbContext tables created
-- ============================================================================

-- Setup
CREATE SCHEMA IF NOT EXISTS public;
SET search_path = public;

\echo '============================================================'
\echo 'RTM Backend Function Deployment'
\echo '============================================================'

-- ############################################################################
-- SECTION 1: NGC_* Functions (18 total)
-- Source: RTM-M3 task
-- ############################################################################

\echo ''
\echo '>>> Section 1: NGC_* Functions (18)'

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
        bu."BusinessUnitName",
        bu."Description",
        bu."CreatedDatetime",
        bu."CreatedBy",
        bu."SiteId"
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
        sg."SupergroupName",
        sg."Description",
        sg."CreatedDatetime",
        sg."CreatedBy",
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
        bq."QueueId",
        bq."TenantId",
        bq."ClassificationId",
        bq."CreatedDatetime",
        bq."CreatedBy"
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
        bs."CreatedBy"
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
        sa."AgentgroupId",
        sa."TenantId",
        sa."CreatedDatetime",
        sa."CreatedBy"
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
        s."SiteId",
        s."TenantId",
        s."SiteName",
        s."Description",
        s."TimeZone",
        s."ClearTime"
    FROM "NGC_Site" s;
END;
$$;

-- ============================================================================
-- 7. NGC_CreateBusinessUnit
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

\echo '    NGC_* functions: 18 deployed'

-- ############################################################################
-- SECTION 2: RTSData_* Functions (8 total: 6 main + 2 aliases)
-- Source: RTM-M4 task
-- ############################################################################

\echo ''
\echo '>>> Section 2: RTSData_* Functions (8)'

-- ============================================================================
-- 1. RTSData_SetInteraction
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
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "RTSData_Interaction";
    DELETE FROM "RTSData_UserStatus";
END;
$$;

-- ============================================================================
-- 5. RTSData_GetInteractions
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
        i."TenantId", i."InteractionId", i."Segment", i."OnDate", i."ServerId",
        i."Workgroup", i."UserId", i."ClassificationCode", i."InteractionType",
        i."CallType", i."Direction", i."CustomCallData", i."IsTransferred",
        i."IsAnswered", i."IsInQueue", i."IsTalk", i."IsAbandoned",
        i."TimeInQueue", i."TalkTime", i."InQueueDateTime", i."AnsweredDateTime",
        i."UpdateTime", i."LastUserId", i."LastWorkgroup", i."IsMessaging",
        i."RemoteAddress", i."IsCallbackRequest", i."TimeZone"
    FROM "RTSData_Interaction" i;
END;
$$;

-- Lowercase alias
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();
CREATE OR REPLACE FUNCTION "RTSData_getInteractions"()
RETURNS TABLE(
    "TenantId" uuid, "InteractionId" text, "Segment" integer, "OnDate" text,
    "ServerId" text, "Workgroup" text, "UserId" text, "ClassificationCode" text,
    "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text,
    "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean,
    "IsTalk" boolean, "IsAbandoned" boolean, "TimeInQueue" integer, "TalkTime" integer,
    "InQueueDateTime" timestamptz, "AnsweredDateTime" timestamptz, "UpdateTime" timestamptz,
    "LastUserId" text, "LastWorkgroup" text, "IsMessaging" boolean,
    "RemoteAddress" text, "IsCallbackRequest" boolean, "TimeZone" text
)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetInteractions"(); $$;

-- ============================================================================
-- 6. RTSData_GetUsersStatuses
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
        s."TenantId", s."UserId", s."StatusId", s."ServerId", s."OnDate",
        s."StatusName", s."StatusGroup", s."TotalDuration", s."MaxDuration",
        s."TotalCount", s."UpdateTime", s."DisplayName", s."TimeZone"
    FROM "RTSData_UserStatus" s;
END;
$$;

-- Lowercase alias
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();
CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"()
RETURNS TABLE(
    "TenantId" uuid, "UserId" text, "StatusId" text, "ServerId" text, "OnDate" text,
    "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuration" integer,
    "TotalCount" integer, "UpdateTime" timestamptz, "DisplayName" text, "TimeZone" text
)
LANGUAGE sql AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(); $$;

\echo '    RTSData_* functions: 8 deployed (6 main + 2 aliases)'

-- ############################################################################
-- SECTION 3: RTSGrid_* Read Functions (8 total)
-- Source: RTM-M5 task
-- ############################################################################

\echo ''
\echo '>>> Section 3: RTSGrid_* Read Functions (8)'

-- ============================================================================
-- 1. RTSGrid_GetDataCells
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetDataCells"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetDataCells"()
RETURNS TABLE(
    "CellId" integer, "CellType" text, "GridId" integer, "ColumnId" integer,
    "RowId" integer, "UnionId" integer, "GridUnionId" integer, "RowUnionId" integer,
    "Metric" text, "ColumnMetric" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c."CellId", c."CellType", g."GridId", o."ColumnId", r."RowId",
           c."UnionId", g."UnionId" AS "GridUnionId", r."UnionId" AS "RowUnionId",
           c."Value" AS "Metric", t."Value" AS "ColumnMetric"
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
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetStatisticCells"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetStatisticCells"()
RETURNS TABLE("CellId" integer, "GridId" integer, "Title" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c."CellId", g."GridId", c."Value" AS "Title"
    FROM "RTSGrid_Grid" g, "RTSGrid_Row" r, "RTSGrid_Cell" c
    WHERE g."GridId" = r."GridId" AND c."RowId" = r."RowId" AND c."CellType" = 'Statistic';
END;
$$;

-- ============================================================================
-- 3. RTSGrid_GetAllUnionQueueClassifications
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionQueueClassifications"()
RETURNS TABLE("BusinessUnitID" integer, "QueueID" text, "ClassificationID" text, "TimeZone" text, "ClearTime" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT u."BusinessUnitId" AS "BusinessUnitID", u."QueueId" AS "QueueID",
           u."ClassificationId" AS "ClassificationID", s."TimeZone", s."ClearTime"
    FROM "NGC_BusinessUnitQueueClassification" u, "NGC_BusinessUnit" b, "NGC_Site" s
    WHERE b."BusinessUnitId" = u."BusinessUnitId" AND b."SiteId" = s."SiteId";
END;
$$;

-- ============================================================================
-- 4. RTSGrid_GetAllUnionUserGroups
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionUserGroups"()
RETURNS TABLE("BusinessUnitID" integer, "SupergroupID" integer, "AgentgroupID" text, "TimeZone" text, "ClearTime" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT u."BusinessUnitId" AS "BusinessUnitID", s."SupergroupId" AS "SupergroupID",
           s."AgentgroupId" AS "AgentgroupID", t."TimeZone", t."ClearTime"
    FROM "NGC_SupergroupAgentgroup" s, "NGC_BusinessUnitSupergroup" u,
         "NGC_BusinessUnit" b, "NGC_Site" t
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND s."SupergroupId" = u."SupergroupId"
      AND b."SiteId" = t."SiteId";
END;
$$;

-- ============================================================================
-- 5. RTSGrid_GetAllMetrics
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllMetrics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllMetrics"()
RETURNS TABLE("MetricId" text, "Description" text, "DataType" text, "MetricFunction" text,
              "MetricParameter" text, "MetricFormat" text, "DefaultValue" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT m."MetricId",
           CASE WHEN m."Description" IS NULL OR m."Description" = '' THEN m."MetricId" ELSE m."Description" END,
           m."DataType", m."MetricFunction", m."MetricParameter", m."MetricFormat", m."DefaultValue"
    FROM "RTSGrid_Metric" m;
END;
$$;

-- ============================================================================
-- 6. RTSGrid_GetAllStatistics
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllStatistics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllStatistics"()
RETURNS TABLE(
    "StatisticId" integer, "Category" text, "Definition" text,
    "ParamType1" text, "ParamValue1" text, "ParamType2" text, "ParamValue2" text,
    "ParamType3" text, "ParamValue3" text, "ParamType4" text, "ParamValue4" text,
    "ParamType5" text, "ParamValue5" text, "ParamType6" text, "ParamValue6" text,
    "ParamType7" text, "ParamValue7" text, "ParamType8" text, "ParamValue8" text,
    "ParamType9" text, "ParamValue9" text, "ParamType10" text, "ParamValue10" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT s."StatisticId", s."Category", s."Definition",
        s."ParamType1", s."ParamValue1", s."ParamType2", s."ParamValue2",
        s."ParamType3", s."ParamValue3", s."ParamType4", s."ParamValue4",
        s."ParamType5", s."ParamValue5", s."ParamType6", s."ParamValue6",
        s."ParamType7", s."ParamValue7", s."ParamType8", s."ParamValue8",
        s."ParamType9", s."ParamValue9", s."ParamType10", s."ParamValue10"
    FROM "RTSGrid_Statistic" s;
END;
$$;

-- ============================================================================
-- 7. RTSGrid_GetUnionUsersMetrics
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetUnionUsersMetrics"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetUnionUsersMetrics"()
RETURNS TABLE("UnionId" integer, "MetricId" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT g."UnionId", c."MetricId"
    FROM "RTSUserGrid_Column" c, "RTSUserGrid_Grid" g
    WHERE c."ColumnsSetId" = g."ColumnsSetId"
    ORDER BY g."UnionId";
END;
$$;

-- ============================================================================
-- 8. RTSUserGrid_GetAllGrids
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSUserGrid_GetAllGrids"();

CREATE OR REPLACE FUNCTION "RTSUserGrid_GetAllGrids"()
RETURNS TABLE("GridId" integer, "UnionId" integer, "CSS" integer, "Title" text,
              "RowsFilterNew" text, "PageSize" integer, "ThresholdScript" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT g."GridId", g."UnionId", g."StyleId" AS "CSS", g."Title",
                        g."RowsFilterNew", g."PageSize", g."ThresholdScript"
    FROM "RTSUserGrid_Grid" g;
END;
$$;

\echo '    RTSGrid_* read functions: 8 deployed'

-- ############################################################################
-- SECTION 4: Missing/Stub Functions (3 total)
-- Source: RTM-M6 task
-- ############################################################################

\echo ''
\echo '>>> Section 4: Missing/Stub Functions (3)'

-- ============================================================================
-- 1. NGC_GetDataGrid
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetDataGrid"(integer);

CREATE OR REPLACE FUNCTION "NGC_GetDataGrid"(p_grid_id integer)
RETURNS TABLE("Title" text, "BusinessUnitID" integer, "CssStyleID" integer,
              "ThresholdID" integer, "ThresholdScript" text, "IsToggle" boolean, "ToggleDefault" boolean)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT g."Title"::text, g."UnionId" AS "BusinessUnitID", g."StyleId" AS "CssStyleID",
           NULL::integer AS "ThresholdID", COALESCE(g."ThresholdScript", '')::text,
           false AS "IsToggle", false AS "ToggleDefault"
    FROM "RTSGrid_Grid" g WHERE g."GridId" = p_grid_id;
END;
$$;

-- ============================================================================
-- 2. NGC_GetCellsByDataGrid
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetCellsByDataGrid"(integer);

CREATE OR REPLACE FUNCTION "NGC_GetCellsByDataGrid"(p_grid_id integer)
RETURNS TABLE("CellID" integer, "ColumnId" integer, "RowNumber" integer, "RowId" integer,
              "CssStyleID" integer, "GridStyleId" integer, "RowStyleId" integer,
              "CellType" text, "Value" text, "Tooltip" text, "OnClick" text)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c."CellId" AS "CellID", c."ColumnId", r."RowNumber", r."RowId",
           c."StyleId" AS "CssStyleID", g."StyleId" AS "GridStyleId", r."StyleId" AS "RowStyleId",
           COALESCE(c."CellType", '')::text, COALESCE(c."Value", '')::text,
           COALESCE(t."Tooltip", '')::text, COALESCE(t."OnClick", '')::text
    FROM "RTSGrid_Cell" c
    JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
    JOIN "RTSGrid_Grid" g ON r."GridId" = g."GridId"
    LEFT JOIN "RTSGrid_Column" o ON c."ColumnId" = o."ColumnId"
    LEFT JOIN "RTSGrid_TemplateCell" t ON o."CellTemplateId" = t."CellTemplateId"
    WHERE g."GridId" = p_grid_id;
END;
$$;

-- ============================================================================
-- 3. RTSUserView_GetHTMLSettings (STUB)
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSUserView_GetHTMLSettings"();

CREATE OR REPLACE FUNCTION "RTSUserView_GetHTMLSettings"()
RETURNS TABLE("SettingValue" text)
LANGUAGE plpgsql
AS $$
BEGIN
    -- STUB: DNN ModuleSettings not migrated. Returns empty.
    RETURN;
END;
$$;

\echo '    Missing/stub functions: 3 deployed'

-- ############################################################################
-- DEPLOYMENT COMPLETE
-- ############################################################################

\echo ''
\echo '============================================================'
\echo 'DEPLOYMENT COMPLETE: 37 functions deployed'
\echo '  - NGC_*: 18'
\echo '  - RTSData_*: 8 (6 main + 2 aliases)'
\echo '  - RTSGrid_*: 8'
\echo '  - Missing/stub: 3'
\echo '============================================================'

-- Verification query
SELECT COUNT(*) AS function_count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname LIKE ANY(ARRAY['ngc_%', 'rts%']);
