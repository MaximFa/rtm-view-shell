#Requires -Version 5.1
<#
.SYNOPSIS
    Restores RTM PostgreSQL database from backup.
.DESCRIPTION
    Drops existing database and restores from custom-format backup.
.PARAMETER PgBinPath
    Path to PostgreSQL bin directory (default: C:\Program Files\PostgreSQL\18\bin)
.PARAMETER DbName
    Database name (default: RTMViewDB)
.PARAMETER DbUser
    Database owner user (default: ccdashboard_user)
.PARAMETER BackupFile
    Backup file to restore (required)
.PARAMETER AdminUser
    PostgreSQL admin user for drop/create (default: postgres)
.EXAMPLE
    .\Restore-RTMDb.ps1 -BackupFile "D:\Backups\RTM\RTMViewDB_20260531.backup"
#>

[CmdletBinding()]
param(
    [string]$PgBinPath = "C:\Program Files\PostgreSQL\18\bin",
    [string]$DbName = "RTMViewDB",
    [string]$DbUser = "ccdashboard_user",
    [Parameter(Mandatory=$true)]
    [string]$BackupFile,
    [string]$AdminUser = "postgres"
)

$ErrorActionPreference = 'Stop'

# Validate tools exist
$pgRestore = Join-Path $PgBinPath "pg_restore.exe"
$dropDb = Join-Path $PgBinPath "dropdb.exe"
$createDb = Join-Path $PgBinPath "createdb.exe"
$psql = Join-Path $PgBinPath "psql.exe"

foreach ($tool in @($pgRestore, $dropDb, $createDb, $psql)) {
    if (-not (Test-Path $tool)) {
        Write-Error "PostgreSQL tool not found: $tool`nSet -PgBinPath to your PostgreSQL bin directory."
        exit 1
    }
}

# Validate backup file
if (-not (Test-Path $BackupFile)) {
    Write-Error "Backup file not found: $BackupFile"
    exit 1
}

$fileInfo = Get-Item $BackupFile
$sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)

Write-Host "=== RTM Database Restore ===" -ForegroundColor Cyan
Write-Host "Database: $DbName"
Write-Host "Owner: $DbUser"
Write-Host "Backup: $BackupFile ($sizeMB MB)"
Write-Host ""

# Warning prompt
Write-Host "WARNING: This will DROP and recreate database '$DbName'!" -ForegroundColor Red
Write-Host "All existing data will be lost." -ForegroundColor Red
Write-Host ""
Write-Host "Press Enter to continue or Ctrl+C to abort..." -ForegroundColor Yellow
Read-Host

$startTime = Get-Date

# Drop existing database
Write-Host "Dropping existing database (if exists)..." -ForegroundColor Yellow
& $dropDb --username=$AdminUser --if-exists $DbName 2>$null
# Ignore errors if DB doesn't exist

# Create fresh database
Write-Host "Creating database $DbName with owner $DbUser..." -ForegroundColor Green
& $createDb --username=$AdminUser --owner=$DbUser $DbName

if ($LASTEXITCODE -ne 0) {
    Write-Error "createdb failed with exit code $LASTEXITCODE"
    exit 1
}

# Restore
Write-Host "Restoring from backup..." -ForegroundColor Green
& $pgRestore --format=custom --username=$DbUser --dbname=$DbName $BackupFile

if ($LASTEXITCODE -ne 0) {
    Write-Warning "pg_restore completed with warnings (exit code $LASTEXITCODE). This may be normal."
}

# Verification
Write-Host ""
Write-Host "Running verification queries..." -ForegroundColor Green

$verifyQuery = @"
SELECT 'Tables' as type, count(*)::text as count FROM information_schema.tables WHERE table_schema = 'public'
UNION ALL
SELECT 'RTSGrid_Metric', count(*)::text FROM public."RTSGrid_Metric"
UNION ALL
SELECT 'RTSData', count(*)::text FROM public."RTSData"
"@

& $psql --username=$DbUser --dbname=$DbName --tuples-only --command="$verifyQuery"

$elapsed = (Get-Date) - $startTime

Write-Host ""
Write-Host "=== Restore Complete ===" -ForegroundColor Cyan
Write-Host "Database: $DbName"
Write-Host "Duration: $([math]::Round($elapsed.TotalSeconds, 1)) seconds"
Write-Host ""
Write-Host "Verify the application connects correctly." -ForegroundColor Green
