# Task: Sync NGC_Queues and NGC_AgentGroups on RTM Service initialization

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Context
RTM Service receives queues and skills from CC platform (Twilio) at startup.
Currently these are only stored in memory. They must also be persisted to
NGC_Queues and NGC_AgentGroups tables so the Shell can show them in
Permission Groups management.

---

## Part 1 — NGC_Queues: sync queues on initialization

### Where it happens
`RTM/RTM/Engine.cs` — the `UnionQueueClassifications` loop (~line 420).
When `ClassificationId == "ALL"` and `!union.Queues.Contains(QueueId)` — a new
queue is confirmed and added. At this point, QueueId must also be upserted into
`NGC_Queues`.

### New SQL function — add to `RTM/sql/pgsql/01_ngc_functions.sql`

Add after the `NGC_GetBusinessUnitIdByName` block:

```sql
-- ============================================================================
-- 1c. NGC_GetOrCreateQueue — idempotent upsert into NGC_Queues
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
```

### New C# method — add to `RTM/RTM/BusinessUnitData.cs`

Add after `createBusinessUnit`:

```csharp
// Upsert queue into NGC_Queues (idempotent)
public static void getOrCreateQueue(string externalId, string name)
{
    try
    {
        var parameters = new List<NpgsqlParameter>();
        parameters.Add(new NpgsqlParameter("@ExternalId", externalId));
        parameters.Add(new NpgsqlParameter("@Name", name));
        parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        DBAdapter.ExecuteNonQuery("NGC_GetOrCreateQueue", parameters);
        AsyncLogger.Info($"getOrCreateQueue: upserted queue={externalId}");
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getOrCreateQueue", ex);
    }
}
```

### Change in `Engine.cs`

In the `UnionQueueClassifications` loop, inside `else if (ClassificationId == "ALL")`:

```csharp
else if (ClassificationId == "ALL")
{
    updatedUnion.Add(QueueId);
    if (!union.Queues.Contains(QueueId))
    {
        union.Queues.Add(QueueId);
        union.addWorkgroup(QueueId, _applicList);
        newUnions.Add(union);
        // *** ADD THIS LINE ***
        BusinessUnitData.getOrCreateQueue(QueueId, QueueId);
    }
}
```

---

## Part 2 — NGC_AgentGroups + NGC_Supergroup: sync skills from Twilio

### Where it happens
`RTM/RTM/Engine.cs` — method `setSkills(List<string> skills, ...)` (~line 1909).
Currently only does `Agentgroups.TryAdd(skill, true)`. Must also persist each skill
to NGC_AgentGroups, then create a matching NGC_Supergroup, then link them.

### New SQL functions — add to `RTM/sql/pgsql/01_ngc_functions.sql`

Add after the NGC_GetOrCreateQueue block:

```sql
-- ============================================================================
-- 1d. NGC_GetOrCreateAgentGroup — idempotent upsert into NGC_AgentGroups
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
-- 1e. NGC_GetSupergroupIdByName — returns SupergroupId for existing supergroup or NULL
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
```

### New C# methods — add to `RTM/RTM/BusinessUnitData.cs`

```csharp
// Upsert agent group into NGC_AgentGroups (idempotent)
public static void getOrCreateAgentGroup(string externalId, string name)
{
    try
    {
        var parameters = new List<NpgsqlParameter>();
        parameters.Add(new NpgsqlParameter("@ExternalId", externalId));
        parameters.Add(new NpgsqlParameter("@Name", name));
        parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        DBAdapter.ExecuteNonQuery("NGC_GetOrCreateAgentGroup", parameters);
        AsyncLogger.Info($"getOrCreateAgentGroup: upserted agentGroup={externalId}");
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getOrCreateAgentGroup", ex);
    }
}

// Get SupergroupId by name, or create if not exists. Returns SupergroupId.
public static int getOrCreateSupergroup(string name, string description)
{
    int supergroupId = 0;
    try
    {
        // Check if exists
        var checkParams = new List<NpgsqlParameter>();
        checkParams.Add(new NpgsqlParameter("@Name", name));
        checkParams.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        var existingScalar = DBAdapter.GetScalar("NGC_GetSupergroupIdByName", checkParams);

        if (existingScalar != null && existingScalar != DBNull.Value)
        {
            supergroupId = Convert.ToInt32(existingScalar);
            AsyncLogger.Info($"getOrCreateSupergroup: existing supergroup={name} id={supergroupId}");
            return supergroupId;
        }

        // Create new
        var createParams = new List<NpgsqlParameter>();
        createParams.Add(new NpgsqlParameter("@SupergroupName", name));
        createParams.Add(new NpgsqlParameter("@Description", description));
        createParams.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
        supergroupId = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateSupergroup", createParams));
        AsyncLogger.Info($"getOrCreateSupergroup: created supergroup={name} id={supergroupId}");
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getOrCreateSupergroup", ex);
    }
    return supergroupId;
}
```

