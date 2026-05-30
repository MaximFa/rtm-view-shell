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
        c."CellType",
        g."GridId",
        o."ColumnId",
        r."RowId",
        c."UnionId",
        g."UnionId" AS "GridUnionId",
        r."UnionId" AS "RowUnionId",
        c."Value" AS "Metric",
        t."Value" AS "ColumnMetric"
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
        c."Value" AS "Title"
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
        u."QueueId" AS "QueueID",
        u."ClassificationId" AS "ClassificationID",
        s."TimeZone",
        s."ClearTime"
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
        s."AgentgroupId" AS "AgentgroupID",
        t."TimeZone",
        t."ClearTime"
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
        m."MetricId",
        CASE WHEN m."Description" IS NULL OR m."Description" = ''
             THEN m."MetricId"
             ELSE m."Description"
        END AS "Description",
        m."DataType",
        m."MetricFunction",
        m."MetricParameter",
        m."MetricFormat",
        m."DefaultValue"
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
        s."Category",
        s."Definition",
        s."ParamType1",
        s."ParamValue1",
        s."ParamType2",
        s."ParamValue2",
        s."ParamType3",
        s."ParamValue3",
        s."ParamType4",
        s."ParamValue4",
        s."ParamType5",
        s."ParamValue5",
        s."ParamType6",
        s."ParamValue6",
        s."ParamType7",
        s."ParamValue7",
        s."ParamType8",
        s."ParamValue8",
        s."ParamType9",
        s."ParamValue9",
        s."ParamType10",
        s."ParamValue10"
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
        c."MetricId"
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
        g."Title",
        g."RowsFilterNew",
        g."PageSize",
        g."ThresholdScript"
    FROM "RTSUserGrid_Grid" g;
END;
$$;

-- ============================================================================
-- End of RTSGrid/RTSUserGrid read functions (8 total)
-- Note: NGC_GetSiteTable is in 01_ngc_functions.sql
-- ============================================================================
