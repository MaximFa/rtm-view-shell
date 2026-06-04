-- Fix NGC_ write functions: convert FUNCTION -> PROCEDURE with correct signatures
-- Based on exact C# BusinessUnitData.cs parameter lists.
-- ExecuteNonQuery uses CALL -> requires PROCEDURE.
-- GetScalar uses SELECT * FROM -> requires FUNCTION (NGC_CreateBusinessUnit, NGC_CreateSupergroup).
--
-- Signature map:
--   NGC_DeleteBusinessUnit          CALL (int, uuid)
--   NGC_ModifyBusinessUnit          CALL (int, text, text, uuid)
--   NGC_CreateSupergroup            CALL (int, text, text, text, uuid) -- overload 2
--   NGC_DeleteSupergroup            CALL (int, uuid)
--   NGC_ModifySupergroup            CALL (int, text, text, uuid)
--   NGC_CreateBUQCMapping           CALL (int, text, text, text, uuid)
--   NGC_DeleteBUQCMapping           CALL (int, text, text, uuid)
--   NGC_CreateBUSupergroupMapping   CALL (int, int, text, uuid)
--   NGC_DeleteBUSupergroupMapping   CALL (int, int, uuid)
--   NGC_CreateSGAgentgroupMapping   CALL (int, text, text, uuid)
--   NGC_DeleteSGAgentgroupMapping   CALL (int, text, uuid)

