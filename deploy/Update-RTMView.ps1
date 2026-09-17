#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates installed RTM View Shell and/or RTM Service.
.DESCRIPTION
    Run from extracted zip package (C:\Temp\<zip>\).
    Stops services, backs up current binaries and DB,
    deploys new files, applies migrations, starts services.

    NOTE: If the package includes Garnet and the server has Memurai, this script
    will migrate to Garnet (disable Memurai, install Garnet). See INC-001(d) Phase 2.

.PARAMETER InstallRoot
    Root installation folder (default: C:\RTMView)
.PARAMETER ShellSvcName / RTMSvcName
    Windows Service names
.PARAMETER SkipShell / SkipRTM
    Update only one component
.PARAMETER KeepBackups
    Number of backups to keep (default: 5)
.PARAMETER MigrationList
    Comma-separated list of migration filenames (without .sql) to apply, in order.
    Example: -MigrationList "20260607_001_name,20260608_002_name"
    If empty (default), only binaries are updated (no DB changes).
.PARAMETER DBApplyUser / DBApplyPassword
    Credentials for applying migrations if different from DBUser (e.g., privileged user
    for ALTER TABLE / CREATE INDEX). Default: uses DBUser credentials.
.PARAMETER RedisPassword
    Password for Garnet. REQUIRED when migrating from Memurai to Garnet.
.PARAMETER GarnetInstallDir
    Installation directory for Garnet (default: C:\Garnet)
.PARAMETER SkipCacheMigration
    Skip Memurai->Garnet migration (keep existing cache service)
.PARAMETER NoAutoRestart
    On failure before DB changes, leave services stopped instead of auto-recovering.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -SkipShell
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -MigrationList "20260607_001_fix,20260608_002_add"
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -RedisPassword "MyPwd"  # Memurai->Garnet migration
#>

[CmdletBinding()]
param(
    [string]$InstallRoot   = "C:\RTMView",
    [string]$ShellSvcName  = "RTMViewShell",
    [string]$RTMSvcName    = "RTMService",
    [switch]$SkipShell,
    [switch]$SkipRTM,
    [int]   $KeepBackups   = 5,
    [switch]$ForceDeploy,
    [Alias("SkipDriftGate")]
    [switch]$SkipDrift,
    [string]$DBHost        = "localhost",
    [string]$DBPort        = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$DBUser        = "ccdashboard_user",
    [string]$DBPassword    = "",
    [string]$MigrationList = "",
    [string]$DBApplyUser   = "",
    [string]$DBApplyPassword = "",
    [string]$RedisPassword = "",
    [string]$GarnetInstallDir = "C:\Garnet",
    [string]$GarnetSvcName = "Garnet",
    [switch]$SkipCacheMigration,
    [switch]$NoAutoRestart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellDest  = Join-Path $InstallRoot "Shell"
$RTMDest    = Join-Path $InstallRoot "RTM"
$BackupRoot = Join-Path $InstallRoot "Backup"
$Timestamp  = Get-Date -Format "ddMMyyyy_HHmm"

function Find-PGTool {
    param([string]$ToolName)
    $searchPaths = @(
        "C:\Program Files\PostgreSQL\18\bin",
        "C:\Program Files\PostgreSQL\17\bin",
        "C:\Program Files\PostgreSQL\16\bin",
        "C:\Program Files\PostgreSQL\15\bin",
        "C:\Program Files\PostgreSQL\14\bin"
    )
    foreach ($p in $searchPaths) {
        $full = Join-Path $p "$ToolName.exe"
        if (Test-Path $full) { return $full }
    }
    $inPath = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "             RTM View Shell - UPDATE                  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run as Administrator."
}

# ══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT CHECKS — all reads, no writes. Failures here cost zero downtime.
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[PREFLIGHT] Verifying prerequisites..." -ForegroundColor Cyan

$preflightFailed = $false

# 1. pg_dump present (always needed for backup)
$pgDumpTool = Find-PGTool "pg_dump"
if ($pgDumpTool) {
    Write-Host "  [OK] pg_dump: $pgDumpTool" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] pg_dump not found" -ForegroundColor Red
    $preflightFailed = $true
}

# 2. psql present (if migrations specified)
$psqlTool = Find-PGTool "psql"
$hasMigrations = $MigrationList -and $MigrationList.Trim()
if ($hasMigrations) {
    if ($psqlTool) {
        Write-Host "  [OK] psql: $psqlTool" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] psql not found (required for migrations)" -ForegroundColor Red
        $preflightFailed = $true
    }
} else {
    Write-Host "  [--] psql: not checked (no migrations)" -ForegroundColor Gray
}

