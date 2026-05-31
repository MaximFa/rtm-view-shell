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
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"(uuid);

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionQueueClassifications"(p_tenant_id uuid)
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
      AND b."SiteId" = s."SiteId"
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND s."TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 5. RTSGrid_GetAllUnionUserGroups
--    Returns user groups (agentgroups) mapped to business units with site info.
--    Column order: BusinessUnitID, SupergroupID, AgentgroupID, TimeZone, ClearTime
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"();
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"(uuid);

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionUserGroups"(p_tenant_id uuid)
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
      AND b."SiteId" = t."SiteId"
      AND s."TenantId" = p_tenant_id
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND t."TenantId" = p_tenant_id;
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
