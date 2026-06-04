-- Fix NGC function signatures that don't match C# calls
-- NGC_CreateBusinessUnit: C# sends (Name, Description, SiteId, CreatedBy, TenantId)
--   = (text, text, text, text, uuid) — 5 params
--   CC created with 3 params (text, text, uuid) — SiteId and CreatedBy missing
-- NGC_CreateSupergroup: C# sends (Name, Description, CreatedBy, TenantId)
--   = (text, text, text, uuid) — 4 params, check needed

-- ============================================================
-- 1. NGC_CreateBusinessUnit (text, text, text, text, uuid)
-- ============================================================
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text, uuid);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text, text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,  -- @BusinessUnitName
    p_description        text,  -- @Description
    p_site_id            text,  -- @SiteId (accepted, stored if column exists)
    p_created_by         text,  -- @CreatedBy (accepted, stored if column exists)
    p_tenant_id          uuid   -- @TenantId
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

-- ============================================================
-- 2. Verify NGC_CreateBusinessUnit columns exist
-- If SiteId or CreatedBy columns are missing, add them
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'NGC_BusinessUnit' AND column_name = 'SiteId'
    ) THEN
        ALTER TABLE "NGC_BusinessUnit" ADD COLUMN "SiteId" text;
        RAISE NOTICE 'Added SiteId column to NGC_BusinessUnit';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'NGC_BusinessUnit' AND column_name = 'CreatedBy'
    ) THEN
        ALTER TABLE "NGC_BusinessUnit" ADD COLUMN "CreatedBy" text;
        RAISE NOTICE 'Added CreatedBy column to NGC_BusinessUnit';
    END IF;
END;
$$;

-- ============================================================
-- 3. Verify NGC_CreateSupergroup signature
-- C# sends (Name, Description, CreatedBy, TenantId) = (text, text, text, uuid)
-- ============================================================
SELECT proname, pg_get_function_arguments(oid) AS args
FROM pg_proc
WHERE proname IN ('NGC_CreateBusinessUnit', 'NGC_CreateSupergroup')
ORDER BY proname;
