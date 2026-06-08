# CC Task — Build the server45 (PG17) UPGRADE bundle: orchestrator + DB-upgrade artefacts (+ binaries publish)

> Session devops-2-0607. Assemble the operator-run UPGRADE bundle for server45 (PG17, existing DB w/ live data).
> Coordinator-approved migration-set (6 idempotent migs + functions/ re-apply). NO pg_dump-RESTORE, NO schema.sql
> wholesale, NO align.sql, NO full re-seed. Pre-flight READ-ONLY probe is the go/no-go gate. RTM-DEPLOY-001:
> _008 changes fn_daytrendagentstatus signature -> DB migs + functions re-apply MUST happen while RTM Service AND
> IIS app-pools are STOPPED, paired with the new Shell binaries (origin/v2=aae7efa, has 71b0d9a).

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES-WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f"; fi
done
sync; echo "=== Integrity check complete ==="
# confirm we are at the release commit
git rev-parse HEAD; git rev-parse origin/v2   # both must be aae7efa9a6e78f96cffd486e321d5926dff588db
```
Known false-M (hash==HEAD, do NOT restore): db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS
Session slug: `devops-2-0607`
Claims for this task: `deploy/Apply-Server45Upgrade.ps1`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo STOP; exit 1; fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1
```
Modify ONLY deploy/Apply-Server45Upgrade.ps1 (plus /tmp throwaways). Untracked build outputs go to
Installations/ and publish/ (not committed; assembled into the bundle zip).
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s, phantom-aware. While holding:
`bash tools/pre-commit-check.sh` -> `git add deploy/Apply-Server45Upgrade.ps1`
-> `git commit -m "deploy: server45 PG17 upgrade orchestrator (probe gate + stop + backup + migs + functions + start + verify/rollback)"`
-> §0.6 post-commit verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

---

## Part 1 — author deploy/Apply-Server45Upgrade.ps1 (the orchestrator)

`#Requires -Version 5.1`, `[CmdletBinding()]`. Params (with sensible defaults; passwords NOT defaulted):
```powershell
param(
  [string]$DBHost="localhost", [string]$DBPort="5432", [string]$Database="rtmviewdb",
  [string]$AppUser="ccdashboard_user", [string]$AppPassword="",
  [string]$SuperUser="postgres",       [string]$SuperPassword="",
  [string]$OpsRoot="C:\RTMView-Ops", [string]$InstallRoot="C:\RTMView",
  [string]$ShellSvcName="RTMViewShell", [string]$RTMSvcName="RTMService",
  [string[]]$AppPools=@("CcDashboard.Web","CcDashboard.Api"),
  [string]$ShellPublish="", [string]$RtmPublish="",  # operator-provided, from Build-ProdRelease on Windows
  [switch]$SkipBinaries, [switch]$InlinePublish  # InlinePublish = opt-in fallback only (NOT default)
)
$ErrorActionPreference="Stop"
```
Reuse `Find-PGTool` from db/tools/Export-All.ps1 (resolves PG17 automatically: try 18,17,16,15). BOM-less temp SQL.

Flow (print a clear banner per phase; STOP on any error; everything relative to $OpsRoot / $ScriptDir):

**Phase 0 — PRE-FLIGHT PROBE (go/no-go, READ-ONLY, BEFORE stop/backup):**
- Run `server45_dependency_probe.sql` (located next to the script in the bundle) as $AppUser.
- Parse output: every object must be `t` EXCEPT `db_patch_history` (expected `f`). If ANY required object is `f`
  (other than db_patch_history) -> Write-Error + EXIT 1 (do NOT stop services, do NOT touch anything). This is the gate.

**Phase 1 — STOP (RTM-DEPLOY-001 window opens):**
- `Stop-Service $RTMSvcName -Force` (if exists); `Stop-Service $ShellSvcName -Force` (if exists).
- Import-Module WebAdministration; for each pool in $AppPools: `Stop-WebAppPool` if it exists & running.
- Confirm stopped before proceeding (no window where old Shell / live RTM hits the new fn signature).

**Phase 2 — DB BACKUP (rollback point):**
- `pg_dump` custom-format of $Database as $SuperUser -> `$OpsRoot\backup\server45_<db>_<yyyyMMdd-HHmmss>.backup`.
  (Find pg_dump via Find-PGTool.) Abort if backup fails (no backup -> no upgrade).

