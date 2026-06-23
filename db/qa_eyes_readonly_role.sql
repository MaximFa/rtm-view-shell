-- QaEyes read-only PostgreSQL role
-- Run as superuser (postgres). Idempotent.

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'qa_eyes_ro') THEN
        CREATE ROLE qa_eyes_ro LOGIN PASSWORD 'CHANGE_ME_BEFORE_USE';
    END IF;
END
$$;

-- Grant USAGE on schemas
GRANT USAGE ON SCHEMA public TO qa_eyes_ro;
GRANT USAGE ON SCHEMA audit TO qa_eyes_ro;
GRANT USAGE ON SCHEMA identity TO qa_eyes_ro;

-- Grant SELECT on all existing tables in each schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO qa_eyes_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO qa_eyes_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA identity TO qa_eyes_ro;

-- Grant SELECT on future tables (so new migrations auto-grant)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO qa_eyes_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO qa_eyes_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT SELECT ON TABLES TO qa_eyes_ro;

-- Explicitly deny write operations (defense in depth)
-- Note: PostgreSQL default is no privileges, but we revoke just in case
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM qa_eyes_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA audit FROM qa_eyes_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA identity FROM qa_eyes_ro;

-- No sequence usage (prevents INSERT even if table privilege were granted by mistake)
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA public FROM qa_eyes_ro;
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA audit FROM qa_eyes_ro;
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA identity FROM qa_eyes_ro;

-- Verify: SELECT has_table_privilege('qa_eyes_ro', 'public.tenants', 'SELECT');  -- should be true
-- Verify: SELECT has_table_privilege('qa_eyes_ro', 'public.tenants', 'INSERT');  -- should be false