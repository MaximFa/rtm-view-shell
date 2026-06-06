--
-- PostgreSQL database dump
--

\restrict 9CkMn3S0oWs396CipggFKc2FzmVSEav2h0ACDXpMdifS1FcPN6iyabLrUyOvewx

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
-- Name: audit; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audit;


--
-- Name: identity; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA identity;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


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
-- Name: NGC_CreateBusinessUnitQueueClassificationMapping(integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateBusinessUnitQueueClassificationMapping"(p_business_unit_id integer, p_queue_id text, p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId", "QueueId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
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
-- Name: NGC_CreateBusinessUnitSupergroupMapping(integer, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateBusinessUnitSupergroupMapping"(p_business_unit_id integer, p_supergroup_id integer, p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
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
-- Name: NGC_CreateSupergroupAgentgroupMapping(integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_CreateSupergroupAgentgroupMapping"(p_supergroup_id integer, p_agentgroup_id text, p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, NOW(), p_tenant_id);
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
-- Name: NGC_DeleteBusinessUnitQueueClassificationMapping(integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_DeleteBusinessUnitQueueClassificationMapping"(p_business_unit_id integer, p_queue_id text, p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "QueueId" = p_queue_id
      AND "TenantId" = p_tenant_id;
END;
$$;


--
-- Name: NGC_DeleteBusinessUnitQueueClassificationMapping(integer, text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteBusinessUnitQueueClassificationMapping"(IN p_business_unit_id integer, IN p_queue_id text, IN p_classification_id text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId"   = p_business_unit_id
      AND "QueueId"          = p_queue_id
      AND "TenantId"         = p_tenant_id;
END;
$$;


--
-- Name: NGC_DeleteBusinessUnitSupergroupMapping(integer, integer, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteBusinessUnitSupergroupMapping"(IN p_business_unit_id integer, IN p_supergroup_id integer, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId"   = p_supergroup_id
      AND "TenantId"       = p_tenant_id;
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
      AND "TenantId"     = p_tenant_id;
END;
$$;


--
-- Name: NGC_DeleteSupergroupAgentgroupMapping(integer, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteSupergroupAgentgroupMapping"(IN p_supergroup_id integer, IN p_agentgroup_id text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id
      AND "TenantId"     = p_tenant_id;
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
    WHERE "TenantId"=p_tenant_id AND "UserId"=p_user_id AND "AgentgroupId"=p_agentgroup_id;
END; $$;


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
END; $$;


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
END; $$;


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
        "Description"      = p_description
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId"       = p_tenant_id;
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
        "Description"    = p_description
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId"     = p_tenant_id;
END;
$$;


--
-- Name: NGC_SetUserAgentgroup(text, text, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_SetUserAgentgroup"(IN p_user_id text, IN p_agentgroup_id text, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO "NGC_UserAgentgroup" ("UserId","AgentgroupId","CreatedDatetime","TenantId")
    VALUES (p_user_id, p_agentgroup_id, NOW(), p_tenant_id)
    ON CONFLICT ("TenantId","UserId","AgentgroupId") DO NOTHING;
END; $$;


--
-- Name: RTSData_GetInteractions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_GetInteractions"(p_tenant_id uuid) RETURNS TABLE("TenantId" uuid, "InteractionId" text, "Segment" integer, "OnDate" text, "ServerId" text, "Workgroup" text, "UserId" text, "ClassificationCode" text, "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text, "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp with time zone, "AnsweredDateTime" timestamp with time zone, "UpdateTime" timestamp with time zone, "LastUserId" text, "LastWorkgroup" text, "IsMessaging" boolean, "RemoteAddress" text, "IsCallbackRequest" boolean, "TimeZone" text)
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


--
-- Name: RTSData_GetInteractions(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_GetInteractions"(p_on_date text, p_tenant_id uuid) RETURNS TABLE("InteractionId" text, "Segment" integer, "Workgroup" text, "ClassificationCode" text, "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text, "RemoteAddress" text, "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "IsMessaging" boolean, "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp without time zone, "AnsweredDateTime" timestamp without time zone, "LastUserId" text, "LastWorkgroup" text, "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text, "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text, "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text, "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text, "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text, "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text)
    LANGUAGE sql
    AS $$
    SELECT
        "InteractionId"::text, "Segment", "Workgroup"::text,
        "ClassificationCode"::text, "InteractionType"::text,
        "CallType"::text, "Direction"::text, "CustomCallData"::text,
        "RemoteAddress"::text, "UserId"::text,
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "IsMessaging", "TimeInQueue", "TalkTime",
        ("InQueueDateTime" AT TIME ZONE 'UTC'),
        ("AnsweredDateTime" AT TIME ZONE 'UTC'),
        "LastUserId"::text, "LastWorkgroup"::text,
        "CustomCallData1"::text, "CustomCallData2"::text,
        "CustomCallData3"::text, "CustomCallData4"::text,
        "CustomCallData5"::text, "CustomCallData6"::text,
        "CustomCallData7"::text, "CustomCallData8"::text,
        "CustomCallData9"::text, "CustomCallData10"::text,
        "CustomCallData11"::text, "CustomCallData12"::text,
        "CustomCallData13"::text, "CustomCallData14"::text,
        "CustomCallData15"::text, "CustomCallData16"::text,
        "CustomCallData17"::text, "CustomCallData18"::text,
        "CustomCallData19"::text, "CustomCallData20"::text,
        "IsCallbackRequest", "TimeZone"::text,
        "ServerId"::text, "OnDate"::text
    FROM "RTSData_Interaction"
    WHERE "OnDate" = p_on_date
      AND "TenantId" = p_tenant_id
    ORDER BY "Segment", "UpdateTime" DESC;
$$;


--
-- Name: RTSData_GetUsersStatuses(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_GetUsersStatuses"(p_tenant_id uuid) RETURNS TABLE("TenantId" uuid, "UserId" text, "StatusId" text, "ServerId" text, "OnDate" text, "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "UpdateTime" timestamp with time zone, "DisplayName" text, "TimeZone" text)
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


--
-- Name: RTSData_GetUsersStatuses(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_GetUsersStatuses"(p_on_date text, p_tenant_id uuid) RETURNS TABLE("UserId" text, "StatusId" text, "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "DisplayName" text, "TimeZone" text, "UpdateTime" timestamp without time zone, "ServerId" text)
    LANGUAGE sql
    AS $$
    SELECT
        "UserId"::text, "StatusId"::text, "StatusName"::text,
        "StatusGroup"::text, "TotalDuration", "MaxDuraction",
        "TotalCount", "DisplayName"::text, "TimeZone"::text,
        ("UpdateTime" AT TIME ZONE 'UTC'),
        "ServerId"::text
    FROM "RTSData_UserStatus"
    WHERE "OnDate" = p_on_date
      AND "TenantId" = p_tenant_id
    ORDER BY "UpdateTime" DESC;
$$;


--
-- Name: RTSData_MidnightClear(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_MidnightClear"(p_tenant_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- [RTM-SEC-001] CRITICAL: Must scope DELETE by TenantId to prevent cross-tenant data loss
    DELETE FROM "RTSData_Interaction" WHERE "TenantId" = p_tenant_id;
    DELETE FROM "RTSData_UserStatus" WHERE "TenantId" = p_tenant_id;
    -- RTSData_ChatMessage is intentionally NOT cleared per production behavior
END;
$$;


--
-- Name: RTSData_SetChatMessage(text, text, integer, text, text, text, text, text, text, text, timestamp with time zone, text, timestamp with time zone, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_SetChatMessage"(p_message_id text, p_interaction_id text, p_segment_id integer, p_user_id text, p_msg_direction text, p_sender text, p_recipient text, p_body text, p_delivery_status text, p_server_id text, p_update_time timestamp with time zone, p_on_date text, p_time_stamp timestamp with time zone, p_tenant_id uuid) RETURNS void
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


--
-- Name: RTSData_SetInteraction(text, integer, text, text, text, text, text, text, text, text, text, boolean, boolean, boolean, boolean, boolean, integer, integer, timestamp with time zone, timestamp with time zone, timestamp with time zone, text, text, boolean, text, boolean, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_SetInteraction"(p_interaction_id text, p_segment integer, p_on_date text, p_server_id text, p_workgroup text, p_user_id text, p_classification_code text, p_interaction_type text, p_call_type text, p_direction text, p_custom_call_data text, p_is_transferred boolean, p_is_answered boolean, p_is_in_queue boolean, p_is_talk boolean, p_is_abandoned boolean, p_time_in_queue integer, p_talk_time integer, p_in_queue_date_time timestamp with time zone, p_answered_date_time timestamp with time zone, p_update_time timestamp with time zone, p_last_user_id text, p_last_workgroup text, p_is_messaging boolean, p_remote_address text, p_is_callback_request boolean, p_time_zone text, p_tenant_id uuid) RETURNS void
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
-- Name: RTSData_getInteractions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_getInteractions"(p_tenant_id uuid) RETURNS TABLE("TenantId" uuid, "InteractionId" text, "Segment" integer, "OnDate" text, "ServerId" text, "Workgroup" text, "UserId" text, "ClassificationCode" text, "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text, "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp with time zone, "AnsweredDateTime" timestamp with time zone, "UpdateTime" timestamp with time zone, "LastUserId" text, "LastWorkgroup" text, "IsMessaging" boolean, "RemoteAddress" text, "IsCallbackRequest" boolean, "TimeZone" text)
    LANGUAGE sql
    AS $$ SELECT * FROM "RTSData_GetInteractions"(p_tenant_id); $$;


--
-- Name: RTSData_getInteractions(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_getInteractions"(p_on_date text, p_tenant_id uuid) RETURNS TABLE("InteractionId" text, "Segment" integer, "Workgroup" text, "ClassificationCode" text, "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text, "RemoteAddress" text, "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean, "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "IsMessaging" boolean, "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp without time zone, "AnsweredDateTime" timestamp without time zone, "LastUserId" text, "LastWorkgroup" text, "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text, "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text, "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text, "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text, "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text, "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text)
    LANGUAGE sql
    AS $$
    SELECT * FROM "RTSData_GetInteractions"(p_on_date, p_tenant_id);
$$;


--
-- Name: RTSData_getUsersStatuses(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_getUsersStatuses"(p_tenant_id uuid) RETURNS TABLE("TenantId" uuid, "UserId" text, "StatusId" text, "ServerId" text, "OnDate" text, "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "UpdateTime" timestamp with time zone, "DisplayName" text, "TimeZone" text)
    LANGUAGE sql
    AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_tenant_id); $$;


--
-- Name: RTSData_getUsersStatuses(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."RTSData_getUsersStatuses"(p_on_date text, p_tenant_id uuid) RETURNS TABLE("UserId" text, "StatusId" text, "StatusName" text, "StatusGroup" text, "TotalDuration" integer, "MaxDuraction" integer, "TotalCount" integer, "DisplayName" text, "TimeZone" text, "UpdateTime" timestamp without time zone, "ServerId" text)
    LANGUAGE sql
    AS $$
    SELECT * FROM "RTSData_GetUsersStatuses"(p_on_date, p_tenant_id);
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
-- Name: fn_daytrendagentstatus(uuid, character varying, text[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_daytrendagentstatus(p_tenantid uuid, p_ondate character varying, p_queuelist text[], p_intervalmin integer) RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
    LANGUAGE sql STABLE
    AS $$
    WITH interval_agents AS (
        SELECT
            DATE_TRUNC('hour', "InQueueDateTime") +
                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                 * (p_intervalmin || ' minutes')::interval) AS interval_start,
            "UserId"
        FROM "RTSData_Interaction"
        WHERE "TenantId"  = p_tenantid
          AND "OnDate"    = p_ondate
          AND "Workgroup" = ANY(p_queuelist)
          AND "IsAnswered" = true
          AND "Direction"  = 'Incoming'
          AND "InQueueDateTime" IS NOT NULL
    ),
    agent_pool AS (
        SELECT DISTINCT interval_start, "UserId" FROM interval_agents
    ),
    pool_summary AS (
        SELECT interval_start,
               COUNT(DISTINCT "UserId") AS logged_in_agents
        FROM agent_pool
        GROUP BY interval_start
    ),
    agent_status AS (
        SELECT
            ap.interval_start,
            ap.interval_start + (p_intervalmin || ' minutes')::interval AS interval_end,
            usl."UserId",
            usl."StatusGroup",
            GREATEST(0,
                EXTRACT(EPOCH FROM (
                    LEAST(
                        COALESCE(usl."EndTime",
                                 ap.interval_start + (p_intervalmin || ' minutes')::interval),
                        ap.interval_start + (p_intervalmin || ' minutes')::interval
                    )
                    - GREATEST(usl."StartTime", ap.interval_start)
                ))::bigint * 1000
            ) AS overlap_ms
        FROM agent_pool ap
        JOIN "RTSData_UserStatusLog" usl ON usl."UserId" = ap."UserId"
        WHERE usl."TenantId"    = p_tenantid
          AND usl."OnDate"      = p_ondate
          AND usl."StatusGroup" IS NOT NULL
          AND usl."StartTime"   < ap.interval_start
                                   + (p_intervalmin || ' minutes')::interval
          AND (usl."EndTime" IS NULL OR usl."EndTime" > ap.interval_start)
    ),
    status_summary AS (
        SELECT
            interval_start,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'AVAILABLE') AS available_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'ONPHONE')   AS onphone_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'BREAK')     AS break_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'PAPERWORK') AS paperwork_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'TRAINING')  AS training_agents,
            COUNT(DISTINCT "UserId")                                             AS total_agents,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'AVAILABLE'),  0) AS available_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'ONPHONE'),    0) AS onphone_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'BREAK'),      0) AS break_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'PAPERWORK'),  0) AS paperwork_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'TRAINING'),   0) AS training_time_ms,
            COALESCE(SUM(overlap_ms),                                              0) AS total_active_time_ms
        FROM agent_status
        GROUP BY interval_start
    )
    SELECT ps.interval_start, 'statuslog.logged_in_agents',    ps.logged_in_agents::double precision    FROM pool_summary ps
    UNION ALL
    SELECT ss.interval_start, 'statuslog.available_agents',    ss.available_agents::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.onphone_agents',      ss.onphone_agents::double precision      FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.break_agents',        ss.break_agents::double precision        FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.paperwork_agents',    ss.paperwork_agents::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.training_agents',     ss.training_agents::double precision     FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.total_agents',        ss.total_agents::double precision        FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.available_time_ms',   ss.available_time_ms::double precision   FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.onphone_time_ms',     ss.onphone_time_ms::double precision     FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.break_time_ms',       ss.break_time_ms::double precision       FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.paperwork_time_ms',   ss.paperwork_time_ms::double precision   FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.training_time_ms',    ss.training_time_ms::double precision    FROM status_summary ss
    UNION ALL
    SELECT ss.interval_start, 'statuslog.total_active_time_ms',ss.total_active_time_ms::double precision FROM status_summary ss
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
-- Name: audit_logs; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_logs (
    "Id" uuid NOT NULL,
    "TenantId" uuid,
    "UserId" uuid,
    "UserName" character varying(256) NOT NULL,
    "EventType" character varying(64) NOT NULL,
    "EventResult" character varying(16) NOT NULL,
    "IpAddress" text,
    "UserAgent" text,
    "Details" jsonb,
    "CreatedAt" timestamp with time zone NOT NULL
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.refresh_tokens (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Jti" uuid NOT NULL,
    "TokenHash" character varying(64) NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "IssuedAt" timestamp with time zone NOT NULL,
    "RevokedAt" timestamp with time zone,
    "ReplacedByTokenId" uuid,
    "IpAddress" text NOT NULL,
    "UserAgent" text NOT NULL
);


--
-- Name: role_claims; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.role_claims (
    "Id" integer NOT NULL,
    "RoleId" uuid NOT NULL,
    "ClaimType" text,
    "ClaimValue" text
);


--
-- Name: role_claims_Id_seq; Type: SEQUENCE; Schema: identity; Owner: -
--

ALTER TABLE identity.role_claims ALTER COLUMN "Id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME identity."role_claims_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: roles; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.roles (
    "Id" uuid NOT NULL,
    "Name" character varying(256),
    "NormalizedName" character varying(256),
    "ConcurrencyStamp" text
);


--
-- Name: two_factor_codes; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.two_factor_codes (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "CodeHash" character varying(64) NOT NULL,
    "Salt" character varying(32) NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "AttemptCount" integer NOT NULL,
    "ConsumedAt" timestamp with time zone
);


--
-- Name: user_claims; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_claims (
    "Id" integer NOT NULL,
    "UserId" uuid NOT NULL,
    "ClaimType" text,
    "ClaimValue" text
);


--
-- Name: user_claims_Id_seq; Type: SEQUENCE; Schema: identity; Owner: -
--

ALTER TABLE identity.user_claims ALTER COLUMN "Id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME identity."user_claims_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_logins; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_logins (
    "LoginProvider" text NOT NULL,
    "ProviderKey" text NOT NULL,
    "ProviderDisplayName" text,
    "UserId" uuid NOT NULL
);


--
-- Name: user_password_history; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_password_history (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "PasswordHash" text NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_roles (
    "UserId" uuid NOT NULL,
    "RoleId" uuid NOT NULL
);


--
-- Name: user_sessions; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_sessions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "ExpiresAt" timestamp with time zone NOT NULL,
    "IpAddress" character varying(45),
    "UserAgent" character varying(500),
    "IsRevoked" boolean NOT NULL
);


--
-- Name: user_tokens; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.user_tokens (
    "UserId" uuid NOT NULL,
    "LoginProvider" text NOT NULL,
    "Name" text NOT NULL,
    "Value" text
);


--
-- Name: users; Type: TABLE; Schema: identity; Owner: -
--

CREATE TABLE identity.users (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "FirstName" character varying(100) NOT NULL,
    "LastName" character varying(100) NOT NULL,
    "PermissionGroupId" uuid,
    "IsActive" boolean NOT NULL,
    "Is2faEnabled" boolean NOT NULL,
    "LastLoginAt" timestamp with time zone,
    "PreferredLocale" character varying(10) DEFAULT 'en-US'::character varying NOT NULL,
    "MustChangePasswordAt" timestamp with time zone,
    "UserName" character varying(256),
    "NormalizedUserName" character varying(256),
    "Email" character varying(256),
    "NormalizedEmail" character varying(256),
    "EmailConfirmed" boolean NOT NULL,
    "PasswordHash" text,
    "SecurityStamp" text,
    "ConcurrencyStamp" text,
    "PhoneNumber" text,
    "PhoneNumberConfirmed" boolean NOT NULL,
    "TwoFactorEnabled" boolean NOT NULL,
    "LockoutEnd" timestamp with time zone,
    "LockoutEnabled" boolean NOT NULL,
    "AccessFailedCount" integer NOT NULL
);


--
-- Name: AuditEvents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."AuditEvents" (
    "Id" uuid NOT NULL,
    "UserId" uuid,
    "EventType" character varying(64) NOT NULL,
    "IpAddress" character varying(45) NOT NULL,
    "UserAgent" character varying(512) NOT NULL,
    "Detail" character varying(2000),
    "OccurredAt" timestamp with time zone NOT NULL
);


--
-- Name: NGC_AgentGroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_AgentGroups" (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "ExternalId" character varying(100) NOT NULL,
    "Name" character varying(200) NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedDatetime" timestamp with time zone DEFAULT now()
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
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "ExternalId" character varying(100) NOT NULL,
    "Name" character varying(200) NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedDatetime" timestamp with time zone DEFAULT now()
);


