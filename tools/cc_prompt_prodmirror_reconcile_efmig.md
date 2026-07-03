# CC TASK — prod-mirror DB: reconcile __EFMigrationsHistory (unblock /reports)  [⛔ЧП · v3 · DBA · DB-setup]

> Authored by dba-0625 for coordinator §4-bless. DB-setup only (not a code change). No push.
> DIAGNOSTIC CORRECTED THE PLAN (I confirmed state per coordinator's ask): the prod-mirror DB (restored 234 b58e2c2 backup) has __EFMigrationsHistory = **0 rows**, but **ALL objects already exist** — to_regclass non-NULL for report_screens, hist_queue_intervals, hist_agent_intervals, arch_rtsdata_interaction, arch_watermark, user_reports (one signature object from EACH of the 4 "new" migrations) + baseline dashboards work. So report_* is NOT missing; the app CRASHES on startup because MigrateAsync sees 0 applied → retries InitialCreate → 'relation already exists'. The coordinator's "insert 22 → migrate applies 4" would FAIL (the 4's objects exist). FIX = record ALL 26 migrations as applied → MigrateAsync no-ops → app starts → /reports works.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §7 (EF/migrations), §35, §39; §38a (ledger is separate from __EFMigrationsHistory).

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_reconcile_efmig.md | status: open
### DIRECTIVE (spec->CC): create staging/reconcile_efmig_prodmirror.sql (insert ALL 26 MigrationIds ON CONFLICT DO NOTHING), apply to rtmviewdb, run migrate (no-op), verify. claim: staging/reconcile_efmig_prodmirror.sql. gate: report_screens present + count=26 + app starts. NO push.
```

## 3. CLAIM
- `staging/reconcile_efmig_prodmirror.sql` (NEW; §0.7 staging/*.sql). No source/code files.

## 4. TASK
### 4.1 Create `staging/reconcile_efmig_prodmirror.sql` (UTF-8, no special encoding needed for pure SQL; keep ASCII)
```sql
-- Prod-mirror DB: baseline __EFMigrationsHistory to the full v3 (HEAD) migration set.
-- ALL 26 migrations' objects already exist (restored 234 b58e2c2 backup + new-migration objects present);
-- history was empty -> MigrateAsync crashed on InitialCreate. Record all as applied so migrate no-ops.
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
('20260605145919_AddUserWidgetSettings','8.0.16'),
('20260621080000_AddHistoricalReportsTables','8.0.16'),
('20260622090000_AddArchiveTables','8.0.16'),
('20260622100000_UserReportSoftDelete','8.0.16'),
('20260624093015_AddReportEntities','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;
```

### 4.2 Apply (as postgres — owner-safe, §A cardinal truth #1)
```
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d rtmviewdb -f staging\reconcile_efmig_prodmirror.sql
```

### 4.3 Run migrate (must NO-OP now) then confirm the app starts
```
# from the published Web dir (or dotnet):
CcDashboard.Web.exe migrate   # expect: "No migrations to apply" / clean exit 0 (all 26 recorded, objects exist)
```
If migrate reports it WOULD apply a migration → STOP + report (means an object is genuinely missing → NOT the assumed state; escalate, do NOT force).

### 4.4 Verify (report in RESULT)
```
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d rtmviewdb -c "SELECT count(*) FROM \"__EFMigrationsHistory\";"   -- expect 26
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d rtmviewdb -c "SELECT to_regclass('public.report_screens'), to_regclass('public.report_widgets'), to_regclass('public.report_permissions'), to_regclass('public.report_categories'), to_regclass('public.report_schedules');"   -- all non-NULL
```
FUNCTIONAL (QA floor): app starts clean (no MigrateAsync 'relation already exists'); /reports renders (QA re-runs its regression).

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-07-02 · Restored prod backup (234) has tables PRESENT but __EFMigrationsHistory EMPTY -> EF MigrateAsync retries InitialCreate -> 'relation already exists' -> app crash. If ALL current-model objects already exist (verify via to_regclass on each migration's signature object), BASELINE the history: INSERT all applied MigrationIds (ProductVersion from Designer, e.g. 8.0.16) ON CONFLICT DO NOTHING -> migrate no-ops -> app starts. Confirm the object-existence state FIRST; if only PARTIAL, insert only the truly-applied set + let migrate apply the rest (never insert an ID whose objects are missing -> hides drift). · SOURCE: prod-mirror EFMigrationsHistory=0 + all 6 signature objects present 2026-07-02 · status: active
```

## 6. Acceptance
- staging/reconcile_efmig_prodmirror.sql created (26 VALUES rows, ON CONFLICT DO NOTHING).
- Applied: __EFMigrationsHistory count = 26; all 5 report_* to_regclass non-NULL.
- migrate = no-op / clean; app starts (no MigrateAsync crash).
- role-dba §B lesson added.
- NO code change; NO push.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add staging/reconcile_efmig_prodmirror.sql` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`.
- Prefix `db:` — `db: reconcile __EFMigrationsHistory for prod-mirror DB (baseline all 26; unblock /reports) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . staging/reconcile_efmig_prodmirror.sql . EFMigrationsHistory=26 . report_* present . migrate no-op . app starts . status done . verified: object-store+live
```
