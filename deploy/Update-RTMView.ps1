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
    [switch]$SkipCacheMigration
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
    Write-Error "Run as Administrator."
}

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
$pgDumpTool = Find-PGTool "pg_dump"
if (-not $pgDumpTool) {
    throw "[DB Backup] pg_dump not found. Install PostgreSQL or add bin to PATH."
}
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
$skipGate = $ForceDeploy -or $SkipDrift
if (-not $skipGate) {
    Write-Host "[E1] Pre-deploy drift gate: running Compare-ToBaseline..." -ForegroundColor Cyan
    $RepoRoot = Split-Path -Parent $ScriptDir
    $ComparePath = Join-Path $RepoRoot "db\tools\Compare-ToBaseline.ps1"
    if (-not (Test-Path $ComparePath)) {
        Write-Host "  [WARN] Compare-ToBaseline.ps1 not found at $ComparePath - skipping drift gate." -ForegroundColor Yellow
    } else {
        $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
        & $ComparePath -DBHost $DBHost -DBPort $DBPort -Database $Database -User $DBUser -Password $DBPassword
        $driftExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        if ($driftExit -eq 2) {
            throw "[E1] REAL schema drift detected vs baseline - review the baseline_delta report before deploying. Re-run with -ForceDeploy to override."
        } elseif ($driftExit -ne 0) {
            throw "[E1] Compare-ToBaseline failed to run (exit $driftExit) - cannot verify drift. Fix tooling or pass -ForceDeploy."
        }
        Write-Host "[E1] Drift gate PASSED (no real drift)." -ForegroundColor Green
    }
} else {
    Write-Host "[E1] Drift gate SKIPPED (-ForceDeploy)." -ForegroundColor Yellow
}

Write-Host ""
if ($MigrationList -and $MigrationList.Trim()) {
    Write-Host "[ 3/5 ] Applying DB changes (functions + migrations)..." -ForegroundColor Cyan
    $psqlTool = Find-PGTool "psql"
    if (-not $psqlTool) {
        throw "[DB Apply] psql not found. Install PostgreSQL or add bin to PATH."
    }

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
            } else {
                Write-Host "  [WARN] Function file not found: $fnPath" -ForegroundColor Yellow
            }
        }

        $migrationsDir = Join-Path $ScriptDir "db\migrations"
        $migrations = @($MigrationList.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        foreach ($mig in $migrations) {
            $migPath = Join-Path $migrationsDir ($mig + ".sql")
            if (-not (Test-Path $migPath)) {
                throw "[DB Apply] Migration file not found: $migPath"
            }
            Write-Host "  Applying migration: $mig" -ForegroundColor Gray
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
            if (Test-Path $existing) { $preserved[$pf] = Get-Content $existing -Raw }
        }

        if (-not (Test-Path $ShellDest)) { New-Item -ItemType Directory -Path $ShellDest -Force | Out-Null }
        Copy-Item -Path "$srcShell\*" -Destination $ShellDest -Recurse -Force

        foreach ($kv in $preserved.GetEnumerator()) {
            $dst = Join-Path $ShellDest $kv.Key
            Set-Content $dst $kv.Value -Encoding UTF8
            Write-Host "  Preserved: $($kv.Key)" -ForegroundColor Gray
        }
        Write-Host "  Shell updated -> $ShellDest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Shell\ not found next to script - skipping Shell update." -ForegroundColor Yellow
    }
}

if (-not $SkipRTM) {
    $srcRTM = Join-Path $ScriptDir "RTM"
    if (Test-Path $srcRTM) {
        $preserveRTM = @("data.sys", "appsettings.json")
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
            Write-Host "  Preserved: $($kv.Key)" -ForegroundColor Gray
        }
        Write-Host "  RTM updated -> $RTMDest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] RTM\ not found next to script - skipping RTM update." -ForegroundColor Yellow
    }
}

# ── [4b/5] Memurai -> Garnet migration (INC-001(d) Phase 2) ──────────────────
Write-Host ""
$garnetSrc = Join-Path $ScriptDir "Extras\Garnet"
$hasGarnetPackage = Test-Path $garnetSrc

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

        # Validate RedisPassword
        if (-not $RedisPassword) {
            Write-Host "  [ERROR] RedisPassword is REQUIRED to migrate from Memurai to Garnet." -ForegroundColor Red
            Write-Host "          Re-run with -RedisPassword <password>, or -SkipCacheMigration to keep Memurai." -ForegroundColor Red
            throw "RedisPassword required for Memurai->Garnet migration"
        }

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
            Write-Error "NSSM not found at $nssmSrc. Cannot register Garnet service."
        }

        # Register Garnet service via NSSM
        $garnetExe = Join-Path $GarnetInstallDir "GarnetServer.exe"
        $garnetArgs = "--bind 127.0.0.1 --port 6379 --auth Password --password $RedisPassword --checkpointdir `"$checkpointDir`" --recover --checkpoint-freq 300"
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
Write-Host ""
foreach ($svcName in @($RTMSvcName, $ShellSvcName)) {
    $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($s) {
        $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host "  $svcName : $($s.Status)" -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "                UPDATE COMPLETE                       " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  Backup : $BackupDir"
if ($MigrationList -and $MigrationList.Trim()) {
    Write-Host "  DB backup : $dbBackupPath"
    Write-Host "  Migrations: $MigrationList"
}
Write-Host ""
