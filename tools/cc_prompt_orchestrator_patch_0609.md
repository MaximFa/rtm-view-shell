# CC Task — Consolidated orchestrator + functions/01 patch (E-015, E-016/[2], E-018, E-010a)

> Session devops-2-0607. ONE patch, TWO files. Fixes the 234-deploy defects found live, in a single
> reviewable change. Supersedes the stale cc_prompt_pg18_orchestrator.md (already landed as 5a16226) and
> cc_prompt_ngc_sigagnostic.md (never issued) — do NOT use those; this prompt carries the full current scope.

## 0. §0.6a MANDATORY INTEGRITY CHECK (run FIRST)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l); W=$(wc -l < "$f" 2>/dev/null)
    if [ $((H-W)) -gt 0 ]; then git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync; echo "=== integrity complete ==="
```

## 0b. §40 — read before starting
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
```

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode, exactly two): `deploy/Apply-Server45Upgrade.ps1`, `db/functions/01_ngc_functions.sql`.
- S1 push-barrier (MARKER-based, tombstone-safe): `grep -q "FREEZE ACTIVE" .coord/push/request.md` → if match STOP & report. A non-empty tombstone ("BARRIER CLEARED"/"FREEZE LIFTED") does NOT block (current request.md IS such a tombstone — do NOT stop on it).
- S2: `python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1 db/functions/01_ngc_functions.sql` (exit1 → STOP).
- S3: commit.lock around git add/commit — create + use `/tmp/acquire_lock.py` EXACTLY as defined in `tools/cc_prompt_sync_block.md` (phantom-aware, retry 5×60s, owner devops-2-0607; 15-min stale = report+wait, never auto-delete). S4: `bash tools/cc_post_commit.sh devops-2-0607 <hash>` (does journal+flush+lock-release atomically — do NOT also journal/release manually). Modify ONLY the two claimed files.
## Git push — DO NOT (§37). §0.3 — Edit tool BANNED, Python read→modify→write + os.fsync, then `tail -3`+`wc -l`.
## §35 — Apply-Server45Upgrade.ps1 MUST stay UTF-8 **BOM** + CRLF. Verify after write:
`head -c3 deploy/Apply-Server45Upgrade.ps1 | xxd | grep -q "efbb bf" && echo "BOM ok" || echo "BOM MISSING — FIX"`

---

# FILE A — deploy/Apply-Server45Upgrade.ps1

The script default is `$ErrorActionPreference = "Stop"`. Keep all existing phases; apply these edits.

## A1 — [E-015] Phase 4 & 5: neutralise psql stderr + abort-safe auto-rollback
**Problem (234 live):** a harmless psql NOTICE on stderr (e.g. "function ... does not exist, skipping")
raised PowerShell `NativeCommandError` (terminating, because EAP=Stop) → script aborted mid-Phase-5 →
`-AutoRollback` did NOT fire (it only checked `$LASTEXITCODE`, never saw a terminating abort).

(a) Around **every** `& $psql ... -f $...` invocation in Phase 4 (migrations) and Phase 5 (functions),
   force `$ErrorActionPreference='Continue'` for the call and decide pass/fail purely on `$LASTEXITCODE`:
```powershell
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$output  = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $file 2>&1
$code    = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
$output | ForEach-Object { Log "  $_" }
if ($code -ne 0) { <existing FAIL handling> }
```
   (ON_ERROR_STOP=1 stays — a REAL SQL error still sets a non-zero exit; only stderr NOTICEs are de-fanged.)

(b) Wrap the Phase 4 + Phase 5 apply bodies in try/catch so a terminating abort ALSO triggers rollback:
```powershell
try {
    # ... Phase 4 migrations loop ...
    # ... Phase 5 functions loop ...
}
catch {
    Log "[ABORT] $($_.Exception.Message)"
    if ($AutoRollback) { Invoke-Rollback "terminating abort: $($_.Exception.Message)" }
    throw
}
```
   So `-AutoRollback` now fires on BOTH a non-zero exit AND a terminating abort.

