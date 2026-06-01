# Install-CcDashboard.ps1
# Installs RTM View Shell + SignalR Simulator as Windows Services (Kestrel).
# Restores the bundled DB snapshot (simulator_db.dump).
#
# Must be run as Administrator from the extracted package directory.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Install-CcDashboard.ps1 `
#       -DBPassword "AppPwd!" -PGSuperPassword "PgPwd!"

[CmdletBinding()]
param(
    # --- Service names ---
    [string]$ServiceName          = "CcDashboard",
    [string]$SignalRServiceName   = "CcDashboardSignalR",

    # --- Install paths ---
    [string]$InstallPath          = "C:\Program Files\CcDashboard",
    [string]$SignalRInstallPath   = "C:\Program Files\CcDashboard\SignalRSimulator",

    # --- CcDashboard.Web: Kestrel ---
    [string]$BindAddress          = "http://localhost",
    [int]   $Port                 = 5000,

    # --- SignalR Simulator: Kestrel ---
    [string]$SignalRBindAddress   = "http://localhost",
    [int]   $SignalRPort          = 5001,

    # --- PostgreSQL (app user) ---
    [string]$DBHost               = "localhost",
    [int]   $DBPort               = 5432,
    [string]$DBName               = "rtmviewdb",
    [string]$DBUser               = "ccdashboard_user",
    [string]$DBPassword           = "",

    # --- PostgreSQL (superuser for DB creation + restore) ---
    [string]$PGSuperUser          = "postgres",
    [string]$PGSuperPassword      = "",

    # --- Redis ---
    [string]$RedisConn            = "localhost:6379",

    # --- Windows Service account ---
    [string]$ServiceAccount       = "LocalSystem"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- Helper: find PostgreSQL tool -------------------------------------------
function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @()
    foreach ($ver in 18, 17, 16, 15, 14, 13, 12) {
        $candidates += "C:\Program Files\PostgreSQL\$ver\bin\$Name.exe"
        $candidates += "C:\Program Files (x86)\PostgreSQL\$ver\bin\$Name.exe"
    }
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }

    $regRoots = @(
        "HKLM:\SOFTWARE\PostgreSQL\Installations",
        "HKLM:\SOFTWARE\WOW6432Node\PostgreSQL\Installations"
    )
    foreach ($root in $regRoots) {
        if (Test-Path $root) {
            Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
                $base = (Get-ItemProperty $_.PSPath -Name "Base Directory" -ErrorAction SilentlyContinue)."Base Directory"
                if ($base) { $p = Join-Path $base "bin\$Name.exe"; if (Test-Path $p) { return $p } }
            }
        }
    }
    Write-Error "$Name not found. Add PostgreSQL bin to PATH."
}

# ---- 0. Must run as Administrator -------------------------------------------
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DumpFile  = Join-Path $ScriptDir "simulator_db.dump"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  RTM View Shell -- Simulator Service Installer"  -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Validate source files -----------------------------------------------
if (-not (Test-Path (Join-Path $ScriptDir "CcDashboard.Web.exe"))) {
    Write-Error "CcDashboard.Web.exe not found in $ScriptDir"
}
if (-not (Test-Path (Join-Path $ScriptDir "SignalRSimulator\SignalRSimulator.exe"))) {
    Write-Error "SignalRSimulator\SignalRSimulator.exe not found in $ScriptDir"
}
if (-not (Test-Path $DumpFile)) {
    Write-Error "simulator_db.dump not found in $ScriptDir. The package is incomplete."
}

