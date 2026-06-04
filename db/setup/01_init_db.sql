-- ============================================================================
-- RTM View Shell — Initial Database Setup
-- Run as PostgreSQL superuser (postgres) ONCE before first install.
-- Usage: psql -U postgres -f db/setup/01_init_db.sql
-- ============================================================================

-- 1. Create app user (skip if exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ccdashboard_user') THEN
        CREATE USER ccdashboard_user WITH PASSWORD 'CHANGE_ME';
        RAISE NOTICE 'Created user ccdashboard_user';
    ELSE
        RAISE NOTICE 'User ccdashboard_user already exists';
    END IF;
END
$$;

-- 2. Create database (run manually if DB does not exist yet)
-- Cannot be run inside a transaction; execute separately if needed:
--   CREATE DATABASE rtmviewdb OWNER ccdashboard_user ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';

-- 3. Connect to target database and configure
\connect rtmviewdb

-- 4. Enable extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 5. Grant privileges
GRANT ALL PRIVILEGES ON DATABASE rtmviewdb TO ccdashboard_user;
GRANT ALL ON SCHEMA public TO ccdashboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ccdashboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ccdashboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ccdashboard_user;

-- Note: identity and audit schemas are created by EF migrations on first Shell startup.
-- After Shell runs, grant access to those schemas:
--   GRANT ALL ON SCHEMA identity TO ccdashboard_user;
--   GRANT ALL ON SCHEMA audit TO ccdashboard_user;

\echo 'Init complete. Next: start Shell to run EF migrations.'
