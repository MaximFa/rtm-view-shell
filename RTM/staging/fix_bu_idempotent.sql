-- Fix: idempotent createBusinessUnit — prevents duplicates on RTM Service restart
-- Deploy this on server: psql -U postgres -d RTMViewDB -f fix_bu_idempotent.sql

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
    RETURN v_id;
END;
$$;

SELECT 'NGC_GetBusinessUnitIdByName deployed OK' AS status;