# 3. Migration files exist
if ($hasMigrations) {
    $migrationsDir = Join-Path $ScriptDir "db\migrations"
    $migrations = @($MigrationList.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $missingMigs = @()
    foreach ($mig in $migrations) {
        $migPath = Join-Path $migrationsDir ($mig + ".sql")
        if (-not (Test-Path $migPath)) {
            $missingMigs += $mig
        }
    }
    if ($missingMigs.Count -eq 0) {
        Write-Host "  [OK] migration files: $($migrations.Count) found" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] missing migrations: $($missingMigs -join ', ')" -ForegroundColor Red
        $preflightFailed = $true
    }
} else {
    Write-Host "  [--] migration files: not checked (no migrations)" -ForegroundColor Gray
}

# 4. Compare-ToBaseline.ps1 path (if drift gate not skipped)
$skipGate = $ForceDeploy -or $SkipDrift
$ComparePath = $null
if (-not $skipGate) {
    $compareCandidates = @(
        (Join-Path $ScriptDir "db\tools\Compare-ToBaseline.ps1"),
        (Join-Path (Split-Path -Parent $ScriptDir) "db\tools\Compare-ToBaseline.ps1")
    )
    foreach ($candidate in $compareCandidates) {
        if (Test-Path $candidate) { $ComparePath = $candidate; break }
    }
    if ($ComparePath) {
        Write-Host "  [OK] drift tool: $ComparePath" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Compare-ToBaseline.ps1 not found in: $($compareCandidates -join ' ; ')" -ForegroundColor Red
        $preflightFailed = $true
    }
} else {
    Write-Host "  [--] drift tool: not checked (drift gate skipped)" -ForegroundColor Gray
}

# 5. Disk space check
$installVolume = Get-Item $InstallRoot -ErrorAction SilentlyContinue
if (-not $installVolume) { $installVolume = Get-Item "C:\" }
$driveLetter = $installVolume.PSDrive.Name
if (-not $driveLetter) { $driveLetter = "C" }
$drive = Get-PSDrive $driveLetter -ErrorAction SilentlyContinue
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$requiredGB = 2.0  # Safety margin for backups
if ($freeGB -ge $requiredGB) {
    Write-Host "  [OK] disk space: ${freeGB}GB free on ${driveLetter}:" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] insufficient disk space: ${freeGB}GB free, need ${requiredGB}GB" -ForegroundColor Red
    $preflightFailed = $true
}

