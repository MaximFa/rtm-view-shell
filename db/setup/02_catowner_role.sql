-- db/setup/02_catowner_role.sql
-- Purpose: Create least-privilege role for CcDashboard.ApplyService (hot-reload metrics)
-- Run: psql -U postgres -d <db> -v catowner_pw='<generated>' -f 02_catowner_role.sql
-- Idempotent: safe to re-run.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ccdashboard_catowner') THEN
    EXECUTE format('CREATE ROLE ccdashboard_catowner LOGIN PASSWORD %L', :'catowner_pw');
  ELSE
    EXECUTE format('ALTER ROLE ccdashboard_catowner WITH LOGIN PASSWORD %L', :'catowner_pw');
  END IF;
END $$;

-- Schema access
GRANT USAGE ON SCHEMA public, audit TO ccdashboard_catowner;

-- Table grants (least-privilege: only what apply-service needs)
GRANT INSERT, SELECT ON public."RTSGrid_Metric"   TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.metric_deploy_log  TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.db_patch_history   TO ccdashboard_catowner;
GRANT INSERT         ON audit.audit_logs          TO ccdashboard_catowner;