# ---- 2. Prompt for passwords ------------------------------------------------
function Read-Pwd([string]$Prompt) {
    $s = Read-Host $Prompt -AsSecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

if ([string]::IsNullOrWhiteSpace($DBPassword))       { $DBPassword       = Read-Pwd "App DB user '$DBUser' password" }
if ([string]::IsNullOrWhiteSpace($PGSuperPassword))  { $PGSuperPassword  = Read-Pwd "PostgreSQL superuser '$PGSuperUser' password" }

$psql      = Find-PGTool "psql"
$pgRestore = Find-PGTool "pg_restore"

# PostgreSQL stores unquoted identifiers as lowercase.
# Use $DBNamePG (lowercase) for all psql/pg_restore operations.
# Npgsql connection string also uses lowercase for consistency.
$DBNamePG = $DBName.ToLower()

# ---- 3. Stop & remove existing services -------------------------------------
foreach ($svcName in @($ServiceName, $SignalRServiceName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "Removing existing service '$svcName'..." -ForegroundColor Yellow
        if ($svc.Status -ne 'Stopped') { Stop-Service -Name $svcName -Force; Start-Sleep 3 }
        sc.exe delete $svcName | Out-Null
        Start-Sleep 2
    }
}

# ---- 4. Copy app files ------------------------------------------------------
Write-Host "Installing to: $InstallPath" -ForegroundColor Green
if (-not (Test-Path $InstallPath)) { New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null }

Write-Host "Copying CcDashboard.Web files..."
Copy-Item (Join-Path $ScriptDir "*") $InstallPath -Recurse -Force `
    -Exclude @("*.ps1", "*.md", "simulator_db.dump")

# SignalRSimulator subfolder is already copied by the above (it's a subdir)
# Ensure logs dir
$logsDir = Join-Path $InstallPath "logs"
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }

# ---- 5. Create PostgreSQL user and database ---------------------------------
Write-Host "Setting up PostgreSQL database '$DBName'..." -ForegroundColor Green

$env:PGPASSWORD = $PGSuperPassword

$createRole = @"
DO `$`$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DBUser') THEN
    CREATE ROLE $DBUser WITH LOGIN PASSWORD '$DBPassword';
  ELSE
    ALTER ROLE $DBUser WITH PASSWORD '$DBPassword';
  END IF;
END `$`$;
"@
& $psql -h $DBHost -p $DBPort -U $PGSuperUser -d postgres -c $createRole
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create DB role." }

$dbExistsRaw = & $psql -h $DBHost -p $DBPort -U $PGSuperUser -d postgres `
    -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNamePG'"
$dbExists = if ($dbExistsRaw) { ($dbExistsRaw | Out-String).Trim() } else { "" }

if ($dbExists -eq '1') {
    Write-Host "Dropping existing database '$DBName' for clean restore..." -ForegroundColor Yellow
    & $psql -h $DBHost -p $DBPort -U $PGSuperUser -d postgres -c `
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DBNamePG' AND pid <> pg_backend_pid();" | Out-Null
    & $psql -h $DBHost -p $DBPort -U $PGSuperUser -d postgres -c "DROP DATABASE $DBNamePG;"
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to drop database." }
}

Write-Host "Creating database '$DBName'..."
& $psql -h $DBHost -p $DBPort -U $PGSuperUser -d postgres -c `
    "CREATE DATABASE $DBNamePG OWNER $DBUser ENCODING 'UTF8';"
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create database." }

& $psql -h $DBHost -p $DBPort -U $PGSuperUser -d $DBNamePG -c `
    "CREATE EXTENSION IF NOT EXISTS pgcrypto; CREATE EXTENSION IF NOT EXISTS pg_trgm;" | Out-Null

# ---- 6. Restore database dump -----------------------------------------------
Write-Host "Restoring simulator database from dump..." -ForegroundColor Green

& $pgRestore -h $DBHost -p $DBPort -U $PGSuperUser -d $DBNamePG `
    --no-owner --no-acl -j 4 -v $DumpFile

if ($LASTEXITCODE -gt 1) { Write-Error "pg_restore failed (exit $LASTEXITCODE)" }

# Grant app user access to all schemas
# Grant app user access — file-based to avoid PowerShell quoting issues
$grantSqlPath = [System.IO.Path]::GetTempFileName() + ".sql"
$grantSql = @"
GRANT USAGE ON SCHEMA public   TO $DBUser;
GRANT USAGE ON SCHEMA identity TO $DBUser;
GRANT USAGE ON SCHEMA audit    TO $DBUser;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public   TO $DBUser;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA identity TO $DBUser;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA audit    TO $DBUser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public   TO $DBUser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA identity TO $DBUser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit    TO $DBUser;
"@
[System.IO.File]::WriteAllText($grantSqlPath, $grantSql, [System.Text.Encoding]::ASCII)
& $psql -h $DBHost -p $DBPort -U $PGSuperUser -d $DBNamePG -f $grantSqlPath | Out-Null
Remove-Item $grantSqlPath -ErrorAction SilentlyContinue

# ---- 7. Update SignalR URL in tenant_settings (key config after restore) ----
Write-Host "Updating SignalR Simulator URL in tenant_settings..."

$signalRUrl = "${SignalRBindAddress}:${SignalRPort}"
# Use file-based SQL — psql -c cannot handle double-quoted identifiers reliably in PowerShell
$updateSqlPath = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($updateSqlPath,
    "UPDATE tenant_settings SET ""SignalRConnectionUrl"" = '$signalRUrl';",
    [System.Text.Encoding]::ASCII)
& $psql -h $DBHost -p $DBPort -U $PGSuperUser -d $DBNamePG -f $updateSqlPath | Out-Null
Remove-Item $updateSqlPath -ErrorAction SilentlyContinue

Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
Write-Host "Database ready. SignalR URL set to: $signalRUrl" -ForegroundColor Green

# UTF-8 without BOM writer — Set-Content -Encoding UTF8 adds BOM in PowerShell 5.x
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# ---- 8. Write CcDashboard.Web appsettings -----------------------------------
Write-Host "Writing appsettings.json (CcDashboard.Web)..."

$ConnStr = "Host=$DBHost;Port=$DBPort;Database=$DBNamePG;Username=$DBUser;Password=$DBPassword;SSL Mode=Prefer"

$appSettings = @"
{
  "AllowedHosts": "*",
  "Kestrel": {
    "Endpoints": {
      "Http": { "Url": "${BindAddress}:${Port}" }
    }
  },
  "ConnectionStrings": {
    "Default": "$ConnStr",
    "Redis":   "$RedisConn"
  },
  "Jwt": {
    "Issuer": "RTMView", "Audience": "RTMView.Users",
    "AccessTokenExpiryMinutes": 15, "RefreshTokenExpiryHours": 8,
    "PrivateKeyPath": "", "PublicKeyPath": ""
  },
  "Smtp": {
    "Host": "localhost", "Port": 25, "UseSsl": false,
    "Username": "", "Password": "", "FromAddress": "noreply@cc-dashboard.local"
  },
  "Seed": {
    "SuperadminEmail": "admin@platform.local",
    "SuperadminPassword": "Admin@123456!"
  },
  "Serilog": {
    "Using": [ "Serilog.Sinks.Console", "Serilog.Sinks.File" ],
    "MinimumLevel": { "Default": "Information", "Override": { "Microsoft": "Warning", "System": "Warning" } },
    "WriteTo": [
      { "Name": "Console" },
      { "Name": "File", "Args": { "path": "logs/log-.txt", "rollingInterval": "Day", "retainedFileCountLimit": 30 } }
    ],
    "Enrich": [ "FromLogContext" ]
  }
}
"@
[System.IO.File]::WriteAllText((Join-Path $InstallPath "appsettings.json"), $appSettings, $utf8NoBom)

# Development env activates BackendEmulation migrations path (idempotent no-op after restore)
$devJson = @"
{
  "Jwt": { "SecretKey": "simulator-secret-key-at-least-32-chars-long!!" },
  "DefaultTenantSlug": "platform"
}
"@
[System.IO.File]::WriteAllText((Join-Path $InstallPath "appsettings.Development.json"), $devJson, $utf8NoBom)

# ---- 9. Write SignalR Simulator appsettings ---------------------------------
Write-Host "Writing appsettings.json (SignalRSimulator)..."

$signalRSettings = @"
{
  "Logging": {
    "LogLevel": { "Default": "Information", "Microsoft.AspNetCore": "Warning" }
  },
  "AllowedHosts": "*",
  "Kestrel": {
    "Endpoints": {
      "Http": { "Url": "${SignalRBindAddress}:${SignalRPort}" }
    }
  },
  "ConnectionStrings": {
    "Default": "$ConnStr"
  },
  "CorsOrigins": [
    "${BindAddress}:${Port}"
  ]
}
"@
[System.IO.File]::WriteAllText((Join-Path $InstallPath "SignalRSimulator\appsettings.json"), $signalRSettings, $utf8NoBom)

# ---- 10. Register Windows Services ------------------------------------------
Write-Host "Registering Windows Services..." -ForegroundColor Green

$WebExe      = Join-Path $InstallPath "CcDashboard.Web.exe"
$SignalRExe  = Join-Path $InstallPath "SignalRSimulator\SignalRSimulator.exe"

$svcExists1 = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svcExists1) {
    Set-Service -Name $ServiceName -BinaryPathName $WebExe -StartupType Automatic
} else {
    New-Service -Name $ServiceName -BinaryPathName $WebExe `
        -DisplayName "CC Dashboard" -StartupType Automatic | Out-Null
}

$svcExists2 = Get-Service -Name $SignalRServiceName -ErrorAction SilentlyContinue
if ($svcExists2) {
    Set-Service -Name $SignalRServiceName -BinaryPathName $SignalRExe -StartupType Automatic
} else {
    New-Service -Name $SignalRServiceName -BinaryPathName $SignalRExe `
        -DisplayName "CC Dashboard SignalR Simulator" -StartupType Automatic | Out-Null
}

# ---- 11. Set env vars in registry for both services -------------------------
$webEnv = @(
    "ASPNETCORE_ENVIRONMENT=Development",
    "ASPNETCORE_URLS=${BindAddress}:${Port}",
    "DOTNET_RUNNING_AS_SERVICE=true"
)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" `
    -Name Environment -Value $webEnv -PropertyType MultiString -Force | Out-Null

$signalREnv = @(
    "ASPNETCORE_ENVIRONMENT=Development",
    "ASPNETCORE_URLS=${SignalRBindAddress}:${SignalRPort}",
    "DOTNET_RUNNING_AS_SERVICE=true"
)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$SignalRServiceName" `
    -Name Environment -Value $signalREnv -PropertyType MultiString -Force | Out-Null

# ---- 12. Configure failure/recovery actions ---------------------------------
sc.exe failure $ServiceName       reset= 86400 actions= restart/0/restart/0/restart/120000 | Out-Null
sc.exe failure $SignalRServiceName reset= 86400 actions= restart/0/restart/0/restart/120000 | Out-Null

# ---- 13. Start services (SignalR first, Web second) -------------------------
Write-Host "Starting SignalR Simulator service..." -ForegroundColor Green
Start-Service -Name $SignalRServiceName
Start-Sleep 3

Write-Host "Starting CcDashboard.Web service..." -ForegroundColor Green
Start-Service -Name $ServiceName
Start-Sleep 5

$webStatus     = (Get-Service -Name $ServiceName).Status
$signalRStatus = (Get-Service -Name $SignalRServiceName).Status

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Installation complete!"                          -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  CcDashboard.Web    [$webStatus]     ${BindAddress}:${Port}"          -ForegroundColor White
Write-Host "  SignalRSimulator   [$signalRStatus]  ${SignalRBindAddress}:${SignalRPort}" -ForegroundColor White
Write-Host ""
Write-Host "  Login:     admin@platform.local"                                     -ForegroundColor White
Write-Host "  Password:  Admin@123456!  (change on first login!)"                  -ForegroundColor Yellow
Write-Host "  Logs:      $logsDir"                                                 -ForegroundColor White
Write-Host ""
Write-Host "  Manage:"                                                              -ForegroundColor Gray
Write-Host "    Stop all:    Stop-Service $ServiceName, $SignalRServiceName"        -ForegroundColor Gray
Write-Host "    Start all:   Start-Service $SignalRServiceName, $ServiceName"       -ForegroundColor Gray
Write-Host ""

if ($webStatus -eq 'Running') { Start-Process "${BindAddress}:${Port}" }
