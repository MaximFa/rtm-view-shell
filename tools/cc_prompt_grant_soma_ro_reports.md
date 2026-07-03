# CC TASK — GRANT soma_ro SELECT on reports tables + migration history  [⛔ЧП · v3 · DBA + devops co-review]

> Authored by dba-0625 for coordinator §4-bless. Real gap exposed: QA's 'report_* missing' was a soma_ro FALSE-NEGATIVE — soma_ro lacks SELECT on the reports tables, so information_schema/queries返回 'permission denied' = looked missing (they exist; /reports UI renders 6). Fix: GRANT soma_ro SELECT on the reports tables + __EFMigrationsHistory so Soma DB cross-checks see ground truth. Soma role owner = devops (§47, SF-SOMA-001) → devops CO-REVIEWS. No secret tables (SF-SOMA-001 keeps identity.users/sso_configurations/tenant_settings via *_safe views only — do NOT grant on those). No push.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY.
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §47 (Soma soma_ro read-only), §39; SF-SOMA-001 (secret-table revokes — respect).

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD
sync
```
S1: if `.coord/push/request.md` present (content-based) → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_grant_soma_ro_reports.md | status: open
### DIRECTIVE (spec->CC): create staging/grant_soma_ro_reports.sql (GRANT SELECT to soma_ro on report_* + __EFMigrationsHistory). claim: staging/grant_soma_ro_reports.sql. devops co-review (Soma owner). gate: soma_ro can SELECT report_screens. NO push.
```

## 3. CLAIM
- `staging/grant_soma_ro_reports.sql` (NEW; §0.7 staging/*.sql). No source/code files.

## 4. TASK — create `staging/grant_soma_ro_reports.sql` (ASCII)
```sql
-- soma_ro read access to the reports feature tables + EF migration history (Soma DB cross-checks).
-- Non-secret tables only (SF-SOMA-001: identity.users/sso_configurations/tenant_settings stay via *_safe views).
GRANT SELECT ON
    public.report_screens,
    public.report_widgets,
    public.report_permissions,
    public.report_categories,
    public.report_schedules,
    public.user_reports,
    public."__EFMigrationsHistory"
TO soma_ro;
-- Future-proof: default SELECT for soma_ro on new public tables created by the app owner
-- (scope to the app/owner role that creates the reports tables — confirm the owner with devops before adding).
-- ALTER DEFAULT PRIVILEGES FOR ROLE <app_owner> IN SCHEMA public GRANT SELECT ON TABLES TO soma_ro;   -- devops confirms <app_owner>
```
NOTE: run as the tables' OWNER (postgres or the app owner) — GRANT requires ownership. The ALTER DEFAULT PRIVILEGES line is commented pending devops confirming the owning role; do NOT guess it.

## 4.1 Apply (operator/devops, as table owner)
```
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d rtmviewdb -f staging\grant_soma_ro_reports.sql
```

## 4.2 Verify (report in RESULT)
```
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d rtmviewdb -c "SET ROLE soma_ro; SELECT count(*) FROM report_screens; RESET ROLE;"   -- must succeed (no 'permission denied')
```
(Or Soma /db/query as soma_ro returns report_screens count without permission error.)

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-07-02 · A restricted read-role (soma_ro) lacking SELECT on a table makes information_schema/queries return 'permission denied' → the table LOOKS missing to that role (QA false-negative 'report_* missing'). Ground truth = query as the OWNER (postgres). When a new feature adds tables, GRANT the read-role SELECT on them (non-secret only; keep SF-SOMA-001 secret-table revokes). · SOURCE: QA soma_ro false-neg on report_* 2026-07-02 · status: active
```

## 6. Acceptance
- staging/grant_soma_ro_reports.sql created (GRANT SELECT to soma_ro on the 6 reports tables + __EFMigrationsHistory; ALTER DEFAULT PRIVILEGES commented pending devops owner-confirm).
- Applied: `SET ROLE soma_ro; SELECT count(*) FROM report_screens;` succeeds.
- NO grant on secret tables (identity.users/sso_configurations/tenant_settings).
- role-dba §B lesson added.
- NO code change; NO push.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add staging/grant_soma_ro_reports.sql` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`.
- Prefix `db:` — `db: GRANT soma_ro SELECT on reports tables + migration history (Soma cross-check) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . staging/grant_soma_ro_reports.sql . soma_ro SELECT report_screens OK . no secret-table grant . status done . verified: object-store+live
```