**Phase 3 — DEPLOY BINARIES (unless -SkipBinaries):**
- (3a) BACK UP CURRENT BINARIES FIRST (rollback source for P8 — mandatory, do NOT skip): copy
  $InstallRoot\Shell and $InstallRoot\RTM -> `$OpsRoot\backup\binaries_<yyyyMMdd-HHmmss>\`. Remember this path.
- (3b) Copy the operator-provided published binaries (from -ShellPublish / -RtmPublish param paths, produced by
  Build-ProdRelease on Windows — see Part 3) into $InstallRoot, PRESERVING secrets/config (appsettings.json,
  data.sys, app.dat) — mirror Update-RTMView.ps1's preserve logic. Binaries land now, started in Phase 6.
- If -SkipBinaries: skip 3a+3b (operator deploys binaries separately via Update-RTMView); P8 then rolls back the
  DB only. (Coordinator DECISION: binaries come from the tested Windows Build-ProdRelease path, NOT a WSL2 publish.)

**Phase 4 — APPLY MIGRATIONS (name-ordered, as $SuperUser for DDL; ON_ERROR_STOP):**
Apply exactly these 6, in this order, each via `psql -v ON_ERROR_STOP=1 -f`:
  1. 20260604_001_add_agent_state_pct_metrics.sql
  2. 20260605_004_metrics_dedup.sql
  3. 20260606_005_history_unavailable_metrics.sql
  4. 20260606_008_daytrend_fn_bu_scope.sql
  5. 20260607_002_db_patch_history.sql
  6. 20260607_003_fix_curlogintimestamp.sql
(All idempotent. Stop on first error -> go to Phase 7 rollback.)

**Phase 5 — RE-APPLY FUNCTIONS (as $SuperUser; ON_ERROR_STOP):**
Apply db/functions in order: 01_ngc_functions.sql, 02_rtsdata_functions.sql, 03_rtsgrid_read.sql, 04_misc_functions.sql.
(02 converts RTSData_SetInteraction + RTSData_SetChatMessage FUNCTION->PROCEDURE; rest idempotent.)

**Phase 6 — START:**
- Start $AppPools; Start-Service $ShellSvcName, $RTMSvcName (those that exist). RTM-DEPLOY-001 window closes.

**Phase 7 — VERIFY (print a checklist; do NOT auto-pass):**
- Re-run Compare-ToBaseline.ps1 -BaselineDir <bundle db> -OutDir $OpsRoot\output -> operator confirms B=0 and
  "ledger present". 
- Operator confirms: RTM Service started clean (Get-Service Running + check RTM log has no 42809/42883);
  DayTrend widget loads in Shell (proves _008 + new Shell pairing).
- Print the exact re-Compare command + the manual checks.

**Phase 8 — ROLLBACK (documented; semi-automatic):**
- If any of Phases 4-6 fail, OR verify fails: stop services/pools again, restore the Phase-2 pg_dump via
  deploy\Restore-SqlDump.ps1 (custom-format restore), restore previous binaries from the Phase-3a binary-backup dir ($OpsRoot\backup\binaries_<stamp>\),
  restart. Print the exact rollback commands referencing the actual backup file path created in Phase 2.

Logging: tee all phase output to `$OpsRoot\output\server45_upgrade_<stamp>.log`. Each migration apply appends a
line to `$OpsRoot\applied\_ledger.txt` (§43): `<UTC> | <script> | OK|FAIL`.

## Part 2 — assemble the OPS bundle (no commit; output to Installations/)
Build `Installations\server45_upgrade_bundle.zip` containing (sourced from origin/v2=aae7efa via git archive or
checkout to a temp dir, NOT the possibly-truncated working tree):
- `Apply-Server45Upgrade.ps1` (the new orchestrator)
- `server45_dependency_probe.sql` (from staging/)
- `migrations\` = the 6 set migrations only (the exact 6 listed in Phase 4)
- `functions\` = db/functions/01..04
- `Update-RTMView.ps1`, `Restore-SqlDump.ps1` (from deploy/)
- `db\tools\Compare-ToBaseline.ps1` + `db\{schema.sql,functions,data,migrations}` (for the Phase-7 re-Compare,
  -BaselineDir target) — OR reference the already-shipped server45_compare_bundle.zip; your call, but the
  re-Compare in Phase 7 needs a -BaselineDir.

## Part 3 — binaries: via prod-release on WINDOWS, NOT inline CC cross-publish  [coordinator DECISION]
Do NOT `dotnet publish` in this CC task. server45 is live/prod; first-release binaries MUST come from the TESTED
Windows build path (§35), not a WSL2 cross-publish built where it will not run. The operator produces binaries
separately from origin/v2=aae7efa on Windows:
```
powershell -ExecutionPolicy Bypass -File tools/Build-ProdRelease.ps1 -Mode Shell   # -> publish\web (+api), §27 paths
powershell -ExecutionPolicy Bypass -File tools/Build-ProdRelease.ps1 -Mode RTM     # -> publish\rtm
```
The orchestrator Phase 3 consumes those via `-ShellPublish` / `-RtmPublish` params; OR the operator runs the
orchestrator with `-SkipBinaries` and deploys binaries via deploy\Update-RTMView.ps1 separately.
OPTIONAL fallback (operator opt-in ONLY, default OFF): a `-InlinePublish` switch MAY dotnet-publish locally —
implement it but keep it off by default and clearly labelled as non-release path. The bundle zip does NOT contain
binaries.

## Self-test (no live DB / no server)
```bash
powershell -NoProfile -Command "$null=[ScriptBlock]::Create((Get-Content -Raw 'D:\Claude\Projects\RTM View Shell\deploy\Apply-Server45Upgrade.ps1')); 'PARSE OK'"
# confirm the 6 migration names + 4 function files are referenced exactly; probe is Phase-0 gate; rollback present
grep -c "20260607_002_db_patch_history" deploy/Apply-Server45Upgrade.ps1   # >=1
unzip -l Installations/server45_upgrade_bundle.zip | grep -E "Apply-Server45Upgrade|dependency_probe|20260604_001|01_ngc_functions|Update-RTMView"
# bundle must NOT contain dotnet binaries (no publish/) — binaries come from Windows Build-ProdRelease
unzip -l Installations/server45_upgrade_bundle.zip | grep -ciE "publish/|\.dll" # expect 0
```
Do NOT run the orchestrator here (it stops services / writes DB) — operator runs it on server45.

## Commit
ONE commit, prefix `deploy:`, message:
`deploy: server45 PG17 upgrade orchestrator (probe gate + stop + backup + migs + functions + start + verify/rollback)`
Then the S4 wrapper. Bundle zip + publish are untracked artefacts (not committed). NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
