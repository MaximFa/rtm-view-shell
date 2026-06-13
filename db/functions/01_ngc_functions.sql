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
--     [FIX 42703] No CreatedDatetime — column does not exist on all servers
--     [FIX E-004] Id = gen_random_uuid(), IsActive = true
-- ============================================================================
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_getorcreatequeue$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_GetOrCreateQueue' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_getorcreatequeue$;

CREATE OR REPLACE PROCEDURE "NGC_GetOrCreateQueue"(
    p_external_id text,
    p_name text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_Queues" ("Id", "ExternalId", "Name", "IsActive", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 1d. NGC_GetOrCreateAgentGroup - idempotent upsert into NGC_AgentGroups
--     [FIX 42703] No CreatedDatetime — column does not exist on all servers
--     [FIX E-004] Id = gen_random_uuid(), IsActive = true
-- ============================================================================
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_getorcreateagentgroup$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_GetOrCreateAgentGroup' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_getorcreateagentgroup$;

CREATE OR REPLACE PROCEDURE "NGC_GetOrCreateAgentGroup"(
    p_external_id text,
    p_name text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_AgentGroups" ("Id", "ExternalId", "Name", "IsActive", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, p_tenant_id)
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
-- 7. NGC_CreateBusinessUnit — AUTHORITATIVE overload set from schema.sql
--    Arity-3: (text, text, uuid) FUNCTION RETURNS TABLE
--    Arity-5: (text, text, text, text, uuid) FUNCTION RETURNS TABLE
-- ============================================================================
-- Kind-agnostic DROP (drops whether FUNCTION or PROCEDURE - server drift tolerance)
DO $drop_createbusinessunit$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateBusinessUnit' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createbusinessunit$;

-- Arity-3: (name, description, tenant_id) — shell/basic caller
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

-- Arity-5: (name, description, site_id, created_by, tenant_id) — full caller
CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,
    p_description text,
    p_site_id text,
    p_created_by text,
    p_tenant_id uuid
)
RETURNS TABLE("BusinessUnitId" integer)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO "NGC_BusinessUnit" (
        "BusinessUnitName", "Description", "CreatedDatetime",
        "SiteId", "CreatedBy", "TenantId"
    )
    VALUES (
        p_business_unit_name, p_description, NOW(),
        p_site_id, p_created_by, p_tenant_id
    )
    RETURNING "NGC_BusinessUnit"."BusinessUnitId";
END;
$$;

-- ============================================================================
-- 8. NGC_ModifyBusinessUnit
-- ============================================================================
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_modifybusinessunit$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_ModifyBusinessUnit' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_modifybusinessunit$;

CREATE OR REPLACE PROCEDURE "NGC_ModifyBusinessUnit"(
    p_business_unit_id integer,
    p_business_unit_name text,
    p_description text,
    p_tenant_id uuid
)
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
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_deletebusinessunit$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_DeleteBusinessUnit' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_deletebusinessunit$;

CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 10. NGC_CreateSupergroup — AUTHORITATIVE overload set from schema.sql
--     Arity-3: (text, text, uuid) FUNCTION RETURNS TABLE
--     Arity-4: (text, text, text, uuid) FUNCTION RETURNS TABLE
--     Arity-5: (integer, text, text, text, uuid) PROCEDURE (upsert by id)
-- ============================================================================
-- Kind-agnostic DROP (drops whether FUNCTION or PROCEDURE - server drift tolerance)
DO $drop_createsupergroup$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroup' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createsupergroup$;

-- Arity-3: (name, description, tenant_id) — shell/basic caller (GetScalar)
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

-- Arity-4: (name, description, created_by, tenant_id) — with audit
CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description text,
    p_created_by text,
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

-- Arity-5: (supergroup_id, name, description, created_by, tenant_id) — upsert by id (ExecuteNonQuery)
CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text,
    p_created_by text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_Supergroup" ("SupergroupId", "SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_supergroup_name, p_description, NOW(), p_tenant_id)
    ON CONFLICT ("SupergroupId") DO UPDATE
    SET "SupergroupName" = EXCLUDED."SupergroupName",
        "Description"    = EXCLUDED."Description";
END;
$$;

-- ============================================================================
-- 11. NGC_ModifySupergroup
-- ============================================================================
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_modifysupergroup$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_ModifySupergroup' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_modifysupergroup$;

CREATE OR REPLACE PROCEDURE "NGC_ModifySupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text,
    p_tenant_id uuid
)
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
-- E-016: kind-agnostic DROP (handles function->procedure conversion on re-apply)
DO $drop_deletesupergroup$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_DeleteSupergroup' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_deletesupergroup$;

