#Requires -Version 5.1
<#
.SYNOPSIS
    Restores RTM PostgreSQL database from a pg_dump backup (custom or plain SQL format).
.EXAMPLE
    .\Restore-SqlDump.ps1 -DumpFile "D:\path\dump.sql" -DBPassword "pwd" -DBAppPassword "pwd" -StopService
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DumpFile,
    [string]$DBName        = "rtmviewdb",
    [string]$DBHost        = "localhost",
    [int]   $DBPort        = 5432,
    [string]$DBUser        = "postgres",
    [string]$DBPassword    = "",
    [string]$DBAppUser     = "ccdashboard_user",
    [string]$DBAppPassword = "",
    [string]$ServiceName   = "RTMService",
    [switch]$StopService
)

$ErrorActionPreference = "Stop"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in 18,17,16,15,14,13) {
        $p = "C:\Program Files\PostgreSQL\$ver\bin\$Name.exe"
        if (Test-Path $p) { return $p }
    }
    return $null
}

$psql      = Find-PGTool "psql"
$pgRestore = Find-PGTool "pg_restore"
if (-not $psql)      { throw "psql not found" }
if (-not $pgRestore) { throw "pg_restore not found" }
if (-not (Test-Path $DumpFile)) { throw "Dump file not found: $DumpFile" }

# Detect format: custom-format starts with magic bytes PGDMP
$header = [System.IO.File]::ReadAllBytes($DumpFile)[0..4]
$magic  = [System.Text.Encoding]::ASCII.GetString($header)
$isCustomFormat = $magic.StartsWith("PGDMP")

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  RTM Database Restore" -ForegroundColor Cyan
Write-Host "  DB     : $DBName" -ForegroundColor Cyan
Write-Host "  Format : $(if ($isCustomFormat) {'custom (pg_restore)'} else {'plain SQL (psql)'})" -ForegroundColor Cyan
Write-Host "  Dump   : $([System.IO.Path]::GetFileName($DumpFile))" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($DBPassword) { $env:PGPASSWORD = $DBPassword }

# [1] Stop service
if ($StopService) {
    $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "[1] Stopping $ServiceName..." -ForegroundColor Yellow
        Stop-Service $ServiceName; Start-Sleep 3
        Write-Host "    Stopped." -ForegroundColor Gray
    } else { Write-Host "[1] $ServiceName not running." -ForegroundColor Gray }
} else { Write-Host "[1] StopService not requested." -ForegroundColor Gray }

# [2] Terminate connections
Write-Host "[2] Terminating connections to $DBName..." -ForegroundColor Cyan
$sqlTerm = "SELECT COUNT(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE datname='$DBName' AND pid <> pg_backend_pid();"
$term = (& $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc $sqlTerm 2>&1)
Write-Host "    Terminated: $("$term".Trim()) sessions." -ForegroundColor Gray

# [3] Drop database
Write-Host "[3] Dropping $DBName (if exists)..." -ForegroundColor Cyan
$sqlEx = "SELECT 1 FROM pg_database WHERE datname='$DBName';"
$exRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc $sqlEx 2>&1
$exVal = if ($exRaw) { "$exRaw".Trim() } else { "" }
if ($exVal -eq "1") {
    & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "DROP DATABASE $DBName;" | Out-Null
    Write-Host "    Dropped." -ForegroundColor Gray
} else { Write-Host "    Not found - skipping." -ForegroundColor Gray }

# [4] Create database
Write-Host "[4] Creating $DBName..." -ForegroundColor Cyan
& $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "CREATE DATABASE $DBName ENCODING 'UTF8';" | Out-Null
Write-Host "    Created." -ForegroundColor Green

# [5] Restore
Write-Host "[5] Restoring..." -ForegroundColor Cyan
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
if ($isCustomFormat) {
    & $pgRestore -h $DBHost -p $DBPort -U $DBUser -d $DBName --no-owner $DumpFile
    $restoreExit = $LASTEXITCODE
} else {
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -v ON_ERROR_STOP=0 -f $DumpFile
    $restoreExit = $LASTEXITCODE
}
$ErrorActionPreference = $prevPref
if ($restoreExit -le 1) {
    Write-Host "    Restored (exit=$restoreExit)." -ForegroundColor Green
} else {
    Write-Host "    [WARN] restore exited $restoreExit" -ForegroundColor Yellow
}

# [6] App user + grants
if ($DBAppUser -and $DBAppPassword) {
    Write-Host "[6] Ensuring app user $DBAppUser..." -ForegroundColor Cyan
    $sqlUser = "SELECT 1 FROM pg_roles WHERE rolname='$DBAppUser';"
    $uRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc $sqlUser 2>&1
    $uVal = if ($uRaw) { "$uRaw".Trim() } else { "" }
    if ($uVal -eq "1") {
        & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "ALTER USER $DBAppUser WITH PASSWORD '$DBAppPassword';" | Out-Null
        Write-Host "    Password updated." -ForegroundColor Gray
    } else {
        & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "CREATE USER $DBAppUser WITH PASSWORD '$DBAppPassword';" | Out-Null
        Write-Host "    User created." -ForegroundColor Green
    }
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c "GRANT ALL PRIVILEGES ON DATABASE $DBName TO $DBAppUser;" | Out-Null
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c "GRANT ALL ON SCHEMA public TO $DBAppUser;" | Out-Null
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DBAppUser;" | Out-Null
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DBAppUser;" | Out-Null
    & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DBAppUser;" | Out-Null
    Write-Host "    Grants applied (DB + schema + tables + sequences + functions)." -ForegroundColor Gray
}

$env:PGPASSWORD = ""

# [7] Start service
if ($StopService) {
    $svc = Get-Service $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        if (Test-Path "C:\RTMView\RTM\data.sys") {
            Write-Host "[7] Starting $ServiceName..." -ForegroundColor Cyan
            Start-Service $ServiceName; Start-Sleep 4
            Write-Host "    $((Get-Service $ServiceName).Status)" -ForegroundColor Green
        } else {
            Write-Host "[7] data.sys missing - NOT started." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  RESTORE COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
