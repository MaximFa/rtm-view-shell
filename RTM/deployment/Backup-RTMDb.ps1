#Requires -Version 5.1
<#
.SYNOPSIS
    Backs up RTM PostgreSQL database.
.DESCRIPTION
    Creates a custom-format backup using pg_dump.
.PARAMETER PgBinPath
    Path to PostgreSQL bin directory (default: C:\Program Files\PostgreSQL\18\bin)
.PARAMETER DbName
    Database name (default: RTMViewDB)
.PARAMETER DbUser
    Database user (default: ccdashboard_user)
.PARAMETER BackupDir
    Backup output directory (default: D:\Backups\RTM)
.PARAMETER BackupFile
    Backup filename (auto-generated if not specified)
.EXAMPLE
    .\Backup-RTMDb.ps1 -DbName "RTMViewDB" -BackupDir "D:\Backups"
#>

[CmdletBinding()]
param(
    [string]$PgBinPath = "C:\Program Files\PostgreSQL\18\bin",
    [string]$DbName = "RTMViewDB",
    [string]$DbUser = "ccdashboard_user",
    [string]$BackupDir = "D:\Backups\RTM",
    [string]$BackupFile = ""
)

$ErrorActionPreference = 'Stop'

# Validate pg_dump exists
$pgDump = Join-Path $PgBinPath "pg_dump.exe"
if (-not (Test-Path $pgDump)) {
    Write-Error "pg_dump not found at: $pgDump`nSet -PgBinPath to your PostgreSQL bin directory."
    exit 1
}

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    Write-Host "Creating backup directory: $BackupDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Generate backup filename
if (-not $BackupFile) {
    $date = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupFile = Join-Path $BackupDir "${DbName}_${date}.backup"
} elseif (-not [System.IO.Path]::IsPathRooted($BackupFile)) {
    $BackupFile = Join-Path $BackupDir $BackupFile
}

Write-Host "=== RTM Database Backup ===" -ForegroundColor Cyan
Write-Host "Database: $DbName"
Write-Host "User: $DbUser"
Write-Host "Output: $BackupFile"
Write-Host ""

# Run pg_dump
Write-Host "Running pg_dump..." -ForegroundColor Green
$startTime = Get-Date

& $pgDump --format=custom --file="$BackupFile" --username=$DbUser $DbName

if ($LASTEXITCODE -ne 0) {
    Write-Error "pg_dump failed with exit code $LASTEXITCODE"
    exit 1
}

$elapsed = (Get-Date) - $startTime
$fileInfo = Get-Item $BackupFile
$sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)

Write-Host ""
Write-Host "=== Backup Complete ===" -ForegroundColor Cyan
Write-Host "File: $BackupFile"
Write-Host "Size: $sizeMB MB"
Write-Host "Duration: $([math]::Round($elapsed.TotalSeconds, 1)) seconds"
Write-Host ""

# List recent backups
Write-Host "=== Recent Backups ===" -ForegroundColor Cyan
Get-ChildItem -Path $BackupDir -Filter "*.backup" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5 |
    ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "$($_.Name) - $size MB - $($_.LastWriteTime)"
    }