--
-- Name: NGC_Site; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_Site" (
    "SiteId" character varying(50) NOT NULL,
    "TenantId" uuid NOT NULL,
    "SiteName" character varying(200),
    "Description" character varying(500),
    "TimeZone" character varying(10),
    "ClearTime" character varying(5)
);


--
-- Name: NGC_Supergroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_Supergroup" (
    "SupergroupId" integer NOT NULL,
    "TenantId" uuid NOT NULL,
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
-- Name: NGC_Supergroup_SupergroupId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."NGC_Supergroup" ALTER COLUMN "SupergroupId" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public."NGC_Supergroup_SupergroupId_seq"
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
-- Name: PermissionGroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."PermissionGroups" (
    "Id" uuid NOT NULL,
    "Name" character varying(256) NOT NULL,
    "Description" character varying(1000) NOT NULL,
    "MenuPermissions" text[] NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
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
    "UserId" character varying(50) NOT NULL,
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
    "CustomCallData20" text,
    "IsCallbackRequest" boolean,
    "TimeZone" character varying(10)
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
    "Duration" integer,
    "UpdateTime" timestamp with time zone,
    "TimeZone" character varying(10),
    "StatusGroup" character varying(50)
);


--
-- Name: RTSData_UserStatusLog_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."RTSData_UserStatusLog_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: RTSData_UserStatusLog_Id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."RTSData_UserStatusLog_Id_seq" OWNED BY public."RTSData_UserStatusLog"."Id";


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
    "MetricId" character varying(100) NOT NULL,
    "Description" text,
    "DataType" character varying(50) NOT NULL,
    "MetricFunction" character varying(200) NOT NULL,
    "MetricParameter" character varying(200) NOT NULL,
    "MetricFormat" character varying(100),
    "DefaultValue" character varying(100),
    "ValueType" character varying(20) DEFAULT 'String'::character varying NOT NULL,
    "MetricType" character varying(20) DEFAULT 'Agent'::character varying NOT NULL,
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
-- Name: RTSGrid_TemplateCell; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."RTSGrid_TemplateCell" (
    "CellTemplateId" integer NOT NULL,
    "StyleId" integer,
    "CellType" character varying(50),
    "Value" character varying(500),
    "Tooltip" character varying(500),
    "OnClick" character varying(500)
);