-- ============================================================
-- 1. NGC_DeleteBusinessUnit (int, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnit"(integer, uuid);
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnit"(integer);
DROP PROCEDURE IF EXISTS "NGC_DeleteBusinessUnit";
CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer,
    p_tenant_id        uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================
-- 2. NGC_ModifyBusinessUnit (int, text, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text);
DROP PROCEDURE IF EXISTS "NGC_ModifyBusinessUnit";
CREATE OR REPLACE PROCEDURE "NGC_ModifyBusinessUnit"(
    p_business_unit_id   integer,
    p_business_unit_name text,
    p_description        text,
    p_tenant_id          uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE "NGC_BusinessUnit"
    SET "BusinessUnitName" = p_business_unit_name,
        "Description"      = p_description
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId"       = p_tenant_id;
END;
$$;

-- ============================================================
-- 3. NGC_CreateSupergroup — TWO overloads:
--    FUNCTION  (text, text, text, uuid)         -> GetScalar  (creates new)
--    PROCEDURE (int, text, text, text, uuid)    -> ExecuteNonQuery (updates existing)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroup"(text, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroup"(text, text, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroup"(integer, text, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroup"(integer, text, text, text, uuid);
DROP PROCEDURE IF EXISTS "NGC_CreateSupergroup"(integer, text, text, text, uuid);

-- FUNCTION overload (GetScalar — returns new SupergroupId)
CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description     text,
    p_created_by      text,
    p_tenant_id       uuid
)
RETURNS TABLE("SupergroupId" integer)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_Supergroup"."SupergroupId";
END;
$$;

-- PROCEDURE overload (ExecuteNonQuery — updates supergroup by ID)
CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroup"(
    p_supergroup_id   integer,
    p_supergroup_name text,
    p_description     text,
    p_created_by      text,
    p_tenant_id       uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_Supergroup" ("SupergroupId", "SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_supergroup_name, p_description, NOW(), p_tenant_id)
    ON CONFLICT ("SupergroupId") DO UPDATE
    SET "SupergroupName" = EXCLUDED."SupergroupName",
        "Description"    = EXCLUDED."Description";
END;
$$;

-- ============================================================
-- 4. NGC_DeleteSupergroup (int, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_DeleteSupergroup"(integer, uuid);
DROP FUNCTION  IF EXISTS "NGC_DeleteSupergroup"(integer);
DROP PROCEDURE IF EXISTS "NGC_DeleteSupergroup";
CREATE OR REPLACE PROCEDURE "NGC_DeleteSupergroup"(
    p_supergroup_id integer,
    p_tenant_id     uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId"     = p_tenant_id;
END;
$$;

-- ============================================================
-- 5. NGC_ModifySupergroup (int, text, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_ModifySupergroup"(integer, text, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_ModifySupergroup"(integer, text, text);
DROP PROCEDURE IF EXISTS "NGC_ModifySupergroup";
CREATE OR REPLACE PROCEDURE "NGC_ModifySupergroup"(
    p_supergroup_id   integer,
    p_supergroup_name text,
    p_description     text,
    p_tenant_id       uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE "NGC_Supergroup"
    SET "SupergroupName" = p_supergroup_name,
        "Description"    = p_description
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId"     = p_tenant_id;
END;
$$;

-- ============================================================
-- 6. NGC_CreateBusinessUnitQueueClassificationMapping (int, text, text, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, text, text, uuid);
DROP PROCEDURE IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping";
CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id  integer,
    p_queue_id          text,
    p_classification_id text,
    p_created_by        text,
    p_tenant_id         uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification"
        ("BusinessUnitId", "QueueId", "ClassificationId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, p_classification_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
END;
$$;

-- ============================================================
-- 7. NGC_DeleteBusinessUnitQueueClassificationMapping (int, text, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text, text, uuid);
DROP PROCEDURE IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping";
CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id  integer,
    p_queue_id          text,
    p_classification_id text,
    p_tenant_id         uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId"   = p_business_unit_id
      AND "QueueId"          = p_queue_id
      AND "TenantId"         = p_tenant_id;
END;
$$;

-- ============================================================
-- 8. NGC_CreateBusinessUnitSupergroupMapping (int, int, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, text, uuid);
DROP PROCEDURE IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping";
CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id    integer,
    p_created_by       text,
    p_tenant_id        uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
END;
$$;

-- ============================================================
-- 9. NGC_DeleteBusinessUnitSupergroupMapping (int, int, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer, uuid);
DROP FUNCTION  IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer);
DROP PROCEDURE IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping";
CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id    integer,
    p_tenant_id        uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId"   = p_supergroup_id
      AND "TenantId"       = p_tenant_id;
END;
$$;

-- ============================================================
-- 10. NGC_CreateSupergroupAgentgroupMapping (int, text, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, text, uuid);
DROP PROCEDURE IF EXISTS "NGC_CreateSupergroupAgentgroupMapping";
CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id  integer,
    p_agentgroup_id  text,
    p_created_by     text,
    p_tenant_id      uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, p_tenant_id)
    ON CONFLICT ("SupergroupId", "AgentgroupId") DO NOTHING;
END;
$$;

-- ============================================================
-- 11. NGC_DeleteSupergroupAgentgroupMapping (int, text, uuid)
-- ============================================================
DROP FUNCTION  IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text, uuid);
DROP FUNCTION  IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text);
DROP PROCEDURE IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping";
CREATE OR REPLACE PROCEDURE "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id     uuid
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id
      AND "TenantId"     = p_tenant_id;
END;
$$;

-- Verify
SELECT proname, prokind,
       pg_get_function_arguments(oid) AS args
FROM pg_proc
WHERE proname IN (
    'NGC_DeleteBusinessUnit', 'NGC_ModifyBusinessUnit',
    'NGC_CreateSupergroup', 'NGC_DeleteSupergroup', 'NGC_ModifySupergroup',
    'NGC_CreateBusinessUnitQueueClassificationMapping',
    'NGC_DeleteBusinessUnitQueueClassificationMapping',
    'NGC_CreateBusinessUnitSupergroupMapping',
    'NGC_DeleteBusinessUnitSupergroupMapping',
    'NGC_CreateSupergroupAgentgroupMapping',
    'NGC_DeleteSupergroupAgentgroupMapping'
)
ORDER BY proname, prokind;
