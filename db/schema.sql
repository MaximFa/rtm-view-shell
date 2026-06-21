-- ============================================================================
-- RTM-CANONICAL SCHEMA — 26 tables (RTM authority only)
-- Regenerate via db/tools/Export-All.ps1 (whitelist approach)
--
-- R0b carve (2026-06-21): EF-app tables (38) removed. They are created by
-- Web.exe migrate (App + Audit EF contexts). See db/REBUILD_RUNBOOK.md.
-- ============================================================================
--
-- PostgreSQL database dump
--

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--

--

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';

--
-- Name: NGC_CreateBusinessUnit(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateBusinessUnit"(p_business_unit_name text, p_description text, p_tenant_id uuid) RETURNS TABLE("BusinessUnitId" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_BusinessUnit" ("BusinessUnitName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_BusinessUnit"."BusinessUnitId";
END;
$$;

--
-- Name: NGC_CreateBusinessUnit(text, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateBusinessUnit"(p_business_unit_name text, p_description text, p_site_id text, p_created_by text, p_tenant_id uuid) RETURNS TABLE("BusinessUnitId" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_BusinessUnit" (
        "BusinessUnitName", "Description", "CreatedDatetime",
        "SiteId", "CreatedBy", "TenantId"
    )
    VALUES (
        p_business_unit_name, p_description, NOW(),
        p_site_id, p_created_by, p_tenant_id
    )
    RETURNING "NGC_BusinessUnit"."BusinessUnitId";
END;
$$;

--
-- Name: NGC_CreateBusinessUnitQueueClassificationMapping(integer, text, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_CreateBusinessUnitQueueClassificationMapping"(IN p_business_unit_id integer, IN p_queue_id text, IN p_classification_id text, IN p_created_by text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification"
        ("BusinessUnitId", "QueueId", "ClassificationId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, p_classification_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
END;
$$;

--
-- Name: NGC_CreateBusinessUnitSupergroupMapping(integer, integer, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_CreateBusinessUnitSupergroupMapping"(IN p_business_unit_id integer, IN p_supergroup_id integer, IN p_created_by text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
END;
$$;

--
-- Name: NGC_CreateSupergroup(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateSupergroup"(p_supergroup_name text, p_description text, p_tenant_id uuid) RETURNS TABLE("SupergroupId" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_Supergroup"."SupergroupId";
END;
$$;

--
-- Name: NGC_CreateSupergroup(text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateSupergroup"(p_supergroup_name text, p_description text, p_created_by text, p_tenant_id uuid) RETURNS TABLE("SupergroupId" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_Supergroup"."SupergroupId";
END;
$$;

--
-- Name: NGC_CreateSupergroup(integer, text, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_CreateSupergroup"(IN p_supergroup_id integer, IN p_supergroup_name text, IN p_description text, IN p_created_by text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_Supergroup" ("SupergroupId", "SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_supergroup_name, p_description, NOW(), p_tenant_id)
    ON CONFLICT ("SupergroupId") DO UPDATE
    SET "SupergroupName" = EXCLUDED."SupergroupName",
        "Description"    = EXCLUDED."Description";
END;
$$;

--
-- Name: NGC_CreateSupergroupAgentgroupMapping(integer, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_CreateSupergroupAgentgroupMapping"(IN p_supergroup_id integer, IN p_agentgroup_id text, IN p_created_by text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, p_tenant_id)
    ON CONFLICT ("SupergroupId", "AgentgroupId") DO NOTHING;
END;
$$;

--
-- Name: NGC_DeleteBusinessUnit(integer, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteBusinessUnit"(IN p_business_unit_id integer, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_DeleteSupergroup(integer, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteSupergroup"(IN p_supergroup_id integer, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_DeleteUserAgentgroup(text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteUserAgentgroup"(IN p_user_id text, IN p_agentgroup_id text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_UserAgentgroup"
    WHERE "TenantId" = p_tenant_id
      AND "UserId" = p_user_id
      AND "AgentgroupId" = p_agentgroup_id;
END;
$$;

--
-- Name: NGC_GetBusinessUnitIdByName(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetBusinessUnitIdByName"(p_business_unit_name text, p_tenant_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id integer;
BEGIN
    SELECT "BusinessUnitId" INTO v_id
    FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitName" = p_business_unit_name
      AND "TenantId" = p_tenant_id
    LIMIT 1;
    RETURN v_id;  -- NULL if not found
END;
$$;

--
-- Name: NGC_GetBusinessUnitQueueClassificationTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetBusinessUnitQueueClassificationTable"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitId" integer, "QueueId" text, "TenantId" uuid, "ClassificationId" text, "CreatedDatetime" timestamp with time zone, "CreatedBy" text)
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
    FROM "NGC_BusinessUnitQueueClassification" bq
    WHERE bq."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_GetBusinessUnitSupergroupTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetBusinessUnitSupergroupTable"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitId" integer, "SupergroupId" integer, "TenantId" uuid, "CreatedDatetime" timestamp with time zone, "CreatedBy" text)
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
    FROM "NGC_BusinessUnitSupergroup" bs
    WHERE bs."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_GetBusinessUnitTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetBusinessUnitTable"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitId" integer, "TenantId" uuid, "BusinessUnitName" text, "Description" text, "CreatedDatetime" timestamp with time zone, "CreatedBy" text, "SiteId" text)
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
    WHERE bu."TenantId" = p_tenant_id
    ORDER BY bu."BusinessUnitId";
END;
$$;

--
-- Name: NGC_GetCellsByDataGrid(integer); Type: FUNCTION; Schema: public; Owner: -
--

-- R0b fix (2026-06-21): Removed dead RTSGrid_TemplateCell JOIN (42P01 on fresh rebuild)
CREATE FUNCTION public."NGC_GetCellsByDataGrid"(p_grid_id integer) RETURNS TABLE("CellID" integer, "ColumnId" integer, "RowNumber" integer, "RowId" integer, "CssStyleID" integer, "GridStyleId" integer, "RowStyleId" integer, "CellType" text, "Value" text, "Tooltip" text, "OnClick" text)
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
        ''::text AS "Tooltip",
        ''::text AS "OnClick"
    FROM "RTSGrid_Cell" c
    JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
    JOIN "RTSGrid_Grid" g ON r."GridId" = g."GridId"
    LEFT JOIN "RTSGrid_Column" o ON c."ColumnId" = o."ColumnId"
    WHERE g."GridId" = p_grid_id;
END;
$$;

--
-- Name: NGC_GetDataGrid(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetDataGrid"(p_grid_id integer) RETURNS TABLE("Title" text, "BusinessUnitID" integer, "CssStyleID" integer, "ThresholdID" integer, "ThresholdScript" text, "IsToggle" boolean, "ToggleDefault" boolean)
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

--
-- Name: NGC_GetOrCreateAgentGroup(text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_GetOrCreateAgentGroup"(IN p_external_id text, IN p_name text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_AgentGroups" ("Id", "ExternalId", "Name", "IsActive", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END;
$$;

--
-- Name: NGC_GetOrCreateQueue(text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_GetOrCreateQueue"(IN p_external_id text, IN p_name text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_Queues" ("Id", "ExternalId", "Name", "IsActive", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END;
$$;

--
-- Name: NGC_GetSiteTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetSiteTable"(p_tenant_id uuid) RETURNS TABLE("SiteId" text, "TenantId" uuid, "SiteName" text, "Description" text, "TimeZone" text, "ClearTime" text)
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
    FROM "NGC_Site" s
    WHERE s."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_GetSupergroupAgentgroupTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetSupergroupAgentgroupTable"(p_tenant_id uuid) RETURNS TABLE("Id" integer, "SupergroupId" integer, "AgentgroupId" text, "TenantId" uuid, "CreatedDatetime" timestamp with time zone, "CreatedBy" text)
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
    FROM "NGC_SupergroupAgentgroup" sa
    WHERE sa."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_GetSupergroupIdByName(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetSupergroupIdByName"(p_name text, p_tenant_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id integer;
BEGIN
    SELECT "SupergroupId" INTO v_id
    FROM "NGC_Supergroup"
    WHERE "SupergroupName" = p_name
      AND "TenantId" = p_tenant_id
    LIMIT 1;
    RETURN v_id;
END;
$$;

--
-- Name: NGC_GetSupergroupTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetSupergroupTable"(p_tenant_id uuid) RETURNS TABLE("SupergroupId" integer, "TenantId" uuid, "SupergroupName" text, "Description" text, "CreatedDatetime" timestamp with time zone, "CreatedBy" text, "SupergroupIdOld" integer)
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
    WHERE sg."TenantId" = p_tenant_id
    ORDER BY sg."SupergroupId";
END;
$$;

--
-- Name: NGC_ModifyBusinessUnit(integer, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_ModifyBusinessUnit"(IN p_business_unit_id integer, IN p_business_unit_name text, IN p_description text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE "NGC_BusinessUnit"
    SET "BusinessUnitName" = p_business_unit_name,
        "Description" = p_description
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_ModifySupergroup(integer, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_ModifySupergroup"(IN p_supergroup_id integer, IN p_supergroup_name text, IN p_description text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE "NGC_Supergroup"
    SET "SupergroupName" = p_supergroup_name,
        "Description" = p_description
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

--
-- Name: NGC_SetUserAgentgroup(text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_SetUserAgentgroup"(IN p_user_id text, IN p_agentgroup_id text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_UserAgentgroup" ("UserId", "AgentgroupId", "CreatedDatetime", "TenantId")
    VALUES (p_user_id, p_agentgroup_id, NOW(), p_tenant_id)
    ON CONFLICT ("TenantId", "UserId", "AgentgroupId") DO NOTHING;
END;
$$;

--
-- Name: RTSData_MidnightClear(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_MidnightClear"(p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "RTSData_Interaction" WHERE "TenantId" = p_tenant_id;
    DELETE FROM "RTSData_UserStatus" WHERE "TenantId" = p_tenant_id;
END; $$;

--
-- Name: RTSData_SetChatMessage(text, text, integer, text, text, text, text, text, text, text, timestamp with time zone, text, timestamp with time zone, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."RTSData_SetChatMessage"(IN p_message_id text, IN p_interaction_id text, IN p_segment_id integer, IN p_user_id text, IN p_msg_direction text, IN p_sender text, IN p_recipient text, IN p_body text, IN p_delivery_status text, IN p_server_id text, IN p_update_time timestamp with time zone, IN p_on_date text, IN p_time_stamp timestamp with time zone, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
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

--
-- Name: RTSData_SetInteraction(text, integer, text, text, text, text, text, text, text, text, boolean, boolean, boolean, boolean, boolean, boolean, double precision, double precision, timestamp with time zone, timestamp with time zone, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, boolean, text, text, timestamp with time zone, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."RTSData_SetInteraction"(IN p_interaction_id text, IN p_segment integer, IN p_workgroup text, IN p_classification_code text, IN p_interaction_type text, IN p_call_type text, IN p_direction text, IN p_custom_call_data text, IN p_remote_address text, IN p_user_id text, IN p_is_transferred boolean, IN p_is_answered boolean, IN p_is_in_queue boolean, IN p_is_talk boolean, IN p_is_abandoned boolean, IN p_is_messaging boolean, IN p_time_in_queue double precision, IN p_talk_time double precision, IN p_in_queue_date_time timestamp with time zone, IN p_answered_date_time timestamp with time zone, IN p_last_user_id text, IN p_last_workgroup text, IN p_custom_call_data1 text, IN p_custom_call_data2 text, IN p_custom_call_data3 text, IN p_custom_call_data4 text, IN p_custom_call_data5 text, IN p_custom_call_data6 text, IN p_custom_call_data7 text, IN p_custom_call_data8 text, IN p_custom_call_data9 text, IN p_custom_call_data10 text, IN p_custom_call_data11 text, IN p_custom_call_data12 text, IN p_custom_call_data13 text, IN p_custom_call_data14 text, IN p_custom_call_data15 text, IN p_custom_call_data16 text, IN p_custom_call_data17 text, IN p_custom_call_data18 text, IN p_custom_call_data19 text, IN p_custom_call_data20 text, IN p_is_callback_request boolean, IN p_time_zone text, IN p_server_id text, IN p_update_time timestamp with time zone, IN p_on_date text, IN p_tenant_id uuid)
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

--
-- Name: RTSData_SetUserStatus(text, text, text, text, text, text, double precision, double precision, integer, text, timestamp with time zone, timestamp with time zone, text, timestamp with time zone, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."RTSData_SetUserStatus"(IN p_user_id text, IN p_status_id text, IN p_server_id text, IN p_on_date text, IN p_status_name text, IN p_status_group text, IN p_total_duration double precision, IN p_max_duration double precision, IN p_total_count integer, IN p_display_name text, IN p_start_time timestamp with time zone, IN p_end_time timestamp with time zone, IN p_time_zone text, IN p_update_time timestamp with time zone, IN p_tenant_id uuid)
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

--
-- Name: RTSGrid_GetAllMetrics(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetAllMetrics"() RETURNS TABLE("MetricId" text, "Description" text, "DataType" text, "MetricFunction" text, "MetricParameter" text, "MetricFormat" text, "DefaultValue" text)
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

--
-- Name: RTSGrid_GetAllStatistics(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetAllStatistics"() RETURNS TABLE("StatisticId" integer, "Category" text, "Definition" text, "ParamType1" text, "ParamValue1" text, "ParamType2" text, "ParamValue2" text, "ParamType3" text, "ParamValue3" text, "ParamType4" text, "ParamValue4" text, "ParamType5" text, "ParamValue5" text, "ParamType6" text, "ParamValue6" text, "ParamType7" text, "ParamValue7" text, "ParamType8" text, "ParamValue8" text, "ParamType9" text, "ParamValue9" text, "ParamType10" text, "ParamValue10" text)
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

--
-- Name: RTSGrid_GetAllUnionQueueClassifications(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetAllUnionQueueClassifications"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitID" integer, "QueueID" text, "ClassificationID" text, "TimeZone" text, "ClearTime" text)
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
      AND b."SiteId" = s."SiteId"
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND s."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: RTSGrid_GetAllUnionUserGroups(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetAllUnionUserGroups"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitID" integer, "SupergroupID" integer, "AgentgroupID" text, "TimeZone" text, "ClearTime" text)
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
      AND b."SiteId" = t."SiteId"
      AND s."TenantId" = p_tenant_id
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND t."TenantId" = p_tenant_id;
END;
$$;

--
-- Name: RTSGrid_GetDataCells(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetDataCells"() RETURNS TABLE("CellId" integer, "CellType" text, "GridId" integer, "ColumnId" integer, "RowId" integer, "UnionId" integer, "GridUnionId" integer, "RowUnionId" integer, "Metric" text, "ColumnMetric" text)
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
        g."UnionId"  AS "GridUnionId",
        r."UnionId"  AS "RowUnionId",
        c."Value"::text  AS "Metric",
        NULL::text   AS "ColumnMetric"
    FROM "RTSGrid_Grid" g
    JOIN "RTSGrid_Row"  r ON r."GridId"    = g."GridId"
    JOIN "RTSGrid_Cell" c ON c."RowId"     = r."RowId"
    JOIN "RTSGrid_Column" o ON o."ColumnId" = c."ColumnId"
    WHERE c."CellType" = 'Data';
END;
$$;

--
-- Name: RTSGrid_GetStatisticCells(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetStatisticCells"() RETURNS TABLE("CellId" integer, "GridId" integer, "Title" text)
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

--
-- Name: RTSGrid_GetUnionUsersMetrics(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSGrid_GetUnionUsersMetrics"() RETURNS TABLE("UnionId" integer, "MetricId" text)
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

--
-- Name: RTSUserGrid_GetAllGrids(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSUserGrid_GetAllGrids"() RETURNS TABLE("GridId" integer, "UnionId" integer, "CSS" integer, "Title" text, "RowsFilterNew" text, "PageSize" integer, "ThresholdScript" text)
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

--
-- Name: RTSUserView_GetHTMLSettings(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSUserView_GetHTMLSettings"() RETURNS TABLE("SettingValue" text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- STUB: Original SP reads from DNN ModuleSettings (portal CMS table).
    -- DNN is not migrated to PostgreSQL. Returns empty result set.
    -- TODO: Replace with appsettings.json config read in C# (OQ-01).
    RETURN;
END;
$$;

--
-- Name: fn_daytrendagentstatus(uuid, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_daytrendagentstatus(p_tenantid uuid, p_ondate character varying, p_businessunitid integer, p_intervalmin integer) RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
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

--
-- Name: fn_daytrendinteractions(uuid, character varying, text[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_daytrendinteractions(p_tenantid uuid, p_ondate character varying, p_queuelist text[], p_intervalmin integer) RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
    LANGUAGE sql STABLE
    AS $$
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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
--
--
--
--

--
--
--
--

--
--
--
--
--
--
--
-- Name: NGC_AgentGroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_AgentGroups" (
    "Id" uuid CONSTRAINT "ngc_AgentGroups_Id_not_null" NOT NULL,
    "TenantId" uuid CONSTRAINT "ngc_AgentGroups_TenantId_not_null" NOT NULL,
    "ExternalId" character varying(100) CONSTRAINT "ngc_AgentGroups_ExternalId_not_null" NOT NULL,
    "Name" character varying(200) CONSTRAINT "ngc_AgentGroups_Name_not_null" NOT NULL,
    "IsActive" boolean CONSTRAINT "ngc_AgentGroups_IsActive_not_null" NOT NULL
);

--
-- Name: NGC_BusinessUnit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_BusinessUnit" (
    "BusinessUnitId" integer NOT NULL,
    "TenantId" uuid NOT NULL,
    "BusinessUnitName" character varying(100),
    "Description" text,
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100),
    "SiteId" character varying(50)
);

--
-- Name: NGC_BusinessUnitQueueClassification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_BusinessUnitQueueClassification" (
    "BusinessUnitId" integer NOT NULL,
    "QueueId" character varying(100) NOT NULL,
    "TenantId" uuid NOT NULL,
    "ClassificationId" character varying(100),
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100)
);

--
-- Name: NGC_BusinessUnitSupergroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_BusinessUnitSupergroup" (
    "BusinessUnitId" integer NOT NULL,
    "SupergroupId" integer NOT NULL,
    "TenantId" uuid NOT NULL,
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100)
);

--
-- Name: NGC_BusinessUnit_BusinessUnitId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."NGC_BusinessUnit" ALTER COLUMN "BusinessUnitId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."NGC_BusinessUnit_BusinessUnitId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: NGC_Queues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_Queues" (
    "Id" uuid CONSTRAINT "ngc_queues_Id_not_null" NOT NULL,
    "TenantId" uuid CONSTRAINT "ngc_queues_TenantId_not_null" NOT NULL,
    "ExternalId" character varying(100) CONSTRAINT "ngc_queues_ExternalId_not_null" NOT NULL,
    "Name" character varying(200) CONSTRAINT "ngc_queues_Name_not_null" NOT NULL,
    "IsActive" boolean CONSTRAINT "ngc_queues_IsActive_not_null" NOT NULL
);

--
-- Name: NGC_Site; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_Site" (
    "SiteId" character varying(50) CONSTRAINT "ngc_site_SiteId_not_null" NOT NULL,
    "TenantId" uuid CONSTRAINT "ngc_site_TenantId_not_null" NOT NULL,
    "SiteName" character varying(200),
    "Description" character varying(500),
    "TimeZone" character varying(10),
    "ClearTime" character varying(5)
);

--
-- Name: NGC_Supergroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_Supergroup" (
    "SupergroupId" integer CONSTRAINT "ngc_supergroup_SupergroupId_not_null" NOT NULL,
    "TenantId" uuid CONSTRAINT "ngc_supergroup_TenantId_not_null" NOT NULL,
    "SupergroupName" character varying(200),
    "Description" character varying(500),
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100),
    "SupergroupIdOld" integer
);

--
-- Name: NGC_SupergroupAgentgroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_SupergroupAgentgroup" (
    "Id" integer NOT NULL,
    "SupergroupId" integer,
    "AgentgroupId" character varying(100),
    "TenantId" uuid NOT NULL,
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100)
);

--
-- Name: NGC_SupergroupAgentgroup_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."NGC_SupergroupAgentgroup" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."NGC_SupergroupAgentgroup_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: NGC_UserAgentgroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_UserAgentgroup" (
    "Id" integer NOT NULL,
    "UserId" character varying(100),
    "AgentgroupId" character varying(100),
    "TenantId" uuid NOT NULL,
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy" character varying(100)
);

--
-- Name: NGC_UserAgentgroup_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."NGC_UserAgentgroup" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."NGC_UserAgentgroup_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSData_ChatMessage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSData_ChatMessage" (
    "MessageId" character varying(100) NOT NULL,
    "ServerId" character varying(50) NOT NULL,
    "OnDate" character varying(50) NOT NULL,
    "InteractionId" character varying(100),
    "SegmentId" integer,
    "UserId" character varying(100),
    "MsgDirection" character varying(50),
    "Sender" character varying(200),
    "Recipient" character varying(200),
    "Body" text,
    "DeliveryStatus" character varying(50),
    "UpdateTime" timestamp with time zone,
    "TimeStamp" timestamp with time zone
);

--
-- Name: RTSData_Interaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSData_Interaction" (
    "TenantId" uuid,
    "InteractionId" character varying(50) NOT NULL,
    "Segment" integer NOT NULL,
    "OnDate" character varying(50) NOT NULL,
    "ServerId" character varying(50) NOT NULL,
    "Workgroup" character varying(100) NOT NULL,
    "UserId" character varying(50) DEFAULT ''::character varying NOT NULL,
    "ClassificationCode" text,
    "InteractionType" character varying(50),
    "CallType" character varying(50),
    "Direction" character varying(50),
    "CustomCallData" text,
    "IsTransferred" boolean,
    "IsAnswered" boolean,
    "IsInQueue" boolean,
    "IsTalk" boolean,
    "IsAbandoned" boolean,
    "TimeInQueue" integer,
    "TalkTime" integer,
    "InQueueDateTime" timestamp with time zone,
    "AnsweredDateTime" timestamp with time zone,
    "UpdateTime" timestamp with time zone,
    "LastUserId" character varying(50),
    "LastWorkgroup" character varying(100),
    "IsMessaging" boolean,
    "RemoteAddress" character varying(50),
    "IsCallbackRequest" boolean,
    "TimeZone" character varying(10),
    "CustomCallData1" text,
    "CustomCallData2" text,
    "CustomCallData3" text,
    "CustomCallData4" text,
    "CustomCallData5" text,
    "CustomCallData6" text,
    "CustomCallData7" text,
    "CustomCallData8" text,
    "CustomCallData9" text,
    "CustomCallData10" text,
    "CustomCallData11" text,
    "CustomCallData12" text,
    "CustomCallData13" text,
    "CustomCallData14" text,
    "CustomCallData15" text,
    "CustomCallData16" text,
    "CustomCallData17" text,
    "CustomCallData18" text,
    "CustomCallData19" text,
    "CustomCallData20" text
);

--
-- Name: RTSData_UserStatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSData_UserStatus" (
    "TenantId" uuid,
    "UserId" character varying(100) NOT NULL,
    "StatusId" character varying(100) NOT NULL,
    "ServerId" character varying(50) NOT NULL,
    "OnDate" character varying(50) NOT NULL,
    "StatusName" character varying(100),
    "StatusGroup" character varying(100),
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "UpdateTime" timestamp with time zone,
    "DisplayName" character varying(100),
    "TimeZone" character varying(10)
);

--
-- Name: RTSData_UserStatusLog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSData_UserStatusLog" (
    "Id" integer NOT NULL,
    "TenantId" uuid,
    "UserId" character varying(100),
    "StatusId" character varying(100),
    "ServerId" character varying(50),
    "OnDate" character varying(50),
    "StartTime" timestamp with time zone,
    "EndTime" timestamp with time zone,
    "Duration" bigint,
    "UpdateTime" timestamp with time zone,
    "TimeZone" character varying(10),
    "StatusGroup" character varying(50)
);

--
-- Name: RTSData_UserStatusLog_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSData_UserStatusLog" ALTER COLUMN "Id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSData_UserStatusLog_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_Cell; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Cell" (
    "CellId" integer NOT NULL,
    "RowId" integer NOT NULL,
    "ColumnId" integer NOT NULL,
    "ColNumber" integer,
    "UnionId" integer,
    "StyleId" integer,
    "CellType" character varying(50),
    "Value" character varying(500),
    "Tooltip" character varying(500),
    "OnClick" character varying(500),
    "ThresholdSetId" integer,
    "NewRowId" integer,
    "OldRowId" integer
);

--
-- Name: RTSGrid_Cell_CellId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_Cell" ALTER COLUMN "CellId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_Cell_CellId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_Column; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Column" (
    "ColumnId" integer NOT NULL,
    "GridId" integer NOT NULL,
    "ColumnNumber" integer NOT NULL,
    "CellTemplateId" integer
);

--
-- Name: RTSGrid_Column_ColumnId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_Column" ALTER COLUMN "ColumnId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_Column_ColumnId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_Grid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Grid" (
    "GridId" integer NOT NULL,
    "UnionId" integer,
    "StyleId" integer,
    "Title" character varying(100) NOT NULL,
    "ThresholdScript" text
);

--
-- Name: RTSGrid_Grid_GridId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_Grid" ALTER COLUMN "GridId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_Grid_GridId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_Metric; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Metric" (
    "MetricId" character varying(100) CONSTRAINT "rtsgrid_metric_MetricId_not_null" NOT NULL,
    "Description" text,
    "DataType" character varying(50) CONSTRAINT "rtsgrid_metric_DataType_not_null" NOT NULL,
    "MetricFunction" character varying(200) CONSTRAINT "rtsgrid_metric_MetricFunction_not_null" NOT NULL,
    "MetricParameter" character varying(200) CONSTRAINT "rtsgrid_metric_MetricParameter_not_null" NOT NULL,
    "MetricFormat" character varying(100),
    "DefaultValue" character varying(100),
    "ValueType" character varying(20) DEFAULT 'String'::character varying CONSTRAINT "rtsgrid_metric_ValueType_not_null" NOT NULL,
    "MetricType" character varying(20) DEFAULT 'Agent'::character varying CONSTRAINT "rtsgrid_metric_MetricType_not_null" NOT NULL,
    "CatalogCategory" character varying(20),
    "CatalogNotes" text,
    "CatalogStatus" character varying(20),
    "Channel" character varying(20),
    "Comparison" text,
    "DisplayName" character varying(200),
    "Family" character varying(100),
    "LongDescription" text,
    "ShortDescription" character varying(500),
    "StandardKpi" character varying(100),
    "StandardRef" character varying(200),
    "ThresholdSec" integer
);

--
-- Name: RTSGrid_MetricTranslation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_MetricTranslation" (
    "MetricId" character varying(100) NOT NULL,
    "Locale" character varying(10) NOT NULL,
    "DisplayName" character varying(200),
    "ShortDescription" character varying(500),
    "LongDescription" text,
    "Comparison" text
);

--
-- Name: RTSGrid_Row; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Row" (
    "RowId" integer NOT NULL,
    "GridId" integer NOT NULL,
    "RowNumber" integer NOT NULL,
    "UnionId" integer,
    "StyleId" integer,
    "ThresholdScript" text,
    "OldRowId" integer
);

--
-- Name: RTSGrid_Row_RowId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_Row" ALTER COLUMN "RowId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_Row_RowId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_Statistic; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_Statistic" (
    "StatisticId" integer NOT NULL,
    "Category" character varying(100),
    "Definition" character varying(500),
    "ParamType1" character varying(100),
    "ParamValue1" character varying(500),
    "ParamType2" character varying(100),
    "ParamValue2" character varying(500),
    "ParamType3" character varying(100),
    "ParamValue3" character varying(500),
    "ParamType4" character varying(100),
    "ParamValue4" character varying(500),
    "ParamType5" character varying(100),
    "ParamValue5" character varying(500),
    "ParamType6" character varying(100),
    "ParamValue6" character varying(500),
    "ParamType7" character varying(100),
    "ParamValue7" character varying(500),
    "ParamType8" character varying(100),
    "ParamValue8" character varying(500),
    "ParamType9" character varying(100),
    "ParamValue9" character varying(500),
    "ParamType10" character varying(100),
    "ParamValue10" character varying(500)
);

--
-- Name: RTSGrid_Statistic_StatisticId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_Statistic" ALTER COLUMN "StatisticId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_Statistic_StatisticId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSGrid_UserStatus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_UserStatus" (
    "UserId" character varying(100) NOT NULL,
    "StatusId" character varying(100) NOT NULL,
    "StatusName" character varying(100),
    "StatusGroup" character varying(100),
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "SourceServer" character varying(50),
    "OnDate" character varying(50)
);

--
-- Name: RTSUserGrid_Column; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSUserGrid_Column" (
    "ColumnId" integer NOT NULL,
    "ColumnsSetId" integer NOT NULL,
    "Title" character varying(100) NOT NULL,
    "MetricId" character varying(100),
    "StyleId" integer,
    "ColumnsOrder" integer NOT NULL
);

--
-- Name: RTSUserGrid_Column_ColumnId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSUserGrid_Column" ALTER COLUMN "ColumnId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSUserGrid_Column_ColumnId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSUserGrid_ColumnsSet; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSUserGrid_ColumnsSet" (
    "ColumnsSetId" integer NOT NULL,
    "Title" character varying(100) NOT NULL,
    "Description" text,
    "Direction" character varying(10)
);

--
-- Name: RTSUserGrid_ColumnsSet_ColumnsSetId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSUserGrid_ColumnsSet" ALTER COLUMN "ColumnsSetId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSUserGrid_ColumnsSet_ColumnsSetId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: RTSUserGrid_Grid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSUserGrid_Grid" (
    "GridId" integer NOT NULL,
    "UnionId" integer,
    "StyleId" integer,
    "Title" character varying(100) NOT NULL,
    "RowsFilter" character varying(300),
    "PageSize" integer,
    "ColumnsSetId" integer,
    "ThresholdScript" text,
    "RowsFilterNew" character varying(300),
    "NoRecordsText" text,
    "AllowPaging" boolean,
    "AllowScroll" boolean,
    "TextDirection" character varying(5)
);

--
-- Name: RTSUserGrid_Grid_GridId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSUserGrid_Grid" ALTER COLUMN "GridId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."RTSUserGrid_Grid_GridId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
--
--
--
--
--

--
--
-- Name: db_patch_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.db_patch_history (
    migration_name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);

--
--
--
--
--
--
-- Name: metric_deploy_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metric_deploy_log (
    "MetricId" text NOT NULL,
    "DeployedAt" timestamp with time zone NOT NULL,
    "SourceCommit" text
);

--
-- Name: ngc_supergroup_SupergroupId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."NGC_Supergroup" ALTER COLUMN "SupergroupId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."ngc_supergroup_SupergroupId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
--
--
--
--
--
--
--
--
--
--
--
--
--
--

--

--

--

--

--

--

--

--

--

--

--

--

--
-- Name: NGC_BusinessUnit PK_NGC_BusinessUnit; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnit"
    ADD CONSTRAINT "PK_NGC_BusinessUnit" PRIMARY KEY ("BusinessUnitId");

--
-- Name: NGC_BusinessUnitQueueClassification PK_NGC_BusinessUnitQueueClassification; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnitQueueClassification"
    ADD CONSTRAINT "PK_NGC_BusinessUnitQueueClassification" PRIMARY KEY ("BusinessUnitId", "QueueId");

--
-- Name: NGC_BusinessUnitSupergroup PK_NGC_BusinessUnitSupergroup; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnitSupergroup"
    ADD CONSTRAINT "PK_NGC_BusinessUnitSupergroup" PRIMARY KEY ("BusinessUnitId", "SupergroupId");

--
-- Name: NGC_Site PK_NGC_Site; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_Site"
    ADD CONSTRAINT "PK_NGC_Site" PRIMARY KEY ("SiteId");

--
-- Name: NGC_Supergroup PK_NGC_Supergroup; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_Supergroup"
    ADD CONSTRAINT "PK_NGC_Supergroup" PRIMARY KEY ("SupergroupId");

--
-- Name: NGC_SupergroupAgentgroup PK_NGC_SupergroupAgentgroup; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_SupergroupAgentgroup"
    ADD CONSTRAINT "PK_NGC_SupergroupAgentgroup" PRIMARY KEY ("Id");

--
-- Name: NGC_UserAgentgroup PK_NGC_UserAgentgroup; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_UserAgentgroup"
    ADD CONSTRAINT "PK_NGC_UserAgentgroup" PRIMARY KEY ("Id");

--
-- Name: RTSData_ChatMessage PK_RTSData_ChatMessage; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_ChatMessage"
    ADD CONSTRAINT "PK_RTSData_ChatMessage" PRIMARY KEY ("MessageId", "ServerId", "OnDate");

--
-- Name: RTSData_Interaction PK_RTSData_Interaction; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_Interaction"
    ADD CONSTRAINT "PK_RTSData_Interaction" PRIMARY KEY ("InteractionId", "Segment", "OnDate", "ServerId", "Workgroup");

--
-- Name: RTSData_UserStatus PK_RTSData_UserStatus; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_UserStatus"
    ADD CONSTRAINT "PK_RTSData_UserStatus" PRIMARY KEY ("UserId", "StatusId", "ServerId", "OnDate");

--
-- Name: RTSData_UserStatusLog PK_RTSData_UserStatusLog; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_UserStatusLog"
    ADD CONSTRAINT "PK_RTSData_UserStatusLog" PRIMARY KEY ("Id");

--
-- Name: RTSGrid_Cell PK_RTSGrid_Cell; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Cell"
    ADD CONSTRAINT "PK_RTSGrid_Cell" PRIMARY KEY ("CellId");

--
-- Name: RTSGrid_Column PK_RTSGrid_Column; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Column"
    ADD CONSTRAINT "PK_RTSGrid_Column" PRIMARY KEY ("ColumnId");

--
-- Name: RTSGrid_Grid PK_RTSGrid_Grid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Grid"
    ADD CONSTRAINT "PK_RTSGrid_Grid" PRIMARY KEY ("GridId");

--
-- Name: RTSGrid_MetricTranslation PK_RTSGrid_MetricTranslation; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_MetricTranslation"
    ADD CONSTRAINT "PK_RTSGrid_MetricTranslation" PRIMARY KEY ("MetricId", "Locale");

--
-- Name: RTSGrid_Row PK_RTSGrid_Row; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Row"
    ADD CONSTRAINT "PK_RTSGrid_Row" PRIMARY KEY ("RowId");

--
-- Name: RTSGrid_Statistic PK_RTSGrid_Statistic; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Statistic"
    ADD CONSTRAINT "PK_RTSGrid_Statistic" PRIMARY KEY ("StatisticId");

--
-- Name: RTSGrid_UserStatus PK_RTSGrid_UserStatus; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_UserStatus"
    ADD CONSTRAINT "PK_RTSGrid_UserStatus" PRIMARY KEY ("UserId", "StatusId");

--
-- Name: RTSUserGrid_Column PK_RTSUserGrid_Column; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSUserGrid_Column"
    ADD CONSTRAINT "PK_RTSUserGrid_Column" PRIMARY KEY ("ColumnId");

--
-- Name: RTSUserGrid_ColumnsSet PK_RTSUserGrid_ColumnsSet; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSUserGrid_ColumnsSet"
    ADD CONSTRAINT "PK_RTSUserGrid_ColumnsSet" PRIMARY KEY ("ColumnsSetId");

--
-- Name: RTSUserGrid_Grid PK_RTSUserGrid_Grid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSUserGrid_Grid"
    ADD CONSTRAINT "PK_RTSUserGrid_Grid" PRIMARY KEY ("GridId");

--

--

--

--

--

--

--

--

--

--

--

--
-- Name: NGC_AgentGroups PK_ngc_AgentGroups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_AgentGroups"
    ADD CONSTRAINT "PK_ngc_AgentGroups" PRIMARY KEY ("Id");

--
-- Name: NGC_Queues PK_ngc_queues; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_Queues"
    ADD CONSTRAINT "PK_ngc_queues" PRIMARY KEY ("Id");

--

--

--

--

--

--
-- Name: RTSGrid_Metric PK_rtsgrid_metric; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Metric"
    ADD CONSTRAINT "PK_rtsgrid_metric" PRIMARY KEY ("MetricId");

--

--

--

--

--

--

--

--

--

--
-- Name: db_patch_history db_patch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.db_patch_history
    ADD CONSTRAINT db_patch_history_pkey PRIMARY KEY (migration_name);

--
-- Name: metric_deploy_log metric_deploy_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metric_deploy_log
    ADD CONSTRAINT metric_deploy_log_pkey PRIMARY KEY ("MetricId");

--
-- Name: NGC_AgentGroups uq_ngc_agentgroups_external_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_AgentGroups"
    ADD CONSTRAINT uq_ngc_agentgroups_external_tenant UNIQUE ("ExternalId", "TenantId");

--
-- Name: NGC_Queues uq_ngc_queues_external_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_Queues"
    ADD CONSTRAINT uq_ngc_queues_external_tenant UNIQUE ("ExternalId", "TenantId");

--
-- Name: NGC_SupergroupAgentgroup uq_supergroup_agentgroup; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_SupergroupAgentgroup"
    ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId", "AgentgroupId");

--

--

--

--

--

--

--

--

--

--

--

--
-- Name: IX_NGC_BusinessUnitSupergroup_SupergroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_NGC_BusinessUnitSupergroup_SupergroupId" ON public."NGC_BusinessUnitSupergroup" USING btree ("SupergroupId");

--
-- Name: IX_NGC_BusinessUnit_SiteId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_NGC_BusinessUnit_SiteId" ON public."NGC_BusinessUnit" USING btree ("SiteId");

--
-- Name: IX_NGC_SupergroupAgentgroup_SupergroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_NGC_SupergroupAgentgroup_SupergroupId" ON public."NGC_SupergroupAgentgroup" USING btree ("SupergroupId");

--
-- Name: IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId" ON public."NGC_UserAgentgroup" USING btree ("TenantId", "UserId", "AgentgroupId");

--
-- Name: IX_RTSData_ChatMessage_MessageId_ServerId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_RTSData_ChatMessage_MessageId_ServerId" ON public."RTSData_ChatMessage" USING btree ("MessageId", "ServerId");

--
-- Name: IX_RTSData_Interaction_UpsertKey; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_RTSData_Interaction_UpsertKey" ON public."RTSData_Interaction" USING btree ("InteractionId", "Segment", "ServerId");

--
-- Name: IX_RTSData_UserStatusLog_StatusGroup_Time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_RTSData_UserStatusLog_StatusGroup_Time" ON public."RTSData_UserStatusLog" USING btree ("TenantId", "StatusGroup", "StartTime", "EndTime");

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--
-- Name: NGC_BusinessUnitQueueClassification FK_NGC_BusinessUnitQueueClassification_NGC_BusinessUnit_Busine~; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnitQueueClassification"
    ADD CONSTRAINT "FK_NGC_BusinessUnitQueueClassification_NGC_BusinessUnit_Busine~" FOREIGN KEY ("BusinessUnitId") REFERENCES public."NGC_BusinessUnit"("BusinessUnitId") ON DELETE CASCADE;

--
-- Name: NGC_BusinessUnitSupergroup FK_NGC_BusinessUnitSupergroup_NGC_BusinessUnit_BusinessUnitId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnitSupergroup"
    ADD CONSTRAINT "FK_NGC_BusinessUnitSupergroup_NGC_BusinessUnit_BusinessUnitId" FOREIGN KEY ("BusinessUnitId") REFERENCES public."NGC_BusinessUnit"("BusinessUnitId") ON DELETE CASCADE;

--
-- Name: NGC_BusinessUnitSupergroup FK_NGC_BusinessUnitSupergroup_NGC_Supergroup_SupergroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnitSupergroup"
    ADD CONSTRAINT "FK_NGC_BusinessUnitSupergroup_NGC_Supergroup_SupergroupId" FOREIGN KEY ("SupergroupId") REFERENCES public."NGC_Supergroup"("SupergroupId") ON DELETE CASCADE;

--
-- Name: NGC_BusinessUnit FK_NGC_BusinessUnit_NGC_Site_SiteId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnit"
    ADD CONSTRAINT "FK_NGC_BusinessUnit_NGC_Site_SiteId" FOREIGN KEY ("SiteId") REFERENCES public."NGC_Site"("SiteId") ON DELETE SET NULL;

--
-- Name: NGC_SupergroupAgentgroup FK_NGC_SupergroupAgentgroup_NGC_Supergroup_SupergroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_SupergroupAgentgroup"
    ADD CONSTRAINT "FK_NGC_SupergroupAgentgroup_NGC_Supergroup_SupergroupId" FOREIGN KEY ("SupergroupId") REFERENCES public."NGC_Supergroup"("SupergroupId");

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--

--
-- PostgreSQL database dump complete
--