--
-- Name: RTSGrid_TemplateCell_CellTemplateId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."RTSGrid_TemplateCell" ALTER COLUMN "CellTemplateId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."RTSGrid_TemplateCell_CellTemplateId_seq"
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
-- Name: ResourcePermissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ResourcePermissions" (
    "Id" uuid NOT NULL,
    "GroupId" uuid NOT NULL,
    "ResourceType" character varying(32) NOT NULL,
    "ResourceId" character varying(256) NOT NULL,
    "CanView" boolean NOT NULL
);


--
-- Name: ScreenPermissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ScreenPermissions" (
    "ScreenId" uuid NOT NULL,
    "GroupId" uuid NOT NULL,
    "CanView" boolean NOT NULL,
    "CanEdit" boolean NOT NULL,
    "CanDelete" boolean NOT NULL
);


--
-- Name: Screens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Screens" (
    "Id" uuid NOT NULL,
    "Name" character varying(256) NOT NULL,
    "OwnerId" uuid NOT NULL,
    "OwnerGroupId" uuid,
    "Status" character varying(32) DEFAULT 'Draft'::character varying NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: UserGroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."UserGroups" (
    "UserId" uuid NOT NULL,
    "GroupId" uuid NOT NULL
);


--
-- Name: Users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Users" (
    "Id" uuid NOT NULL,
    "Email" character varying(256) NOT NULL,
    "DisplayName" character varying(256) NOT NULL,
    "PasswordHash" character varying(1024) NOT NULL,
    "IsSsoUser" boolean NOT NULL,
    "TwoFactorEnabled" boolean NOT NULL,
    "TwoFactorSecret" character varying(512),
    "TwoFactorSecretExpiry" timestamp with time zone,
    "IsActive" boolean DEFAULT true NOT NULL,
    "AccessFailedCount" integer NOT NULL,
    "LockoutEnd" timestamp with time zone,
    "LastLoginAt" timestamp with time zone,
    "CreatedAt" timestamp with time zone NOT NULL
);


