#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates installed RTM View Shell and/or RTM Service.
.DESCRIPTION
    Run from extracted zip package (C:\Temp\<zip>\).
    Stops services, backs up current binaries and DB,
    deploys new files, applies migrations, starts services.

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

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -SkipShell
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -MigrationList "20260607_001_fix,20260608_002_add"
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
    [string]$DBApplyPassword = ""
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
