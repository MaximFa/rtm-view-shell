# CC TASK — create staging/reconcile_efmig_234.sql (EF-reconcile for 234 converge-deploy)  [⛔v3 · DBA · DB-setup] · §4-PASS coordinator-0703 2026-07-03T13:35Z

> Authored by dba-0625. §4-PASS coordinator-0703 (13:35Z; note: §3 CLAIM also covers .claude/skills/role-dba/role-dba.md §B — committed in §7). Creates the 234 EF-history reconcile SQL. NO run here; operator applies on 234 as postgres BEFORE the new Shell first start. NO push.
> WHY: 234 __EFMigrationsHistory = 2 junk InitialCreate rows (20260507105829 / 20260507135314) — do NOT match HEAD (135247). All 24 CC tables + baseline objects exist; the 4 reports-v1 objects are ABSENT (verified). Without reconcile, migrate retries InitialCreate → 'relation already exists' → crash (§38.6 DB-INTAKE-01). Insert the 22 b58e2c2 App MigrationIds → migrate applies ONLY the 4 reports-v1 (clean create).

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §38.6 (DB-INTAKE-01), §43 (external-server ops), §39.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD
sync
```
S1: if `.coord/push/request.md` present (content-based, active) → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_reconcile_efmig_234.md | status: open
### DIRECTIVE (spec->CC): create staging/reconcile_efmig_234.sql (22 b58e2c2 MigrationIds ON CONFLICT DO NOTHING + verify tail). claim: staging/reconcile_efmig_234.sql. gate: 22 rows + verify. NO run. NO push.
```

## 3. CLAIM
- `staging/reconcile_efmig_234.sql` (NEW; §0.7 staging/*.sql). No source/code.

## 4. TASK — create `staging/reconcile_efmig_234.sql` (ASCII)
```sql
-- ============================================================================
-- 234 CONVERGE-DEPLOY: EF-history reconcile (baseline to b58e2c2 state)
-- Run as POSTGRES on 234, BEFORE the new Shell's first start (MigrateAsync).
-- (Update-RTMView does NOT call EF migrate - coordinator-verified 2026-07-03;
--  the new Shell's startup MigrateAsync is the migrate trigger.)
-- 234 has all 24 CC tables + baseline objects; the 4 reports-v1 objects are ABSENT.
-- __EFMigrationsHistory holds 2 non-matching junk InitialCreate rows -> without this
-- baseline, MigrateAsync retries InitialCreate -> 'relation already exists' -> crash (SS38.6).
-- Insert the 22 b58e2c2 App MigrationIds so migrate applies ONLY the 4 reports-v1.
-- The 2 junk rows are LEFT as-is (unknown IDs; EF ignores them).
-- Idempotent: ON CONFLICT DO NOTHING.
-- ============================================================================
INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion") VALUES
('20260507135247_InitialCreate','8.0.16'),
('20260507191205_NgcConfiguration','8.0.16'),
('20260508070300_RtsGridMetricCrossTenant','8.0.16'),
('20260509063517_LicensingAndUserSessions','8.0.16'),
('20260509092003_NgcQueueAgentGroupTables','8.0.16'),
('20260510110123_AddDashboardCategory','8.0.16'),
('20260510182755_AddSignalRConnectionUrlToTenantSettings','8.0.16'),
('20260511130954_AddDashboardIsDarkMode','8.0.16'),
('20260513084402_AddGridIdToDashboardWidget','8.0.16'),
('20260513094211_AddRtsUserGridTables','8.0.16'),
('20260513105023_ChangeGridIdToIdentityByDefault','8.0.16'),
('20260513120913_AddTenantSettingsAppearance','8.0.16'),
('20260513194331_AddValueTypeToRtsGridMetric','8.0.16'),
('20260513195301_AddMetricValueAndMetricType','8.0.16'),
('20260514080241_AddWidgetTemplates','8.0.16'),
('20260515231936_RenameRtsGridMetricToPascalCase','8.0.16'),
('20260515232925_RenameNgcTablesToPascalCase','8.0.16'),
('20260525223134_SeparateBackendTablesToBeDb','8.0.16'),
('20260527150112_AddHistoryMetricTable','8.0.16'),
('20260528043639_AddAgentStateRegistry','8.0.16'),
('20260529054939_AddInfoSlotTables','8.0.16'),
('20260605145919_AddUserWidgetSettings','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;

-- verify (expect >= 24 = 2 junk + 22 baseline; report_screens still NULL pre-migrate)
SELECT count(*) AS efmig_count FROM "__EFMigrationsHistory";
SELECT to_regclass('public.report_screens') AS report_screens_should_be_null;
```

## 4.1 (operator, on 234, as postgres — DO NOT run here)
```
psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f staging\reconcile_efmig_234.sql
```
Expect: efmig_count >= 24; report_screens = NULL (migrate not run yet). THEN start new Shell -> MigrateAsync applies the 4 reports-v1 (report_*/hist_*/arch_*/user_reports) clean.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-07-03 · 234 converge: __EFMigrationsHistory had 2 junk InitialCreate rows (IDs not matching HEAD) - EF ignores unknown IDs, so leave them; insert the b58e2c2 baseline set (git ls-tree b58e2c2 App migrations) so migrate applies only the post-baseline (reports-v1) migrations. Verify reports-v1 objects ABSENT first (clean create). Update-RTMView does NOT call EF migrate - the new Shell startup MigrateAsync does; run the reconcile BEFORE first start. · SOURCE: 234 Compare 20260703 + EF-history probe · status: active
```

## 6. Acceptance
- staging/reconcile_efmig_234.sql created: 22 VALUES rows (b58e2c2 set), ON CONFLICT DO NOTHING, verify tail (count + report_screens to_regclass).
- role-dba §B lesson added.
- NO run; NO code change; NO push.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5x60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add staging/reconcile_efmig_234.sql` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`.
- Prefix `db:` — `db: reconcile_efmig_234.sql - EF-history baseline for 234 converge (22 b58e2c2 ids) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . staging/reconcile_efmig_234.sql (22 rows) . status done . verified: object-store
```
