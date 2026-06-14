#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Обновляет установленный RTM View Shell и/или RTM Service.
.DESCRIPTION
    Запускать из распакованного zip-пакета (C:\Temp\<zip>\).
    Останавливает сервисы, делает резервную копию текущих бинарников,
    разворачивает новые файлы, запускает сервисы.

.PARAMETER InstallRoot
    Корневая папка установки (default: C:\RTMView)
.PARAMETER ShellSvcName / RTMSvcName
    Имена Windows Services
.PARAMETER SkipShell / SkipRTM
    Обновить только один компонент
.PARAMETER KeepBackups
    Количество резервных копий (default: 5)

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1
    powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -SkipShell
#>

[CmdletBinding()]
param(
    [string]$InstallRoot   = "C:\RTMView",
    [string]$ShellSvcName  = "RTMViewShell",
    [string]$RTMSvcName    = "RTMService",
    [switch]$SkipShell,
    [switch]$SkipRTM,
    [int]   $KeepBackups   = 5,
    [switch]$ForceDeploy,         # E1: skip drift gate
    [Alias("SkipDriftGate")]
    [switch]$SkipDrift,           # alias
    # DB connection for drift gate
    [string]$DBHost        = "localhost",
    [string]$DBPort        = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$DBUser        = "ccdashboard_user",
    [string]$DBPassword    = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellDest  = Join-Path $InstallRoot "Shell"
$RTMDest    = Join-Path $InstallRoot "RTM"
$BackupRoot = Join-Path $InstallRoot "Backup"
$Timestamp  = Get-Date -Format "ddMMyyyy_HHmm"

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║             RTM View Shell — UPDATE                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Admin check ───────────────────────────────────────────────────────────────
$p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run as Administrator."
}

# ── Stop services ─────────────────────────────────────────────────────────────
Write-Host "[ 1/4 ] Stopping services..." -ForegroundColor Cyan
foreach ($svcName in @($ShellSvcName, $RTMSvcName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Stopped") {
        Stop-Service -Name $svcName -Force
        Write-Host "  Stopped: $svcName" -ForegroundColor Gray
    } elseif (-not $svc) {
        Write-Host "  Not installed: $svcName" -ForegroundColor Gray
    }
}

# ── Backup current binaries ───────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 2/4 ] Backing up current installation..." -ForegroundColor Cyan
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

# Prune old backups
$allBackups = Get-ChildItem $BackupRoot -Directory | Sort-Object Name
if ($allBackups.Count -gt $KeepBackups) {
    $toDelete = $allBackups | Select-Object -First ($allBackups.Count - $KeepBackups)
    foreach ($b in $toDelete) {
        Remove-Item $b.FullName -Recurse -Force
        Write-Host "  Pruned old backup: $($b.Name)" -ForegroundColor Gray
    }
}

# ── E1: Pre-deploy drift gate ─────────────────────────────────────────────────
Write-Host ""
$skipGate = $ForceDeploy -or $SkipDrift
if (-not $skipGate) {
    Write-Host "[E1] Pre-deploy drift gate: running Compare-ToBaseline..." -ForegroundColor Cyan
    # Locate Compare-ToBaseline.ps1 relative to this script (deploy/ -> repo root -> db/tools/)
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
            throw "[E1] REAL schema drift detected vs baseline - review the baseline_delta report before deploying. Re-run with -ForceDeploy to override (only if the drift is understood/intended)."
        } elseif ($driftExit -ne 0) {
            throw "[E1] Compare-ToBaseline failed to run (exit $driftExit) - cannot verify drift. Fix tooling or pass -ForceDeploy."
        }
        Write-Host "[E1] Drift gate PASSED (no real drift)." -ForegroundColor Green
    }
} else {
    Write-Host "[E1] Drift gate SKIPPED (-ForceDeploy)." -ForegroundColor Yellow
}

# ── Deploy new files ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/4 ] Deploying new files..." -ForegroundColor Cyan

if (-not $SkipShell) {
    $srcShell = Join-Path $ScriptDir "Shell"
    if (Test-Path $srcShell) {
        # Preserve config files the user may have customised
        $preserveFiles = @("appsettings.Production.json", "nlog.config")
        $preserved = @{}
        foreach ($pf in $preserveFiles) {
            $existing = Join-Path $ShellDest $pf
            if (Test-Path $existing) { $preserved[$pf] = Get-Content $existing -Raw }
        }

        # Overwrite binaries
        if (-not (Test-Path $ShellDest)) { New-Item -ItemType Directory -Path $ShellDest -Force | Out-Null }
        Copy-Item -Path "$srcShell\*" -Destination $ShellDest -Recurse -Force

        # Restore preserved configs
        foreach ($kv in $preserved.GetEnumerator()) {
            $dst = Join-Path $ShellDest $kv.Key
            Set-Content $dst $kv.Value -Encoding UTF8
            Write-Host "  Preserved: $($kv.Key)" -ForegroundColor Gray
        }
        Write-Host "  Shell updated -> $ShellDest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Shell\ not found next to script — skipping Shell update." -ForegroundColor Yellow
    }
}

if (-not $SkipRTM) {
    $srcRTM = Join-Path $ScriptDir "RTM"
    if (Test-Path $srcRTM) {
        # Preserve RTM secrets (app.dat comes from zip; only data.sys preserved)
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
        Write-Host "  [WARN] RTM\ not found next to script — skipping RTM update." -ForegroundColor Yellow
    }
}

# ── Start services ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/4 ] Starting services..." -ForegroundColor Cyan
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
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                UPDATE COMPLETE                       ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  Backup : $BackupDir"
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