## A2 — [E-018] kill orphan service exe after Stop-Service (before Phase 3 deploy)
**Problem (234 live):** `Stop-Service RTMViewShell` returns but the Kestrel `CcDashboard.Web.exe` survives →
Phase 3 file-lock / later Start fails. Same risk for the RTM exe.

Add a helper near the other helpers and call it in Phase 1 for BOTH services (replacing the bare Stop-Service):
```powershell
function Stop-ServiceAndExe([string]$svcName) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Stopped") { Log "Stopping $svcName..."; Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
    # wait up to 20s for Stopped
    for ($i=0; $i -lt 20 -and (Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status -ne "Stopped"; $i++) { Start-Sleep 1 }
    # derive exe from the service binary path and force-kill any survivor
    $cim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
    if ($cim -and $cim.PathName) {
        $exe = [System.IO.Path]::GetFileNameWithoutExtension(($cim.PathName -replace '^"([^"]+)".*','$1'))
        $procs = Get-Process -Name $exe -ErrorAction SilentlyContinue
        if ($procs) { Log "Killing orphan exe '$exe' (pid $($procs.Id -join ','))"; $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
    }
    Log "${svcName}: stopped (exe clear)."
}
```
   In Phase 1 use `Stop-ServiceAndExe $RTMSvcName` and `Stop-ServiceAndExe $ShellSvcName` instead of the
   plain Stop-Service calls. Keep the app-pool stop loop afterwards (harmless no-op on 234).
   Belt-and-braces: also kill known exe names if the CIM derive misses: `CcDashboard.Web`, and the RTM exe
   (derive from $RTMSvcName; if its process name differs, the CIM PathName handles it).

## A3 — [E-010a] success-path binary-version manifest
Add param `[string]$ReleaseCommit = ""`. After Phase 6 (services started) on overall success, write a manifest:
```powershell
$manifest = @"
# RTMView Server Manifest — auto-written by Apply-Server45Upgrade.ps1
ReleaseCommit: $ReleaseCommit
PostgreSQL:    $pgVerActual
UpgradedAt:    $(Get-Date -Format o)
Database:      $Database
Migrations:    $($migrations -join ', ')
ShellDeployed: $([bool]$ShellPublish)
RtmDeployed:   $([bool]$RtmPublish)
"@
Set-Content (Join-Path $OpsRoot "SERVER.md") $manifest -Encoding UTF8
Add-Content $LedgerFile "$(Get-Date -Format o) | MANIFEST | commit=$ReleaseCommit PG=$pgVerActual migs=$($migrations.Count)"
Log "Manifest written: $OpsRoot\SERVER.md"
```
   (`$pgVerActual` already exists from the version-detect added in 5a16226; if not, capture `SHOW server_version`.)
   Document in `.PARAMETER`: -ReleaseCommit is the source commit of this package; the build/INSTALL.txt passes it.
   E-010b (READ-before-upgrade: db_patch_history §38a + manifest → to-apply delta) is a SEPARATE follow-up — NOT here.

---

# FILE B — db/functions/01_ngc_functions.sql

## B1 — [E-016/[2]] sig-agnostic DROP for NGC write-PROCEDURES only
**Problem (234 live):** fixed `DROP FUNCTION IF EXISTS "NGC_X"(sig)` ERRORS ("X is not a function") when on
the target NGC_X is already a PROCEDURE (IF EXISTS does NOT suppress wrong-kind). Re-apply aborts (exit 3).

For EACH NGC routine whose definition is `CREATE [OR REPLACE] PROCEDURE "NGC_X"`, replace the fixed-signature
`DROP FUNCTION IF EXISTS "NGC_X"(...)` line(s) immediately preceding it with ONE sig-agnostic DO-loop:
```sql
DO $drop_<name>$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc WHERE proname='NGC_<Name>' AND prokind='f' LOOP
    EXECUTE 'DROP FUNCTION ' || r.sig::text;
  END LOOP;
END $drop_<name>$;
```
Rules — READ CAREFULLY:
- **ONLY for the write-PROCEDURES.** Do NOT touch the `DROP FUNCTION` lines that precede NGC read-FUNCTIONS
  (e.g. NGC_GetBusinessUnitTable, NGC_GetBusinessUnitIdByName, NGC_Get*Table). Those legitimately stay
  FUNCTIONS — their `DROP FUNCTION` is correct. Distinguish by the kind of the CREATE that follows the DROP:
  PROCEDURE → convert; FUNCTION → leave.
