# CC task — DEVOPS STEP-2: build 234 deploy package (Full) from b58e2c2
> §4-PASS by coordinator-0612 2026-06-18T15:13:05Z. Owner: devops (devops-2-0607). Executor: native CC. Builds a DEPLOY ARTIFACT (Installations/ zip, gitignored). NO push.
> STEP-1 gate satisfied: dba finalized 10-mig -MigrationList + backend NGC=CALL confirmed. Baseline = pushed origin/v2-backend b58e2c2.

## INIT + discipline
- role-devops INIT if cold-started (else proceed + flag). §0.2: HEAD==origin/v2-backend==b58e2c2 (hash-verify). POST-VERIFY (ls+cat+git, not -f/-s).
- prod-release skill: build via tools/Build-ProdRelease.ps1 -Mode Full (Shell + DB). §35: PS1/TXT in zip = UTF-8 BOM + CRLF (else Windows PS 'Unexpected token').

## TASK — build the Full 234 package from b58e2c2 objects
1. `tools/Build-ProdRelease.ps1 -Mode Full -DBPassword "<pw>"` (NO Read-Host; non-interactive; password via -DBPassword per §35 lessons). Produces Installations\DDMMYYYY.HHMM_Full.zip with:
   - Shell self-contained publish (CcDashboard.Web, win-x64) — the widget UX package + deploy-tab.
   - DB module: db/schema.sql (regen, no phantoms), db/functions/*, db/migrations/* (ALL — incl 20260613_001_backfill), db/data baseline, db/setup.
   - deploy/Install-RTMView.ps1 + Update-RTMView.ps1 (E1 pre-deploy Compare gate + -ForceDeploy + backup step), Restore-SqlDump.ps1, Memurai MSI from cache.
2. CRITICAL — the 234 apply uses an EXPLICIT -MigrationList (dba-finalized, FULL-10, ordered):
   `20260604_001_add_agent_state_pct_metrics,20260605_004_metrics_dedup,20260606_005_history_unavailable_metrics,20260606_008_daytrend_fn_bu_scope,20260613_001_backfill_metric_deploy_log,20260613_011_45_table_drift_addcolumns,20260613_012_drop_legacy_mapping_functions,20260613_013_sgag_unique_constraint,20260613_014_schema_reconcile,20260613_015_ngc_createsupergroup_overloads`
   Ensure the package's Update/apply config can take this list (or document it in the package README for the STEP-4 apply). Functions re-apply (db/functions/01-04) happens before/with migrations (self-heals NGC B=1 PROCEDURE).
3. PG18: 234 is PG18 — confirm the package's PG-tool path resolution handles PG18 (Find-PGTool covers 15-18). No content change.

## VERIFY (object-store + zip)
- HEAD==b58e2c2 (hash). Build from HEAD, not truncated WT. zip contains: publish\web\CcDashboard.Web.exe, db\ (schema+functions+migrations incl _001+_011-015+data), deploy\*.ps1, README. PS1 = BOM+CRLF.
- Report the zip path + the embedded/README -MigrationList (FULL-10) + Shell build 0-err (cite the dotnet publish result — native build IS available to devops).
- NO push, NO commit (Installations gitignored).

## Report -> .coord/inbox/coordinator.md + chat: zip path, contents, -MigrationList embedded, Shell publish result, PG18 note. Then STEP 3 = operator stages on 234 + pg_dump backup.
