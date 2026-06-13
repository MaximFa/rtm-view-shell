# CC TASK — Fix ApplyService provisioning (server-45 deploy blocker) — for devops-2-0607

> Issued by coordinator-0612. Two real defects block Phase 5a of deploy/Apply-Server45Upgrade.ps1
> (observed live on server 45, 2026-06-12). Prod (Shell+RTM) is UP; ApplyService provisioning failed.
> Fix BOTH in the repo, commit (NO push). Operator then copies the two corrected files onto the
> server-45 package and re-runs STEP B.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## §0.6a Integrity block — Step 0
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# deploy/Apply-Server45Upgrade.ps1 is currently TRUNCATED by PD-007 mount-drift (working < HEAD).
# This task RESTORES it from HEAD before editing (STEP 1). Do NOT blanket line-count-restore here.
sync
```

## Multi-session sync — MANDATORY (tools/cc_prompt_sync_block.md)
Session slug: `devops-2-0607`
Claims: `deploy/Apply-Server45Upgrade.ps1, db/setup/02_catowner_role.sql`
- S1: if `.coord/push/request.md` contains "FREEZE ACTIVE" -> STOP.
- S2: `python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql` -> exit 1 = STOP.
- S3: commit.lock (owner=devops-2-0607) around the commit; retry 5x60s; phantom-aware.
- S4: after commit run `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)`.
- S5: NO `git push`.

ALL writes Python + os.fsync (§0.3). Edit tool BANNED. After each write: `sync` + `tail -3` + `wc -l`.

---

## DEFECT 1 — db/setup/02_catowner_role.sql : psql :'var' inside DO block never substitutes
`:'catowner_pw'` sits inside a `DO $$...$$` dollar-quoted block. psql does NOT perform client-side
variable substitution inside dollar-quoting -> server sees literal `:` -> `syntax error at or near ":"`
-> role ccdashboard_catowner is NEVER created (cascade of "role does not exist"). FIX: pass the password
via a session GUC set at TOP LEVEL (where :'var' substitutes), read it inside DO with current_setting().

### STEP 1 — write the corrected file (Python + fsync), full content:
```
-- db/setup/02_catowner_role.sql
-- Purpose: Create least-privilege role for CcDashboard.ApplyService (hot-reload metrics)
-- Run: psql -U postgres -d <db> -v catowner_pw='<generated>' -f 02_catowner_role.sql
-- Idempotent: safe to re-run.
-- NOTE: psql client-side :'var' substitution does NOT work inside DO $$...$$ dollar-quoted blocks.
--       Pass the password via a session GUC set at top level, read it with current_setting() in the DO.

SELECT set_config('ccdashboard.catowner_pw', :'catowner_pw', false);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ccdashboard_catowner') THEN
    EXECUTE format('CREATE ROLE ccdashboard_catowner LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  ELSE
    EXECUTE format('ALTER ROLE ccdashboard_catowner WITH LOGIN PASSWORD %L', current_setting('ccdashboard.catowner_pw'));
  END IF;
END $$;

-- Schema access
GRANT USAGE ON SCHEMA public, audit TO ccdashboard_catowner;

-- Table grants (least-privilege: only what apply-service needs)
GRANT INSERT, SELECT ON public."RTSGrid_Metric"   TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.metric_deploy_log  TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.db_patch_history   TO ccdashboard_catowner;
GRANT INSERT         ON audit.audit_logs          TO ccdashboard_catowner;
```
Verify: file ends with the `audit.audit_logs` GRANT line; `grep -c "current_setting" db/setup/02_catowner_role.sql` == 2; no remaining `:'catowner_pw'`.

## DEFECT 2 — deploy/Apply-Server45Upgrade.ps1
### STEP 2 — RESTORE the script from HEAD first (it is truncated drift)
```bash
git show HEAD:deploy/Apply-Server45Upgrade.ps1 > deploy/Apply-Server45Upgrade.ps1
sync; tail -3 deploy/Apply-Server45Upgrade.ps1; wc -l deploy/Apply-Server45Upgrade.ps1   # expect ~1034 lines, proper closing
```

### STEP 3a — fix 7 StrictMode-unsafe property reads (lines ~626-628, 684, 825-827)
Under `Set-StrictMode -Version Latest`, `-not $xJson.Prop` THROWS when Prop is absent. Replace ALL
`-not $<...>Json<...>.Prop` with a PSObject membership test. Apply via Python+fsync regex over the file:
```python
import os, re
p="deploy/Apply-Server45Upgrade.ps1"
t=open(p,encoding="utf-8").read()
before=len(re.findall(r'-not \$\w*Json(?:\.\w+)*\.\w+', t))
t=re.sub(r'-not (\$\w*Json(?:\.\w+)*)\.(\w+)', r'\1.PSObject.Properties.Name -notcontains "\2"', t)
after=len(re.findall(r'-not \$\w*Json(?:\.\w+)*\.\w+', t))
with open(p,"w",encoding="utf-8") as f: f.write(t); f.flush(); os.fsync(f.fileno())
print(f"StrictMode reads: {before} -> {after} (expect 7 -> 0)")
```
Must print `7 -> 0`.

### STEP 3b — add ON_ERROR_STOP=1 to the catowner-role psql call (Phase 5a, ~line 601)
Currently the role-provision psql runs WITHOUT `-v ON_ERROR_STOP=1`, so psql swallows errors and exits 0
-> the script falsely logs "role provisioned". Add ON_ERROR_STOP so a future role failure is caught and
(-AutoRollback) handled. Locate the role-provision invocation (the one running $roleScript):
`& $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v catowner_pw="$catownerPw" -f $roleScript 2>&1`
and insert `-v ON_ERROR_STOP=1` immediately after `-d $Database`. Apply via Python+fsync targeted replace
(match the exact roleScript invocation only — NOT the migration loop which already has ON_ERROR_STOP).
Verify with grep that the roleScript line now contains both `ON_ERROR_STOP=1` and `catowner_pw=`.

### STEP 4 — verify the script is intact
```bash
pwsh -NoProfile -Command "try { [scriptblock]::Create((Get-Content -Raw deploy/Apply-Server45Upgrade.ps1)); 'PARSE-OK' } catch { 'PARSE-FAIL: ' + \$_.Exception.Message }" 2>/dev/null || echo "pwsh unavailable - skip parse, rely on tail/wc"
tail -3 deploy/Apply-Server45Upgrade.ps1; wc -l deploy/Apply-Server45Upgrade.ps1
grep -nE 'PSObject.Properties.Name -notcontains' deploy/Apply-Server45Upgrade.ps1   # expect 7 hits
```

## STEP 5 — COMMIT (single fix: commit, NO push), commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql
# acquire commit.lock (owner devops-2-0607), then:
git add deploy/Apply-Server45Upgrade.ps1 db/setup/02_catowner_role.sql
git commit -m "fix: ApplyService provisioning on server-45 deploy — catowner role :var-in-DO (use session GUC) + 7 StrictMode JSON property reads + ON_ERROR_STOP on role psql"
```
Then §0.6 post-commit verify (git status clean; hash-check both files vs HEAD) +
`bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` + PD-007 re-sync of both files. NO push.

## STEP 6 — REPORT to coordinator-0612 (Python+fsync, append)
Append to `.coord/inbox/coordinator-0612.md`: commit hash; both files' final line counts + tail-OK;
StrictMode 7->0 confirmed; role SQL grep (2x current_setting, 0x :'var'); confirm NO push; unpushed count.
NOTE for operator (include in report): after commit, the two corrected files must be copied onto the
server-45 package (overwriting the buggy ones) before re-running STEP B — OR rebuild the package.