- Unique `$drop_<name>$` tag per routine. `prokind='f'` so an existing PROCEDURE is left untouched (idempotent).
- Drop ALL fixed-arg overloads for that procedure; the DO-loop replaces them.
- Procedure bodies BYTE-UNCHANGED. The 14 write-procedures (verify by scanning, don't trust blindly):
  NGC_GetOrCreateQueue, NGC_GetOrCreateAgentGroup, NGC_ModifyBusinessUnit, NGC_DeleteBusinessUnit,
  NGC_ModifySupergroup, NGC_DeleteSupergroup, NGC_CreateBusinessUnitQueueClassificationMapping,
  NGC_DeleteBusinessUnitQueueClassificationMapping, NGC_CreateBusinessUnitSupergroupMapping,
  NGC_DeleteBusinessUnitSupergroupMapping, NGC_CreateSupergroupAgentgroupMapping,
  NGC_DeleteSupergroupAgentgroupMapping, NGC_SetUserAgentgroup, NGC_DeleteUserAgentgroup.

## B-test — fresh DB + RE-APPLY-ON-PROCEDURES (reproduce the 234 failure)
```powershell
$psql="C:\Program Files\PostgreSQL\18\bin\psql.exe"; $env:PGPASSWORD="!@#qweASDzxc"
powershell -File db\tools\Create-FreshDb.ps1 -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc"  # or Restore-All -DropAndRecreate
& $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db\functions\01_ngc_functions.sql; "first apply exit=$LASTEXITCODE"   # expect 0
& $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db\functions\01_ngc_functions.sql; "RE-APPLY exit=$LASTEXITCODE"     # expect 0  <-- this is the E-016 regression guard
& $psql -h localhost -U postgres -d rtmviewdb -t -A -c "SELECT proname,prokind FROM pg_proc WHERE proname LIKE 'NGC_%' AND prokind NOT IN ('p','f');"  # expect 0 rows
$env:PGPASSWORD=$null
```
Static: `grep -c '\$drop_' db/functions/01_ngc_functions.sql` ≥ 14 ; no `DROP FUNCTION IF EXISTS "NGC_` line
remains immediately before a `CREATE [OR REPLACE] PROCEDURE` ; dollar-quote balance even ; proper `tail -3`.
If no Postgres in CC env: run static checks, and clearly report the re-apply test was NOT executed.

---

## Self-tests for FILE A (no server)
- AST parse 0 errors (`[Parser]::ParseFile`).
- grep: `$ReleaseCommit` param present; `$ErrorActionPreference = "Continue"` appears in Phase 4 AND 5 psql calls;
  `Stop-ServiceAndExe` defined + called for both services; `try{`/`catch{` wraps Phase4/5 with Invoke-Rollback;
  `SERVER.md` write present. BOM ok. `tail -3` proper close.

## Commit (ONE commit, both files)
`bash tools/pre-commit-check.sh` → 0 ; commit.lock → `git add deploy/Apply-Server45Upgrade.ps1 db/functions/01_ngc_functions.sql`
→ `git commit -m "deploy+db: orchestrator E-015 psql-stderr+abort-rollback, E-018 orphan-exe kill, E-010a manifest; fn01 NGC sig-agnostic DROP (E-016)"`
→ §0.6 post-commit verify → `bash tools/cc_post_commit.sh devops-2-0607 <hash>` (journal+flush+lock-release, atomic) → HEAD re-sync (PD-007). NO push.

## Report back
AST parse; A-greps; fn01 DO-loop count + residual fixed-NGC-proc DROP count (must be 0); re-apply-test exit codes
(both 0) OR "static-only not run"; BOM; commit hash. Do NOT push.
