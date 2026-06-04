#!/usr/bin/env python3
"""Create RTM deployment scripts"""

import os

base = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\RTM\deployment"

# 1. Publish-RTM.ps1
publish_script = r'''#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a production release package for RTM service.
.DESCRIPTION
    Publishes RTM as self-contained win-x64, copies config files,
    and creates a versioned ZIP package.
.EXAMPLE
    .\Publish-RTM.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RTMRoot = Split-Path -Parent $ScriptDir
$ProjectPath = Join-Path $RTMRoot "RTM\RTM.csproj"
$PublishDir = Join-Path $ScriptDir "publish"

# Get version from csproj
[xml]$csproj = Get-Content $ProjectPath
$version = $csproj.Project.PropertyGroup.AssemblyVersion
if (-not $version) { $version = "1.0.0" }

$date = Get-Date -Format "yyyyMMdd"
$zipName = "RTM_v${version}_${date}.zip"

Write-Host "=== RTM Production Build ===" -ForegroundColor Cyan
Write-Host "Version: $version"
Write-Host "Output: $PublishDir"

# Clean publish directory
if (Test-Path $PublishDir) {
    Write-Host "Cleaning previous publish..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $PublishDir
}

# Publish
Write-Host "Publishing RTM (self-contained, win-x64)..." -ForegroundColor Green
dotnet publish $ProjectPath -c Release -r win-x64 --self-contained true -o $PublishDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Publish failed with exit code $LASTEXITCODE"
    exit 1
}

# Copy config files (excluding secrets)
$configFiles = @("appsettings.json", "log4net.config")
foreach ($cfg in $configFiles) {
    $src = Join-Path $RTMRoot "RTM\$cfg"
    if (Test-Path $src) {
        Copy-Item $src -Destination $PublishDir -Force
        Write-Host "Copied: $cfg" -ForegroundColor Gray
    }
}

# Create ZIP
$zipPath = Join-Path $ScriptDir $zipName
Write-Host "Creating package: $zipName" -ForegroundColor Green
Compress-Archive -Path "$PublishDir\*" -DestinationPath $zipPath -Force

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host ""
Write-Host "=== Build Complete ===" -ForegroundColor Cyan
Write-Host "Package: $zipPath"
Write-Host "Size: $([math]::Round($zipSize, 2)) MB"
Write-Host ""
Write-Host "=== MANUAL FILES REQUIRED ===" -ForegroundColor Yellow
Write-Host "The following files contain secrets and must be provided manually:"
Write-Host "  - app.dat      (encrypted configuration)"
Write-Host "  - data.sys     (license/encryption data)"
Write-Host ""
Write-Host "Copy these files to the target server's install directory."
'''

with open(os.path.join(base, "Publish-RTM.ps1"), "w", encoding="utf-8", newline="\n") as f:
    f.write(publish_script)
print("Created Publish-RTM.ps1")

