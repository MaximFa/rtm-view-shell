-- 234: mark as applied in db_patch_history the 2 migrations PROVEN applied by probe (2026-07-03):
--   20260605_004_metrics_dedup      (RTSGrid_Cell.Value renames done: old_refs=0)
--   20260606_008_daytrend_fn_bu_scope (server fn sig == _008 CREATE sig)
-- These are NOT re-applied (objects already correct); the ledger row stops Compare flagging UNKNOWN.
INSERT INTO public.db_patch_history (migration_name) VALUES
  ('20260605_004_metrics_dedup'),
  ('20260606_008_daytrend_fn_bu_scope')
ON CONFLICT (migration_name) DO NOTHING;
SELECT migration_name FROM public.db_patch_history
 WHERE migration_name IN ('20260605_004_metrics_dedup','20260606_008_daytrend_fn_bu_scope') ORDER BY 1;
