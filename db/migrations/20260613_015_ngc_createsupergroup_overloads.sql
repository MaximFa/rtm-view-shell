-- Migration: 20260613_015_ngc_createsupergroup_overloads
-- Purpose: Ensure ALL 3 NGC_CreateSupergroup canonical overloads exist
-- Compare 212532 Dim B: NGC_CreateSupergroup "expected PROCEDURE, server has FUNCTION" or missing
-- ROOT CAUSE: EF rebuild didn't reproduce the routine set (45-DRIFT class)
-- All 3 overloads are caller-backed:
--   GetScalar:360 -> FUNCTION(text,text,uuid)
--   GetScalar:288 -> FUNCTION(text,text,text,uuid)
--   ExecuteNonQuery:384 -> PROCEDURE(integer,text,text,text,uuid)

-- KIND-AGNOSTIC DROP-ALL (clears any partial/stale overloads)
DO $drop_createsupergroup$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroup' LOOP
        IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text;
        END IF;
    END LOOP;
END $drop_createsupergroup$;

-- CREATE ALL 3 CANONICAL OVERLOADS (bodies from db/functions/01 HEAD)

-- Arity-3: (name, description, tenant_id) — GetScalar:360
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

-- Arity-4: (name, description, created_by, tenant_id) — GetScalar:288
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

-- Arity-5: (supergroup_id, name, description, created_by, tenant_id) — ExecuteNonQuery:384 (PROCEDURE)
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

-- Self-record in db_patch_history (§38a convention)
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260613_015_ngc_createsupergroup_overloads')
ON CONFLICT (migration_name) DO NOTHING;