# 2. Install-RTM.ps1
install_script = r'''#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs RTM as a Windows Service.
.DESCRIPTION
    Idempotent installation script for RTM on Windows Server.
    Creates directories, registers service, configures recovery.
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\RTM)
.PARAMETER ServiceName
    Windows Service name (default: RTMService)
.PARAMETER Port
    HTTP port for RTM API (default: 8088)
.EXAMPLE
    .\Install-RTM.ps1 -InstallPath "D:\RTM" -ServiceName "RTM" -Port 8080
#>

[CmdletBinding()]
param(
    [string]$InstallPath = "C:\Program Files\RTM",
    [string]$ServiceName = "RTMService",
    [int]$Port = 8088
)

$ErrorActionPreference = 'Stop'

Write-Host "=== RTM Service Installation ===" -ForegroundColor Cyan
Write-Host "Install Path: $InstallPath"
Write-Host "Service Name: $ServiceName"
Write-Host "Port: $Port"
Write-Host ""

# Check Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# Check .NET Runtime (informational for self-contained)
$dotnetInfo = dotnet --list-runtimes 2>$null | Select-String "Microsoft.AspNetCore.App 8"
if (-not $dotnetInfo) {
    Write-Host "WARNING: .NET 8 ASP.NET Core Runtime not detected." -ForegroundColor Yellow
    Write-Host "         Self-contained deployment will still work." -ForegroundColor Yellow
}

# Create log directory
$LogPath = "D:\IceDash\Logs\RTMLogs\Logs"
if (-not (Test-Path $LogPath)) {
    Write-Host "Creating log directory: $LogPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Create install directory
if (-not (Test-Path $InstallPath)) {
    Write-Host "Creating install directory: $InstallPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy published files (assumes publish folder exists in same directory as script)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PublishDir = Join-Path $ScriptDir "publish"

if (-not (Test-Path $PublishDir)) {
    Write-Error "Publish directory not found: $PublishDir`nRun Publish-RTM.ps1 first."
    exit 1
}

Write-Host "Copying files to $InstallPath..." -ForegroundColor Green
Copy-Item -Path "$PublishDir\*" -Destination $InstallPath -Recurse -Force

# Check required secret files
$requiredFiles = @("app.dat", "data.sys")
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $InstallPath $file
    if (-not (Test-Path $filePath)) {
        Write-Error "Required file missing: $file`nCopy $file to $InstallPath before installation."
        exit 1
    }
}
Write-Host "Secret files verified: app.dat, data.sys" -ForegroundColor Green

# Stop existing service if running
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Remove existing service registration
if ($existingService) {
    Write-Host "Removing existing service registration..." -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Register Windows Service
$exePath = Join-Path $InstallPath "RTM.exe"
Write-Host "Registering Windows Service..." -ForegroundColor Green

sc.exe create $ServiceName binPath= "`"$exePath`"" start= auto | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create service. Exit code: $LASTEXITCODE"
    exit 1
}

sc.exe description $ServiceName "RTM Real-Time Monitoring Service" | Out-Null

# Configure service recovery (restart on failure)
Write-Host "Configuring service recovery..." -ForegroundColor Green
sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null

# Start service
Write-Host "Starting service..." -ForegroundColor Green
Start-Service -Name $ServiceName

# Wait and check status
Write-Host "Waiting for service to start..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$service = Get-Service -Name $ServiceName
$status = $service.Status

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Cyan
Write-Host "Install Path:  $InstallPath"
Write-Host "Service Name:  $ServiceName"
Write-Host "Service Status: $status"
Write-Host "Port:          $Port"
Write-Host "Log Path:      $LogPath"
Write-Host ""

if ($status -eq "Running") {
    Write-Host "RTM Service is running successfully!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Service is not running. Check logs at $LogPath" -ForegroundColor Yellow
}
'''

with open(os.path.join(base, "Install-RTM.ps1"), "w", encoding="utf-8", newline="\n") as f:
    f.write(install_script)
print("Created Install-RTM.ps1")

# 3. Backup-RTMDb.ps1
backup_script = r'''#Requires -Version 5.1
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
'''

with open(os.path.join(base, "Backup-RTMDb.ps1"), "w", encoding="utf-8", newline="\n") as f:
    f.write(backup_script)
print("Created Backup-RTMDb.ps1")

# 4. Restore-RTMDb.ps1
restore_script = r'''#Requires -Version 5.1
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
'''

with open(os.path.join(base, "Restore-RTMDb.ps1"), "w", encoding="utf-8", newline="\n") as f:
    f.write(restore_script)
print("Created Restore-RTMDb.ps1")

