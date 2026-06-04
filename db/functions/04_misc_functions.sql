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
