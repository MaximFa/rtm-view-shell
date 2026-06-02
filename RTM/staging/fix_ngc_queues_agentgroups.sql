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
