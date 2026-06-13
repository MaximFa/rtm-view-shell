-- ============================================================================
-- Migration: 20260613_012_drop_legacy_mapping_functions
-- Purpose: Remove dead 3-param FUNCTION overloads for NGC_Create*Mapping
--          that cause 42883 when RTM CALLs the canonical PROCEDURE
--
-- Background: db/functions/01 had dual overloads (FUNCTION + PROCEDURE).
-- Shell never called the FUNCTION (grep = 0 callers). RTM calls PROCEDURE via
-- ExecuteNonQuery/CALL. On some servers the FUNCTION landed deterministically;
-- RTM CALL -> 42883 (no matching PROCEDURE). Fix = remove FUNCTION, keep PROCEDURE.
--
-- Idempotent: DROP IF EXISTS + CREATE OR REPLACE PROCEDURE
-- ============================================================================

-- NGC_CreateBusinessUnitQueueClassificationMapping: drop 3-param FUNCTION
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, uuid);

-- Ensure canonical 5-param PROCEDURE exists
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

-- NGC_CreateBusinessUnitSupergroupMapping: drop 3-param FUNCTION
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, uuid);

-- Ensure canonical 4-param PROCEDURE exists
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

-- NGC_CreateSupergroupAgentgroupMapping: drop 3-param FUNCTION
DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, uuid);

-- Ensure canonical 4-param PROCEDURE exists
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

-- §38a self-record (MANDATORY for db/migrations/ files)
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260613_012_drop_legacy_mapping_functions')
ON CONFLICT (migration_name) DO NOTHING;

-- ============================================================================
-- End of migration 20260613_012
-- ============================================================================