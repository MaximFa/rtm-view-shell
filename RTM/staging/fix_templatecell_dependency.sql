-- ============================================================================
-- Hotfix: Remove RTSGrid_TemplateCell dependency from RTSGrid_GetDataCells
--
-- Problem: RTSGrid_GetDataCells used INNER JOIN with RTSGrid_TemplateCell.
--          RTSGrid_TemplateCell has always been empty (never populated from MSSQL).
--          Result: function returned 0 rows -> RTM Engine registered no cells
--          -> updateGridData never sent -> QueueGrid/DataSlot showed no data.
--
-- Fix: Remove TemplateCell join entirely. All data cells have CellType='Data'
--      explicitly. Column order preserved (C# reads by index).
--      ColumnMetric (index 9) returns NULL — never used when Metric (index 8) is set.
--
-- Deploy: psql -U ccdashboard_user -d ccdashboarddb -f fix_templatecell_dependency.sql
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
        g."UnionId"  AS "GridUnionId",
        r."UnionId"  AS "RowUnionId",
        c."Value"::text  AS "Metric",
        NULL::text   AS "ColumnMetric"
    FROM "RTSGrid_Grid" g
    JOIN "RTSGrid_Row"  r ON r."GridId"   = g."GridId"
    JOIN "RTSGrid_Cell" c ON c."RowId"    = r."RowId"
    JOIN "RTSGrid_Column" o ON o."ColumnId" = c."ColumnId"
    WHERE c."CellType" = 'Data';
END;
$$;

-- Verify: should return rows for each Data cell in RTSGrid_Cell
-- SELECT count(*) FROM "RTSGrid_GetDataCells"();
