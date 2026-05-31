# RTM Deployment Guide

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
