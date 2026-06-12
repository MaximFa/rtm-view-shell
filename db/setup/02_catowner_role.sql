-- db/setup/02_catowner_role.sql
-- Least-privilege role for CcDashboard.ApplyService (hot-reload metrics). Idempotent.
-- NOTE: psql :'var' does NOT substitute inside DO $$...$$ — pass via session GUC set at top level.
SELECT set_config('ccdashboard.catowner_pw', :'catowner_pw', false);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ccdashboard_catowner') THEN
    EXECUTE format('CREATE ROLE ccdashboard_catowner LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  ELSE
    EXECUTE format('ALTER ROLE ccdashboard_catowner WITH LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  END IF;
END $$;

GRANT USAGE ON SCHEMA public, audit TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public."RTSGrid_Metric"   TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.metric_deploy_log  TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.db_patch_history   TO ccdashboard_catowner;
GRANT INSERT         ON audit.audit_logs          TO ccdashboard_catowner;