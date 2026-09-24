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
