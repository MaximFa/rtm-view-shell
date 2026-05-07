#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Zero-downtime update script for RTM View Shell [DEPLOY-15].
.DESCRIPTION
    Stops IIS pools, backs up the app dir, copies new files,
    runs pg_basebackup, applies migrations, then restarts pools.
    Target max downtime: 2 minutes.
.PARAMETER ZipPath
    Path to the new publish zip.
.PARAMETER SiteName
    IIS site name (default: CcDashboard.Web).
.PARAMETER AppPath
    Installation directory (default: C:\Program Files\CcDashboard\web).
.PARAMETER BackupRoot
    Backup root directory (default: C:\Backups\CcDashboard).
.PARAMETER PgDumpPath
    Path to pg_basebackup.exe (default: auto-detect from PATH).
.PARAMETER PgConnectionString
    PostgreSQL connection string for backup. If empty, pg_basebackup is skipped.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [string]$SiteName            = "CcDashboard.Web",
    [string]$AppPath             = "C:\Program Files\CcDashboard\web",
    [string]$BackupRoot          = "C:\Backups\CcDashboard",
    [string]$PgDumpPath          = "",
    [string]$PgConnectionString  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $BackupRoot $stamp

Write-Host "=== RTM View Shell Update ($stamp) ===" -ForegroundColor Cyan

Import-Module WebAdministration -ErrorAction Stop

# 1. Stop IIS pools
Write-Host "[1/6] Stopping IIS application pool..."
Stop-WebAppPool -Name $SiteName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "      Pool stopped"

# 2. Backup app directory
Write-Host "[2/6] Backing up application to $backupDir..."
if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
Copy-Item -Path $AppPath -Destination $backupDir -Recurse -Force
Write-Host "      Backup complete"

# 3. pg_basebackup (optional)
if ($PgConnectionString)
{
    Write-Host "[3/6] Running pg_basebackup..."
    $pgBackupDir = Join-Path $BackupRoot "pg_$stamp"
    if ($PgDumpPath)
    { & $PgDumpPath -D $pgBackupDir --format=plain --wal-method=fetch --progress }
    else
    { pg_basebackup -D $pgBackupDir --format=plain --wal-method=fetch --progress }
    Write-Host "      pg_basebackup complete"
}
else
{
    Write-Host "[3/6] Skipping pg_basebackup (PgConnectionString not set)"
}

# 4. Copy new files
Write-Host "[4/6] Deploying new files to $AppPath..."
Expand-Archive -Path $ZipPath -DestinationPath $AppPath -Force
Write-Host "      Files deployed"

# 5. Apply migrations
Write-Host "[5/6] Applying database migrations..."
$exe = Join-Path $AppPath "CcDashboard.Web.exe"
if (Test-Path $exe)
{
    & $exe migrate
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "Migration failed! Rolling back application files..."
        # Rollback: restore from backup
        Remove-Item -Path $AppPath -Recurse -Force
        Copy-Item -Path $backupDir -Destination $AppPath -Recurse -Force
        Write-Error "Update FAILED. Application restored from backup. Investigate migration errors."
    }
    Write-Host "      Migrations applied"
}
else
{
    Write-Warning "      Executable not found — skipping migrations."
}

# 6. Start IIS pools
Write-Host "[6/6] Starting IIS application pool..."
Start-WebAppPool -Name $SiteName
Write-Host "      Pool started"

Write-Host ""
Write-Host "=== Update complete ===" -ForegroundColor Green
Write-Host "Backup saved to: $backupDir"
