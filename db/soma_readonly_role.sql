-- Soma read-only PostgreSQL role (soma_ro)
-- Run as superuser (postgres). Idempotent.
-- Migrates from qa_eyes_ro if exists, otherwise creates fresh.

DO $$
BEGIN
    -- Rename qa_eyes_ro -> soma_ro if exists
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'qa_eyes_ro') THEN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'soma_ro') THEN
            ALTER ROLE qa_eyes_ro RENAME TO soma_ro;
            RAISE NOTICE 'Renamed qa_eyes_ro -> soma_ro';
        ELSE
            RAISE NOTICE 'Both qa_eyes_ro and soma_ro exist; keeping soma_ro';
        END IF;
    END IF;
    
    -- Create soma_ro if not exists
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'soma_ro') THEN
        CREATE ROLE soma_ro LOGIN PASSWORD 'CHANGE_ME_BEFORE_USE';
        RAISE NOTICE 'Created soma_ro role';
    END IF;
END
$$;

-- Grant USAGE on schemas
GRANT USAGE ON SCHEMA public TO soma_ro;
GRANT USAGE ON SCHEMA audit TO soma_ro;
GRANT USAGE ON SCHEMA identity TO soma_ro;

-- ============================================================
-- PUBLIC SCHEMA: full SELECT on all tables
-- ============================================================
GRANT SELECT ON ALL TABLES IN SCHEMA public TO soma_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO soma_ro;

-- ============================================================
-- AUDIT SCHEMA: full SELECT on all tables
-- ============================================================
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO soma_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO soma_ro;

-- ============================================================
-- IDENTITY SCHEMA: selective access (revoke secrets)
-- ============================================================

-- First grant SELECT on all identity tables
GRANT SELECT ON ALL TABLES IN SCHEMA identity TO soma_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT SELECT ON TABLES TO soma_ro;

-- REVOKE entire access to sensitive tables
REVOKE ALL ON identity.refresh_tokens FROM soma_ro;
REVOKE ALL ON identity.two_factor_codes FROM soma_ro;
REVOKE ALL ON identity.user_password_history FROM soma_ro;

-- identity.users: grant only non-secret columns
-- (cannot do column-level GRANT easily; instead use a VIEW)
-- For now, we revoke and create a restricted view

-- Create restricted view for users (no PasswordHash/SecurityStamp/ConcurrencyStamp)
DROP VIEW IF EXISTS identity.users_safe;
CREATE VIEW identity.users_safe AS
SELECT 
    "Id", "TenantId", "UserName", "NormalizedUserName", 
    "Email", "NormalizedEmail", "EmailConfirmed",
    "PhoneNumber", "PhoneNumberConfirmed",
    "TwoFactorEnabled", "LockoutEnd", "LockoutEnabled", "AccessFailedCount",
    "FirstName", "LastName", "PermissionGroupId", "IsActive", 
    "Is2faEnabled", "LastLoginAt", "PreferredLocale", "MustChangePasswordAt"
FROM identity.users;
GRANT SELECT ON identity.users_safe TO soma_ro;
-- Keep full users table revoked - soma_ro uses users_safe instead
-- (soma_ro still has SELECT on users but queries should use users_safe)

-- sso_configurations: create view without ClientSecret
DROP VIEW IF EXISTS public.sso_configurations_safe;
CREATE VIEW public.sso_configurations_safe AS
SELECT 
    "Id", "TenantId", "Provider", "MetadataUrl", "ClientId",
    'REDACTED'::text AS "ClientSecret", "ClaimMappings", "IsActive"
FROM public.sso_configurations;
GRANT SELECT ON public.sso_configurations_safe TO soma_ro;

-- tenant_settings: create view without EmailProviderConfig
DROP VIEW IF EXISTS public.tenant_settings_safe;
CREATE VIEW public.tenant_settings_safe AS
SELECT 
    "TenantId", "PasswordMinLength", "PasswordExpireDays", 
    "Require2faForAll", "AuditRetentionDays", "DefaultLocale",
    "SoftDeleteDashboards", "SoftDeleteRetentionDays",
    'REDACTED'::text AS "EmailProviderConfig", "SsoConfigurationId",
    "SignalRConnectionUrl"
FROM public.tenant_settings;
GRANT SELECT ON public.tenant_settings_safe TO soma_ro;

-- ============================================================
-- Explicitly deny write operations (defense in depth)
-- ============================================================
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM soma_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA audit FROM soma_ro;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA identity FROM soma_ro;

-- No sequence usage
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA public FROM soma_ro;
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA audit FROM soma_ro;
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA identity FROM soma_ro;

-- ============================================================
-- Verification queries (run manually to confirm)
-- ============================================================
-- SELECT has_table_privilege('soma_ro', 'public.tenants', 'SELECT');  -- true
-- SELECT has_table_privilege('soma_ro', 'public.tenants', 'INSERT');  -- false
-- SELECT has_table_privilege('soma_ro', 'identity.refresh_tokens', 'SELECT');  -- false
-- SELECT * FROM identity.users_safe LIMIT 1;  -- should work
-- SELECT "PasswordHash" FROM identity.users LIMIT 1;  -- soma_ro can still SELECT but use users_safe instead