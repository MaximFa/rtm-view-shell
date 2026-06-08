#Requires -Version 5.1
<#
.SYNOPSIS
    SERVER UPGRADE ORCHESTRATOR — PG18-ready. Auto-detects PostgreSQL version.
    RTM-DEPLOY-001: fn_daytrendagentstatus signature change requires coordinated DB+binaries upgrade.

.DESCRIPTION
    Run from the extracted upgrade bundle (server45_upgrade_bundle.zip or similar).
    Phase 0 (pre-flight probe) is the go/no-go gate — READ-ONLY, runs BEFORE anything stops.
    If ANY required object is missing (except db_patch_history), script exits immediately.
    Binaries come from the tested Windows Build-ProdRelease path (§35), not inline cross-publish.

    PG18-ready: auto-detects server version; for Server 234 pass the to-apply set from
    Compare-ToBaseline as -MigrationList. The built-in default-6 (which includes _008) is safe
    — _008 is idempotent when already applied.

    For SERVER 234 specifically, pass the explicit 5-set (omits _008, already applied):
    -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260607_002_db_patch_history.sql,20260607_003_fix_curlogintimestamp.sql"

.PARAMETER AppPassword
    Password for ccdashboard_user (migrations run as superuser, but probe runs as app user).
.PARAMETER SuperPassword
    Password for postgres (DDL migrations).
.PARAMETER ShellPublish
    Path to published Shell binaries (from Build-ProdRelease -Mode Shell).
.PARAMETER RtmPublish
    Path to published RTM binaries (from Build-ProdRelease -Mode RTM).
.PARAMETER SkipBinaries
    If set, skip Phase 3 binary deployment (operator deploys separately via Update-RTMView.ps1).
.PARAMETER InlinePublish
    [OPT-IN ONLY] Fallback: dotnet publish locally. NOT the release path; use only if instructed.
.PARAMETER PgVersion
    PostgreSQL version to prefer (e.g., "18"). Empty = auto-detect (tries 18,17,16,15 in order).
.PARAMETER MigrationList
    Comma-separated list of migration file names to apply, in order. Empty = built-in default set.
.PARAMETER AutoRollback
    On Phase 4/5 failure: automatically run rollback (DB + binaries) before throwing.
.PARAMETER NoResume
    Force re-backup of binaries even if a prior run marker exists (disables clean-resume).

.EXAMPLE
    .\Apply-Server45Upgrade.ps1 -AppPassword "pw" -SuperPassword "spw" -ShellPublish "C:\Build\Shell" -RtmPublish "C:\Build\RTM"
    .\Apply-Server45Upgrade.ps1 -AppPassword "pw" -SuperPassword "spw" -SkipBinaries
#>

[CmdletBinding()]
param(
    [string]$DBHost         = "localhost",
    [string]$DBPort         = "5432",
    [string]$Database       = "rtmviewdb",
    [string]$AppUser        = "ccdashboard_user",
    [string]$AppPassword    = "",
    [string]$SuperUser      = "postgres",
    [string]$SuperPassword  = "",
    [string]$OpsRoot        = "C:\RTMView-Ops",
    [string]$InstallRoot    = "C:\RTMView",
    [string]$ShellSvcName   = "RTMViewShell",
    [string]$RTMSvcName     = "RTMService",
    [string[]]$AppPools     = @("CcDashboard.Web", "CcDashboard.Api"),
    [string]$ShellPublish   = "",
    [string]$RtmPublish     = "",
    [switch]$SkipBinaries,
    [switch]$InlinePublish,
    [string]$PgVersion      = "",        # "" = auto-detect (18,17,16,15). Set "18" to force.
    [string]$MigrationList  = "",        # "" = built-in default set. Else comma-separated file names.
    [switch]$AutoRollback,               # on phase 4/5 failure: auto-run rollback before throwing
    [switch]$NoResume                    # force re-backup of binaries even if prior run marker exists
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile   = Join-Path $OpsRoot "output\server45_upgrade_$Timestamp.log"
$LedgerFile = Join-Path $OpsRoot "applied\_ledger.txt"
$BinaryBackupDir = $null  # set in Phase 3a

# ── Helpers ───────────────────────────────────────────────────────────────────
function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $vers = if ($PgVersion) { @($PgVersion) + @("18","17","16","15") | Select-Object -Unique } else { @("18","17","16","15") }
    foreach ($ver in $vers) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = Join-Path $base "$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Log([string]$msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Banner([string]$phase, [string]$title) {
    $sep = "=" * 70
    Log ""
    Log $sep
    Log "  PHASE $phase — $title"
    Log $sep
}