# 5. README.md
readme = r'''# RTM Deployment Guide

Production deployment scripts for RTM Real-Time Monitoring Service.

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| OS | Windows Server 2019+ or Windows 10/11 |
| PostgreSQL | 15+ (must be installed and running) |
| .NET | 8.0 Runtime (optional for self-contained deploy) |
| Disk | D:\IceDash\Logs\RTMLogs\Logs\ for logs |

## Files Overview

| File | Purpose |
|------|---------|
| `Publish-RTM.ps1` | Build production release package |
| `Install-RTM.ps1` | Install RTM as Windows Service |
| `Backup-RTMDb.ps1` | Backup PostgreSQL database |
| `Restore-RTMDb.ps1` | Restore database from backup |

## Deployment Steps

### 1. Backup Source Database (on source server)

```powershell
.\Backup-RTMDb.ps1 -DbName "RTMViewDB" -BackupDir "D:\Backups\RTM"
```

Copy the `.backup` file to the target server.

### 2. Build Release Package (on dev machine)

```powershell
cd RTM\deployment
.\Publish-RTM.ps1
```

This creates `RTM_v{version}_{date}.zip` in the deployment folder.

### 3. Prepare Secret Files

The following files contain secrets and are NOT included in the package:

| File | Description |
|------|-------------|
| `app.dat` | Encrypted application configuration |
| `data.sys` | License and encryption keys |

Copy these files from a secure location to the target server.

### 4. Install on Target Server

```powershell
# Extract the ZIP to deployment folder
Expand-Archive -Path "RTM_v1.0.0_20260531.zip" -DestinationPath "C:\Temp\RTM\publish"

# Copy secret files to publish folder
Copy-Item "app.dat", "data.sys" -Destination "C:\Temp\RTM\publish"

# Run installation (as Administrator)
cd C:\Temp\RTM
.\Install-RTM.ps1 -InstallPath "C:\Program Files\RTM" -ServiceName "RTMService" -Port 8088
```

### 5. Restore Database (if migrating)

```powershell
.\Restore-RTMDb.ps1 -BackupFile "D:\Backups\RTM\RTMViewDB_20260531.backup"
```

### 6. Verify Installation

```powershell
# Check service status
Get-Service RTMService

# Check logs
Get-Content "D:\IceDash\Logs\RTMLogs\Logs\RTM.log" -Tail 50

# Test API endpoint
Invoke-WebRequest -Uri "http://localhost:8088/health" -UseBasicParsing
```

## Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `appsettings.json` | Install dir | Connection strings, logging, ports |
| `log4net.config` | Install dir | Log4net configuration |
| `app.dat` | Install dir | Encrypted app settings (SECRET) |
| `data.sys` | Install dir | License data (SECRET) |

## Service Management

```powershell
# Start service
Start-Service RTMService

# Stop service
Stop-Service RTMService

# Restart service
Restart-Service RTMService

# Check status
Get-Service RTMService

# View service details
sc.exe qc RTMService
```

## Log Files

| Location | Content |
|----------|---------|
| `D:\IceDash\Logs\RTMLogs\Logs\RTM.log` | Application logs |
| `D:\IceDash\Logs\RTMLogs\Logs\RTM_error.log` | Error logs |
| Windows Event Viewer | Service start/stop events |

## Rollback Procedure

If the new version has issues:

1. Stop the service:
   ```powershell
   Stop-Service RTMService
   ```

2. Restore previous version:
   ```powershell
   # Assuming you kept the previous install
   Copy-Item "C:\Backup\RTM\*" -Destination "C:\Program Files\RTM" -Recurse -Force
   ```

3. Restore database (if needed):
   ```powershell
   .\Restore-RTMDb.ps1 -BackupFile "D:\Backups\RTM\RTMViewDB_pre_upgrade.backup"
   ```

4. Start service:
   ```powershell
   Start-Service RTMService
   ```

## Troubleshooting

### Service won't start

1. Check Windows Event Viewer > Application logs
2. Check `D:\IceDash\Logs\RTMLogs\Logs\RTM.log`
3. Verify `app.dat` and `data.sys` are present
4. Verify PostgreSQL connection string in `appsettings.json`

### Database connection errors

1. Verify PostgreSQL is running: `Get-Service postgresql*`
2. Test connection: `psql -U ccdashboard_user -d RTMViewDB -c "SELECT 1"`
3. Check firewall allows port 5432 (if remote DB)

### Port already in use

```powershell
# Find process using port 8088
Get-NetTCPConnection -LocalPort 8088 | Select-Object OwningProcess
Get-Process -Id <PID>
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-31 | Initial deployment scripts |
'''

with open(os.path.join(base, "README.md"), "w", encoding="utf-8", newline="\n") as f:
    f.write(readme)
print("Created README.md")

print("\nAll 5 deployment files created in RTM/deployment/")
