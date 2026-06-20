# CC task — DEVOPS: add DB-apply to Update-RTMView.ps1 (-MigrationList + pg_dump backup + functions) — package defect fix
> §4-PASS by coordinator-0612 2026-06-19T05:37:29Z. Owner: devops (devops-2-0607). Executor: native CC. Commit `deploy:`. **NO push** (rides next barrier).
> DEFECT: deploy/Update-RTMView.ps1 (bundled in 234 pkg) updates BINARIES + runs the E1 gate but does NOT apply DB migrations/functions and does NOT pg_dump the DB. README documents -MigrationList but the script has no such param (operator hit "parameter cannot be found"). 234 untouched (gate-by-error).

## INIT + discipline
- role-devops INIT if cold-started (else proceed+flag). §0.2: branch v2-backend, hash-verify deploy/Update-RTMView.ps1 vs HEAD. POST-VERIFY (ls+cat+git, not -f/-s). §0.3 Python+fsync for any .coord write.
- Binding PREAMBLE -> .coord/cc/devops.md (NORM-CUR-07). §42.6 sync (S1 barrier, S2 claim deploy/Update-RTMView.ps1 + README, S3 commit.lock, S4 post-commit). NO push.

## THE WORK — deploy/Update-RTMView.ps1
1. **New params:** `[string]$MigrationList = ""` (comma-separated migration filenames, ordered). Optionally `[string]$DBApplyUser`/`[string]$DBApplyPassword` if migrations need higher privilege than $DBUser (see step 4 privilege note).
2. **pg_dump DB backup — NEW, BEFORE any DB change:** insert after the binary-backup step (step 2), BEFORE the E1 gate. pg_dump custom-format the $Database to $BackupDir\db_$($Database)_$Timestamp.dump (Find-PGTool for pg_dump, PG15-18). $env:PGPASSWORD pattern. FAIL-STOP if pg_dump errors (do NOT proceed to apply without a DB backup). Echo the dump path.
3. **DB apply stage — NEW, AFTER the E1 gate, BEFORE deploying binaries** (so schema is ready for the new binaries):
   - If -MigrationList is non-empty:
     a. Re-apply SQL functions: db/functions/01_ngc_functions.sql, 02_rtsdata_functions.sql, 03_rtsgrid_read.sql, 04_misc_functions.sql (at $ScriptDir\db\functions\). psql -f each, ON_ERROR_STOP=1. (Self-heals the NGC PROCEDURE per RTM-SEC-002.)
     b. For each name in $MigrationList.Split(','): apply $ScriptDir\db\migrations\$name.sql via psql -f $file -v ON_ERROR_STOP=1, IN ORDER. **Use psql -f <file>, NOT -c with embedded SQL** (B2 lesson: PowerShell strips embedded quotes -> 42703). Echo each migration + its result; FAIL-STOP on error.
     c. Each migration self-records (§38a db_patch_history); idempotent on 234.
   - If -MigrationList empty: skip DB apply (binary-only update, current behaviour) + note it.
4. **PRIVILEGE note (flag for dba/operator):** migrations do ALTER TABLE / CREATE INDEX / INSERT/UPDATE/DELETE. On 234 most are idempotent no-ops (IF NOT EXISTS / to_regclass guards), and the data ones (_001/_004/_005/_008) need INSERT/UPDATE/DELETE on RTSGrid_Metric/metric_deploy_log (ccdashboard_user has these per grants). The structural _011-015 ALTER/CREATE need owner/super BUT no-op where the object exists (234 structurally complete). Default apply user = $DBUser; expose $DBApplyUser/$DBApplyPassword for the case a privileged user is required. dba confirms the 234 apply-user before run.
5. Keep the E1 gate exactly as-is (runs before DB apply; on 234 expect cosmetic exit 2 -> operator uses -ForceDeploy after dba review). Keep binary deploy + service start after the DB apply.

## README fix
Update the package README (and deploy/ README if any): the -MigrationList example now MATCHES the implemented param. Add the privilege note + that pg_dump runs automatically before apply.

## VERIFY (cite real build/parse — devops HAS native tools)
- PowerShell parse clean: `[System.Management.Automation.Language.Parser]::ParseFile(...)` no errors.
- Object-store: Update-RTMView.ps1 has $MigrationList param, a pg_dump-backup block before E1, a functions+migrations apply loop (psql -f, ON_ERROR_STOP) after E1 before binary deploy.
- Dry sanity (no real 234): `-MigrationList ""` path = binary-only (unchanged); `-MigrationList "x"` path enters the apply loop.

## Commit (deploy:, NO push) under commit.lock
git add deploy/Update-RTMView.ps1 (+ README if in repo) ; commit -m "deploy: Update-RTMView DB-apply — -MigrationList (functions re-apply + ordered migrations, psql -f) + pg_dump DB backup before apply (was binary-only; README promised -MigrationList) [devops]" ; §0.6 post-commit ; cc_post_commit.sh ; §0.7 re-sync ; sync.

## REPACKAGE / PATCH (so 234 gets the fix)
- Fastest: produce the FIXED deploy/Update-RTMView.ps1 (BOM+CRLF §35) as a standalone file -> operator REPLACES the one file in the staged package on 234 (C:\RTMView-Ops\incoming\234_b58e2c2_19062026_Full\Update-RTMView.ps1). Provide its path + a one-line "swap this file" instruction.
- OR full repackage (Build-ProdRelease -Mode Full) if cleaner — your call; the single-file swap is lower-friction since the package is already staged.

## Report -> .coord/inbox/coordinator.md + chat: commit hash; the fixed Update-RTMView path for the operator to swap; -MigrationList + pg_dump confirmed (object-store); README fixed; privilege note. NO push.
