-- Migration: 20260609_010_metric_deploy_log
-- Purpose: Create per-metric deploy ledger table (hot-reload apply-service contract §3, §38a)
-- Cross-tenant like RTSGrid_Metric (WGT-01) - NO TenantId column
-- MetricId is text (matching RTSGrid_Metric.MetricId type: PascalCase RT / dotted history)

CREATE TABLE IF NOT EXISTS public.metric_deploy_log (
    "MetricId" text PRIMARY KEY,
    "DeployedAt" timestamptz NOT NULL,
    "SourceCommit" text NULL
);

-- Shell reads for delta (manifest minus ledger); apply-owner writes
GRANT SELECT, INSERT ON public.metric_deploy_log TO ccdashboard_user;

-- Self-record per §38a
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260609_010_metric_deploy_log') ON CONFLICT (migration_name) DO NOTHING;