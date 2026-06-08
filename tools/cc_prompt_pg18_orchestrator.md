# CC Task — Harden the upgrade orchestrator for PG18 in-place upgrades (Server 234)

> Session devops-2-0607. Make `deploy/Apply-Server45Upgrade.ps1` safe and reusable for a PG18
> in-place Full upgrade. Four hardening points (all observed on server45):
> hole#1 Shell-preserve `appsettings.json`; hole#2 clean-resume + auto-rollback; PG-version
> parameterisation; delta-driven migration list. SINGLE script, behaviour-compatible default.

## 0. MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ $((HEAD_LINES - WT_LINES)) -gt 0 ]; then git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f"; fi
done
sync; echo "=== integrity complete ==="
```

## 0b. Mandatory — read before starting (§40)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
```

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode): `deploy/Apply-Server45Upgrade.ps1` ONLY.
- S1 push-barrier check: if `.coord/push/request.md` is non-empty → STOP, report.
- S2: `python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1` (exit1 → STOP).
- S3/S4: commit.lock around every git add/commit (owner devops-2-0607), then `bash tools/cc_post_commit.sh devops-2-0607 <hash>`.
- Modify ONLY `deploy/Apply-Server45Upgrade.ps1`.

## Git push — DO NOT push (§37). Rides next barrier.

## §0.3 — Edit tool BANNED. All writes via Python read→modify→write + os.fsync, then `tail -3` + `wc -l` verify.

## §35 — PS1 MUST stay UTF-8 **BOM** + CRLF. Verify after write:
```bash
head -c3 deploy/Apply-Server45Upgrade.ps1 | xxd | grep -q "efbb bf" && echo "BOM ok" || echo "BOM MISSING — FIX"
```

---

## The changes — `deploy/Apply-Server45Upgrade.ps1`

Current state is the server45/PG17 orchestrator (8 phases: probe→stop→DB backup→deploy binaries
→migrations→functions→start→verify+rollback). Apply these edits; keep all existing phase logic
and logging intact.

### Change 1 — Parameters (add four)
In the `param(...)` block add:
```powershell
    [string]$PgVersion      = "",        # "" = auto-detect (18,17,16,15). Set "18" to force.
    [string]$MigrationList  = "",        # "" = built-in default set. Else comma-separated file names in apply order.
    [switch]$AutoRollback,               # on phase 4/5 failure: auto-run rollback (DB + binaries) before throwing
    [switch]$NoResume                    # force re-backup of binaries even if a prior run marker exists
```

### Change 2 — `Find-PGTool`: honour `-PgVersion`
Make the version list prefer `$PgVersion` first when set:
```powershell
function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $vers = if ($PgVersion) { @($PgVersion) + @("18","17","16","15") | Select-Object -Unique } else { @("18","17","16","15") }
    foreach ($ver in $vers) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = Join-Path $base "$ver\bin\$Name.exe"; if (Test-Path $p) { return $p }
        }
    }
    return $null
}
```
After resolving `$psql`, derive and log the actual server version:
```powershell
$pgVerActual = (& $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -t -A -c "SHOW server_version;" 2>$null)
Log "PostgreSQL server version: $pgVerActual"
```
(Set `$env:PGPASSWORD=$AppPassword` around that call, clear after.)
Update the banner text from "SERVER45 (PG17)" to "SERVER UPGRADE ORCHESTRATOR (PG $pgVerActual)".

