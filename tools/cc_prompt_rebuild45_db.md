# OPERATOR RUNBOOK — Server-45 clean DB rebuild (EF-migrate path) then orchestrator
# (devops-2-0607 draft -> coordinator §4 before operator runs. NOT a CC code task — operator runs on server 45, PG15 client.)
> [coordinator-0612 §4 2026-06-12 PASS w/ amendments applied: FLAG1 strip migrate-history overwrite (filter in step 5); FLAG4 add _010 + step-7 asserts; FLAG2/3 OK. Run only this amended version.]

> WHY EF-migrate (not schema.sql): `CcDashboard.Web.exe migrate` populates __EFMigrationsHistory -> later RTMViewShell
> start = EF no-op -> NO MORE flapping. schema.sql would not set EF history -> Shell start re-triggers EF recreation = flap.
> Confirmed: the 3 "missing" columns are EF-owned (BackendEmulation migrations 20260526203609_AddRtsDataEntitiesAndStatusGroup
> = StatusGroup; 20260606100233_AddCatalogueFieldsToRtsGridMetric = CatalogCategory+DisplayName) -> Web.exe migrate creates them.
> Seed = db/data/* (canonical: 198-metric catalog + translations) — and db/data/01_system.sql carries the FIXED platform
> tenant UUID 019e03e9-60dd-72da-bd01-648ffdb2b433 == the RTM appsettings TenantId -> tenant stays consistent (RTM scoping intact).

PRE: run from the extracted a6fd360 package dir on server 45. PG15 client: C:\Program Files\PostgreSQL\15\bin.
STEP 0 (mandatory): Set-ExecutionPolicy -Scope Process Bypass -Force ; Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File

## PART 1 — clean DB rebuild (deterministic). $psql='C:\Program Files\PostgreSQL\15\bin\psql.exe'; $env:PGPASSWORD='!@#qweASDzxc'
1. (postgres) drop+create:
   & $psql -h localhost -U postgres -d postgres -c "DROP DATABASE IF EXISTS rtmviewdb WITH (FORCE);"
   & 'C:\Program Files\PostgreSQL\15\bin\createdb.exe' -h localhost -U postgres -E UTF8 rtmviewdb
2. (postgres) roles/extensions/grants (idempotent):
   & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=0 -f .\db\setup\01_init_db.sql
3. (EF schema — sets __EFMigrationsHistory, creates all 3 columns) — use the DEPLOYED Shell exe (its appsettings has the real
   conn-string + TenantId; binaries already deployed by the prior runs):
   & 'C:\RTMView\Shell\CcDashboard.Web.exe' migrate
   (If it errors on connection, confirm C:\RTMView\Shell\appsettings.json ConnectionStrings:Default points to rtmviewdb/ccdashboard_user.)
4. (ccdashboard_user) functions 01..04 — ON_ERROR_STOP=1:
   foreach 01_ngc_functions, 02_rtsdata_functions, 03_rtsgrid_read, 04_misc_functions:
   & $psql -h localhost -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -f .\db\functions\<f>.sql
5. (ccdashboard_user) canonical seed — ON_ERROR_STOP=1, IN ORDER (01_system carries the fixed tenant/superadmin/EF-history; it TRUNCATEs+COPYs):
   01_system, 02_metrics, 03_rtsgrid, 04_catalog, 05_metric_translations  (each: -f .\db\data\<f>.sql)
   🔴 [§4 FLAG1 FIX — MANDATORY] 01_system.sql TRUNCATEs+overwrites __EFMigrationsHistory / __BackendEmulationMigrationsHistory /
   __ef_migrations_history with a Jun-11 snapshot — that would CLOBBER the correct history set by `Web.exe migrate` (step 3) and
   re-trigger the EF flap. STRIP those 3 history blocks first; let migrate own the history. Run BEFORE applying 01_system:
   ```powershell
   $src=Get-Content ".\db\data\01_system.sql"; $o=New-Object System.Collections.Generic.List[string]; $skip=$false
   $tg=@('-- __EFMigrationsHistory','-- __BackendEmulationMigrationsHistory','-- __ef_migrations_history')
   foreach($l in $src){ if(-not $skip -and ($tg -contains $l.Trim())){$skip=$true;continue}; if($skip){ if($l.Trim() -eq '\.'){$skip=$false}; continue }; $o.Add($l) }
   Set-Content ".\db\data\01_system_nohist.sql" -Value $o -Encoding UTF8
   ```
   Then apply **01_system_nohist.sql** (NOT 01_system.sql) in this step; 02..05 unchanged. (Keeps tenants/settings/roles/users +
   the FIXED tenant UUID; only the EF-history overwrite is removed.)
   ⚠ 01_system uses TRUNCATE ... RESTART IDENTITY CASCADE — fine on a fresh DB; it OVERWRITES any tenant migrate/DatabaseInitializer seeded with the FIXED UUID. (It also asserts __EFMigrationsHistory rows — see §4 flag 1.)
6. (ccdashboard_user) the 4 SQL migrations (EF covers columns; these add metric DATA + the CURRENT daytrend fn _008):
   20260604_001_add_agent_state_pct_metrics, 20260605_004_metrics_dedup, 20260606_005_history_unavailable_metrics, 20260606_008_daytrend_fn_bu_scope (each -f .\migrations\<f>.sql, ON_ERROR_STOP=1)
   🔴 [§4 FLAG4 FIX — MANDATORY] ALSO apply **20260609_010_metric_deploy_log** here (CREATE TABLE IF NOT EXISTS, idempotent). The
   '4-migration' list assumed the PRE-EXISTING 45 (where _010 was applied); a FRESH rebuild has it UNAPPLIED -> metric_deploy_log
   table absent -> ApplyService can't write. So step 6 = FIVE migrations: 001, 004, 005, 008, 010. (devops: confirm no OTHER
   db/migrations/* objects are needed beyond EF-migrate+data/*+these 5 via the step-7 asserts; if an assert fails, add that migration.)
7. probe sanity (ccdashboard_user, read-only): & $psql ... -t -A -f .\server45_dependency_probe.sql  -> EXPECT all |t (db_patch_history may be t now).
   [§4 ASSERT — must all return TRUE; if any FALSE, the rebuild is incomplete, fix before PART 2]:
   ```sql
   SELECT to_regclass('public.metric_deploy_log') IS NOT NULL AS metric_deploy_log;
   SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='RTSGrid_Metric' AND column_name='CatalogCategory') AS catalogcategory;
   SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='RTSGrid_Metric' AND column_name='DisplayName') AS displayname;
   SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='RTSData_UserStatusLog' AND column_name='StatusGroup') AS statusgroup;
   ```
$env:PGPASSWORD=$null

## PART 2 — orchestrator finishes (binaries + ApplyService + F-3) on the clean DB
Now the orchestrator's Phase-0 probe PASSES, Phase-2 backs up the CLEAN DB (good rollback anchor), Phase 5a provisions ApplyService, Phase 5c F-3 rebind, Phase 6 starts services. Run (one line):
.\Apply-Server45Upgrade.ps1 -PgVersion 15 -AutoRollback -ReleaseCommit 'a6fd360' -AppPassword '!@#qweASDzxc' -SuperPassword '!@#qweASDzxc' -InstallRoot 'C:\RTMView' -MigrationList '20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260606_008_daytrend_fn_bu_scope.sql' -ShellPublish '.\bin\Shell' -RtmPublish '.\bin\RTM' -ApplyServicePublish '.\bin\ApplyService'
(migrations idempotent = no-op re-apply; functions idempotent; Shell start = EF no-op now -> no flap.)

## POST: Compare-ToBaseline + DG-1 (8088=127.0.0.1) + DG-2 (RTMApplyService running, token) + metric_deploy_log exists.

## §4 FLAGS for coordinator (resolve before operator runs):
 1. db/data/01_system.sql "EF migration history" — it appears to seed __EFMigrationsHistory rows. If those rows MISMATCH what Web.exe migrate set (step 3), confirm order is harmless (01_system runs AFTER migrate; if it overwrites EF history with the SAME set, fine; if a different/stale set, EF on Shell start could re-trigger migrations). Please verify 01_system's EF-history matches the current migration set, OR drop the EF-history part of 01_system (let migrate own it).
 2. Does `CcDashboard.Web.exe migrate` run DatabaseInitializer seeding (random-UUID tenant) or migrations-only? If it seeds, 01_system's TRUNCATE+fixed-UUID overwrites it (OK). Confirm.
 3. Run-as-user for functions/data: Create-FreshDb uses AppUser (ccdashboard_user). Confirm functions don't need postgres (some GRANTs/SECURITY DEFINER?).
 4. Is the 4-migration set sufficient on a fresh EF+seed DB, or are other db/migrations needed (e.g., metric tweaks not in data/* )? My read: EF+data/* cover the schema+catalog; the 4 add the remaining data/fn. Confirm no others required.
