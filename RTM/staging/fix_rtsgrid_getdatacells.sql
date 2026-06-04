-- Fix: RTSGrid_GetDataCells — LEFT JOIN on RTSGrid_TemplateCell
-- Problem: INNER JOIN excluded Shell-created cells (CellType='Data', no CellTemplateId)
-- Fix: LEFT JOIN allows cells without a template to be included
-- Shell creates cells with CellType='Data', Value=MetricId — no template needed
-- Legacy DNN cells (CellType='None') still require template with CellType='Data'
-- After applying: call http://localhost:8088/LoadData to reload Engine configuration

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
    FROM "RTSGrid_Grid" g
    JOIN "RTSGrid_Row" r ON g."GridId" = r."GridId"
    JOIN "RTSGrid_Cell" c ON c."RowId" = r."RowId"
    JOIN "RTSGrid_Column" o ON c."ColumnId" = o."ColumnId"
    LEFT JOIN "RTSGrid_TemplateCell" t ON o."CellTemplateId" = t."CellTemplateId"
    WHERE (c."CellType" = 'Data')
       OR (c."CellType" = 'None' AND t."CellType" = 'Data');
END;
$$;

-- Verify: should return rows for Shell-created grids
-- SELECT COUNT(*) FROM "RTSGrid_GetDataCells"() WHERE "GridId" = <your_grid_id>;
