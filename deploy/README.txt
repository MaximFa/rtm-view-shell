================================================================================
  RTM View Shell — Installation Guide
  Package built: {BUILD_DATE}
================================================================================

PACKAGE CONTENTS
----------------
  Shell\                RTM View Shell (Blazor Server, self-contained)
  RTM\                  RTM Service (Windows Service, self-contained)
  RTM\app.dat           RTM encrypted configuration (included)
  DB\*.sql              PostgreSQL database backup (pg_dump)
  Extras\               Memurai installer (Redis for Windows)
  Install-RTMView.ps1   Fresh installation script
  Update-RTMView.ps1    Update / upgrade script
  README.txt            This file


PREREQUISITES (on target server)
---------------------------------
  [x] Windows Server 2019+ or Windows 10/11
  [x] PostgreSQL 15+ installed and running
  [ ] Redis/Memurai — installed automatically by Install-RTMView.ps1
  [x] Administrator access
  [ ] data.sys — copy manually (see SECRETS below)


SECRETS
---------
  app.dat  — included in this package (RTM\app.dat), copied automatically.
  data.sys — NOT included, must be copied manually.

  Obtain data.sys from the previous server or secure storage and copy to:
    C:\RTMView\RTM\data.sys

  The RTM Service will NOT start without data.sys.


FRESH INSTALLATION (new server)
---------------------------------
  1. Copy this zip to C:\Temp\ on the target server.
  2. Right-click the zip -> Extract All -> C:\Temp\
  3. Open PowerShell as Administrator.
  4. Navigate to the extracted folder:
       cd C:\Temp\<zip-folder-name>
  5. Run the installer:
       powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1

     Optional parameters:
       -DBPassword "YourPgPwd"   # PostgreSQL password for DB restore
       -RedisPassword "Rds!Pwd"  # Set Memurai password (recommended)
       -SkipDB                   # Skip DB restore (if DB already configured)

  6. Copy data.sys to C:\RTMView\RTM\
     (app.dat is already in the package and deployed automatically)

  7. Start services:
       Start-Service RTMService
       Start-Service RTMViewShell

  8. Verify:
       Invoke-WebRequest http://localhost:5000/health -UseBasicParsing


UPDATE (existing installation)
---------------------------------
  1. Copy this zip to C:\Temp\ on the target server.
  2. Extract to C:\Temp\
  3. Open PowerShell as Administrator.
  4. Run:
       powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1

     Optional parameters:
       -SkipShell              # Update RTM Service only
       -SkipRTM                # Update Shell only
       -ForceDeploy            # Skip drift gate (E1) if you understand the drift
       -MigrationList "m1,m2"  # Apply DB migrations (comma-separated, in order)
       -DBApplyUser "user"     # Privileged user for migrations (if different)
       -DBApplyPassword "pwd"  # Password for privileged user

     Example with migrations:
       powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 `
         -DBPassword "YourPwd" `
         -MigrationList "20260607_001_add_metric,20260608_002_fix_function"

  NOTE: The update script automatically:
    - Backs up current binaries to C:\RTMView\Backup\<timestamp>\
    - Backs up the database via pg_dump (custom format .dump) BEFORE any changes
    - Re-applies SQL functions (self-heals NGC procedures per RTM-SEC-002)
    - Applies migrations in order (if -MigrationList specified)
    - Preserves appsettings.Production.json and data.sys
    - Replaces app.dat from the new package
    - Keeps the last 5 backups

  PRIVILEGE NOTE for migrations:
    Most migrations are idempotent (IF NOT EXISTS guards). Default apply user is
    ccdashboard_user which has INSERT/UPDATE/DELETE on RTSGrid_Metric etc.
    Structural migrations (ALTER TABLE, CREATE INDEX) need owner or superuser
    privileges but are no-ops if the objects already exist. Use -DBApplyUser
    for privileged operations if needed (consult DBA before running).


SERVICE MANAGEMENT
--------------------
  Check status:   Get-Service RTMViewShell, RTMService
  Start:          Start-Service RTMViewShell; Start-Service RTMService
  Stop:           Stop-Service RTMViewShell; Stop-Service RTMService
  Restart:        Restart-Service RTMViewShell; Restart-Service RTMService

  Logs:
    Shell : C:\RTMView\Logs\
    RTM   : D:\IceDash\Logs\RTMLogs\Logs\


INSTALLED PATHS
-----------------
  Shell binaries  :  C:\RTMView\Shell\
  RTM binaries    :  C:\RTMView\RTM\
  Backups         :  C:\RTMView\Backup\
  Logs            :  C:\RTMView\Logs\
  Shell URL       :  http://localhost:5000
  RTM API URL     :  http://localhost:8088


DATABASE
----------
  DB name     : rtmviewdb
  DB backup   : DB\*.sql (pg_dump plain-text format)
  Manual restore (if needed):
    psql -h localhost -U postgres -c "CREATE DATABASE \"rtmviewdb\";"
    psql -h localhost -U postgres -d rtmviewdb -f DB\rtmviewdb_DDMMYYYY.sql


MONITORING
------------
  Health endpoints (Shell):
    GET /health        Liveness check (always 200 if process is up)
    GET /health/ready  Readiness check (includes Redis/PostgreSQL connectivity)

  Alert on non-200 from /health/ready — indicates Redis or DB down.
  Example monitoring command:
    curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health/ready
    (should return 200; 503 = dependency unhealthy)

  If Redis/Memurai crashes, the Shell continues serving cached data but SignalR
  backplane degrades. Memurai is configured to auto-restart on failure (Install-RTMView.ps1).


TROUBLESHOOTING
-----------------
  Service fails to start:
    1. Check data.sys is in C:\RTMView\RTM\
    2. Check Windows Event Viewer -> Application -> Source: RTMService
    3. Check C:\RTMView\Logs\ for Shell errors

  Port conflict (5000 or 8088 in use):
    netstat -ano | findstr :5000
    Reinstall with custom port:
      Install-RTMView.ps1 -ShellPort 5100 -RTMPort 8090

  Memurai/Redis not starting:
    Get-Service Memurai | Select Status
    Check: C:\Program Files\Memurai\memurai.conf


================================================================================
  Support: maxim@profit-sg.com
================================================================================