function Ledger([string]$script, [string]$result) {
    $line = "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') | $script | $result"
    Add-Content -Path $LedgerFile -Value $line -Encoding UTF8
}

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

# ── Setup ─────────────────────────────────────────────────────────────────────
if (-not $AppPassword) { throw "AppPassword is required (for pre-flight probe as $AppUser)." }
if (-not $SuperPassword) { throw "SuperPassword is required (for DDL migrations as $SuperUser)." }

foreach ($dir in @("$OpsRoot\output", "$OpsRoot\backup", "$OpsRoot\applied")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$psql   = Find-PGTool "psql"
$pgdump = Find-PGTool "pg_dump"
if (-not $psql)   { throw "psql not found. Install PostgreSQL client tools." }
if (-not $pgdump) { throw "pg_dump not found. Install PostgreSQL client tools." }

# Detect actual PostgreSQL server version
$env:PGPASSWORD = $AppPassword
$pgVerActual = (& $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -t -A -c "SHOW server_version;" 2>$null)
$env:PGPASSWORD = $null
if (-not $pgVerActual) { $pgVerActual = "unknown" }

# Script-scope paths for Invoke-Rollback (Change 5b — hoist to script scope)
$shellDir = Join-Path $InstallRoot "Shell"
$rtmDir   = Join-Path $InstallRoot "RTM"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      SERVER UPGRADE ORCHESTRATOR (PG $pgVerActual) — RTM-DEPLOY-001            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Log "PostgreSQL server version: $pgVerActual"
Log "Upgrade started: $Timestamp"
Log "Target: $AppUser@${DBHost}:${DBPort}/$Database"
Log "Ops root: $OpsRoot"
Log "Install root: $InstallRoot"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 0 — PRE-FLIGHT PROBE (go/no-go, READ-ONLY)
# ══════════════════════════════════════════════════════════════════════════════
Banner "0" "PRE-FLIGHT PROBE (READ-ONLY — go/no-go gate)"

$probeFile = Join-Path $ScriptDir "server45_dependency_probe.sql"
if (-not (Test-Path $probeFile)) {
    throw "Probe file not found: $probeFile"
}

$env:PGPASSWORD = $AppPassword
Log "Running probe as $AppUser..."
$probeOutput = & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -t -A -f $probeFile 2>&1
$env:PGPASSWORD = $null

Log "Probe output:"
$probeOutput | ForEach-Object { Log "  $_" }

# Parse: expect "object|t" for all except db_patch_history which should be "...|f"
$failed = @()
foreach ($line in $probeOutput) {
    if ($line -match '^(.+)\|(t|f)$') {
        $obj = $Matches[1].Trim()
        $exists = $Matches[2]
        if ($obj -match 'db_patch_history') {
            # Expected to be 'f' — _002 creates it
            if ($exists -eq 't') {
                Log "  [INFO] db_patch_history already exists (re-run or partial apply)"
            }
        } else {
            if ($exists -eq 'f') {
                $failed += $obj
            }
        }
    }
}

if ($failed.Count -gt 0) {
    Log ""
    Log "!!! PROBE FAILED — required objects missing:"
    foreach ($f in $failed) { Log "  - $f" }
    Log ""
    Log "STOPPING. Do NOT proceed. Report to coordinator."
    throw "Pre-flight probe failed: $($failed.Count) missing objects."
}

Log ""
Log "PRE-FLIGHT PROBE PASSED — all required dependencies present."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 1 — STOP SERVICES (RTM-DEPLOY-001 window opens)
# ══════════════════════════════════════════════════════════════════════════════
Banner "1" "STOP SERVICES + APP POOLS"

# Stop RTM Service
$rtmSvc = Get-Service -Name $RTMSvcName -ErrorAction SilentlyContinue
if ($rtmSvc -and $rtmSvc.Status -ne "Stopped") {
    Log "Stopping $RTMSvcName..."
    Stop-Service -Name $RTMSvcName -Force
    Start-Sleep -Seconds 3
}
Log "${RTMSvcName}: $(if ($rtmSvc) { (Get-Service $RTMSvcName).Status } else { 'not installed' })"

# Stop Shell Service
$shellSvc = Get-Service -Name $ShellSvcName -ErrorAction SilentlyContinue
if ($shellSvc -and $shellSvc.Status -ne "Stopped") {
    Log "Stopping $ShellSvcName..."
    Stop-Service -Name $ShellSvcName -Force
    Start-Sleep -Seconds 3
}
Log "${ShellSvcName}: $(if ($shellSvc) { (Get-Service $ShellSvcName).Status } else { 'not installed' })"

# Stop IIS App Pools
Import-Module WebAdministration -ErrorAction SilentlyContinue
foreach ($pool in $AppPools) {
    try {
        $p = Get-WebAppPoolState -Name $pool -ErrorAction SilentlyContinue
        if ($p -and $p.Value -eq "Started") {
            Log "Stopping app pool: $pool"
            Stop-WebAppPool -Name $pool
        }
    } catch {
        Log "  [WARN] App pool '$pool' not found or error: $($_.Exception.Message)"
    }
}

Log "All services/pools stopped — RTM-DEPLOY-001 window OPEN."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 2 — DB BACKUP (rollback point)
# ══════════════════════════════════════════════════════════════════════════════
Banner "2" "DATABASE BACKUP (custom-format pg_dump)"

$backupFile = Join-Path $OpsRoot "backup\server45_${Database}_${Timestamp}.backup"
Log "Creating backup: $backupFile"

$env:PGPASSWORD = $SuperPassword
& $pgdump -h $DBHost -p $DBPort -U $SuperUser -d $Database -Fc -f $backupFile 2>&1 | ForEach-Object { Log "  $_" }
$env:PGPASSWORD = $null

if (-not (Test-Path $backupFile) -or (Get-Item $backupFile).Length -lt 1000) {
    throw "Backup failed or file too small. ABORTING — no backup, no upgrade."
}
$backupSizeMB = [math]::Round((Get-Item $backupFile).Length / 1MB, 2)
Log "Backup complete: $backupSizeMB MB"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3 — DEPLOY BINARIES (unless -SkipBinaries)
# ══════════════════════════════════════════════════════════════════════════════
Banner "3" "DEPLOY BINARIES"

if ($SkipBinaries) {
    Log "SkipBinaries set — operator deploys binaries separately via Update-RTMView.ps1"
} elseif ($InlinePublish) {
    Log "[WARN] InlinePublish is OPT-IN ONLY — NOT the tested release path!"
    Log "Consider using Build-ProdRelease.ps1 on Windows and passing -ShellPublish / -RtmPublish."
    # Inline publish would go here but is intentionally not implemented as default
    throw "InlinePublish not implemented. Use Build-ProdRelease.ps1 and -ShellPublish/-RtmPublish."
} else {
    # Phase 3a — backup current binaries (resume-safe)
    $BinaryBackupDir = Join-Path $OpsRoot "backup\binaries_$Timestamp"
    $resumeMarker = Join-Path $OpsRoot "applied\.binaries_deployed_marker"
    if ((Test-Path $resumeMarker) -and (-not $NoResume)) {
        $prior = Get-Content $resumeMarker -Raw
        Log "[RESUME] Binary-deploy marker found ($prior). Skipping re-backup to preserve original rollback point."
        Log "[RESUME] (use -NoResume to force a fresh backup)"
    } else {
        New-Item -ItemType Directory -Path $BinaryBackupDir -Force | Out-Null
        if (Test-Path $shellDir) {
            Log "Backing up Shell binaries..."
            Copy-Item -Path $shellDir -Destination (Join-Path $BinaryBackupDir "Shell") -Recurse -Force
        }
        if (Test-Path $rtmDir) {
            Log "Backing up RTM binaries..."
            Copy-Item -Path $rtmDir -Destination (Join-Path $BinaryBackupDir "RTM") -Recurse -Force
        }
        Log "Binary backup: $BinaryBackupDir"
    }

    # Phase 3b — deploy new binaries (preserving configs)
    # hole#1 fix: appsettings.json MUST be preserved (clobbering it breaks Shell startup)
    $shellPreserve = @("appsettings.json", "appsettings.Production.json", "web.config", "nlog.config")
    $rtmPreserve   = @("data.sys", "appsettings.json", "log4net.config", "app.dat")

    if ($ShellPublish -and (Test-Path $ShellPublish)) {
        Log "Deploying Shell from: $ShellPublish"
        $preserved = @{}
        foreach ($pf in $shellPreserve) {
            $existing = Join-Path $shellDir $pf
            if (Test-Path $existing) { $preserved[$pf] = Get-Content $existing -Raw }
        }
        if (-not (Test-Path $shellDir)) { New-Item -ItemType Directory -Path $shellDir -Force | Out-Null }
        Copy-Item -Path "$ShellPublish\*" -Destination $shellDir -Recurse -Force
        foreach ($kv in $preserved.GetEnumerator()) {
            Set-Content (Join-Path $shellDir $kv.Key) $kv.Value -Encoding UTF8
            Log "  Preserved: $($kv.Key)"
        }
        Log "  Shell deployed."
        # hole#1 assertion: verify appsettings.json was preserved
        $shellAppCfg = Join-Path $shellDir "appsettings.json"
        if (-not (Test-Path $shellAppCfg) -or (Get-Item $shellAppCfg).Length -lt 10) {
            throw "Shell appsettings.json missing/empty after deploy (hole#1). Restore from $BinaryBackupDir before starting Shell."
        }
        Log "  Verified Shell appsettings.json present ($((Get-Item $shellAppCfg).Length) bytes)."
    } elseif ($ShellPublish) {
        Log "[WARN] ShellPublish path not found: $ShellPublish"
    } else {
        Log "[WARN] ShellPublish not specified — Shell binaries not deployed."
    }

    if ($RtmPublish -and (Test-Path $RtmPublish)) {
        Log "Deploying RTM from: $RtmPublish"
        $preservedRTM = @{}
        foreach ($pf in $rtmPreserve) {
            $existing = Join-Path $rtmDir $pf
            if (Test-Path $existing) { $preservedRTM[$pf] = [System.IO.File]::ReadAllBytes($existing) }
        }
        if (-not (Test-Path $rtmDir)) { New-Item -ItemType Directory -Path $rtmDir -Force | Out-Null }
        Copy-Item -Path "$RtmPublish\*" -Destination $rtmDir -Recurse -Force
        foreach ($kv in $preservedRTM.GetEnumerator()) {
            [System.IO.File]::WriteAllBytes((Join-Path $rtmDir $kv.Key), $kv.Value)
            Log "  Preserved: $($kv.Key)"
        }
        Log "  RTM deployed."
    } elseif ($RtmPublish) {
        Log "[WARN] RtmPublish path not found: $RtmPublish"
    } else {
        Log "[WARN] RtmPublish not specified — RTM binaries not deployed."
    }
    # Write resume marker after successful binary deploy
    Set-Content $resumeMarker "$Timestamp | Shell+RTM deployed" -Encoding UTF8
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4 — APPLY MIGRATIONS (name-ordered, as superuser)
# ══════════════════════════════════════════════════════════════════════════════
Banner "4" "APPLY MIGRATIONS"

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

$migrationsDir = Join-Path $ScriptDir "migrations"
$env:PGPASSWORD = $SuperPassword

foreach ($mig in $migrations) {
    $migFile = Join-Path $migrationsDir $mig
    if (-not (Test-Path $migFile)) {
        Log "[ERROR] Migration not found: $migFile"
        Ledger $mig "FAIL (not found)"
        throw "Migration file missing: $mig. ROLLBACK REQUIRED."
    }

    Log "Applying: $mig"
    $output = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $migFile 2>&1
    $exitCode = $LASTEXITCODE

    $output | ForEach-Object { Log "  $_" }

    if ($exitCode -ne 0) {
        Ledger $mig "FAIL"
        Log "[ERROR] Migration failed: $mig (exit code $exitCode)"
        if ($AutoRollback) { Invoke-Rollback "migration $mig failed" }
        throw "Migration $mig failed. $(if(-not $AutoRollback){'ROLLBACK REQUIRED — see Phase 8.'})"
    }

    Ledger $mig "OK"
    Log "  OK"
}

$env:PGPASSWORD = $null
Log "All $($migrations.Count) migrations applied successfully."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5 — RE-APPLY FUNCTIONS (as superuser)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5" "RE-APPLY FUNCTIONS"

$functions = @(
    "01_ngc_functions.sql",
    "02_rtsdata_functions.sql",
    "03_rtsgrid_read.sql",
    "04_misc_functions.sql"
)

$functionsDir = Join-Path $ScriptDir "functions"
$env:PGPASSWORD = $SuperPassword

foreach ($fn in $functions) {
    $fnFile = Join-Path $functionsDir $fn
    if (-not (Test-Path $fnFile)) {
        Log "[ERROR] Function file not found: $fnFile"
        Ledger $fn "FAIL (not found)"
        throw "Function file missing: $fn. ROLLBACK REQUIRED."
    }

    Log "Applying: $fn"
    $output = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $fnFile 2>&1
    $exitCode = $LASTEXITCODE

    $output | ForEach-Object { Log "  $_" }

    if ($exitCode -ne 0) {
        Ledger $fn "FAIL"
        Log "[ERROR] Function apply failed: $fn (exit code $exitCode)"
        if ($AutoRollback) { Invoke-Rollback "function $fn failed" }
        throw "Function $fn failed. $(if(-not $AutoRollback){'ROLLBACK REQUIRED — see Phase 8.'})"
    }

    Ledger $fn "OK"
    Log "  OK"
}

$env:PGPASSWORD = $null
Log "All function files re-applied successfully."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6 — START SERVICES
# ══════════════════════════════════════════════════════════════════════════════
Banner "6" "START SERVICES + APP POOLS"

# Start IIS App Pools
foreach ($pool in $AppPools) {
    try {
        $p = Get-WebAppPoolState -Name $pool -ErrorAction SilentlyContinue
        if ($p) {
            Start-WebAppPool -Name $pool
            Log "Started app pool: $pool"
        }
    } catch {
        Log "  [WARN] Could not start app pool '$pool': $($_.Exception.Message)"
    }
}

# Start Shell Service
if ($shellSvc) {
    Start-Service -Name $ShellSvcName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Log "${ShellSvcName}: $((Get-Service $ShellSvcName).Status)"
}

# Start RTM Service
if ($rtmSvc) {
    Start-Service -Name $RTMSvcName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Log "${RTMSvcName}: $((Get-Service $RTMSvcName).Status)"
}

Log "RTM-DEPLOY-001 window CLOSED — services started."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 7 — VERIFY (operator checklist)
# ══════════════════════════════════════════════════════════════════════════════
Banner "7" "VERIFICATION CHECKLIST"

Log ""
Log "Manual verification required:"
Log ""
Log "1. Re-run Compare-ToBaseline to confirm no B (routine-kind) diffs:"
Log "   powershell -File db\tools\Compare-ToBaseline.ps1 -BaselineDir `"$ScriptDir\db`" -OutDir `"$OpsRoot\output`" -Password `"<pw>`""
Log "   Expected: B=0, 'ledger present' in delta report."
Log ""
Log "2. Confirm RTM Service started without 42809/42883 errors:"
Log "   Get-Service $RTMSvcName"
Log "   Get-Content `"$InstallRoot\RTM\logs\*.log`" -Tail 50 | Select-String '42809|42883'"
Log ""
Log "3. Confirm DayTrend widget loads in Shell (proves _008 + new Shell pairing):"
Log "   Open browser -> navigate to a dashboard with DayTrend -> verify chart renders."
Log ""
Log "If ALL checks pass: upgrade complete."
Log "If ANY check fails: proceed to Phase 8 ROLLBACK."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 8 — ROLLBACK (documented commands)
# ══════════════════════════════════════════════════════════════════════════════
Banner "8" "ROLLBACK COMMANDS (if needed)"

Log ""
Log "If verification failed, execute these commands to roll back:"
Log ""
Log "# 1. Stop services again"
Log "Stop-Service $RTMSvcName -Force; Stop-Service $ShellSvcName -Force"
Log "Stop-WebAppPool CcDashboard.Web; Stop-WebAppPool CcDashboard.Api"
Log ""
Log "# 2. Restore database from backup"
Log "powershell -File deploy\Restore-SqlDump.ps1 -DumpFile `"$backupFile`" -Database $Database -SuperPassword `"<pw>`""
Log ""
if ($BinaryBackupDir) {
    Log "# 3. Restore previous binaries"
    Log "Copy-Item -Path `"$BinaryBackupDir\Shell\*`" -Destination `"$InstallRoot\Shell`" -Recurse -Force"
    Log "Copy-Item -Path `"$BinaryBackupDir\RTM\*`" -Destination `"$InstallRoot\RTM`" -Recurse -Force"
    Log ""
}
Log "# 4. Start services"
Log "Start-WebAppPool CcDashboard.Web; Start-WebAppPool CcDashboard.Api"
Log "Start-Service $ShellSvcName; Start-Service $RTMSvcName"
Log ""

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              UPGRADE SCRIPT COMPLETE — VERIFY MANUALLY               ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  Log: $LogFile"
Write-Host "  Backup: $backupFile"
if ($BinaryBackupDir) { Write-Host "  Binary backup: $BinaryBackupDir" }
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
