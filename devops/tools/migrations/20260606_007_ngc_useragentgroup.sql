-- Migration: 20260606_007_ngc_useragentgroup
-- Adds NGC_UserAgentgroup (agent->agentgroup membership) + Set/Delete SPs.
-- Idempotent: CREATE TABLE/INDEX IF NOT EXISTS, CREATE OR REPLACE FUNCTION, history ON CONFLICT.
\set ON_ERROR_STOP on
BEGIN;
CREATE TABLE IF NOT EXISTS public."NGC_UserAgentgroup" (
    "Id"              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "UserId"          character varying(100),
    "AgentgroupId"    character varying(100),
    "TenantId"        uuid NOT NULL,
    "CreatedDatetime" timestamp with time zone,
    "CreatedBy"       character varying(100)
);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId"
    ON public."NGC_UserAgentgroup" ("TenantId", "UserId", "AgentgroupId");
-- Register the BackendEmulation EF migration:
INSERT INTO public."__BackendEmulationMigrationsHistory" ("MigrationId","ProductVersion")
VALUES ('20260606205958_AddNgcUserAgentgroup','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;
COMMIT;

-- ============================================================================
-- 19. NGC_SetUserAgentgroup  (idempotent upsert; agent->agentgroup membership)
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_SetUserAgentgroup"(text, text, uuid);
CREATE OR REPLACE FUNCTION "NGC_SetUserAgentgroup"(
    p_user_id text,
    p_agentgroup_id text,
    p_tenant_id uuid
)
RETURNS void
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
-- ============================================================================
DROP FUNCTION IF EXISTS "NGC_DeleteUserAgentgroup"(text, text, uuid);
CREATE OR REPLACE FUNCTION "NGC_DeleteUserAgentgroup"(
    p_user_id text,
    p_agentgroup_id text,
    p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "NGC_UserAgentgroup"
    WHERE "TenantId" = p_tenant_id
      AND "UserId" = p_user_id
      AND "AgentgroupId" = p_agentgroup_id;
END;
$$;