--
-- Name: WidgetSlots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."WidgetSlots" (
    "Id" uuid NOT NULL,
    "ScreenId" uuid NOT NULL,
    "CategoryId" character varying(256) NOT NULL,
    "WidgetTypeId" character varying(256) NOT NULL
);


--
-- Name: __BackendEmulationMigrationsHistory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."__BackendEmulationMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL
);


--
-- Name: __EFMigrationsHistory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL
);


--
-- Name: __ef_migrations_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.__ef_migrations_history (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL
);


--
-- Name: dashboard_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_categories (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Description" character varying(500),
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedByUserId" uuid NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "UpdatedByUserId" uuid NOT NULL
);


--
-- Name: dashboard_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_permissions (
    "PermissionGroupId" uuid NOT NULL,
    "DashboardId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "AccessLevel" integer NOT NULL
);


--
-- Name: dashboard_widgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_widgets (
    "Id" uuid NOT NULL,
    "DashboardId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "WidgetCatalogItemId" uuid NOT NULL,
    "IsDeleted" boolean NOT NULL,
    "PositionJson" jsonb,
    "ConfigJson" jsonb,
    "GridId" integer NOT NULL
);


--
-- Name: dashboard_widgets_GridId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dashboard_widgets ALTER COLUMN "GridId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."dashboard_widgets_GridId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboards (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Description" text,
    "Status" character varying(20) NOT NULL,
    "IsPublic" boolean NOT NULL,
    "CreatedByUserId" uuid NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "UpdatedByUserId" uuid NOT NULL,
    "IsDeleted" boolean NOT NULL,
    "DeletedAt" timestamp with time zone,
    "DeletedByUserId" uuid,
    "LayoutJson" jsonb,
    "CategoryId" uuid,
    "IsDarkMode" boolean DEFAULT false NOT NULL
);


--
-- Name: history_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.history_metrics (
    "MetricId" character varying(100) NOT NULL,
    "Description" character varying(200) NOT NULL,
    "DataType" character varying(20) NOT NULL,
    "MetricFunction" character varying(50) NOT NULL,
    "MetricParameter" character varying(200) NOT NULL,
    "MetricFormat" character varying(20) NOT NULL,
    "DefaultValue" character varying(20) NOT NULL,
    "ValueType" character varying(20) NOT NULL,
    "MetricType" character varying(50) NOT NULL
);


--
-- Name: info_slot_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.info_slot_messages (
    "Id" uuid NOT NULL,
    "InfoSlotId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Content" text NOT NULL,
    "Priority" character varying(10) NOT NULL,
    "ExpiresAt" timestamp with time zone,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedByUserId" uuid NOT NULL,
    "DeactivatedAt" timestamp with time zone,
    "DeactivatedByUserId" uuid
);


--
-- Name: info_slot_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.info_slot_permissions (
    "InfoSlotId" uuid NOT NULL,
    "PermissionGroupId" uuid NOT NULL,
    "TenantId" uuid NOT NULL
);


--
-- Name: info_slots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.info_slots (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Description" character varying(500),
    "DisplayMode" character varying(20) NOT NULL,
    "SecondsPerMessage" integer NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedByUserId" uuid NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "UpdatedByUserId" uuid NOT NULL
);


--
-- Name: menu_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_permissions (
    "PermissionGroupId" uuid NOT NULL,
    "MenuKey" character varying(100) NOT NULL,
    "TenantId" uuid NOT NULL
);


--
-- Name: permission_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_groups (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Description" text,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "CreatedByUserId" uuid NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL,
    "UpdatedByUserId" uuid NOT NULL
);


--
-- Name: pg_business_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_business_units (
    "PermissionGroupId" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "BusinessUnitId" integer DEFAULT 0 NOT NULL
);


