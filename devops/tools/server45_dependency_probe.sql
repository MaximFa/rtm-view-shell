-- server45_dependency_probe.sql  — READ-ONLY dependency proof + pre-flight go/no-go before the upgrade.
-- Run on server45 (PG17) as ccdashboard_user, FIRST, BEFORE stop/backup:
--   psql -h localhost -U ccdashboard_user -d <db> -f server45_dependency_probe.sql
-- Expected: every row exists=t EXCEPT db_patch_history (exists=f — created by 20260607_002 in the upgrade).
-- ANY required object = f (other than db_patch_history) -> STOP, do NOT begin apply; report to coordinator.

SELECT 'NGC_UserAgentgroup (table)              [_008 dep / _007]' AS object,
       to_regclass('public."NGC_UserAgentgroup"') IS NOT NULL AS exists
UNION ALL SELECT 'history_metrics (table)                [_005 dep / EF]',
       to_regclass('public.history_metrics') IS NOT NULL
UNION ALL SELECT 'RTSGrid_MetricTranslation (table)      [_001-0607 / EF]',
       to_regclass('public."RTSGrid_MetricTranslation"') IS NOT NULL
UNION ALL SELECT 'RTSGrid_Metric (table)                 [_004001 / _003 dep]',
       to_regclass('public."RTSGrid_Metric"') IS NOT NULL
UNION ALL SELECT 'RTSData_UserStatusLog (table)          [functions/02 SetUserStatus write]',
       to_regclass('public."RTSData_UserStatusLog"') IS NOT NULL
UNION ALL SELECT 'RTSData_UserStatusLog.StatusGroup (col) [_004 / SetUserStatus writes it]',
       EXISTS(SELECT 1 FROM information_schema.columns
              WHERE table_name='RTSData_UserStatusLog' AND column_name='StatusGroup')
UNION ALL SELECT 'RTSGrid_Metric.CatalogCategory (col)    [_003 catalog]',
       EXISTS(SELECT 1 FROM information_schema.columns
              WHERE table_name='RTSGrid_Metric' AND column_name='CatalogCategory')
UNION ALL SELECT 'RTSGrid_Metric.DisplayName (col)        [catalogue/metric work]',
       EXISTS(SELECT 1 FROM information_schema.columns
              WHERE table_name='RTSGrid_Metric' AND column_name='DisplayName')
UNION ALL SELECT 'fn_daytrendagentstatus (routine)        [_008 CREATE OR REPLACE]',
       EXISTS(SELECT 1 FROM pg_proc WHERE proname='fn_daytrendagentstatus')
UNION ALL SELECT 'db_patch_history (table) EXPECT f        [_002 creates it]',
       to_regclass('public.db_patch_history') IS NOT NULL
ORDER BY 1;
