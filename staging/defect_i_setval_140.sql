-- Defect I — one-time IDENTITY-sequence resync on 140's rtmviewdb.
-- Run as POSTGRES (owner). Idempotent: setval(..., MAX, true) -> next live insert = MAX+1 (always free).
-- Root: baseline TRUNCATE ... RESTART IDENTITY + COPY-with-explicit-ids does NOT advance the identity seq
--       => seq sits at 1 while rows occupy 1..N => first LIVE insert draws an existing id => 23505 PK.
-- Source: dba-0625 diagnosis + verified GENERATED-ALWAYS IDENTITY PKs (schema.sql). §4-PASS coordinator 2026-07-13.

BEGIN;

-- QueueGrid-save path (the crashing PK_RTSGrid_Column + its siblings)
SELECT setval(pg_get_serial_sequence('public."RTSGrid_Cell"','CellId'),                 (SELECT GREATEST(COALESCE(MAX("CellId"),0),1)         FROM public."RTSGrid_Cell"), true);
SELECT setval(pg_get_serial_sequence('public."RTSGrid_Column"','ColumnId'),             (SELECT GREATEST(COALESCE(MAX("ColumnId"),0),1)       FROM public."RTSGrid_Column"), true);
SELECT setval(pg_get_serial_sequence('public."RTSGrid_Grid"','GridId'),                 (SELECT GREATEST(COALESCE(MAX("GridId"),0),1)         FROM public."RTSGrid_Grid"), true);
SELECT setval(pg_get_serial_sequence('public."RTSGrid_Row"','RowId'),                   (SELECT GREATEST(COALESCE(MAX("RowId"),0),1)          FROM public."RTSGrid_Row"), true);

-- AgentGrid-save siblings (same latent 23505)
SELECT setval(pg_get_serial_sequence('public."RTSUserGrid_Column"','ColumnId'),         (SELECT GREATEST(COALESCE(MAX("ColumnId"),0),1)       FROM public."RTSUserGrid_Column"), true);
SELECT setval(pg_get_serial_sequence('public."RTSUserGrid_ColumnsSet"','ColumnsSetId'), (SELECT GREATEST(COALESCE(MAX("ColumnsSetId"),0),1)   FROM public."RTSUserGrid_ColumnsSet"), true);
SELECT setval(pg_get_serial_sequence('public."RTSUserGrid_Grid"','GridId'),             (SELECT GREATEST(COALESCE(MAX("GridId"),0),1)         FROM public."RTSUserGrid_Grid"), true);

-- NGC_ / RTSData same-class (folded per operator: prevents sibling 23505 on BU/agentgroup creation)
SELECT setval(pg_get_serial_sequence('public."NGC_BusinessUnit"','BusinessUnitId'),     (SELECT GREATEST(COALESCE(MAX("BusinessUnitId"),0),1) FROM public."NGC_BusinessUnit"), true);
SELECT setval(pg_get_serial_sequence('public."NGC_Supergroup"','SupergroupId'),         (SELECT GREATEST(COALESCE(MAX("SupergroupId"),0),1)   FROM public."NGC_Supergroup"), true);
SELECT setval(pg_get_serial_sequence('public."NGC_SupergroupAgentgroup"','Id'),         (SELECT GREATEST(COALESCE(MAX("Id"),0),1)             FROM public."NGC_SupergroupAgentgroup"), true);
SELECT setval(pg_get_serial_sequence('public."NGC_UserAgentgroup"','Id'),               (SELECT GREATEST(COALESCE(MAX("Id"),0),1)             FROM public."NGC_UserAgentgroup"), true);
SELECT setval(pg_get_serial_sequence('public."RTSData_UserStatusLog"','Id'),            (SELECT GREATEST(COALESCE(MAX("Id"),0),1)             FROM public."RTSData_UserStatusLog"), true);

COMMIT;

-- VERIFY (each setval RETURNs its table max above; this shows the max per table for cross-check):
SELECT 'RTSGrid_Cell' t,           COALESCE(MAX("CellId"),0)        m FROM public."RTSGrid_Cell"
UNION ALL SELECT 'RTSGrid_Column',        COALESCE(MAX("ColumnId"),0)      FROM public."RTSGrid_Column"
UNION ALL SELECT 'RTSGrid_Grid',          COALESCE(MAX("GridId"),0)        FROM public."RTSGrid_Grid"
UNION ALL SELECT 'RTSGrid_Row',           COALESCE(MAX("RowId"),0)         FROM public."RTSGrid_Row"
UNION ALL SELECT 'RTSUserGrid_Column',    COALESCE(MAX("ColumnId"),0)      FROM public."RTSUserGrid_Column"
UNION ALL SELECT 'RTSUserGrid_ColumnsSet',COALESCE(MAX("ColumnsSetId"),0)  FROM public."RTSUserGrid_ColumnsSet"
UNION ALL SELECT 'RTSUserGrid_Grid',      COALESCE(MAX("GridId"),0)        FROM public."RTSUserGrid_Grid"
UNION ALL SELECT 'NGC_BusinessUnit',      COALESCE(MAX("BusinessUnitId"),0) FROM public."NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Supergroup',        COALESCE(MAX("SupergroupId"),0)  FROM public."NGC_Supergroup"
UNION ALL SELECT 'NGC_SupergroupAgentgroup', COALESCE(MAX("Id"),0)         FROM public."NGC_SupergroupAgentgroup"
UNION ALL SELECT 'NGC_UserAgentgroup',    COALESCE(MAX("Id"),0)            FROM public."NGC_UserAgentgroup"
UNION ALL SELECT 'RTSData_UserStatusLog', COALESCE(MAX("Id"),0)            FROM public."RTSData_UserStatusLog";