--
-- Name: pg_queues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_queues (
    "PermissionGroupId" uuid NOT NULL,
    "ObjectId" uuid NOT NULL,
    "TenantId" uuid NOT NULL
);


--
-- Name: pg_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_skills (
    "PermissionGroupId" uuid NOT NULL,
    "ObjectId" uuid NOT NULL,
    "TenantId" uuid NOT NULL
);


--
-- Name: pg_supergroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pg_supergroups (
    "PermissionGroupId" uuid NOT NULL,
    "SupergroupId" integer NOT NULL,
    "TenantId" uuid NOT NULL
);


--
-- Name: sso_configurations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sso_configurations (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Provider" character varying(20) NOT NULL,
    "MetadataUrl" text,
    "ClientId" text,
    "ClientSecret" text,
    "ClaimMappings" jsonb NOT NULL,
    "IsActive" boolean NOT NULL
);


--
-- Name: tenant_agent_state_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_agent_state_definitions (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "AgentStateId" uuid NOT NULL,
    "AgentStateGroupId" uuid NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: tenant_agent_state_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_agent_state_groups (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "GroupName" character varying(100) NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: tenant_agent_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_agent_states (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "AgentState" character varying(100) NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: tenant_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_settings (
    "TenantId" uuid NOT NULL,
    "PasswordMinLength" integer NOT NULL,
    "PasswordExpireDays" integer NOT NULL,
    "Require2faForAll" boolean NOT NULL,
    "AuditRetentionDays" integer NOT NULL,
    "DefaultLocale" text NOT NULL,
    "SoftDeleteDashboards" boolean NOT NULL,
    "SoftDeleteRetentionDays" integer NOT NULL,
    "EmailProviderConfig" text,
    "SsoConfigurationId" uuid,
    "MaxConcurrentConnections" integer DEFAULT 0 NOT NULL,
    "PurchasedLicences" integer DEFAULT 0 NOT NULL,
    "SignalRConnectionUrl" text,
    "BackgroundColorPalette" text,
    "FontColorPalette" text,
    "FontSizes" text
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    "Id" uuid NOT NULL,
    "Slug" character varying(100) NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Status" character varying(20) NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: user_widget_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_widget_settings (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "WidgetId" uuid NOT NULL,
    "SettingsJson" jsonb NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone NOT NULL
);


--
-- Name: widget_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.widget_catalog (
    "Id" uuid NOT NULL,
    "Category" character varying(100) NOT NULL,
    "Name" character varying(200) NOT NULL,
    "Description" text,
    "IconUrl" text,
    "IsActive" boolean NOT NULL
);


--
-- Name: widget_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.widget_templates (
    "Id" uuid NOT NULL,
    "TenantId" uuid NOT NULL,
    "Name" character varying(200) NOT NULL,
    "WidgetCatalogItemId" uuid NOT NULL,
    "ConfigJson" jsonb,
    "CreatedByUserId" uuid NOT NULL,
    "CreatedAt" timestamp with time zone NOT NULL
);


--
-- Name: RTSData_UserStatusLog Id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_UserStatusLog" ALTER COLUMN "Id" SET DEFAULT nextval('public."RTSData_UserStatusLog_Id_seq"'::regclass);


--
-- Name: audit_logs PK_audit_logs; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_logs
    ADD CONSTRAINT "PK_audit_logs" PRIMARY KEY ("Id");


--
-- Name: refresh_tokens PK_refresh_tokens; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.refresh_tokens
    ADD CONSTRAINT "PK_refresh_tokens" PRIMARY KEY ("Id");


--
-- Name: role_claims PK_role_claims; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.role_claims
    ADD CONSTRAINT "PK_role_claims" PRIMARY KEY ("Id");


--
-- Name: roles PK_roles; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.roles
    ADD CONSTRAINT "PK_roles" PRIMARY KEY ("Id");


--
-- Name: two_factor_codes PK_two_factor_codes; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.two_factor_codes
    ADD CONSTRAINT "PK_two_factor_codes" PRIMARY KEY ("Id");


--
-- Name: user_claims PK_user_claims; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_claims
    ADD CONSTRAINT "PK_user_claims" PRIMARY KEY ("Id");


--
-- Name: user_logins PK_user_logins; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_logins
    ADD CONSTRAINT "PK_user_logins" PRIMARY KEY ("LoginProvider", "ProviderKey");


--
-- Name: user_password_history PK_user_password_history; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_password_history
    ADD CONSTRAINT "PK_user_password_history" PRIMARY KEY ("Id");


--
-- Name: user_roles PK_user_roles; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_roles
    ADD CONSTRAINT "PK_user_roles" PRIMARY KEY ("UserId", "RoleId");


--
-- Name: user_sessions PK_user_sessions; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_sessions
    ADD CONSTRAINT "PK_user_sessions" PRIMARY KEY ("Id");


--
-- Name: user_tokens PK_user_tokens; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_tokens
    ADD CONSTRAINT "PK_user_tokens" PRIMARY KEY ("UserId", "LoginProvider", "Name");


--
-- Name: users PK_users; Type: CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.users
    ADD CONSTRAINT "PK_users" PRIMARY KEY ("Id");


--
-- Name: AuditEvents PK_AuditEvents; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."AuditEvents"
    ADD CONSTRAINT "PK_AuditEvents" PRIMARY KEY ("Id");


--
-- Name: NGC_AgentGroups PK_NGC_AgentGroups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_AgentGroups"
    ADD CONSTRAINT "PK_NGC_AgentGroups" PRIMARY KEY ("Id");


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
-- Name: NGC_Queues PK_NGC_Queues; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_Queues"
    ADD CONSTRAINT "PK_NGC_Queues" PRIMARY KEY ("Id");


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
-- Name: PermissionGroups PK_PermissionGroups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."PermissionGroups"
    ADD CONSTRAINT "PK_PermissionGroups" PRIMARY KEY ("Id");


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
-- Name: RTSGrid_Metric PK_RTSGrid_Metric; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_Metric"
    ADD CONSTRAINT "PK_RTSGrid_Metric" PRIMARY KEY ("MetricId");


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
-- Name: RTSGrid_TemplateCell PK_RTSGrid_TemplateCell; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSGrid_TemplateCell"
    ADD CONSTRAINT "PK_RTSGrid_TemplateCell" PRIMARY KEY ("CellTemplateId");


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
-- Name: ResourcePermissions PK_ResourcePermissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ResourcePermissions"
    ADD CONSTRAINT "PK_ResourcePermissions" PRIMARY KEY ("Id");


--
-- Name: ScreenPermissions PK_ScreenPermissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ScreenPermissions"
    ADD CONSTRAINT "PK_ScreenPermissions" PRIMARY KEY ("ScreenId", "GroupId");


--
-- Name: Screens PK_Screens; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Screens"
    ADD CONSTRAINT "PK_Screens" PRIMARY KEY ("Id");


--
-- Name: UserGroups PK_UserGroups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserGroups"
    ADD CONSTRAINT "PK_UserGroups" PRIMARY KEY ("UserId", "GroupId");


--
-- Name: Users PK_Users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Users"
    ADD CONSTRAINT "PK_Users" PRIMARY KEY ("Id");


--
-- Name: WidgetSlots PK_WidgetSlots; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."WidgetSlots"
    ADD CONSTRAINT "PK_WidgetSlots" PRIMARY KEY ("Id");


--
-- Name: __BackendEmulationMigrationsHistory PK___BackendEmulationMigrationsHistory; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."__BackendEmulationMigrationsHistory"
    ADD CONSTRAINT "PK___BackendEmulationMigrationsHistory" PRIMARY KEY ("MigrationId");


--
-- Name: __EFMigrationsHistory PK___EFMigrationsHistory; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."__EFMigrationsHistory"
    ADD CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId");


--
-- Name: __ef_migrations_history PK___ef_migrations_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.__ef_migrations_history
    ADD CONSTRAINT "PK___ef_migrations_history" PRIMARY KEY ("MigrationId");


--
-- Name: dashboard_categories PK_dashboard_categories; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_categories
    ADD CONSTRAINT "PK_dashboard_categories" PRIMARY KEY ("Id");


--
-- Name: dashboard_permissions PK_dashboard_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_permissions
    ADD CONSTRAINT "PK_dashboard_permissions" PRIMARY KEY ("PermissionGroupId", "DashboardId");


--
-- Name: dashboard_widgets PK_dashboard_widgets; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT "PK_dashboard_widgets" PRIMARY KEY ("Id");


--
-- Name: dashboards PK_dashboards; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT "PK_dashboards" PRIMARY KEY ("Id");


--
-- Name: history_metrics PK_history_metrics; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_metrics
    ADD CONSTRAINT "PK_history_metrics" PRIMARY KEY ("MetricId");


--
-- Name: info_slot_messages PK_info_slot_messages; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slot_messages
    ADD CONSTRAINT "PK_info_slot_messages" PRIMARY KEY ("Id");


--
-- Name: info_slot_permissions PK_info_slot_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slot_permissions
    ADD CONSTRAINT "PK_info_slot_permissions" PRIMARY KEY ("InfoSlotId", "PermissionGroupId");


--
-- Name: info_slots PK_info_slots; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slots
    ADD CONSTRAINT "PK_info_slots" PRIMARY KEY ("Id");


--
-- Name: menu_permissions PK_menu_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_permissions
    ADD CONSTRAINT "PK_menu_permissions" PRIMARY KEY ("PermissionGroupId", "MenuKey");


--
-- Name: permission_groups PK_permission_groups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_groups
    ADD CONSTRAINT "PK_permission_groups" PRIMARY KEY ("Id");


--
-- Name: pg_business_units PK_pg_business_units; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_business_units
    ADD CONSTRAINT "PK_pg_business_units" PRIMARY KEY ("PermissionGroupId", "BusinessUnitId");


--
-- Name: pg_queues PK_pg_queues; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_queues
    ADD CONSTRAINT "PK_pg_queues" PRIMARY KEY ("PermissionGroupId", "ObjectId");


--
-- Name: pg_skills PK_pg_skills; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_skills
    ADD CONSTRAINT "PK_pg_skills" PRIMARY KEY ("PermissionGroupId", "ObjectId");


--
-- Name: pg_supergroups PK_pg_supergroups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_supergroups
    ADD CONSTRAINT "PK_pg_supergroups" PRIMARY KEY ("PermissionGroupId", "SupergroupId");


--
-- Name: sso_configurations PK_sso_configurations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sso_configurations
    ADD CONSTRAINT "PK_sso_configurations" PRIMARY KEY ("Id");


--
-- Name: tenant_agent_state_definitions PK_tenant_agent_state_definitions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_state_definitions
    ADD CONSTRAINT "PK_tenant_agent_state_definitions" PRIMARY KEY ("Id");


--
-- Name: tenant_agent_state_groups PK_tenant_agent_state_groups; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_state_groups
    ADD CONSTRAINT "PK_tenant_agent_state_groups" PRIMARY KEY ("Id");


--
-- Name: tenant_agent_states PK_tenant_agent_states; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_states
    ADD CONSTRAINT "PK_tenant_agent_states" PRIMARY KEY ("Id");


--
-- Name: tenant_settings PK_tenant_settings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT "PK_tenant_settings" PRIMARY KEY ("TenantId");


--
-- Name: tenants PK_tenants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT "PK_tenants" PRIMARY KEY ("Id");


--
-- Name: user_widget_settings PK_user_widget_settings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_widget_settings
    ADD CONSTRAINT "PK_user_widget_settings" PRIMARY KEY ("Id");


--
-- Name: widget_catalog PK_widget_catalog; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widget_catalog
    ADD CONSTRAINT "PK_widget_catalog" PRIMARY KEY ("Id");


--
-- Name: widget_templates PK_widget_templates; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widget_templates
    ADD CONSTRAINT "PK_widget_templates" PRIMARY KEY ("Id");


--
-- Name: RTSData_UserStatusLog RTSData_UserStatusLog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."RTSData_UserStatusLog"
    ADD CONSTRAINT "RTSData_UserStatusLog_pkey" PRIMARY KEY ("Id");


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
-- Name: IX_audit_logs_EventType_CreatedAt; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX "IX_audit_logs_EventType_CreatedAt" ON audit.audit_logs USING btree ("EventType", "CreatedAt");


--
-- Name: IX_audit_logs_TenantId_CreatedAt; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX "IX_audit_logs_TenantId_CreatedAt" ON audit.audit_logs USING btree ("TenantId", "CreatedAt");


--
-- Name: EmailIndex; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "EmailIndex" ON identity.users USING btree ("NormalizedEmail");


--
-- Name: IX_role_claims_RoleId; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "IX_role_claims_RoleId" ON identity.role_claims USING btree ("RoleId");


--
-- Name: IX_user_claims_UserId; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "IX_user_claims_UserId" ON identity.user_claims USING btree ("UserId");


--
-- Name: IX_user_logins_UserId; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "IX_user_logins_UserId" ON identity.user_logins USING btree ("UserId");


--
-- Name: IX_user_roles_RoleId; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "IX_user_roles_RoleId" ON identity.user_roles USING btree ("RoleId");


--
-- Name: IX_user_sessions_UserId_IsRevoked_ExpiresAt; Type: INDEX; Schema: identity; Owner: -
--

CREATE INDEX "IX_user_sessions_UserId_IsRevoked_ExpiresAt" ON identity.user_sessions USING btree ("UserId", "IsRevoked", "ExpiresAt");


--
-- Name: IX_users_NormalizedEmail_TenantId; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX "IX_users_NormalizedEmail_TenantId" ON identity.users USING btree ("NormalizedEmail", "TenantId") WHERE ("IsActive" = true);


--
-- Name: RoleNameIndex; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX "RoleNameIndex" ON identity.roles USING btree ("NormalizedName");


--
-- Name: UserNameIndex; Type: INDEX; Schema: identity; Owner: -
--

CREATE UNIQUE INDEX "UserNameIndex" ON identity.users USING btree ("NormalizedUserName");


--
-- Name: IX_AuditEvents_OccurredAt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_AuditEvents_OccurredAt" ON public."AuditEvents" USING btree ("OccurredAt");


--
-- Name: IX_AuditEvents_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_AuditEvents_UserId" ON public."AuditEvents" USING btree ("UserId");


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
-- Name: IX_PermissionGroups_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_PermissionGroups_Name" ON public."PermissionGroups" USING btree ("Name");


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
-- Name: IX_ResourcePermissions_GroupId_ResourceType; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_ResourcePermissions_GroupId_ResourceType" ON public."ResourcePermissions" USING btree ("GroupId", "ResourceType");


--
-- Name: IX_ScreenPermissions_GroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_ScreenPermissions_GroupId" ON public."ScreenPermissions" USING btree ("GroupId");


--
-- Name: IX_Screens_OwnerId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_Screens_OwnerId" ON public."Screens" USING btree ("OwnerId");


--
-- Name: IX_UserGroups_GroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_UserGroups_GroupId" ON public."UserGroups" USING btree ("GroupId");


--
-- Name: IX_Users_Email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_Users_Email" ON public."Users" USING btree ("Email");


--
-- Name: IX_WidgetSlots_ScreenId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_WidgetSlots_ScreenId" ON public."WidgetSlots" USING btree ("ScreenId");


--
-- Name: IX_dashboard_categories_TenantId_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_dashboard_categories_TenantId_Name" ON public.dashboard_categories USING btree ("TenantId", "Name");


--
-- Name: IX_dashboard_permissions_DashboardId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_dashboard_permissions_DashboardId" ON public.dashboard_permissions USING btree ("DashboardId");


--
-- Name: IX_dashboard_widgets_DashboardId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_dashboard_widgets_DashboardId" ON public.dashboard_widgets USING btree ("DashboardId");


--
-- Name: IX_dashboard_widgets_WidgetCatalogItemId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_dashboard_widgets_WidgetCatalogItemId" ON public.dashboard_widgets USING btree ("WidgetCatalogItemId");


--
-- Name: IX_dashboards_CategoryId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_dashboards_CategoryId" ON public.dashboards USING btree ("CategoryId");


--
-- Name: IX_dashboards_TenantId_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_dashboards_TenantId_Name" ON public.dashboards USING btree ("TenantId", "Name");


--
-- Name: IX_info_slot_messages_InfoSlotId_IsActive_ExpiresAt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_info_slot_messages_InfoSlotId_IsActive_ExpiresAt" ON public.info_slot_messages USING btree ("InfoSlotId", "IsActive", "ExpiresAt");


--
-- Name: IX_info_slot_messages_TenantId_CreatedAt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_info_slot_messages_TenantId_CreatedAt" ON public.info_slot_messages USING btree ("TenantId", "CreatedAt");


--
-- Name: IX_info_slot_permissions_PermissionGroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_info_slot_permissions_PermissionGroupId" ON public.info_slot_permissions USING btree ("PermissionGroupId");


--
-- Name: IX_info_slots_TenantId_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_info_slots_TenantId_Name" ON public.info_slots USING btree ("TenantId", "Name");


--
-- Name: IX_permission_groups_TenantId_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_permission_groups_TenantId_Name" ON public.permission_groups USING btree ("TenantId", "Name");


--
-- Name: IX_sso_configurations_TenantId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_sso_configurations_TenantId" ON public.sso_configurations USING btree ("TenantId");


--
-- Name: IX_tenant_agent_state_definitions_AgentStateGroupId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_tenant_agent_state_definitions_AgentStateGroupId" ON public.tenant_agent_state_definitions USING btree ("AgentStateGroupId");


--
-- Name: IX_tenant_agent_state_definitions_AgentStateId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_tenant_agent_state_definitions_AgentStateId" ON public.tenant_agent_state_definitions USING btree ("AgentStateId");


--
-- Name: IX_tenant_agent_state_definitions_TenantId_AgentStateId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_tenant_agent_state_definitions_TenantId_AgentStateId" ON public.tenant_agent_state_definitions USING btree ("TenantId", "AgentStateId");


--
-- Name: IX_tenant_agent_state_groups_TenantId_GroupName; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_tenant_agent_state_groups_TenantId_GroupName" ON public.tenant_agent_state_groups USING btree ("TenantId", "GroupName");


--
-- Name: IX_tenant_agent_states_TenantId_AgentState; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_tenant_agent_states_TenantId_AgentState" ON public.tenant_agent_states USING btree ("TenantId", "AgentState");


--
-- Name: IX_tenants_Slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_tenants_Slug" ON public.tenants USING btree ("Slug");


--
-- Name: IX_user_widget_settings_TenantId_UserId_WidgetId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_user_widget_settings_TenantId_UserId_WidgetId" ON public.user_widget_settings USING btree ("TenantId", "UserId", "WidgetId");


--
-- Name: IX_widget_templates_TenantId_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_widget_templates_TenantId_Name" ON public.widget_templates USING btree ("TenantId", "Name");


--
-- Name: IX_widget_templates_WidgetCatalogItemId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_widget_templates_WidgetCatalogItemId" ON public.widget_templates USING btree ("WidgetCatalogItemId");


--
-- Name: role_claims FK_role_claims_roles_RoleId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.role_claims
    ADD CONSTRAINT "FK_role_claims_roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES identity.roles("Id") ON DELETE CASCADE;


--
-- Name: user_claims FK_user_claims_users_UserId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_claims
    ADD CONSTRAINT "FK_user_claims_users_UserId" FOREIGN KEY ("UserId") REFERENCES identity.users("Id") ON DELETE CASCADE;


--
-- Name: user_logins FK_user_logins_users_UserId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_logins
    ADD CONSTRAINT "FK_user_logins_users_UserId" FOREIGN KEY ("UserId") REFERENCES identity.users("Id") ON DELETE CASCADE;


--
-- Name: user_roles FK_user_roles_roles_RoleId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_roles
    ADD CONSTRAINT "FK_user_roles_roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES identity.roles("Id") ON DELETE CASCADE;


--
-- Name: user_roles FK_user_roles_users_UserId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_roles
    ADD CONSTRAINT "FK_user_roles_users_UserId" FOREIGN KEY ("UserId") REFERENCES identity.users("Id") ON DELETE CASCADE;


--
-- Name: user_tokens FK_user_tokens_users_UserId; Type: FK CONSTRAINT; Schema: identity; Owner: -
--

ALTER TABLE ONLY identity.user_tokens
    ADD CONSTRAINT "FK_user_tokens_users_UserId" FOREIGN KEY ("UserId") REFERENCES identity.users("Id") ON DELETE CASCADE;


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
-- Name: ResourcePermissions FK_ResourcePermissions_PermissionGroups_GroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ResourcePermissions"
    ADD CONSTRAINT "FK_ResourcePermissions_PermissionGroups_GroupId" FOREIGN KEY ("GroupId") REFERENCES public."PermissionGroups"("Id") ON DELETE CASCADE;


--
-- Name: ScreenPermissions FK_ScreenPermissions_PermissionGroups_GroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ScreenPermissions"
    ADD CONSTRAINT "FK_ScreenPermissions_PermissionGroups_GroupId" FOREIGN KEY ("GroupId") REFERENCES public."PermissionGroups"("Id") ON DELETE CASCADE;


--
-- Name: ScreenPermissions FK_ScreenPermissions_Screens_ScreenId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ScreenPermissions"
    ADD CONSTRAINT "FK_ScreenPermissions_Screens_ScreenId" FOREIGN KEY ("ScreenId") REFERENCES public."Screens"("Id") ON DELETE CASCADE;


--
-- Name: UserGroups FK_UserGroups_PermissionGroups_GroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserGroups"
    ADD CONSTRAINT "FK_UserGroups_PermissionGroups_GroupId" FOREIGN KEY ("GroupId") REFERENCES public."PermissionGroups"("Id") ON DELETE CASCADE;


--
-- Name: UserGroups FK_UserGroups_Users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."UserGroups"
    ADD CONSTRAINT "FK_UserGroups_Users_UserId" FOREIGN KEY ("UserId") REFERENCES public."Users"("Id") ON DELETE CASCADE;


--
-- Name: WidgetSlots FK_WidgetSlots_Screens_ScreenId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."WidgetSlots"
    ADD CONSTRAINT "FK_WidgetSlots_Screens_ScreenId" FOREIGN KEY ("ScreenId") REFERENCES public."Screens"("Id") ON DELETE CASCADE;


--
-- Name: dashboard_categories FK_dashboard_categories_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_categories
    ADD CONSTRAINT "FK_dashboard_categories_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: dashboard_permissions FK_dashboard_permissions_dashboards_DashboardId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_permissions
    ADD CONSTRAINT "FK_dashboard_permissions_dashboards_DashboardId" FOREIGN KEY ("DashboardId") REFERENCES public.dashboards("Id") ON DELETE CASCADE;


--
-- Name: dashboard_permissions FK_dashboard_permissions_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_permissions
    ADD CONSTRAINT "FK_dashboard_permissions_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: dashboard_widgets FK_dashboard_widgets_dashboards_DashboardId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT "FK_dashboard_widgets_dashboards_DashboardId" FOREIGN KEY ("DashboardId") REFERENCES public.dashboards("Id") ON DELETE CASCADE;


--
-- Name: dashboard_widgets FK_dashboard_widgets_widget_catalog_WidgetCatalogItemId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT "FK_dashboard_widgets_widget_catalog_WidgetCatalogItemId" FOREIGN KEY ("WidgetCatalogItemId") REFERENCES public.widget_catalog("Id") ON DELETE CASCADE;


--
-- Name: dashboards FK_dashboards_dashboard_categories_CategoryId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT "FK_dashboards_dashboard_categories_CategoryId" FOREIGN KEY ("CategoryId") REFERENCES public.dashboard_categories("Id") ON DELETE SET NULL;


--
-- Name: dashboards FK_dashboards_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT "FK_dashboards_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: info_slot_messages FK_info_slot_messages_info_slots_InfoSlotId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slot_messages
    ADD CONSTRAINT "FK_info_slot_messages_info_slots_InfoSlotId" FOREIGN KEY ("InfoSlotId") REFERENCES public.info_slots("Id") ON DELETE CASCADE;


--
-- Name: info_slot_permissions FK_info_slot_permissions_info_slots_InfoSlotId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slot_permissions
    ADD CONSTRAINT "FK_info_slot_permissions_info_slots_InfoSlotId" FOREIGN KEY ("InfoSlotId") REFERENCES public.info_slots("Id") ON DELETE CASCADE;


--
-- Name: info_slot_permissions FK_info_slot_permissions_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.info_slot_permissions
    ADD CONSTRAINT "FK_info_slot_permissions_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: menu_permissions FK_menu_permissions_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_permissions
    ADD CONSTRAINT "FK_menu_permissions_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: permission_groups FK_permission_groups_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_groups
    ADD CONSTRAINT "FK_permission_groups_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: pg_business_units FK_pg_business_units_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_business_units
    ADD CONSTRAINT "FK_pg_business_units_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: pg_queues FK_pg_queues_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_queues
    ADD CONSTRAINT "FK_pg_queues_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: pg_skills FK_pg_skills_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_skills
    ADD CONSTRAINT "FK_pg_skills_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: pg_supergroups FK_pg_supergroups_permission_groups_PermissionGroupId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pg_supergroups
    ADD CONSTRAINT "FK_pg_supergroups_permission_groups_PermissionGroupId" FOREIGN KEY ("PermissionGroupId") REFERENCES public.permission_groups("Id") ON DELETE CASCADE;


--
-- Name: sso_configurations FK_sso_configurations_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sso_configurations
    ADD CONSTRAINT "FK_sso_configurations_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: tenant_agent_state_definitions FK_tenant_agent_state_definitions_tenant_agent_state_groups_Ag~; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_state_definitions
    ADD CONSTRAINT "FK_tenant_agent_state_definitions_tenant_agent_state_groups_Ag~" FOREIGN KEY ("AgentStateGroupId") REFERENCES public.tenant_agent_state_groups("Id") ON DELETE CASCADE;


--
-- Name: tenant_agent_state_definitions FK_tenant_agent_state_definitions_tenant_agent_states_AgentSta~; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_state_definitions
    ADD CONSTRAINT "FK_tenant_agent_state_definitions_tenant_agent_states_AgentSta~" FOREIGN KEY ("AgentStateId") REFERENCES public.tenant_agent_states("Id") ON DELETE CASCADE;


--
-- Name: tenant_agent_state_groups FK_tenant_agent_state_groups_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_state_groups
    ADD CONSTRAINT "FK_tenant_agent_state_groups_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: tenant_agent_states FK_tenant_agent_states_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_agent_states
    ADD CONSTRAINT "FK_tenant_agent_states_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: tenant_settings FK_tenant_settings_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT "FK_tenant_settings_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: widget_templates FK_widget_templates_tenants_TenantId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widget_templates
    ADD CONSTRAINT "FK_widget_templates_tenants_TenantId" FOREIGN KEY ("TenantId") REFERENCES public.tenants("Id") ON DELETE CASCADE;


--
-- Name: widget_templates FK_widget_templates_widget_catalog_WidgetCatalogItemId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widget_templates
    ADD CONSTRAINT "FK_widget_templates_widget_catalog_WidgetCatalogItemId" FOREIGN KEY ("WidgetCatalogItemId") REFERENCES public.widget_catalog("Id") ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 9CkMn3S0oWs396CipggFKc2FzmVSEav2h0ACDXpMdifS1FcPN6iyabLrUyOvewx

