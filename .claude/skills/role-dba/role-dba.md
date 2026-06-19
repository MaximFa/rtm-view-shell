---
role: dba
project: RTM View Shell
version: 0.1
last_verified: 2026-06-19T09:30:00Z
owner: dba
reviewer: curator
---
# role-dba — RTM DBA role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (db/, RTM/sql/, git log --oneline db/), NOT session narrative.
> Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: Database schema, migrations, functions, Compare-ToBaseline, metrics. Owns: db/, RTM/sql/.
Does NOT write application code — code changes flow via CC prompts.

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **Apply-user for DDL migrations = owner/superuser (postgres), not app-user.**
   ccdashboard_user gets "must be owner" on ALTER TABLE / CREATE INDEX. Run the WHOLE
   migration list as postgres for consistent privilege. Read-only Compare gate stays app-user.
   · SOURCE: dba-0610 STEP-4 apply-user confirm 2026-06-19

2. **§38a: Migrations self-record in db_patch_history ledger.**
   Every NEW migration MUST end with INSERT INTO db_patch_history. Pre-ledger migrations
   (before _002_db_patch_history) cannot self-record — permanent D-drift noise.
   · SOURCE: CLAUDE.md §38a, 234 Compare 114916 D=4

3. **Compare-ToBaseline is MANDATORY before any deploy (E1 gate).**
   Yields the server-specific -MigrationList AND catches runtime-critical drift.
   · SOURCE: 234+45 deploys 2026-06-19

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-19 · Apply-user for DDL migration set = OWNER/superuser (postgres), NOT app user. DML-only migs could use app user, but run the WHOLE list as postgres for one consistent privilege. · SOURCE: dba-0610 STEP-4 apply-user confirm · status: active
- 2026-06-19 · Idempotent-migration NOTICEs ("already exists, skipping" / "does not exist, skipping") on already-populated server are EXPECTED, not errors — the guards (IF NOT EXISTS / to_regclass / ON CONFLICT) make re-apply safe. · SOURCE: 234 STEP-4b log (all 10 migs [OK] amid NOTICEs) · status: active
- 2026-06-19 · Pre-ledger migrations (created before _002_db_patch_history) CANNOT self-record (§38a) -> permanent D-drift (MISSING/unknown) in Compare even when applied+effective. Optional 1-row-each ledger-backfill to reach D=0. · SOURCE: 234 Compare-after 114916 (D=4: _604_001/_605_004/_606_005/_606_008) · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Test-Path "db/tools/Compare-ToBaseline.ps1"` — must be True
2. `Select-String -Path "db/schema.sql" -Pattern "CREATE TABLE"` — expect count >10
3. `Test-Path "db/migrations"` — must be True
4. `Select-String -Path "CLAUDE.md" -Pattern "db_patch_history"` — must exist (§38a)

## §D REFERENCE
Schema: db/schema.sql, db/functions/*.sql.
Migrations: db/migrations/*.sql (self-record per §38a).
Tooling: db/tools/Compare-ToBaseline.ps1, db/tools/Export-All.ps1.
