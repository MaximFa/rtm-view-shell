-- 20260607_002_db_patch_history.sql
-- Creates the migration ledger. From this migration onward, every migration self-records
-- its filename here on apply, so Compare-ToBaseline dimension D becomes EXACT (not heuristic).
-- Pre-ledger migrations are NOT backfilled here (Compare probes them); see CLAUDE.md §38a.
-- Fresh installs: Create-FreshDb.ps1/Restore-All.ps1 apply migrations name-ordered, so _002
-- creates the table before any later migration self-records.
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS public.db_patch_history (
    migration_name text PRIMARY KEY,
    applied_at     timestamptz NOT NULL DEFAULT now()
);

-- self-record this migration
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260607_002_db_patch_history')
ON CONFLICT (migration_name) DO NOTHING;