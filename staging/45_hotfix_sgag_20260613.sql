-- 45 hotfix: Add uq_supergroup_agentgroup unique constraint (table drift fix)
-- Canonical constraint from schema.sql HEAD:3487: UNIQUE ("SupergroupId","AgentgroupId")
-- Required by NGC_CreateSupergroupAgentgroupMapping ON CONFLICT clause
-- Error 42P10 without it: there is no unique or exclusion constraint matching ON CONFLICT

-- STEP 1: Dedup guard - remove duplicate (SupergroupId, AgentgroupId) rows if any exist
-- Keep the row with MIN("Id") for each (SG, AG) pair
DO $dedup_sgag$
DECLARE
    dup_count integer;
BEGIN
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "SupergroupId", "AgentgroupId"
        FROM "NGC_SupergroupAgentgroup"
        GROUP BY "SupergroupId", "AgentgroupId"
        HAVING COUNT(*) > 1
    ) dups;

    IF dup_count > 0 THEN
        RAISE NOTICE 'DEDUP: Found % duplicate (SupergroupId, AgentgroupId) pairs - removing extras', dup_count;

        DELETE FROM "NGC_SupergroupAgentgroup" a
        USING (
            SELECT "SupergroupId", "AgentgroupId", MIN("Id") AS keep_id
            FROM "NGC_SupergroupAgentgroup"
            GROUP BY "SupergroupId", "AgentgroupId"
            HAVING COUNT(*) > 1
        ) dups
        WHERE a."SupergroupId" = dups."SupergroupId"
          AND a."AgentgroupId" = dups."AgentgroupId"
          AND a."Id" <> dups.keep_id;

        RAISE NOTICE 'DEDUP: Removed % duplicate rows', (SELECT COUNT(*) FROM "NGC_SupergroupAgentgroup" WHERE FALSE);
    ELSE
        RAISE NOTICE 'DEDUP: No duplicate (SupergroupId, AgentgroupId) pairs found - OK';
    END IF;
END $dedup_sgag$;

-- STEP 2: Add the canonical unique constraint (idempotent - guarded IF NOT EXISTS)
DO $add_uq_sgag$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_supergroup_agentgroup'
          AND conrelid = '"NGC_SupergroupAgentgroup"'::regclass
    ) THEN
        ALTER TABLE "NGC_SupergroupAgentgroup"
        ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId", "AgentgroupId");
        RAISE NOTICE 'ADDED constraint uq_supergroup_agentgroup';
    ELSE
        RAISE NOTICE 'SKIP: constraint uq_supergroup_agentgroup already exists';
    END IF;
END $add_uq_sgag$;

-- VERIFY: constraint now exists
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = '"NGC_SupergroupAgentgroup"'::regclass
  AND conname = 'uq_supergroup_agentgroup';
