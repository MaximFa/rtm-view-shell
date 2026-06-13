-- 45 Dim B hotfix: NGC_CreateSupergroup — ensure ALL 3 canonical overloads
-- Compare 212532 Dim B: NGC_CreateSupergroup "expected PROCEDURE, server has FUNCTION" or missing
-- ROOT CAUSE: EF rebuild didn't reproduce the routine set (45-DRIFT class)
-- All 3 overloads are caller-backed:
--   GetScalar:360 -> FUNCTION(text,text,uuid)
--   GetScalar:288 -> FUNCTION(text,text,text,uuid)
--   ExecuteNonQuery:384 -> PROCEDURE(integer,text,text,text,uuid)

-- VERIFY BEFORE: current state of NGC_CreateSupergroup overloads
DO $$
DECLARE r record; cnt int := 0;
BEGIN
    RAISE NOTICE '=== NGC_CreateSupergroup BEFORE ===';
    FOR r IN SELECT proname, prokind, pg_get_function_identity_arguments(oid) AS args
             FROM pg_proc WHERE proname='NGC_CreateSupergroup' ORDER BY prokind, args
    LOOP
        RAISE NOTICE '  prokind=%, args=%', r.prokind, r.args;
        cnt := cnt + 1;
    END LOOP;
    IF cnt = 0 THEN RAISE NOTICE '  (no overloads found)'; END IF;
    RAISE NOTICE 'Count: %', cnt;
END $$;

-- KIND-AGNOSTIC DROP-ALL (clears any partial/stale overloads)
DO $drop_createsupergroup$
DECLARE r record;
BEGIN
    FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroup' LOOP
        IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
        ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text;
        END IF;
        RAISE NOTICE 'Dropped: %', r.sig::text;
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

-- VERIFY AFTER: must show exactly 3 overloads (2 'f' + 1 'p')
DO $$
DECLARE r record; cnt int := 0;
BEGIN
    RAISE NOTICE '=== NGC_CreateSupergroup AFTER ===';
    FOR r IN SELECT proname, prokind, pg_get_function_identity_arguments(oid) AS args
             FROM pg_proc WHERE proname='NGC_CreateSupergroup' ORDER BY prokind, args
    LOOP
        RAISE NOTICE '  prokind=%, args=%', r.prokind, r.args;
        cnt := cnt + 1;
    END LOOP;
    RAISE NOTICE 'Count: % (expected: 3)', cnt;
    IF cnt <> 3 THEN
        RAISE EXCEPTION 'VERIFY FAILED: expected 3 overloads, got %', cnt;
    END IF;
END $$;

SELECT proname, prokind, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc WHERE proname='NGC_CreateSupergroup' ORDER BY prokind, args;