# 6. RedisPassword if Garnet migration needed
$garnetSrc = Join-Path $ScriptDir "Extras\Garnet"
$hasGarnetPackage = Test-Path $garnetSrc
if (-not $SkipCacheMigration -and $hasGarnetPackage) {
    $memuraiSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
    $garnetSvc = Get-Service -Name $GarnetSvcName -ErrorAction SilentlyContinue
    if ($memuraiSvc -and -not $garnetSvc) {
        if ($RedisPassword) {
            Write-Host "  [OK] RedisPassword: provided (Memurai->Garnet migration)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] RedisPassword required for Memurai->Garnet migration" -ForegroundColor Red
            $preflightFailed = $true
        }
    } else {
        Write-Host "  [--] RedisPassword: not required (no cache migration)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [--] RedisPassword: not checked (no Garnet package or skipped)" -ForegroundColor Gray
}

if ($preflightFailed) {
    throw "[PREFLIGHT] One or more prerequisites failed. Fix the issues above and re-run."
}
Write-Host "[PREFLIGHT] All checks passed." -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# E1 DRIFT GATE — runs BEFORE services stop (reading only)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
if (-not $skipGate) {
    Write-Host "[E1] Pre-deploy drift gate: running Compare-ToBaseline..." -ForegroundColor Cyan
    Write-Host "  [E1] drift tool resolved: $ComparePath" -ForegroundColor Gray
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $ComparePath -DBHost $DBHost -DBPort $DBPort -Database $Database -User $DBUser -Password $DBPassword
    $driftExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($driftExit -eq 2) {
        throw "[E1] REAL schema drift detected vs baseline - review the baseline_delta report before deploying. To deploy over KNOWN drift re-run with -ForceDeploy; if the drift instrument itself is wrong, -SkipDrift with the measured reason on record."
    } elseif ($driftExit -ne 0) {
        throw "[E1] Compare-ToBaseline failed to run (exit $driftExit) - cannot verify drift. Fix tooling, or pass -SkipDrift (instrument not usable) - not -ForceDeploy, which means deploying over known drift."
    }
    Write-Host "[E1] Drift gate PASSED (no real drift)." -ForegroundColor Green
} else {
    $skipBy = @()
    if ($PSBoundParameters.ContainsKey('ForceDeploy') -and $ForceDeploy) { $skipBy += '-ForceDeploy' }
    if ($PSBoundParameters.ContainsKey('SkipDrift')   -and $SkipDrift)   { $skipBy += '-SkipDrift' }
    Write-Host ("[E1] Drift gate SKIPPED (" + ($skipBy -join ' ') + ")." ) -ForegroundColor Yellow
}

# ══════════════════════════════════════════════════════════════════════════════
# DEPLOY REGION — services stopped here. Wrapped in try/finally for recovery.
# ══════════════════════════════════════════════════════════════════════════════
$script:dbMutated = $false   # Set $true when first DB change is applied
$script:started = $false     # Set $true by normal [5/5] start
$dbBackupPath = $null        # Will be set if backup succeeds

try {

Write-Host ""
Write-Host "[ 1/5 ] Stopping services..." -ForegroundColor Cyan
foreach ($svcName in @($ShellSvcName, $RTMSvcName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Stopped") {
        Stop-Service -Name $svcName -Force
        Write-Host "  Stopped: $svcName" -ForegroundColor Gray
    } elseif (-not $svc) {
        Write-Host "  Not installed: $svcName" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "[ 2/5 ] Backing up current installation..." -ForegroundColor Cyan
$BackupDir = Join-Path $BackupRoot $Timestamp
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

if (-not $SkipShell -and (Test-Path $ShellDest)) {
    $bkShell = Join-Path $BackupDir "Shell"
    Copy-Item -Path $ShellDest -Destination $bkShell -Recurse -Force
    Write-Host "  Backed up: $ShellDest -> $bkShell" -ForegroundColor Gray
}
if (-not $SkipRTM -and (Test-Path $RTMDest)) {
    $bkRTM = Join-Path $BackupDir "RTM"
    Copy-Item -Path $RTMDest -Destination $bkRTM -Recurse -Force
    Write-Host "  Backed up: $RTMDest -> $bkRTM" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[ 2b/5 ] Backing up database (pg_dump)..." -ForegroundColor Cyan
$dbBackupPath = Join-Path $BackupDir ("db_" + $Database + "_" + $Timestamp + ".dump")
$env:PGPASSWORD = $DBPassword
try {
    & $pgDumpTool -h $DBHost -p $DBPort -U $DBUser -Fc -f $dbBackupPath $Database
    if ($LASTEXITCODE -ne 0) {
        throw "[DB Backup] pg_dump failed with exit code $LASTEXITCODE. Cannot proceed without DB backup."
    }
    Write-Host "  DB backup: $dbBackupPath" -ForegroundColor Green
} finally {
    $env:PGPASSWORD = $null
}

$allBackups = @(Get-ChildItem $BackupRoot -Directory | Sort-Object Name)
if ($allBackups.Count -gt $KeepBackups) {
    $toDelete = $allBackups | Select-Object -First ($allBackups.Count - $KeepBackups)
    foreach ($b in $toDelete) {
        [System.IO.Directory]::Delete($b.FullName, $true)
        Write-Host "  Pruned old backup: $($b.Name)" -ForegroundColor Gray
    }
}

Write-Host ""
if ($hasMigrations) {
    Write-Host "[ 3/5 ] Applying DB changes (functions + migrations)..." -ForegroundColor Cyan

    $applyUser = if ($DBApplyUser) { $DBApplyUser } else { $DBUser }
    $applyPass = if ($DBApplyPassword) { $DBApplyPassword } else { $DBPassword }
    $env:PGPASSWORD = $applyPass

    try {
        $functionsDir = Join-Path $ScriptDir "db\functions"
        $functionFiles = @(
            "01_ngc_functions.sql",
            "02_rtsdata_functions.sql",
            "03_rtsgrid_read.sql",
            "04_misc_functions.sql"
        )
        foreach ($fn in $functionFiles) {
            $fnPath = Join-Path $functionsDir $fn
            if (Test-Path $fnPath) {
                Write-Host "  Applying: $fn" -ForegroundColor Gray
                & $psqlTool -h $DBHost -p $DBPort -U $applyUser -d $Database -f $fnPath -v ON_ERROR_STOP=1
                if ($LASTEXITCODE -ne 0) {
                    throw "[DB Apply] Function file $fn failed (exit $LASTEXITCODE). Aborting."
                }
                $script:dbMutated = $true
            } else {
                Write-Host "  [WARN] Function file not found: $fnPath" -ForegroundColor Yellow
            }
        }

        $migrationsDir = Join-Path $ScriptDir "db\migrations"
        $migrations = @($MigrationList.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        foreach ($mig in $migrations) {
            $migPath = Join-Path $migrationsDir ($mig + ".sql")
            Write-Host "  Applying migration: $mig" -ForegroundColor Gray
            $script:dbMutated = $true
            & $psqlTool -h $DBHost -p $DBPort -U $applyUser -d $Database -f $migPath -v ON_ERROR_STOP=1
            if ($LASTEXITCODE -ne 0) {
                throw "[DB Apply] Migration $mig failed (exit $LASTEXITCODE). Aborting. DB state may be partial - review and restore from backup if needed."
            }
            Write-Host "    [OK] $mig" -ForegroundColor Green
        }

        $migCount = $migrations.Count
        Write-Host "  DB apply complete ($migCount migrations)." -ForegroundColor Green
    } finally {
        $env:PGPASSWORD = $null
    }
} else {
    Write-Host "[ 3/5 ] No migrations specified (-MigrationList empty). Binary-only update." -ForegroundColor Gray
}

Write-Host ""
Write-Host "[ 4/5 ] Deploying new files..." -ForegroundColor Cyan

if (-not $SkipShell) {
    $srcShell = Join-Path $ScriptDir "Shell"
    if (Test-Path $srcShell) {
        $preserveFiles = @("appsettings.json", "appsettings.Production.json", "nlog.config")
        $preserved = @{}
        foreach ($pf in $preserveFiles) {
            $existing = Join-Path $ShellDest $pf
            if (Test-Path $existing) { $preserved[$pf] = [System.IO.File]::ReadAllBytes($existing) }
        }

        if (-not (Test-Path $ShellDest)) { New-Item -ItemType Directory -Path $ShellDest -Force | Out-Null }
        Copy-Item -Path "$srcShell\*" -Destination $ShellDest -Recurse -Force

        foreach ($kv in $preserved.GetEnumerator()) {
            $dst = Join-Path $ShellDest $kv.Key
            [System.IO.File]::WriteAllBytes($dst, $kv.Value)
            Write-Host "  Preserved: $($kv.Key) (package version ignored)" -ForegroundColor Gray
        }
        Write-Host "  Shell updated -> $ShellDest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Shell\ not found next to script - skipping Shell update." -ForegroundColor Yellow
    }
}

if (-not $SkipRTM) {
    $srcRTM = Join-Path $ScriptDir "RTM"
    if (Test-Path $srcRTM) {
        $preserveRTM = @("data.sys", "appsettings.json", "log4net.config")
        $preservedRTM = @{}
        foreach ($pf in $preserveRTM) {
            $existing = Join-Path $RTMDest $pf
            if (Test-Path $existing) { $preservedRTM[$pf] = [System.IO.File]::ReadAllBytes($existing) }
        }

        if (-not (Test-Path $RTMDest)) { New-Item -ItemType Directory -Path $RTMDest -Force | Out-Null }
        Copy-Item -Path "$srcRTM\*" -Destination $RTMDest -Recurse -Force

        foreach ($kv in $preservedRTM.GetEnumerator()) {
            $dst = Join-Path $RTMDest $kv.Key
            [System.IO.File]::WriteAllBytes($dst, $kv.Value)
            Write-Host "  Preserved: $($kv.Key) (package version ignored)" -ForegroundColor Gray
        }
        Write-Host "  RTM updated -> $RTMDest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] RTM\ not found next to script - skipping RTM update." -ForegroundColor Yellow
    }
}

# ── [4b/5] Memurai -> Garnet migration (INC-001(d) Phase 2) ──────────────────
Write-Host ""
if (-not $SkipCacheMigration -and $hasGarnetPackage) {
    Write-Host "[ 4b/5 ] Cache service migration (Memurai -> Garnet)..." -ForegroundColor Cyan

    $memuraiSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
    $garnetSvc = Get-Service -Name $GarnetSvcName -ErrorAction SilentlyContinue

    if ($garnetSvc) {
        Write-Host "  Garnet already installed — ensuring it's running..." -ForegroundColor Green
        # Ensure Garnet is set to Automatic + recovery
        try {
            Set-Service -Name $GarnetSvcName -StartupType Automatic -ErrorAction Stop
            & sc.exe failure $GarnetSvcName reset= 86400 actions= restart/5000/restart/10000/restart/60000 | Out-Null
            & sc.exe failureflag $GarnetSvcName 1 | Out-Null
        } catch { }
        Start-Service $GarnetSvcName -ErrorAction SilentlyContinue
        Write-Host "  Garnet: $((Get-Service $GarnetSvcName).Status)" -ForegroundColor Green
    } elseif ($memuraiSvc) {
        # Memurai exists, Garnet doesn't — migrate
        Write-Host "  Detected Memurai — migrating to Garnet..." -ForegroundColor Yellow

        # Stop and disable Memurai (but do NOT uninstall — rollback safety)
        Write-Host "  Stopping and disabling Memurai (retained for rollback)..." -ForegroundColor Gray
        Stop-Service "Memurai" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "Memurai" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  Memurai: Stopped, StartupType=Disabled" -ForegroundColor Gray

        # Install Garnet
        if (-not (Test-Path $GarnetInstallDir)) {
            New-Item -ItemType Directory -Path $GarnetInstallDir -Force | Out-Null
        }
        Copy-Item -Path "$garnetSrc\*" -Destination $GarnetInstallDir -Recurse -Force
        Write-Host "  Copied Garnet binaries to $GarnetInstallDir" -ForegroundColor Gray

        # Create checkpoint directory
        $checkpointDir = Join-Path $GarnetInstallDir "data"
        if (-not (Test-Path $checkpointDir)) {
            New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
        }

        # Copy NSSM
        $nssmSrc = Join-Path $ScriptDir "Extras\nssm\nssm.exe"
        if (Test-Path $nssmSrc) {
            $nssmDest = Join-Path $GarnetInstallDir "nssm.exe"
            Copy-Item $nssmSrc -Destination $nssmDest -Force
        } else {
            throw "NSSM not found at $nssmSrc. Cannot register Garnet service."
        }

        # Register Garnet service via NSSM
        $garnetExe = Join-Path $GarnetInstallDir "GarnetServer.exe"
        $garnetArgs = "--bind 127.0.0.1 --port 6379 --auth Password --password $RedisPassword --checkpointdir `"$checkpointDir`" --recover true"
        $nssmExe = Join-Path $GarnetInstallDir "nssm.exe"

        Write-Host "  Registering $GarnetSvcName service via NSSM..." -ForegroundColor Gray
        & $nssmExe install $GarnetSvcName $garnetExe $garnetArgs | Out-Null
        & $nssmExe set $GarnetSvcName AppDirectory $GarnetInstallDir | Out-Null
        & $nssmExe set $GarnetSvcName Start SERVICE_AUTO_START | Out-Null
        & $nssmExe set $GarnetSvcName DisplayName "Garnet (Redis-compatible cache)" | Out-Null
        & $nssmExe set $GarnetSvcName Description "Microsoft Garnet - Redis-compatible cache for RTM View Shell (INC-001d)" | Out-Null

        # Apply recovery policy
        & sc.exe failure $GarnetSvcName reset= 86400 actions= restart/5000/restart/10000/restart/60000 | Out-Null
        & sc.exe failureflag $GarnetSvcName 1 | Out-Null

        # Start Garnet
        Start-Sleep 2
        Start-Service $GarnetSvcName -ErrorAction SilentlyContinue
        Start-Sleep 3
        $s = Get-Service $GarnetSvcName -ErrorAction SilentlyContinue
        Write-Host "  $GarnetSvcName : $($s.Status)" -ForegroundColor $(if ($s.Status -eq "Running") {"Green"} else {"Red"})

        Write-Host ""
        Write-Host "  *** SECURITY NOTE (INC-001d COND-1): ***" -ForegroundColor Yellow
        Write-Host "  Redis state was RESET by the cache swap. Revoked-JTI list and rate-limit" -ForegroundColor Yellow
        Write-Host "  counters start EMPTY. A revoked token (<=15min old) may work again." -ForegroundColor Yellow
        Write-Host "  For critical users, bump their SecurityStamp after this migration." -ForegroundColor Yellow
        Write-Host ""
    } else {
        # Neither Memurai nor Garnet — fresh install needed
        Write-Host "  No cache service found. Run Install-RTMView.ps1 for fresh install." -ForegroundColor Yellow
    }
} elseif ($SkipCacheMigration) {
    Write-Host "[ 4b/5 ] Cache migration skipped (-SkipCacheMigration)." -ForegroundColor Gray
} else {
    Write-Host "[ 4b/5 ] No Garnet package in Extras\ — cache service unchanged." -ForegroundColor Gray
}

Write-Host ""
Write-Host "[ 5/5 ] Starting services..." -ForegroundColor Cyan
foreach ($svcName in @($RTMSvcName, $ShellSvcName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
    } else {
        Write-Host "  [WARN] Service not registered: $svcName" -ForegroundColor Yellow
        Write-Host "         Run Install-RTMView.ps1 first for a fresh install." -ForegroundColor Yellow
    }
}

Start-Sleep -Seconds 8
$script:started = $true
Write-Host ""
foreach ($svcName in @($RTMSvcName, $ShellSvcName)) {
    $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($s) {
        $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  $svcName : $($s.Status)" -ForegroundColor $color
    }
}

} finally {
    if (-not $script:started) {
        Write-Host ""
        if ($script:dbMutated) {
            # DB was partially modified — DO NOT auto-start, manual recovery needed
            Write-Host "========================================================================" -ForegroundColor Red
            Write-Host "  DEPLOY FAILED AFTER DB CHANGES — MANUAL RECOVERY REQUIRED            " -ForegroundColor Red
            Write-Host "========================================================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "  The deploy failed AFTER database modifications were applied." -ForegroundColor Red
            Write-Host "  Services are intentionally LEFT STOPPED to prevent app/schema mismatch." -ForegroundColor Red
            Write-Host ""
            Write-Host "  Backup directory : $BackupDir" -ForegroundColor Yellow
            if ($dbBackupPath) {
                Write-Host "  DB dump file     : $dbBackupPath" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "  To restore the database:" -ForegroundColor Cyan
                $pgRestoreTool = Find-PGTool "pg_restore"
                if ($pgRestoreTool) {
                    Write-Host "    `$env:PGPASSWORD = '<password>'" -ForegroundColor White
                    Write-Host "    & '$pgRestoreTool' -h $DBHost -p $DBPort -U $DBUser -d $Database -c '$dbBackupPath'" -ForegroundColor White
                }
            }
            Write-Host ""
            Write-Host "  After restoring, manually start services:" -ForegroundColor Cyan
            Write-Host "    Start-Service $RTMSvcName" -ForegroundColor White
            Write-Host "    Start-Service $ShellSvcName" -ForegroundColor White
            Write-Host ""
        } else {
            # No DB changes — safe to auto-restart
            if ($NoAutoRestart) {
                Write-Host "[RECOVERY] Deploy failed before DB changes. -NoAutoRestart: services left stopped." -ForegroundColor Yellow
            } else {
                Write-Host "[RECOVERY] Deploy failed before DB changes. Restarting services..." -ForegroundColor Yellow

                # Start RTMService first (adapter depends on engine)
                try {
                    $rtmSvc = Get-Service -Name $RTMSvcName -ErrorAction SilentlyContinue
                    if ($rtmSvc) {
                        Start-Service -Name $RTMSvcName -ErrorAction Stop
                        Write-Host "  [RECOVERY] Started: $RTMSvcName" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "  [RECOVERY] FAILED to start $RTMSvcName : $_" -ForegroundColor Red
                }

                # Then Shell
                try {
                    $shellSvc = Get-Service -Name $ShellSvcName -ErrorAction SilentlyContinue
                    if ($shellSvc) {
                        Start-Service -Name $ShellSvcName -ErrorAction Stop
                        Write-Host "  [RECOVERY] Started: $ShellSvcName" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "  [RECOVERY] FAILED to start $ShellSvcName : $_" -ForegroundColor Red
                }

                Start-Sleep -Seconds 3
                Write-Host ""
                Write-Host "[RECOVERY] Service status after recovery:" -ForegroundColor Cyan
                foreach ($svcName in @($RTMSvcName, $ShellSvcName)) {
                    $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                    if ($s) {
                        $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
                        Write-Host "  $svcName : $($s.Status)" -ForegroundColor $color
                    }
                }
            }
        }
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "                UPDATE COMPLETE                       " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Backup : $BackupDir"
if ($hasMigrations) {
    Write-Host "  DB backup : $dbBackupPath"
    Write-Host "  Migrations: $MigrationList"
}
Write-Host ""