### Change 3 — hole#1: Shell-preserve MUST include plain `appsettings.json`
This is the server45 failure (Shell would not start — publish clobbered `appsettings.json`).
Change the Shell preserve list in Phase 3b:
```powershell
# BEFORE: $shellPreserve = @("appsettings.Production.json", "web.config", "nlog.config")
$shellPreserve = @("appsettings.json", "appsettings.Production.json", "web.config", "nlog.config")
```
Leave `$rtmPreserve = @("data.sys","appsettings.json","log4net.config","app.dat")` unchanged.
After the Shell deploy loop, add an explicit assertion so a clobber can never pass silently:
```powershell
$shellAppCfg = Join-Path $shellDir "appsettings.json"
if (-not (Test-Path $shellAppCfg) -or (Get-Item $shellAppCfg).Length -lt 10) {
    throw "Shell appsettings.json missing/empty after deploy (hole#1). Restore from `$BinaryBackupDir before starting Shell."
}
Log "  Verified Shell appsettings.json present ($((Get-Item $shellAppCfg).Length) bytes)."
```

### Change 4 — hole#2a: clean RESUME (don't overwrite the good binary backup on re-run)
Phase 3a currently always backs up current binaries. On a re-run after a partial upgrade the
"current" binaries are already the NEW ones, so re-backup would destroy the only good rollback
point. Guard it with a per-release marker:
```powershell
# Phase 3a — backup current binaries (resume-safe)
$BinaryBackupDir = Join-Path $OpsRoot "backup\binaries_$Timestamp"
$resumeMarker = Join-Path $OpsRoot "applied\.binaries_deployed_marker"
if ((Test-Path $resumeMarker) -and (-not $NoResume)) {
    $prior = Get-Content $resumeMarker -Raw
    Log "[RESUME] Binary-deploy marker found ($prior). Skipping re-backup to preserve original rollback point."
    Log "[RESUME] (use -NoResume to force a fresh backup)"
} else {
    New-Item -ItemType Directory -Path $BinaryBackupDir -Force | Out-Null
    if (Test-Path $shellDir) { Copy-Item $shellDir (Join-Path $BinaryBackupDir "Shell") -Recurse -Force; Log "Backed up Shell binaries." }
    if (Test-Path $rtmDir)   { Copy-Item $rtmDir   (Join-Path $BinaryBackupDir "RTM")   -Recurse -Force; Log "Backed up RTM binaries." }
    Log "Binary backup: $BinaryBackupDir"
}
```
After a SUCCESSFUL Phase 3b deploy, write the marker:
```powershell
Set-Content $resumeMarker "$Timestamp | Shell+RTM deployed" -Encoding UTF8
```
(Phase 7 success / end-of-run may clear it; leave clearing to the operator for now — document it.)

### Change 5 — hole#2b: AUTO-rollback on Phase 4/5 failure
Add an `Invoke-Rollback` function near the other helpers:
```powershell
function Invoke-Rollback([string]$reason) {
    Log ""; Log "!!! AUTO-ROLLBACK TRIGGERED: $reason"
    try {
        Stop-Service $RTMSvcName   -Force -ErrorAction SilentlyContinue
        Stop-Service $ShellSvcName -Force -ErrorAction SilentlyContinue
        foreach ($pool in $AppPools) { Stop-WebAppPool -Name $pool -ErrorAction SilentlyContinue }
        if (Test-Path $backupFile) {
            Log "Restoring DB from $backupFile ..."
            $env:PGPASSWORD = $SuperPassword
            & $psql -h $DBHost -p $DBPort -U $SuperUser -d "postgres" -c "DROP DATABASE IF EXISTS `"$Database`" WITH (FORCE);" 2>&1 | ForEach-Object { Log "  $_" }
            & $psql -h $DBHost -p $DBPort -U $SuperUser -d "postgres" -c "CREATE DATABASE `"$Database`";" 2>&1 | ForEach-Object { Log "  $_" }
            & (Find-PGTool "pg_restore") -h $DBHost -p $DBPort -U $SuperUser -d $Database $backupFile 2>&1 | ForEach-Object { Log "  $_" }
            $env:PGPASSWORD = $null
        }
        if ($BinaryBackupDir -and (Test-Path $BinaryBackupDir)) {
            if (Test-Path (Join-Path $BinaryBackupDir "Shell")) { Copy-Item (Join-Path $BinaryBackupDir "Shell\*") $shellDir -Recurse -Force }
            if (Test-Path (Join-Path $BinaryBackupDir "RTM"))   { Copy-Item (Join-Path $BinaryBackupDir "RTM\*")   $rtmDir   -Recurse -Force }
            Log "Restored binaries from $BinaryBackupDir"
        }
        foreach ($pool in $AppPools) { Start-WebAppPool -Name $pool -ErrorAction SilentlyContinue }
        if ($shellSvc) { Start-Service $ShellSvcName -ErrorAction SilentlyContinue }
        if ($rtmSvc)   { Start-Service $RTMSvcName   -ErrorAction SilentlyContinue }
        Log "AUTO-ROLLBACK complete — services restarted on previous release."
    } catch { Log "[ROLLBACK ERROR] $($_.Exception.Message) — MANUAL recovery required (see Phase 8)." }
}
```
Wrap the Phase 4 and Phase 5 `foreach` apply loops so that on failure, when `-AutoRollback` is set,
rollback runs before the `throw`. Pattern for each failing branch:
```powershell
if ($exitCode -ne 0) {
    Ledger $mig "FAIL"; Log "[ERROR] $mig failed (exit $exitCode)."
    if ($AutoRollback) { Invoke-Rollback "migration $mig failed" }
    throw "Migration $mig failed. $(if(-not $AutoRollback){'ROLLBACK REQUIRED — see Phase 8.'})"
}
```
(Same shape for the Phase 5 function failure branch.)

### Change 5b — §4 NOTE (a): hoist $shellDir/$rtmDir to script scope (auto-rollback correctness)
`Invoke-Rollback` reads `$shellDir`/`$rtmDir`, but in the current script they are assigned only inside
the Phase 3b `else` block (skipped under `-SkipBinaries`). Define BOTH once at script scope, right after
`$InstallRoot` is known (near the top, before Phase 0), and have Phase 3b REUSE them (do not re-declare):
```powershell
$shellDir = Join-Path $InstallRoot "Shell"
$rtmDir   = Join-Path $InstallRoot "RTM"
```
This guarantees `Invoke-Rollback` always resolves them regardless of the binary-deploy path.
Every variable `Invoke-Rollback` references must exist at script scope before Phase 4:
`$backupFile, $BinaryBackupDir, $ShellSvcName, $RTMSvcName, $SuperUser, $SuperPassword, $AppPools,
$shellDir, $rtmDir, $shellSvc, $rtmSvc, $psql, $DBHost, $DBPort, $Database`. Grep-confirm each in the
self-test (AST parse will NOT catch a name typo).

### Change 6 — delta-driven migration list
Replace the hardcoded `$migrations = @(...)` with: use `-MigrationList` when supplied, else keep
the current built-in list as the documented default. `_004` is now FIXED (commit 782a857) so it
stays in the default set.
```powershell
if ($MigrationList) {
    $migrations = $MigrationList.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    Log "Using operator-supplied migration list ($($migrations.Count) entries)."
} else {
    $migrations = @(
        "20260604_001_add_agent_state_pct_metrics.sql",
        "20260605_004_metrics_dedup.sql",
        "20260606_005_history_unavailable_metrics.sql",
        "20260606_008_daytrend_fn_bu_scope.sql",
        "20260607_002_db_patch_history.sql",
        "20260607_003_fix_curlogintimestamp.sql"
    )
    Log "Using built-in default migration list ($($migrations.Count) entries)."
}
```
Replace the trailing `Log "All 6 migrations applied successfully."` with `Log "All $($migrations.Count) migrations applied successfully."`.

### Change 7 — update the `.SYNOPSIS`/`.PARAMETER` doc header
Document `-PgVersion`, `-MigrationList`, `-AutoRollback`, `-NoResume`, and note: "PG18-ready;
auto-detects server version; for Server 234 pass the to-apply set from Compare-ToBaseline as
-MigrationList. _008 may be skipped if already applied (idempotent if kept).
For SERVER 234 specifically, pass the explicit 5-set (omits _008, already applied):
-MigrationList \"20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260607_002_db_patch_history.sql,20260607_003_fix_curlogintimestamp.sql\"
The built-in default-6 (which includes _008) is also safe — _008 is an idempotent no-op when already applied."

---

## Self-test (no server needed)
1. **Parse clean** (PowerShell AST — no execution):
```bash
pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'deploy/Apply-Server45Upgrade.ps1'), [ref]\$null, [ref]\$null) | Out-Null; if (\$?) {'PARSE OK'}" 2>&1 || \
powershell -NoProfile -Command "..." # if pwsh absent, use Windows PowerShell equivalent
```
   If neither pwsh nor PowerShell available in CC env, at minimum grep-verify: `param(` contains the
   4 new params; `$shellPreserve` line lists `appsettings.json` first; `Invoke-Rollback` defined;
   `$resumeMarker` referenced; `$MigrationList.Split` present.
2. **BOM check** (above) returns "BOM ok".
2b. **Var-scope (§4 note a)**: grep-confirm `$shellDir`/`$rtmDir` are assigned at script scope BEFORE
   Phase 0, and that all variables listed in Change 5b appear in the script. Auto-rollback must not
   reference an undefined name.
3. `tail -3 deploy/Apply-Server45Upgrade.ps1` ends on the closing banner `Write-Host "" `/brace — NOT mid-statement.
4. `wc -l` ≥ original (we only add lines).

## Commit
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock → `git add deploy/Apply-Server45Upgrade.ps1`
  → `git commit -m "deploy: PG18-ready orchestrator — appsettings.json preserve (hole#1), clean-resume + auto-rollback (hole#2), -PgVersion, delta-driven -MigrationList"`
- §0.6 post-commit verify → `bash tools/cc_post_commit.sh devops-2-0607 <hash>` → journal append → release lock.
- Re-sync from HEAD (§0.6 PD-007) as final step.

## Report back
- Confirm: 4 new params present; appsettings.json in Shell-preserve + assertion; resume marker + Invoke-Rollback; delta-driven list; BOM ok; parse/grep self-test results; commit hash. Do NOT push.
