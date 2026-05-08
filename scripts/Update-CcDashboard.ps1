#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Update script for RTM View Shell (Kestrel + Windows Service) [DEPLOY-15].
.DESCRIPTION
    Stops the Windows Service, backs up the app dir, optionally runs pg_basebackup,
    deploys new files, applies migrations, then restarts the service.
    Target max downtime: 2 minutes.
.PARAMETER ZipPath
    Path to the new publish zip.
.PARAMETER AppPath
    Installation directory (default: C:\Program Files\CcDashboard\web).
.PARAMETER ServiceName
    Windows Service name (default: CcDashboard).
.PARAMETER BackupRoot
    Backup root directory (default: C:\Backups\CcDashboard).
.PARAMETER PgBackupDir
    If set, runs pg_basebackup to this directory before migration.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [string]$AppPath     = "C:\Program Files\CcDashboard\web",
    [string]$ServiceName = "CcDashboard",
    [string]$BackupRoot  = "C:\Backups\CcDashboard",
    [string]$PgBackupDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $BackupRoot $stamp

Write-Host "=== RTM View Shell Update ($stamp) ===" -ForegroundColor Cyan

# ── 1. Stop service ────────────────────────────────────────────────────────────
Write-Host "[1/6] Stopping Windows Service '$ServiceName'..."
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne "Stopped")
{
    Stop-Service -Name $ServiceName -Force
    $svc.WaitForStatus("Stopped", (New-TimeSpan -Seconds 30))
}
Write-Host "      Service stopped"

# ── 2. Backup app directory ────────────────────────────────────────────────────
Write-Host "[2/6] Backing up application to $backupDir..."
if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
Copy-Item -Path $AppPath -Destination $backupDir -Recurse -Force
Write-Host "      Backup complete"

# ── 3. pg_basebackup (optional) ───────────────────────────────────────────────
if ($PgBackupDir)
{
    Write-Host "[3/6] Running pg_basebackup to $PgBackupDir..."
    $pgExe = (Get-Command pg_basebackup -ErrorAction SilentlyContinue)?.Source ?? "pg_basebackup"
    & $pgExe -D $PgBackupDir --format=plain --wal-method=fetch --progress
    if ($LASTEXITCODE -ne 0) { Write-Error "pg_basebackup failed" }
    Write-Host "      pg_basebackup complete"
}
else
{
    Write-Host "[3/6] Skipping pg_basebackup (PgBackupDir not set)"
}

# ── 4. Deploy new files ────────────────────────────────────────────────────────
Write-Host "[4/6] Deploying new files to $AppPath..."
# Preserve appsettings.Production.json — don't overwrite secrets
$prodConfig = Join-Path $AppPath "appsettings.Production.json"
$prodConfigBackup = $null
if (Test-Path $prodConfig)
{
    $prodConfigBackup = Get-Content $prodConfig -Raw
}

Expand-Archive -Path $ZipPath -DestinationPath $AppPath -Force

if ($prodConfigBackup)
{
    Set-Content $prodConfig $prodConfigBackup -Encoding UTF8
    Write-Host "      appsettings.Production.json preserved"
}
Write-Host "      Files deployed"

# ── 5. Apply migrations ────────────────────────────────────────────────────────
Write-Host "[5/6] Applying database migrations..."
$exe = Join-Path $AppPath "CcDashboard.Web.exe"
if (Test-Path $exe)
{
    $env:ASPNETCORE_ENVIRONMENT = "Production"
    & $exe migrate
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "Migration failed! Rolling back application files..."
        Remove-Item -Path $AppPath -Recurse -Force
        Copy-Item -Path $backupDir -Destination $AppPath -Recurse -Force
        Write-Error "Update FAILED. Application restored from backup at $backupDir."
    }
    Write-Host "      Migrations applied"
}
else
{
    Write-Warning "      Executable not found — skipping migrations."
}

# ── 6. Start service ───────────────────────────────────────────────────────────
Write-Host "[6/6] Starting Windows Service '$ServiceName'..."
Start-Service -Name $ServiceName
(Get-Service -Name $ServiceName).WaitForStatus("Running", (New-TimeSpan -Seconds 30))
Write-Host "      Service running"

Write-Host ""
Write-Host "=== Update complete ===" -ForegroundColor Green
Write-Host "Backup saved to: $backupDir"
Write-Host "Service status:  $((Get-Service $ServiceName).Status)"
