-- 20260613_001_backfill_metric_deploy_log.sql
-- Backfill metric_deploy_log with every metric already live in RTSGrid_Metric.
-- 234 iter-1: baseline seeds RTSGrid_Metric directly (not via hot-reload) -> ledger empty -> Deploy tab shows
-- every metric as undeployed. Make the ledger COMPLETE. Idempotent; safe to re-run. §38a self-record.
\set ON_ERROR_STOP on

INSERT INTO public.metric_deploy_log ("MetricId","DeployedAt","SourceCommit")
SELECT m."MetricId", now(), 'baseline'
FROM   public."RTSGrid_Metric" m
ON CONFLICT ("MetricId") DO NOTHING;

INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260613_001_backfill_metric_deploy_log') ON CONFLICT (migration_name) DO NOTHING;

-- Verification
SELECT (SELECT count(*) FROM public."RTSGrid_Metric")  AS live_metrics,
       (SELECT count(*) FROM public.metric_deploy_log) AS ledger_rows,
       (SELECT count(*) FROM public."RTSGrid_Metric" m
          WHERE NOT EXISTS (SELECT 1 FROM public.metric_deploy_log l WHERE l."MetricId" = m."MetricId")) AS still_undeployed;
-- expect: ledger_rows >= live_metrics, still_undeployed = 0