### Change in `Engine.cs` — `setSkills` method

Replace the current body of `setSkills`:

```csharp
public bool setSkills(List<string> skills, DateTime timeStamp, long messageId)
{
    try
    {
        AsyncLogger.Info("setSkils count=" + skills.Count);

        foreach (string skill in skills)
        {
            Agentgroups.TryAdd(skill, true);

            // Persist to NGC_AgentGroups
            BusinessUnitData.getOrCreateAgentGroup(skill, skill);

            // Get or create matching Supergroup
            int supergroupId = BusinessUnitData.getOrCreateSupergroup(skill, skill);

            // Create Supergroup <-> AgentGroup link
            if (supergroupId > 0)
            {
                BusinessUnitData.createSupergroupAgentgroupMapping(supergroupId, skill, "system");
            }
        }
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("Engine.setSkils", ex);
    }
    return true;
}
```

---

## Part 3 — Staging SQL for server deployment

Create `RTM/staging/fix_ngc_queues_agentgroups.sql`:

```sql
-- Fix: create NGC_Queues and NGC_AgentGroups tables + sync functions
-- Deploy: psql -U postgres -d rtmviewdb -f RTM/staging/fix_ngc_queues_agentgroups.sql

-- NGC_Queues table
CREATE TABLE IF NOT EXISTS "NGC_Queues" (
    "QueueId"         SERIAL PRIMARY KEY,
    "ExternalId"      text NOT NULL,
    "Name"            text NOT NULL,
    "CreatedDatetime" timestamptz DEFAULT NOW(),
    "TenantId"        uuid NOT NULL,
    UNIQUE ("ExternalId", "TenantId")
);

-- NGC_AgentGroups table
CREATE TABLE IF NOT EXISTS "NGC_AgentGroups" (
    "AgentGroupId"    SERIAL PRIMARY KEY,
    "ExternalId"      text NOT NULL,
    "Name"            text NOT NULL,
    "CreatedDatetime" timestamptz DEFAULT NOW(),
    "TenantId"        uuid NOT NULL,
    UNIQUE ("ExternalId", "TenantId")
);

-- Function: NGC_GetOrCreateQueue
DROP FUNCTION IF EXISTS "NGC_GetOrCreateQueue"(text, text, uuid);
CREATE OR REPLACE FUNCTION "NGC_GetOrCreateQueue"(
    p_external_id text, p_name text, p_tenant_id uuid
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_Queues" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END; $$;

-- Function: NGC_GetOrCreateAgentGroup
DROP FUNCTION IF EXISTS "NGC_GetOrCreateAgentGroup"(text, text, uuid);
CREATE OR REPLACE FUNCTION "NGC_GetOrCreateAgentGroup"(
    p_external_id text, p_name text, p_tenant_id uuid
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO "NGC_AgentGroups" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
END; $$;

-- Function: NGC_GetSupergroupIdByName
DROP FUNCTION IF EXISTS "NGC_GetSupergroupIdByName"(text, uuid);
CREATE OR REPLACE FUNCTION "NGC_GetSupergroupIdByName"(
    p_name text, p_tenant_id uuid
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    SELECT "SupergroupId" INTO v_id FROM "NGC_Supergroup"
    WHERE "SupergroupName" = p_name AND "TenantId" = p_tenant_id LIMIT 1;
    RETURN v_id;
END; $$;

SELECT 'NGC_Queues + NGC_AgentGroups + 3 functions deployed OK' AS status;
```

---

## File write rules (MANDATORY)
- Python + `os.fsync()` for ALL writes — Edit tool is BANNED
- After every write: `sync && tail -3 <path> && wc -l <path>`

## Pre-commit check (MANDATORY)
```bash
bash tools/pre-commit-check.sh
```
Only commit if exit code 0.

## Commit message
```
feat(RTM): sync NGC_Queues and NGC_AgentGroups on initialization

- NGC_Queues: queues upserted on UnionQueueClassification load
- NGC_AgentGroups: skills upserted from Twilio setSkills()
- NGC_Supergroup + NGC_SupergroupAgentgroup: created per skill
- 3 new SQL functions: GetOrCreateQueue, GetOrCreateAgentGroup,
  GetSupergroupIdByName
- Staging: fix_ngc_queues_agentgroups.sql for server deployment
```

## Post-commit re-sync (MANDATORY)
```bash
for f in RTM/sql/pgsql/01_ngc_functions.sql RTM/RTM/BusinessUnitData.cs RTM/RTM/Engine.cs RTM/staging/fix_ngc_queues_agentgroups.sql; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
