-- ============================================================================
-- 45 Hotfix: 42883 (missing PROCEDURE) + 23505 (IDENTITY resync)
-- File: staging/45_hotfix_20260613.sql
-- Apply: psql -U postgres -d rtmviewdb -f 45_hotfix_20260613.sql
-- Idempotent: safe to run multiple times on any server
-- ============================================================================

-- ============================================================================
-- PART A1: Fix 42883 — drop dead 3-param FUNCTION, ensure canonical PROCEDURE
-- Root cause: db/functions/01 had both FUNCTION(3-param) + PROCEDURE(N-param).
-- On some servers the FUNCTION landed; RTM CALLs PROCEDURE -> 42883.
-- Fix: DROP the FUNCTION, ensure only the PROCEDURE exists.
-- ============================================================================

-- A1.1: NGC_CreateBusinessUnitQueueClassificationMapping
-- Kind-agnostic DROP (clear any overloads)
DO $drop1$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateBusinessUnitQueueClassificationMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop1$;

-- Create canonical 5-param PROCEDURE (RTM caller: ExecuteNonQuery = CALL)
CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_classification_id text,
    p_created_by text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification"
        ("BusinessUnitId", "QueueId", "ClassificationId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, p_classification_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
END;
$$;

-- A1.2: NGC_CreateBusinessUnitSupergroupMapping
DO $drop2$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateBusinessUnitSupergroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop2$;

-- Create canonical 4-param PROCEDURE
CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_created_by text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
END;
$$;

-- A1.3: NGC_CreateSupergroupAgentgroupMapping
DO $drop3$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroupAgentgroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop3$;

-- Create canonical 4-param PROCEDURE
CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_created_by text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, p_tenant_id)
    ON CONFLICT ("SupergroupId", "AgentgroupId") DO NOTHING;
END;
$$;

-- ============================================================================
-- PART A2: Fix 23505 — resync IDENTITY sequences after seed data insert
-- Root cause: seed data INSERTs explicit IDs without updating the sequence.
-- Fix: setval each sequence to MAX(id) so next INSERT gets the right value.
-- ============================================================================

-- RTSGrid tables
SELECT setval(pg_get_serial_sequence('"RTSGrid_Grid"','GridId'), GREATEST((SELECT COALESCE(MAX("GridId"),0) FROM "RTSGrid_Grid"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Row"','RowId'), GREATEST((SELECT COALESCE(MAX("RowId"),0) FROM "RTSGrid_Row"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Column"','ColumnId'), GREATEST((SELECT COALESCE(MAX("ColumnId"),0) FROM "RTSGrid_Column"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Cell"','CellId'), GREATEST((SELECT COALESCE(MAX("CellId"),0) FROM "RTSGrid_Cell"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Statistic"','StatisticId'), GREATEST((SELECT COALESCE(MAX("StatisticId"),0) FROM "RTSGrid_Statistic"),1));

-- RTSUserGrid tables
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_Grid"','GridId'), GREATEST((SELECT COALESCE(MAX("GridId"),0) FROM "RTSUserGrid_Grid"),1));
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_Column"','ColumnId'), GREATEST((SELECT COALESCE(MAX("ColumnId"),0) FROM "RTSUserGrid_Column"),1));
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_ColumnsSet"','ColumnsSetId'), GREATEST((SELECT COALESCE(MAX("ColumnsSetId"),0) FROM "RTSUserGrid_ColumnsSet"),1));

-- NGC tables (defensive — may not have IDENTITY on all servers)
DO $seq_ngc$
BEGIN
  IF pg_get_serial_sequence('"NGC_BusinessUnit"','BusinessUnitId') IS NOT NULL THEN
    PERFORM setval(pg_get_serial_sequence('"NGC_BusinessUnit"','BusinessUnitId'), GREATEST((SELECT COALESCE(MAX("BusinessUnitId"),0) FROM "NGC_BusinessUnit"),1));
  END IF;
  IF pg_get_serial_sequence('"NGC_Supergroup"','SupergroupId') IS NOT NULL THEN
    PERFORM setval(pg_get_serial_sequence('"NGC_Supergroup"','SupergroupId'), GREATEST((SELECT COALESCE(MAX("SupergroupId"),0) FROM "NGC_Supergroup"),1));
  END IF;
  IF pg_get_serial_sequence('"NGC_SupergroupAgentgroup"','Id') IS NOT NULL THEN
    PERFORM setval(pg_get_serial_sequence('"NGC_SupergroupAgentgroup"','Id'), GREATEST((SELECT COALESCE(MAX("Id"),0) FROM "NGC_SupergroupAgentgroup"),1));
  END IF;
END $seq_ngc$;

-- ============================================================================
-- VERIFY after applying:
-- 1. SELECT proname, pg_get_function_identity_arguments(oid), prokind
--    FROM pg_proc WHERE proname LIKE 'NGC_Create%Mapping' ORDER BY 1,2;
--    -> Each name shows ONLY prokind='p' (PROCEDURE), no 'f' (FUNCTION)
-- 2. Test CALL: BEGIN; CALL "NGC_CreateBusinessUnitQueueClassificationMapping"(1,'q','c','sys',gen_random_uuid()); ROLLBACK;
-- 3. QueueGrid save succeeds (no 23505 on Grid/Row/Column/Cell INSERTs)
-- ============================================================================