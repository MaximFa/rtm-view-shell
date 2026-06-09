-- 20260607_003_fix_curlogintimestamp.sql
-- Fix dead metric: engine switch (UserManager.cs) is case-sensitive 'CurLoginTimestamp';
-- the metric was seeded 'CurLoginTimeStamp' (capital S) -> never produced a value.
\set ON_ERROR_STOP on

UPDATE "RTSGrid_Metric"
   SET "MetricFunction" = 'CurLoginTimestamp'
 WHERE "MetricId" = 'MonAgentCurrentLoginTimeStamp'
   AND "MetricFunction" = 'CurLoginTimeStamp';

-- self-record (db_patch_history ledger convention from _002)
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260607_003_fix_curlogintimestamp')
ON CONFLICT (migration_name) DO NOTHING;
