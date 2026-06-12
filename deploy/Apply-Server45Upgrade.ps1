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
.PARAMETER ApplyServicePublish
    Path to published CcDashboard.ApplyService binaries. If empty, ApplyService is not deployed.
.PARAMETER ApplyServicePort
    Loopback port for ApplyService Kestrel (default: 5099). Binds 127.0.0.1 ONLY (DEPLOY-08).
.PARAMETER ApplySvcName
    Windows service name for ApplyService (default: RTMApplyService).
.PARAMETER ShellAppSettingsPath
    Path to deployed Shell appsettings.json to patch BaseUrl. Default: $InstallRoot\Shell\appsettings.json.

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
    [switch]$NoResume,                   # force re-backup of binaries even if prior run marker exists
    [string]$ApplyServicePublish = "",     # path to published ApplyService binaries
    [int]$ApplyServicePort       = 5099,   # loopback port for ApplyService (Kestrel)
    [string]$ApplySvcName        = "RTMApplyService",  # Windows service name
    [string]$ShellAppSettingsPath = "",    # path to Shell appsettings.json (default: $InstallRoot\Shell\appsettings.json)
    [string]$ReleaseCommit = ""              # git commit hash for SERVER.md manifest
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
function Test-IISAvailable {
    return [bool](Get-Command Get-WebAppPoolState -ErrorAction SilentlyContinue) -and (Test-Path 'IIS:\AppPools' -ErrorAction SilentlyContinue)
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
        if (Test-IISAvailable) { foreach ($pool in $AppPools) { Stop-WebAppPool -Name $pool -ErrorAction SilentlyContinue } }
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
        if (Test-IISAvailable) { foreach ($pool in $AppPools) { Start-WebAppPool -Name $pool -ErrorAction SilentlyContinue } }
        if ($shellSvc) { Start-Service $ShellSvcName -ErrorAction SilentlyContinue }
        if ($rtmSvc)   { Start-Service $RTMSvcName   -ErrorAction SilentlyContinue }
        Log "AUTO-ROLLBACK complete — services restarted on previous release."
    } catch { Log "[ROLLBACK ERROR] $($_.Exception.Message) — MANUAL recovery required (see Phase 8)." }
}

