-- Migration: 20260606_009_ngc_useragentgroup_procedures
-- Convert NGC_Set/DeleteUserAgentgroup FUNCTION -> PROCEDURE (RTM DBAdapter uses CALL; 42809 on function).
-- Idempotent: DROP ROUTINE IF EXISTS (works for function or procedure) + CREATE PROCEDURE.
\set ON_ERROR_STOP on

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

-- Verify: both must be prokind='p' (procedure)
SELECT proname, prokind FROM pg_proc
WHERE proname IN ('NGC_SetUserAgentgroup','NGC_DeleteUserAgentgroup') ORDER BY proname;
