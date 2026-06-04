#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a clean RTM View Shell database from scratch.
.DESCRIPTION
    Step 1: Run 01_init_db.sql (CREATE USER, extensions, grants) as superuser
    Step 2: Start Shell once -> DatabaseInitializer runs all EF migrations + seeds tenant/superadmin
    Step 3: Deploy SQL functions from db/functions/
    Step 4: Apply db/baseline.sql (metrics, RTSGrid, NGC_Site, widget_catalog)

    Prerequisites:
      - PostgreSQL 18 installed and running
      - Database "rtmviewdb" created (or use -CreateDatabase flag)
      - Shell binary at $ShellExe (for EF migrations)
.EXAMPLE
    .\Create-FreshDb.ps1 -SuperPassword "pgpw" -AppPassword "apppw" -CreateDatabase
#>
[CmdletBinding()]
param(
    [string]$DBHost        = "localhost",
    [string]$DBPort        = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$SuperUser     = "postgres",
    [string]$SuperPassword = "",
    [string]$AppUser       = "ccdashboard_user",
    [string]$AppPassword   = "!@#qweASDzxc",
    [string]$ShellExe      = "C:\RTMView\Shell\CcDashboard.Web.exe",
    [switch]$CreateDatabase,
    [switch]$SkipMigrations
)

$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$SetupDir   = Join-Path $RepoRoot "db\setup"
$FunctionsDir = Join-Path $RepoRoot "db\functions"
$BaselineSql  = Join-Path $RepoRoot "db\baseline.sql"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in @("18","17","16","15")) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = "$base\$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

$psql    = Find-PGTool "psql"
$createdb = Find-PGTool "createdb"
if (-not $psql) { throw "psql not found." }

Write-Host "" ; Write-Host "RTM View Shell — Create Fresh Database" -ForegroundColor Cyan
Write-Host "Target: ${AppUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Gray
Write-Host ""

# ── Step 1: CREATE DATABASE (optional) ──────────────────────────────────
Write-Host "[ 1/4 ] Database setup..." -ForegroundColor Cyan
if ($CreateDatabase) {
    if ($SuperPassword) { $env:PGPASSWORD = $SuperPassword }
    Write-Host "  Creating database $Database..." -ForegroundColor Gray
    & $createdb -h $DBHost -p $DBPort -U $SuperUser -E UTF8 $Database 2>&1 | Write-Host
    $env:PGPASSWORD = ""
}
if ($SuperPassword) { $env:PGPASSWORD = $SuperPassword }
$initSql = Join-Path $SetupDir "01_init_db.sql"
if (Test-Path $initSql) {
    Write-Host "  Applying 01_init_db.sql..." -ForegroundColor Gray
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $initSql 2>&1 | Write-Host
    Write-Host "  Init SQL done." -ForegroundColor Green
} else {
    Write-Host "  01_init_db.sql not found — skipping." -ForegroundColor Yellow
}
$env:PGPASSWORD = ""

# ── Step 2: EF Migrations via Shell startup ──────────────────────────────
Write-Host "" ; Write-Host "[ 2/4 ] EF Migrations..." -ForegroundColor Cyan
if ($SkipMigrations) {
    Write-Host "  Skipped (-SkipMigrations)." -ForegroundColor Yellow
} elseif (Test-Path $ShellExe) {
    Write-Host "  Running: $ShellExe migrate" -ForegroundColor Gray
    & $ShellExe migrate
    Write-Host "  EF Migrations + seed applied." -ForegroundColor Green
} else {
    Write-Host "  Shell binary not found at: $ShellExe" -ForegroundColor Yellow
    Write-Host "  Run manually: CcDashboard.Web.exe migrate" -ForegroundColor Yellow
}

# ── Step 3: SQL Functions ────────────────────────────────────────────────
Write-Host "" ; Write-Host "[ 3/4 ] SQL Functions..." -ForegroundColor Cyan
if ($AppPassword) { $env:PGPASSWORD = $AppPassword }
$functionFiles = @(
    "01_ngc_functions.sql",
    "02_rtsdata_functions.sql",
    "03_rtsgrid_read.sql",
    "04_misc_functions.sql"
)
foreach ($f in $functionFiles) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -f $file -q
        Write-Host "  Applied: $f" -ForegroundColor Green
    } else {
        Write-Host "  Not found: $f" -ForegroundColor Yellow
    }
}

# ── Step 4: Baseline seed data ───────────────────────────────────────────
Write-Host "" ; Write-Host "[ 4/4 ] Baseline seed data..." -ForegroundColor Cyan
if (Test-Path $BaselineSql) {
    & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -f $BaselineSql -q
    Write-Host "  baseline.sql applied." -ForegroundColor Green
} else {
    Write-Host "  baseline.sql not found — run Export-Baseline.ps1 first." -ForegroundColor Yellow
}
$env:PGPASSWORD = ""

Write-Host ""
Write-Host "Done. Fresh database is ready." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Configure appsettings (connection string, TenantId)" -ForegroundColor Yellow
Write-Host "  2. Start Shell service" -ForegroundColor Yellow
Write-Host "  3. Start RTM Service" -ForegroundColor Yellow