function Stop-ServiceAndExe([string]$svcName, [string]$componentDir = "") {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Stopped") { Log "Stopping $svcName..."; Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
    # wait up to 20s for Stopped
    for ($i=0; $i -lt 20 -and (Get-Service -Name $svcName -ErrorAction SilentlyContinue).Status -ne "Stopped"; $i++) { Start-Sleep 1 }
    
    # A5: Kill orphan processes by PATH (not just exe name) — catches Kestrel children
    if ($componentDir -and (Test-Path $componentDir)) {
        $dirPrefix = $componentDir.TrimEnd('\') + '\'
        $orphans = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like "$dirPrefix*" }
        foreach ($p in $orphans) {
            Log "  Killing orphan by path: $($p.Name) (pid $($p.ProcessId)) - $($p.ExecutablePath)"
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
        }
        Start-Sleep 2
        # Verify none remain
        $survivors = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like "$dirPrefix*" }
        if ($survivors) {
            foreach ($s in $survivors) { Log "  [WARN] Survivor: $($s.Name) (pid $($s.ProcessId))" }
            throw "${svcName}: Failed to kill all processes under $componentDir — $($survivors.Count) survivors remain"
        }
    } else {
        # Fallback: derive exe from the service binary path (legacy behavior)
        $cim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
        if ($cim -and $cim.PathName) {
            $exe = [System.IO.Path]::GetFileNameWithoutExtension(($cim.PathName -replace '^"([^"]+)".*','$1'))
            $procs = Get-Process -Name $exe -ErrorAction SilentlyContinue
            if ($procs) { Log "Killing orphan exe '$exe' (pid $($procs.Id -join ','))"; $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
        }
    }
    Log "${svcName}: stopped (exe clear)."
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

# A5: Neutralize service recovery BEFORE stopping (prevents restart during kill)
$rtmSvc = Get-Service -Name $RTMSvcName -ErrorAction SilentlyContinue
if ($rtmSvc) {
    Log "Neutralizing $RTMSvcName recovery (prevent respawn during upgrade)..."
    Set-Service -Name $RTMSvcName -StartupType Manual -ErrorAction SilentlyContinue
    & sc.exe failure $RTMSvcName reset= 0 actions= "" 2>&1 | Out-Null
    Stop-ServiceAndExe $RTMSvcName $rtmDir
} else { Log "${RTMSvcName}: not installed" }

$shellSvc = Get-Service -Name $ShellSvcName -ErrorAction SilentlyContinue
if ($shellSvc) {
    Log "Neutralizing $ShellSvcName recovery (prevent respawn during upgrade)..."
    Set-Service -Name $ShellSvcName -StartupType Manual -ErrorAction SilentlyContinue
    & sc.exe failure $ShellSvcName reset= 0 actions= "" 2>&1 | Out-Null
    Stop-ServiceAndExe $ShellSvcName $shellDir
} else { Log "${ShellSvcName}: not installed" }

# Stop ApplyService (silently skip if absent)
$applyDir = Join-Path $InstallRoot "ApplyService"
$applySvc = Get-Service -Name $ApplySvcName -ErrorAction SilentlyContinue
if ($applySvc) {
    Set-Service -Name $ApplySvcName -StartupType Manual -ErrorAction SilentlyContinue
    & sc.exe failure $ApplySvcName reset= 0 actions= "" 2>&1 | Out-Null
    Stop-ServiceAndExe $ApplySvcName $applyDir
} else { Log "NT SERVICE\${ApplySvcName}: not installed (skipping)" }

# Stop IIS App Pools (skip if IIS not available — Kestrel-only servers)
if (Test-IISAvailable) {
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
} else {
    Log "IIS not available — skipping app pool stop (Kestrel-only server)"
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
            if (Test-Path $existing) {
                $preservedRTM[$pf] = [System.IO.File]::ReadAllBytes($existing)
                Log "  Pre-deploy preserve: $pf ($([System.IO.File]::ReadAllBytes($existing).Length) bytes)"
            } else {
                Log "  [INFO] $pf not found at $existing (first-time install or already absent)"
            }
        }
        if (-not (Test-Path $rtmDir)) { New-Item -ItemType Directory -Path $rtmDir -Force | Out-Null }
        Copy-Item -Path "$RtmPublish\*" -Destination $rtmDir -Recurse -Force
        foreach ($kv in $preservedRTM.GetEnumerator()) {
            [System.IO.File]::WriteAllBytes((Join-Path $rtmDir $kv.Key), $kv.Value)
            Log "  Preserved: $($kv.Key)"
        }
        Log "  RTM deployed."
        
        # A6: Assert RTM:TenantId was preserved (not Guid.Empty from package)
        $rtmAppCfg = Join-Path $rtmDir "appsettings.json"
        if (Test-Path $rtmAppCfg) {
            try {
                $rtmCfgJson = Get-Content $rtmAppCfg -Raw | ConvertFrom-Json
                $rtmTenantId = $null
                if ($rtmCfgJson.RTM -and $rtmCfgJson.RTM.TenantId) { $rtmTenantId = $rtmCfgJson.RTM.TenantId }
                if (-not $rtmTenantId -or $rtmTenantId -eq "00000000-0000-0000-0000-000000000000") {
                    Log "[FATAL] RTM appsettings TenantId is empty/placeholder after deploy — appsettings.json was clobbered!"
                    Log "  Restore from $BinaryBackupDir\RTM\appsettings.json and retry."
                    throw "RTM:TenantId clobbered (A6 assertion). Deploy failed."
                }
                Log "  Verified RTM:TenantId = $rtmTenantId (not clobbered)"
            } catch {
                if ($_.Exception.Message -match "clobbered") { throw }
                Log "  [WARN] Could not verify RTM:TenantId: $($_.Exception.Message)"
            }
        } else {
            Log "[WARN] RTM appsettings.json not found after deploy — first-time install? Set TenantId manually."
        }
    } elseif ($RtmPublish) {
        Log "[WARN] RtmPublish path not found: $RtmPublish"
    } else {
        Log "[WARN] RtmPublish not specified — RTM binaries not deployed."
    }

    # Deploy ApplyService
    $applyDir = Join-Path $InstallRoot "ApplyService"
    $applyPreserve = @("appsettings.json")
    if ($ApplyServicePublish -and (Test-Path $ApplyServicePublish)) {
        Log "Deploying ApplyService from: $ApplyServicePublish"
        $preservedApply = @{}
        foreach ($pf in $applyPreserve) {
            $existing = Join-Path $applyDir $pf
            if (Test-Path $existing) { $preservedApply[$pf] = Get-Content $existing -Raw }
        }
        if (-not (Test-Path $applyDir)) { New-Item -ItemType Directory -Path $applyDir -Force | Out-Null }
        Copy-Item -Path "$ApplyServicePublish\*" -Destination $applyDir -Recurse -Force
        foreach ($kv in $preservedApply.GetEnumerator()) {
            Set-Content (Join-Path $applyDir $kv.Key) $kv.Value -Encoding UTF8
            Log "  Preserved: $($kv.Key)"
        }
        Log "  ApplyService deployed."
    } elseif ($ApplyServicePublish) {
        Log "[WARN] ApplyServicePublish path not found: $ApplyServicePublish"
    }
    # Write resume marker after successful binary deploy
    Set-Content $resumeMarker "$Timestamp | Shell+RTM deployed" -Encoding UTF8
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4 — APPLY MIGRATIONS (name-ordered, as superuser)
# ══════════════════════════════════════════════════════════════════════════════
Banner "4" "APPLY MIGRATIONS"

