# Task: Fix duplicate NGC_BusinessUnit rows on RTM Service restart

## Problem

On every restart of RTM Service, `NGC_BusinessUnit` and `NGC_BusinessUnitQueueClassification`
get duplicate rows for every queue received from the CC platform.

Root cause: `Engine.cs` has an in-memory check (`_workgroupManagerList.ContainsKey(id)`)
that prevents duplicates **within one session**. But on restart the list is empty, so every
queue triggers `BusinessUnitData.createBusinessUnit()` → which calls `NGC_CreateBusinessUnit`
→ plain INSERT, no existence check → duplicate rows every restart.

`NGC_BusinessUnitQueueClassification` is protected (`ON CONFLICT DO NOTHING`) — not the issue.
`NGC_BusinessUnit` has no such protection — this is where duplicates accumulate.

## Fix

**Two-part fix:**

### Part 1 — New SQL function `NGC_GetBusinessUnitIdByName`

In `RTM/sql/pgsql/01_ngc_functions.sql`, add a new function **after the existing
`NGC_GetBusinessUnitTable` block** (after line ~43, before the `NGC_GetSupergroupTable` block):

```sql
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
```

### Part 2 — Modify `BusinessUnitData.createBusinessUnit()` in C#

File: `RTM/RTM/BusinessUnitData.cs`

Replace the existing `createBusinessUnit` method with an idempotent version:

```csharp
//  Create BusinessUnit (idempotent: returns existing ID if name already exists)
public static int createBusinessUnit(string name, string description, string siteId, string createdBy)
{
    int retVal = 0;
    try
    {
        // Step 1: check if already exists
        var checkParams = new List<NpgsqlParameter>();
        checkParams.Add(new NpgsqlParameter("@BusinessUnitName", name));
        checkParams.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        var existingScalar = DBAdapter.GetScalar("NGC_GetBusinessUnitIdByName", checkParams);

        if (existingScalar != null && existingScalar != DBNull.Value)
        {
            int existingId = Convert.ToInt32(existingScalar);
            AsyncLogger.Info($"createBusinessUnit: existing BU found name={name} id={existingId} (skipping INSERT)");
            return existingId;
        }

        // Step 2: insert new
        var parameters = new List<NpgsqlParameter>();
        parameters.Add(new NpgsqlParameter("@BusinessUnitName", name));
        parameters.Add(new NpgsqlParameter("@Description", description));
        parameters.Add(new NpgsqlParameter("@SiteId", siteId));
        parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
        parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        int businessUnitID = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateBusinessUnit", parameters));

        AsyncLogger.Info($"createBusinessUnit: new BU created name={name} id={businessUnitID}");
        retVal = businessUnitID;
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createBusinessUnit", ex);
    }

    return retVal;
}
```

### Part 3 — Staging deployment script

Create `RTM/staging/fix_bu_idempotent.sql` with the new SQL function only (for deployment
to the server without re-running the full 01_ngc_functions.sql):

```sql
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
```

## File write rules (MANDATORY)

- Use Python with `os.fsync()` for ALL file writes — Edit tool is BANNED in this repo
- After every write: `sync && tail -3 <path> && wc -l <path>`
- Working directory: `D:\Claude\Projects\RTM View Shell`

## Pre-commit check (MANDATORY)

```bash
bash tools/pre-commit-check.sh
```
Only commit if exit code 0.

## Commit message

```
fix(RTM): idempotent createBusinessUnit — check existence before INSERT

NGC_GetBusinessUnitIdByName SQL function added.
BusinessUnitData.createBusinessUnit() now returns existing ID
if a BU with same name+TenantId already exists, preventing
duplicate rows on every RTM Service restart.

Staging: RTM/staging/fix_bu_idempotent.sql for server deployment.
```

## Post-commit re-sync (MANDATORY)

```bash
for f in RTM/sql/pgsql/01_ngc_functions.sql RTM/RTM/BusinessUnitData.cs RTM/staging/fix_bu_idempotent.sql; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
