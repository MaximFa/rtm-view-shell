-- ============================================================================
-- NGC_* PL/pgSQL Functions for RTM Backend Migration
-- Output of RTM-M3 task
--
-- These functions replace SQL Server stored procedures called from
-- RTM/RTM/BusinessUnitData.cs via DBAdapter.
--
-- All identifiers are double-quoted (PostgreSQL case-sensitivity).
-- SERIAL columns use RETURNING for insert functions.
-- ============================================================================

-- ============================================================================
-- 1. NGC_GetBusinessUnitTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitTable"(p_tenant_id uuid)
RETURNS TABLE(
    "BusinessUnitId" integer,
    "TenantId" uuid,
    "BusinessUnitName" text,
    "Description" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text,
    "SiteId" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bu."BusinessUnitId",
        bu."TenantId",
        bu."BusinessUnitName"::text,
        bu."Description"::text,
        bu."CreatedDatetime",
        bu."CreatedBy"::text,
        bu."SiteId"::text
    FROM "NGC_BusinessUnit" bu
    WHERE bu."TenantId" = p_tenant_id
    ORDER BY bu."BusinessUnitId";
END;
$$;

-- ============================================================================
-- 1b. NGC_GetBusinessUnitIdByName — returns existing BusinessUnitId or NULL
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitIdByName"(text, uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitIdByName"(
    p_business_unit_name text,
    p_tenant_id uuid
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_id integer;
BEGIN
    SELECT "BusinessUnitId" INTO v_id
    FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitName" = p_business_unit_name
      AND "TenantId" = p_tenant_id
    LIMIT 1;
    RETURN v_id;  -- NULL if not found
END;
$$;


-- ============================================================================
-- 1c. NGC_GetOrCreateQueue - idempotent upsert into NGC_Queues
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetOrCreateQueue"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_GetOrCreateQueue"(
    p_external_id text,
    p_name text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_Queues" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 1d. NGC_GetOrCreateAgentGroup - idempotent upsert into NGC_AgentGroups
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetOrCreateAgentGroup"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_GetOrCreateAgentGroup"(
    p_external_id text,
    p_name text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_AgentGroups" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 1e. NGC_GetSupergroupIdByName - returns SupergroupId for existing supergroup or NULL
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSupergroupIdByName"(text, uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupIdByName"(
    p_name text,
    p_tenant_id uuid
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_id integer;
BEGIN
    SELECT "SupergroupId" INTO v_id
    FROM "NGC_Supergroup"
    WHERE "SupergroupName" = p_name
      AND "TenantId" = p_tenant_id
    LIMIT 1;
    RETURN v_id;
END;
$$;

-- ============================================================================
-- 2. NGC_GetSupergroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupTable"(p_tenant_id uuid)
RETURNS TABLE(
    "SupergroupId" integer,
    "TenantId" uuid,
    "SupergroupName" text,
    "Description" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text,
    "SupergroupIdOld" integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sg."SupergroupId",
        sg."TenantId",
        sg."SupergroupName"::text,
        sg."Description"::text,
        sg."CreatedDatetime",
        sg."CreatedBy"::text,
        sg."SupergroupIdOld"
    FROM "NGC_Supergroup" sg
    WHERE sg."TenantId" = p_tenant_id
    ORDER BY sg."SupergroupId";
END;
$$;

-- ============================================================================
-- 3. NGC_GetBusinessUnitQueueClassificationTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitQueueClassificationTable"(p_tenant_id uuid)
RETURNS TABLE(
    "BusinessUnitId" integer,
    "QueueId" text,
    "TenantId" uuid,
    "ClassificationId" text,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bq."BusinessUnitId",
        bq."QueueId"::text,
        bq."TenantId",
        bq."ClassificationId"::text,
        bq."CreatedDatetime",
        bq."CreatedBy"::text
    FROM "NGC_BusinessUnitQueueClassification" bq
    WHERE bq."TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 4. NGC_GetBusinessUnitSupergroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitSupergroupTable"(p_tenant_id uuid)
RETURNS TABLE(
    "BusinessUnitId" integer,
    "SupergroupId" integer,
    "TenantId" uuid,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        bs."BusinessUnitId",
        bs."SupergroupId",
        bs."TenantId",
        bs."CreatedDatetime",
        bs."CreatedBy"::text
    FROM "NGC_BusinessUnitSupergroup" bs
    WHERE bs."TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 5. NGC_GetSupergroupAgentgroupTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupAgentgroupTable"(p_tenant_id uuid)
RETURNS TABLE(
    "Id" integer,
    "SupergroupId" integer,
    "AgentgroupId" text,
    "TenantId" uuid,
    "CreatedDatetime" timestamptz,
    "CreatedBy" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa."Id",
        sa."SupergroupId",
        sa."AgentgroupId"::text,
        sa."TenantId",
        sa."CreatedDatetime",
        sa."CreatedBy"::text
    FROM "NGC_SupergroupAgentgroup" sa
    WHERE sa."TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 6. NGC_GetSiteTable
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_GetSiteTable"();
DROP FUNCTION IF EXISTS "NGC_GetSiteTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSiteTable"(p_tenant_id uuid)
RETURNS TABLE(
    "SiteId" text,
    "TenantId" uuid,
    "SiteName" text,
    "Description" text,
    "TimeZone" text,
    "ClearTime" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s."SiteId"::text,
        s."TenantId",
        s."SiteName"::text,
        s."Description"::text,
        s."TimeZone"::text,
        s."ClearTime"::text
    FROM "NGC_Site" s
    WHERE s."TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 7. NGC_CreateBusinessUnit
--    Returns generated BusinessUnitId (SERIAL)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,
    p_description text,
    p_tenant_id uuid
)
RETURNS TABLE("BusinessUnitId" integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_BusinessUnit" ("BusinessUnitName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_BusinessUnit"."BusinessUnitId";
END;
$$;

-- ============================================================================
-- 8. NGC_ModifyBusinessUnit
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text);
DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_ModifyBusinessUnit"(
    p_business_unit_id integer,
    p_business_unit_name text,
    p_description text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "NGC_BusinessUnit"
    SET "BusinessUnitName" = p_business_unit_name,
        "Description" = p_description
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 9. NGC_DeleteBusinessUnit
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 10. NGC_CreateSupergroup
--     Returns generated SupergroupId (SERIAL)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text);
DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description text,
    p_tenant_id uuid
)
RETURNS TABLE("SupergroupId" integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_name, p_description, NOW(), p_tenant_id)
    RETURNING "NGC_Supergroup"."SupergroupId";
END;
$$;

-- ============================================================================
-- 11. NGC_ModifySupergroup
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text);
DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_ModifySupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE "NGC_Supergroup"
    SET "SupergroupName" = p_supergroup_name,
        "Description" = p_description
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 12. NGC_DeleteSupergroup
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer);
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroup"(
    p_supergroup_id integer,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 13. NGC_CreateBusinessUnitQueueClassificationMapping
--     UPSERT: ON CONFLICT DO NOTHING (idempotent create)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId", "QueueId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "QueueId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 14. NGC_DeleteBusinessUnitQueueClassificationMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "QueueId" = p_queue_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 15. NGC_CreateBusinessUnitSupergroupMapping
--     UPSERT: ON CONFLICT DO NOTHING (idempotent create)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, NOW(), p_tenant_id)
    ON CONFLICT ("BusinessUnitId", "SupergroupId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 16. NGC_DeleteBusinessUnitSupergroupMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 17. NGC_CreateSupergroupAgentgroupMapping
--     Note: NGC_SupergroupAgentgroup has surrogate PK "Id" (SERIAL).
--     The logical uniqueness is (SupergroupId, AgentgroupId) but EF model
--     doesn't define a unique constraint on it. We use ON CONFLICT DO NOTHING
--     on the surrogate PK which means duplicates are possible.
--     If business logic requires uniqueness, add:
--       CREATE UNIQUE INDEX IF NOT EXISTS "IX_NGC_SupergroupAgentgroup_Logical"
--       ON "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId");
--     For now, simple INSERT matching original T-SQL behavior.
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, NOW(), p_tenant_id);
END;
$$;

-- ============================================================================
-- 18. NGC_DeleteSupergroupAgentgroupMapping
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- End of NGC_* functions (18 total)
-- ============================================================================