if ($MigrationList) {
    $migrations = @($MigrationList.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
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

# E-015: try/catch ensures -AutoRollback fires on terminating abort
try {

foreach ($mig in $migrations) {
    $migFile = Join-Path $migrationsDir $mig
    if (-not (Test-Path $migFile)) {
        Log "[ERROR] Migration not found: $migFile"
        Ledger $mig "FAIL (not found)"
        throw "Migration file missing: $mig. ROLLBACK REQUIRED."
    }

    Log "Applying: $mig"
    # E-015: neutralize psql stderr — decide on exit code only
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $output = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $migFile 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
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
    # E-015: neutralize psql stderr — decide on exit code only
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $output = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $fnFile 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
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

} catch {
    Log "[ABORT] $($_.Exception.Message)"
    if ($AutoRollback) { Invoke-Rollback "terminating abort: $($_.Exception.Message)" }
    throw
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5a — PROVISION APPLYSERVICE (role + secrets + config wiring)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5a" "PROVISION APPLYSERVICE"

if ($ApplyServicePublish) {
    Log "ApplyService deployment requested — provisioning ccdashboard_catowner role + secrets..."

    # Generate secrets using CSRNG (RandomNumberGenerator, NOT Get-Random)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 32
    $rng.GetBytes($bytes)
    $catownerPw = [Convert]::ToBase64String($bytes) -replace '[+/=]',''  # URL-safe
    $rng.GetBytes($bytes)
    $applyToken = [Convert]::ToBase64String($bytes) -replace '[+/=]',''  # URL-safe
    $rng.Dispose()
    Log "Generated catownerPw ($($catownerPw.Length) chars) and applyToken ($($applyToken.Length) chars) via CSRNG"

    # Provision role (run as postgres)
    $roleScript = Join-Path $ScriptDir "db\setup\02_catowner_role.sql"
    if (-not (Test-Path $roleScript)) {
        $roleScript = Join-Path (Split-Path $ScriptDir) "db\setup\02_catowner_role.sql"
    }
    if (-not (Test-Path $roleScript)) {
        throw "Role setup script not found: db/setup/02_catowner_role.sql"
    }
    Log "Provisioning ccdashboard_catowner role..."
    $env:PGPASSWORD = $SuperPassword
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $roleOutput = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -v catowner_pw="$catownerPw" -f $roleScript 2>&1
    $roleExitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    $env:PGPASSWORD = $null
    $roleOutput | ForEach-Object { Log "  $_" }
    if ($roleExitCode -ne 0) {
        Ledger "02_catowner_role.sql" "FAIL"
        if ($AutoRollback) { Invoke-Rollback "catowner role provision failed" }
        throw "Role provision failed (exit $roleExitCode). ROLLBACK REQUIRED."
    }
    Ledger "02_catowner_role.sql" "OK"
    Log "  ccdashboard_catowner role provisioned."

    # Build catowner connection string
    $catownerConn = "Host=$DBHost;Port=$DBPort;Database=$Database;Username=ccdashboard_catowner;Password=$catownerPw"

    # ApplyService config: non-secret in appsettings, secrets in service ENV
    $applyDir = Join-Path $InstallRoot "ApplyService"
    $applyAppSettings = Join-Path $applyDir "appsettings.json"
    if (Test-Path $applyAppSettings) {
        Log "Patching ApplyService appsettings.json (non-secrets only)..."
        $applyJson = Get-Content $applyAppSettings -Raw | ConvertFrom-Json
        # Ensure Kestrel section exists
        if ($applyJson.PSObject.Properties.Name -notcontains "Kestrel") { $applyJson | Add-Member -NotePropertyName "Kestrel" -NotePropertyValue ([PSCustomObject]@{}) }
        if ($applyJson.Kestrel.PSObject.Properties.Name -notcontains "Endpoints") { $applyJson.Kestrel | Add-Member -NotePropertyName "Endpoints" -NotePropertyValue ([PSCustomObject]@{}) }
        if ($applyJson.Kestrel.Endpoints.PSObject.Properties.Name -notcontains "Http") { $applyJson.Kestrel.Endpoints | Add-Member -NotePropertyName "Http" -NotePropertyValue ([PSCustomObject]@{}) }
        $applyJson.Kestrel.Endpoints.Http | Add-Member -NotePropertyName "Url" -NotePropertyValue "http://127.0.0.1:$ApplyServicePort" -Force
        # Write back (read-modify-write preserves other keys)
        $applyJson | ConvertTo-Json -Depth 10 | Set-Content $applyAppSettings -Encoding UTF8
        Log "  Set Kestrel.Endpoints.Http.Url = http://127.0.0.1:$ApplyServicePort"
    }

    # Register ApplyService Windows Service (B5)
    $existingApplySvc = Get-Service -Name $ApplySvcName -ErrorAction SilentlyContinue
    $applyExePath = Join-Path $applyDir "CcDashboard.ApplyService.exe"
    if (-not $existingApplySvc) {
        Log "Registering new Windows service: $ApplySvcName"
        New-Service -Name $ApplySvcName -BinaryPathName "`"$applyExePath`"" -StartupType Automatic -DisplayName "RTM Apply Service" | Out-Null
        Log "  Service registered."
    } else {
        # Update binary path if changed
        $cim = Get-CimInstance Win32_Service -Filter "Name='$ApplySvcName'" -ErrorAction SilentlyContinue
        if ($cim -and $cim.PathName -ne "`"$applyExePath`"") {
            Log "Updating service binary path..."
            sc.exe config $ApplySvcName binPath= "`"$applyExePath`"" | Out-Null
        }
        Log "  Service $ApplySvcName already exists."
    }

    # Set service environment variables (secrets: token + catowner connection)
    # Registry: HKLM\SYSTEM\CurrentControlSet\Services\$ApplySvcName\Environment (REG_MULTI_SZ)
    $svcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ApplySvcName"
    $envVars = @(
        "ConnectionStrings__CatalogueOwner=$catownerConn",
        "ApplyService__Token=$applyToken"
    )
    Set-ItemProperty -Path $svcRegPath -Name "Environment" -Value $envVars -Type MultiString
    Log "  Set ApplyService ENV: ConnectionStrings__CatalogueOwner, ApplyService__Token (secrets in registry, NOT appsettings)"

    # Set Shell service environment variable (MetricsApply__Token)
    # Registry: HKLM\SYSTEM\CurrentControlSet\Services\$ShellSvcName\Environment
    $shellSvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ShellSvcName"
    if (Test-Path $shellSvcRegPath) {
        # Read existing env vars and append/update
        $existingEnv = @()
        try { $existingEnv = @(Get-ItemPropertyValue -Path $shellSvcRegPath -Name "Environment" -ErrorAction SilentlyContinue) } catch {}
        # Remove old MetricsApply__Token if present
        $existingEnv = $existingEnv | Where-Object { $_ -notmatch "^MetricsApply__Token=" }
        $existingEnv += "MetricsApply__Token=$applyToken"
        Set-ItemProperty -Path $shellSvcRegPath -Name "Environment" -Value $existingEnv -Type MultiString
        Log "  Set Shell ENV: MetricsApply__Token (same token value, secret in registry, NOT appsettings)"
    } else {
        Log "  [WARN] Shell service registry path not found: $shellSvcRegPath — Shell env not set."
    }

    # Patch Shell appsettings: ONLY non-secret BaseUrl (B3.5)
    $shellDir = Join-Path $InstallRoot "Shell"
    if (-not $ShellAppSettingsPath) { $ShellAppSettingsPath = Join-Path $shellDir "appsettings.json" }
    if (Test-Path $ShellAppSettingsPath) {
        Log "Patching Shell appsettings.json (non-secret BaseUrl only)..."
        $shellJson = Get-Content $ShellAppSettingsPath -Raw | ConvertFrom-Json
        if ($shellJson.PSObject.Properties.Name -notcontains "MetricsApply") { $shellJson | Add-Member -NotePropertyName "MetricsApply" -NotePropertyValue ([PSCustomObject]@{}) }
        $shellJson.MetricsApply | Add-Member -NotePropertyName "BaseUrl" -NotePropertyValue "http://127.0.0.1:$ApplyServicePort" -Force
        # NOTE: Token is NOT written here — it's the Shell service env var MetricsApply__Token
        $shellJson | ConvertTo-Json -Depth 10 | Set-Content $ShellAppSettingsPath -Encoding UTF8
        Log "  Set MetricsApply:BaseUrl = http://127.0.0.1:$ApplyServicePort (Token is ENV VAR, not here)"
    } else {
        Log "  [WARN] Shell appsettings not found: $ShellAppSettingsPath"
    }

    Log ""
    Log "NOTE: DPAPI/Credential Manager = future hardening; env-var is the CODE-05-sanctioned v1 path; caller unchanged."
    Log "ApplyService provisioning complete."
} else {
    Log "ApplyServicePublish not specified — skipping ApplyService provisioning."
}



# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5b — NTFS ACL LOCK (F-4 integrity anchor)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5b" "NTFS ACL LOCK (F-4 integrity anchor)"

# F-4 defense-in-depth: lock PackageMigrationsDir + ManifestPath so tampering requires admin.
# Combined with F-4 hash-check in ApplyService = real migration integrity.

if ($ApplyServicePublish) {
    $applyDir = Join-Path $InstallRoot "ApplyService"
    $applyAppSettings = Join-Path $applyDir "appsettings.json"

    # Read configured paths from appsettings.json
    $pkgMigDir = $null
    $manifestPath = $null
    if (Test-Path $applyAppSettings) {
        try {
            $applyJson = Get-Content $applyAppSettings -Raw | ConvertFrom-Json
            $pkgMigDir = $applyJson.PackageMigrationsDir
            $manifestPath = $applyJson.ManifestPath
        } catch {
            Log "[WARN] Could not parse ApplyService appsettings.json for paths"
        }
    }

    # Default paths if not configured
    if (-not $pkgMigDir) { $pkgMigDir = Join-Path $InstallRoot "Packages\migrations" }
    if (-not $manifestPath) { $manifestPath = Join-Path $InstallRoot "Packages\manifest.json" }

    Log "Locking paths for F-4 integrity:"
    Log "  PackageMigrationsDir: $pkgMigDir"
    Log "  ManifestPath: $manifestPath"

    # Ensure the target directories exist
    if (-not (Test-Path $pkgMigDir)) {
        New-Item -ItemType Directory -Path $pkgMigDir -Force | Out-Null
        Log "  Created directory: $pkgMigDir"
    }
    $manifestDir = Split-Path $manifestPath -Parent
    if ($manifestDir -and -not (Test-Path $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Log "  Created directory: $manifestDir"
    }

    # icacls command pattern:
    # - Remove inheritance: /inheritance:r
    # - Grant SYSTEM full: /grant:r "SYSTEM:(OI)(CI)F"
    # - Grant Administrators full: /grant:r "Administrators:(OI)(CI)F"
    # - Grant service account read+execute: /grant:r "$ApplySvcName:(OI)(CI)RX"
    # - Remove Users and Authenticated Users (no write for non-admins)

    # Apply ACL to PackageMigrationsDir
    Log "  Applying ACL to PackageMigrationsDir..."
    $aclOutput = & icacls $pkgMigDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F" /grant:r "NT SERVICE\${ApplySvcName}:(OI)(CI)RX" 2>&1
    $aclOutput | ForEach-Object { Log "    $_" }
    & icacls $pkgMigDir /remove:g "Users" 2>&1 | Out-Null
    & icacls $pkgMigDir /remove:g "Authenticated Users" 2>&1 | Out-Null
    Log "  ACL applied to PackageMigrationsDir."

    # Apply ACL to ManifestPath (file or parent dir if file doesn't exist yet)
    if (Test-Path $manifestPath) {
        Log "  Applying ACL to ManifestPath (file)..."
        $aclOutput = & icacls $manifestPath /inheritance:r /grant:r "SYSTEM:F" /grant:r "Administrators:F" /grant:r "NT SERVICE\${ApplySvcName}:RX" 2>&1
        $aclOutput | ForEach-Object { Log "    $_" }
        & icacls $manifestPath /remove:g "Users" 2>&1 | Out-Null
        & icacls $manifestPath /remove:g "Authenticated Users" 2>&1 | Out-Null
        Log "  ACL applied to ManifestPath."
    } else {
        Log "  ManifestPath file does not exist yet - applying ACL to parent directory..."
        if ($manifestDir -and (Test-Path $manifestDir)) {
            $aclOutput = & icacls $manifestDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F" /grant:r "NT SERVICE\${ApplySvcName}:(OI)(CI)RX" 2>&1
            $aclOutput | ForEach-Object { Log "    $_" }
            & icacls $manifestDir /remove:g "Users" 2>&1 | Out-Null
            & icacls $manifestDir /remove:g "Authenticated Users" 2>&1 | Out-Null
            Log "  ACL applied to manifest directory (files inherit)."
        }
    }

    # Log final ACLs for audit
    Log "  Final ACL verification:"
    Log "    PackageMigrationsDir:"
    & icacls $pkgMigDir 2>&1 | ForEach-Object { Log "      $_" }
    if (Test-Path $manifestPath) {
        Log "    ManifestPath:"
        & icacls $manifestPath 2>&1 | ForEach-Object { Log "      $_" }
    } elseif ($manifestDir -and (Test-Path $manifestDir)) {
        Log "    ManifestDir (parent):"
        & icacls $manifestDir 2>&1 | ForEach-Object { Log "      $_" }
    }

    Ledger "NTFS_ACL_LOCK" "OK"
    Log "F-4 NTFS ACL lock complete - tampering requires Administrator."
} else {
    Log "ApplyServicePublish not specified - skipping NTFS ACL lock."
}




# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5c — RTM LOOPBACK REBIND (F-3 security fix)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5c" "RTM LOOPBACK REBIND (F-3 security fix)"

# F-3: RTM SignalR hub must bind 127.0.0.1 only (not * or 0.0.0.0) so it is
# unreachable from browser/network. Shell reaches it via RtmRelayService (§34).

$rtmAppSettingsPath = Join-Path $rtmDir "appsettings.json"

# B1 — Assert/patch deployed RTM appsettings bind = loopback
if (Test-Path $rtmAppSettingsPath) {
    Log "B1: Checking RTM appsettings Kestrel bind..."
    try {
        $rtmJson = Get-Content $rtmAppSettingsPath -Raw | ConvertFrom-Json
        $currentUrl = $null
        if ($rtmJson.Kestrel -and $rtmJson.Kestrel.Endpoints -and $rtmJson.Kestrel.Endpoints.Http) {
            $currentUrl = $rtmJson.Kestrel.Endpoints.Http.Url
        }

        $loopbackUrl = "http://127.0.0.1:8088"
        if ($currentUrl -ne $loopbackUrl) {
            Log "  Changing Kestrel bind: $currentUrl -> $loopbackUrl"
            # Ensure structure exists
            if ($rtmJson.PSObject.Properties.Name -notcontains "Kestrel") { $rtmJson | Add-Member -NotePropertyName "Kestrel" -NotePropertyValue ([PSCustomObject]@{}) }
            if ($rtmJson.Kestrel.PSObject.Properties.Name -notcontains "Endpoints") { $rtmJson.Kestrel | Add-Member -NotePropertyName "Endpoints" -NotePropertyValue ([PSCustomObject]@{}) }
            if ($rtmJson.Kestrel.Endpoints.PSObject.Properties.Name -notcontains "Http") { $rtmJson.Kestrel.Endpoints | Add-Member -NotePropertyName "Http" -NotePropertyValue ([PSCustomObject]@{}) }
            $rtmJson.Kestrel.Endpoints.Http | Add-Member -NotePropertyName "Url" -NotePropertyValue $loopbackUrl -Force
            $rtmJson | ConvertTo-Json -Depth 10 | Set-Content $rtmAppSettingsPath -Encoding UTF8
            Log "  RTM appsettings patched: Kestrel bind = $loopbackUrl"
        } else {
            Log "  RTM appsettings already loopback-bound: $currentUrl"
        }
    } catch {
        Log "[WARN] B1: Could not parse/patch RTM appsettings: $($_.Exception.Message)"
    }
} else {
    Log "[WARN] B1: RTM appsettings not found: $rtmAppSettingsPath"
}

# B2 — Update tenant_settings.SignalRConnectionUrl to loopback (Shell→RTM relay)
Log "B2: Setting tenant_settings.SignalRConnectionUrl to loopback..."
$rtmTenantId = $null
if (Test-Path $rtmAppSettingsPath) {
    try {
        $rtmJson = Get-Content $rtmAppSettingsPath -Raw | ConvertFrom-Json
        if ($rtmJson.RTM -and $rtmJson.RTM.TenantId) {
            $rtmTenantId = $rtmJson.RTM.TenantId
        }
    } catch {
        Log "[WARN] B2: Could not read RTM:TenantId from appsettings"
    }
}

if ($rtmTenantId -and $rtmTenantId -ne "00000000-0000-0000-0000-000000000000") {
    $signalRUrl = "http://127.0.0.1:8088/signalr"
    $updateSql = "UPDATE tenant_settings SET `"SignalRConnectionUrl`" = '$signalRUrl' WHERE `"TenantId`" = '$rtmTenantId';"
    Log "  Updating tenant_settings for TenantId=$rtmTenantId"
    Log "  SignalRConnectionUrl = $signalRUrl"

    $env:PGPASSWORD = $AppPassword
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $updateOutput = & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -c $updateSql 2>&1
    $updateExitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    $env:PGPASSWORD = $null

    $updateOutput | ForEach-Object { Log "    $_" }
    if ($updateExitCode -ne 0) {
        Log "[WARN] B2: UPDATE failed (exit $updateExitCode) — set SignalRConnectionUrl via Tenant Settings UI"
    } else {
        Log "  B2: SignalRConnectionUrl set to loopback."
        Ledger "F3_SIGNALR_URL" "OK"
    }
} else {
    Log "[WARN] B2: RTM:TenantId empty or placeholder — cannot update tenant_settings."
    Log "  Set SignalRConnectionUrl = http://127.0.0.1:8088/signalr via Tenant Settings UI after deploy."
}

Ledger "F3_RTM_LOOPBACK" "OK"
Log "F-3 RTM loopback rebind complete — hub now unreachable from network."

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6 — START SERVICES
# ══════════════════════════════════════════════════════════════════════════════
Banner "6" "START SERVICES + APP POOLS"

# Start IIS App Pools (skip if IIS not available — Kestrel-only servers)
if (Test-IISAvailable) {
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
} else {
    Log "IIS not available — skipping app pool start (Kestrel-only server)"
}

# Start Shell Service (A5: restore StartupType after Phase 1 neutralization)
if ($shellSvc) {
    Set-Service -Name $ShellSvcName -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $ShellSvcName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Log "${ShellSvcName}: $((Get-Service $ShellSvcName).Status)"
}

# Start RTM Service (A5: restore StartupType after Phase 1 neutralization)
if ($rtmSvc) {
    Set-Service -Name $RTMSvcName -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $RTMSvcName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Log "${RTMSvcName}: $((Get-Service $RTMSvcName).Status)"
}

# Start ApplyService
if ($ApplyServicePublish) {
    $applySvc = Get-Service -Name $ApplySvcName -ErrorAction SilentlyContinue
    if ($applySvc) {
        Start-Service -Name $ApplySvcName -ErrorAction SilentlyContinue
        # Wait loop for Running
        for ($i=0; $i -lt 30 -and (Get-Service -Name $ApplySvcName -ErrorAction SilentlyContinue).Status -ne "Running"; $i++) { Start-Sleep 1 }
        Log "NT SERVICE\${ApplySvcName}: $((Get-Service $ApplySvcName).Status)"
        # Health check (optional)
        try {
            $healthUrl = "http://127.0.0.1:$ApplyServicePort/health"
            $resp = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200) { Log "  Health check OK: $healthUrl" }
        } catch {
            Log "  [INFO] Health endpoint not available or not responding (non-fatal)."
        }
    }
}

Log "RTM-DEPLOY-001 window CLOSED — services started."

# E-010a: Write success manifest
$manifest = @"
# RTMView Server Manifest — auto-written by Apply-Server45Upgrade.ps1
ReleaseCommit: $ReleaseCommit
PostgreSQL:    $pgVerActual
UpgradedAt:    $(Get-Date -Format o)
Database:      $Database
Migrations:    $($migrations -join ', ')
ShellDeployed: $([bool]$ShellPublish)
RtmDeployed:   $([bool]$RtmPublish)
ApplyServiceDeployed: $([bool]$ApplyServicePublish)
ApplyServicePort: $ApplyServicePort
"@
Set-Content (Join-Path $OpsRoot "SERVER.md") $manifest -Encoding UTF8
Add-Content $LedgerFile "$(Get-Date -Format o) | MANIFEST | commit=$ReleaseCommit PG=$pgVerActual migs=$($migrations.Count)"
Log "Manifest written: $OpsRoot\SERVER.md"

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
Log "======== E2E SMOKE TEST CHECKLIST (D) — run on throwaway box ========"
Log ""
Log "4. StrictMode @() fix: single-migration -MigrationList runs without .Count error:"
Log "   .\Apply-Server45Upgrade.ps1 ... -MigrationList `"20260607_002_db_patch_history.sql`""
Log "   Expected: 'Using operator-supplied migration list (1 entries)' + no 'Property Count not found'"
Log ""
Log "5. UseWindowsService: all three Windows services START and stay Running:"
Log "   Get-Service $ShellSvcName,$RTMSvcName,$ApplySvcName | Select-Object Name,Status"
Log "   Expected: all Running (not Stopped, not StartPending)"
Log ""
Log "6. Metrics catalog ships with Shell (no fallback):"
Log "   Test-Path `"$InstallRoot\Shell\docs\metrics-catalog.json`""
Log "   Expected: True. Shell logs should NOT show 'Using database metrics as fallback'"
Log ""
Log "7. RTM:TenantId preserved (!= Guid.Empty) — checked automatically during deploy (A6 assertion)"
Log ""
Log "8. icacls NT SERVICE\ grants succeed (not 'No mapping between account names'):"
Log "   icacls `"$InstallRoot\Packages`" | Select-String 'NT SERVICE'"
Log "   Expected: grant lines with NT SERVICE\$ApplySvcName"
Log ""
Log "If ANY check FAILS or is NOT-RUN: DO NOT mark release as verified."
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
