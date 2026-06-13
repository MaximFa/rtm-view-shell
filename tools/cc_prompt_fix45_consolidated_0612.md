# CC TASK — Server-45 deploy: consolidated fix + repackage (devops-2-0607)

> Issued by coordinator-0612. The earlier fix (commit 5c6a535) shipped db/setup/02_catowner_role.sql
> with DOUBLED apostrophes (CC write mangled the single quotes) -> psql `syntax error at or near "ccdashboard"`
> on server 45. Plus: Invoke-Rollback assumes IIS app pools, but server 45 is Kestrel Windows Services ->
> rollback errors + leaves Shell/RTM stopped. Fix BOTH in repo, repackage, commit (NO push).
> CLAIM: db/setup/02_catowner_role.sql is granted to you (dba-0610 dormant, operator-authorised; see .coord/queue.md GRANT).

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## §0.6a Integrity block — Step 0
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
git log --oneline -3   # expect HEAD=5c6a535 fix:... ; verify by object store, not mount line-count
sync
```

## Multi-session sync (tools/cc_prompt_sync_block.md)
Session slug: `devops-2-0607`
Claims: `deploy/Apply-Server45Upgrade.ps1, db/setup/02_catowner_role.sql`
- S1 barrier check.
- S2 `coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql`.
  ⚠ KNOWN: this checker reads SESSION-FILE claims, NOT queue GRANTs, so it STILL reports the
  `db/setup/02_catowner_role.sql held by dba-0610 (module db)` conflict. That ONE conflict is RESOLVED
  out-of-band: `.coord/queue.md` GRANT 2026-06-12T09:19Z (-> devops-2-0607; dba-0610 dormant HB 06-10 >2 days,
  operator-authorised takeover §42.2; coordinator-0612 arbitration). PROCEED despite that exit-1 — do NOT STOP
  on THIS specific known dba-0610/02_catowner conflict. If coord_check_claims reports ANY OTHER path conflict,
  STOP + report.
- S3 commit.lock (owner devops-2-0607); S4 cc_post_commit.sh; S5 NO push.
ALL writes Python+os.fsync (§0.3). Edit tool BANNED.

---

## FIX 1 — db/setup/02_catowner_role.sql : rewrite with SINGLE quotes (ANTI-RAKE)
The committed file has `''ccdashboard...''` / `:''catowner_pw''` (doubled). Root cause: embedding SQL in a
Python string doubled the apostrophes. SAFE method — write via a QUOTED heredoc (literal, no escaping), then
fsync through Python reading that temp. Do EXACTLY this:
```bash
cat > /tmp/devops_catowner.sql <<'SQL'
-- db/setup/02_catowner_role.sql
-- Least-privilege role for CcDashboard.ApplyService (hot-reload metrics). Idempotent.
-- NOTE: psql :'var' does NOT substitute inside DO $$...$$ — pass via session GUC set at top level.
SELECT set_config('ccdashboard.catowner_pw', :'catowner_pw', false);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ccdashboard_catowner') THEN
    EXECUTE format('CREATE ROLE ccdashboard_catowner LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  ELSE
    EXECUTE format('ALTER ROLE ccdashboard_catowner WITH LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  END IF;
END $$;

GRANT USAGE ON SCHEMA public, audit TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public."RTSGrid_Metric"   TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.metric_deploy_log  TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.db_patch_history   TO ccdashboard_catowner;
GRANT INSERT         ON audit.audit_logs          TO ccdashboard_catowner;
SQL
python3 -c "import os; d=open('/tmp/devops_catowner.sql',encoding='utf-8').read(); f=open('db/setup/02_catowner_role.sql','w',encoding='utf-8'); f.write(d); f.flush(); os.fsync(f.fileno()); f.close(); print('written',len(d),'bytes')"
sync
```
MANDATORY byte-verify (the anti-rake gate — DO NOT proceed unless all three pass):
```bash
echo "doubled-apostrophes (must be 0): $(grep -c \"''\" db/setup/02_catowner_role.sql)"
echo "current_setting (must be 2): $(grep -c current_setting db/setup/02_catowner_role.sql)"
echo "psql var literal (must be 1): $(grep -c \":'catowner_pw'\" db/setup/02_catowner_role.sql)"
```
If doubled != 0 -> the write mangled quotes again; re-do via the heredoc method, do NOT hand-edit.

## FIX 2 — deploy/Apply-Server45Upgrade.ps1 : rollback must not assume IIS on Kestrel servers
Invoke-Rollback (and Phase 3 stop / Phase 6 start) call Stop/Start-WebAppPool on $AppPools. Server 45 has
NO IIS — `IIS:\AppPools\CcDashboard.Web` does not exist -> `Start-WebAppPool` throws a terminating
provider error (not suppressed by -EA SilentlyContinue), aborts the rollback, leaves Shell/RTM stopped.
FIX: guard every WebAppPool operation so a missing IIS drive is a no-op. Add a helper near the top
(after param/Set-StrictMode), e.g.:
```powershell
function Test-IISAvailable {
    return [bool](Get-Command Get-WebAppPoolState -ErrorAction SilentlyContinue) -and (Test-Path 'IIS:\AppPools' -ErrorAction SilentlyContinue)
}
```
Then wrap each `Stop-WebAppPool` / `Start-WebAppPool` loop with `if (Test-IISAvailable) { ... }` (Kestrel
servers skip pool ops entirely). Apply via Python+fsync targeted replacements; verify no bare
Start-WebAppPool/Stop-WebAppPool remains outside a Test-IISAvailable guard:
```bash
grep -nE 'Start-WebAppPool|Stop-WebAppPool' deploy/Apply-Server45Upgrade.ps1
```

## FIX 3 — confirm FIX from 5c6a535 still intact (StrictMode + ON_ERROR_STOP)
```bash
echo "StrictMode PSObject guards (must be 7): $(grep -c 'PSObject.Properties.Name -notcontains' deploy/Apply-Server45Upgrade.ps1)"
grep -n 'ON_ERROR_STOP=1' deploy/Apply-Server45Upgrade.ps1 | grep -i catowner_pw || echo "CHECK: ensure role psql has ON_ERROR_STOP (it should from 5c6a535)"
```
If StrictMode count != 7 -> re-apply the PSObject fix (regex from cc_prompt_fix_applysvc_provision_0612.md FIX 2 STEP 3a).

## COMMIT (single fix:, NO push) under commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql
git add deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql
git commit -m "fix: server-45 deploy — de-double catowner SQL quotes (5c6a535 regression) + rollback IIS-pool guard for Kestrel servers"
```
Then §0.6 post-commit verify + `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` + PD-007 re-sync. NO push.

## REPACKAGE — rebuild the server-45 package from the fixed tree
Rebuild the 45 in-place upgrade package (same process as Installations/45_0ef423b_20260611-1208.zip was built;
see tools/cc_prompt_build_45.md). Use the new HEAD commit as -ReleaseCommit. Output to Installations/.
Report the EXACT new zip path + verify it contains the corrected db/setup/02_catowner_role.sql
(unzip -p ... | grep -c "''" == 0) and the fixed Apply-Server45Upgrade.ps1 (7 PSObject guards, IIS guard present).

## REPORT to coordinator-0612 (Python+fsync, append .coord/inbox/coordinator-0612.md)
- commit hash; the three verify-gate results (doubled=0, current_setting=2, var=1); StrictMode=7; IIS-guard added;
- new package path + in-package verify (doubled=0); unpushed count; confirm NO push.
- NOTE for operator: deploy server 45 from the NEW package (extract, STEP B same params, NO -AutoRollback needed
  but now safe even if it fires). No more manual file copies.