CREATE OR REPLACE PROCEDURE "NGC_DeleteSupergroup"(
    p_supergroup_id integer,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 13. NGC_CreateBusinessUnitQueueClassificationMapping — AUTHORITATIVE overload set
--     Arity-3: (integer, text, uuid) FUNCTION RETURNS void (Shell)
--     Arity-5: (integer, text, text, text, uuid) PROCEDURE (RTM full)
-- ============================================================================
-- Kind-agnostic DROP
DO $drop_createbusinessunitqueueclassificationmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateBusinessUnitQueueClassificationMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createbusinessunitqueueclassificationmapping$;

-- Arity-3: (bu_id, queue_id, tenant_id) FUNCTION RETURNS void — Shell caller (SELECT fn())
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

-- Arity-5: (bu_id, queue_id, classification_id, created_by, tenant_id) PROCEDURE — RTM (CALL)
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

-- ============================================================================
-- 14. NGC_DeleteBusinessUnitQueueClassificationMapping — AUTHORITATIVE overload set
--     Arity-3: (integer, text, uuid) FUNCTION RETURNS void
--     Arity-4: (integer, text, text, uuid) PROCEDURE
-- ============================================================================
-- Kind-agnostic DROP
DO $drop_deletebusinessunitqueueclassificationmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_DeleteBusinessUnitQueueClassificationMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_deletebusinessunitqueueclassificationmapping$;

-- Arity-3: (bu_id, queue_id, tenant_id) FUNCTION RETURNS void — Shell
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

-- Arity-4: (bu_id, queue_id, classification_id, tenant_id) PROCEDURE — RTM
CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_classification_id text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId"   = p_business_unit_id
      AND "QueueId"          = p_queue_id
      AND "TenantId"         = p_tenant_id;
END;
$$;

-- ============================================================================
-- 15. NGC_CreateBusinessUnitSupergroupMapping — AUTHORITATIVE overload set
--     Arity-3: (integer, integer, uuid) FUNCTION RETURNS void
--     Arity-4: (integer, integer, text, uuid) PROCEDURE
-- ============================================================================
-- Kind-agnostic DROP
DO $drop_createbusinessunitsupergroupmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateBusinessUnitSupergroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createbusinessunitsupergroupmapping$;

-- Arity-3: (bu_id, supergroup_id, tenant_id) FUNCTION RETURNS void — Shell
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

-- Arity-4: (bu_id, supergroup_id, created_by, tenant_id) PROCEDURE — RTM
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

-- ============================================================================
-- 16. NGC_DeleteBusinessUnitSupergroupMapping
-- ============================================================================
-- E-016: kind-agnostic DROP
DO $drop_deletebusinessunitsupergroupmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_DeleteBusinessUnitSupergroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_deletebusinessunitsupergroupmapping$;

CREATE OR REPLACE PROCEDURE "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_tenant_id uuid
)
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
-- 17. NGC_CreateSupergroupAgentgroupMapping — AUTHORITATIVE overload set
--     Arity-3: (integer, text, uuid) FUNCTION RETURNS void
--     Arity-4: (integer, text, text, uuid) PROCEDURE
-- ============================================================================
-- Kind-agnostic DROP
DO $drop_createsupergroupagentgroupmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroupAgentgroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createsupergroupagentgroupmapping$;

-- Arity-3: (supergroup_id, agentgroup_id, tenant_id) FUNCTION RETURNS void — Shell
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

-- Arity-4: (supergroup_id, agentgroup_id, created_by, tenant_id) PROCEDURE — RTM
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
-- 18. NGC_DeleteSupergroupAgentgroupMapping
-- ============================================================================
-- E-016: kind-agnostic DROP
DO $drop_deletesupergroupagentgroupmapping$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_DeleteSupergroupAgentgroupMapping' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_deletesupergroupagentgroupmapping$;

CREATE OR REPLACE PROCEDURE "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id uuid
)
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
-- 19. NGC_SetUserAgentgroup  (idempotent upsert; agent->agentgroup membership)
--     PROCEDURE (not FUNCTION) — RTM DBAdapter uses CALL [RTM-SEC-002]
-- ============================================================================
DROP ROUTINE IF EXISTS "NGC_SetUserAgentgroup"(text, text, uuid);
CREATE PROCEDURE "NGC_SetUserAgentgroup"(
    p_user_id text,
    p_agentgroup_id text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "NGC_UserAgentgroup" ("UserId", "AgentgroupId", "CreatedDatetime", "TenantId")
    VALUES (p_user_id, p_agentgroup_id, NOW(), p_tenant_id)
    ON CONFLICT ("TenantId", "UserId", "AgentgroupId") DO NOTHING;
END;
$$;

-- ============================================================================
-- 20. NGC_DeleteUserAgentgroup
--     PROCEDURE (not FUNCTION) — RTM DBAdapter uses CALL [RTM-SEC-002]
-- ============================================================================
DROP ROUTINE IF EXISTS "NGC_DeleteUserAgentgroup"(text, text, uuid);
CREATE PROCEDURE "NGC_DeleteUserAgentgroup"(
    p_user_id text,
    p_agentgroup_id text,
    p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_UserAgentgroup"
    WHERE "TenantId" = p_tenant_id
      AND "UserId" = p_user_id
      AND "AgentgroupId" = p_agentgroup_id;
END;
$$;

-- ============================================================================
-- End of NGC_* functions (20 total + additional overloads)
-- ============================================================================