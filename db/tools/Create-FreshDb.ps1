# Create-FreshDb.ps1
# Creates a clean RTM View Shell database from scratch.
# Steps: EF migrations -> SQL functions -> Shell startup seed -> baseline.sql
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File db\tools\Create-FreshDb.ps1 `
#     -DBPassword "yourpw" -DBAppPassword "apppw"

[CmdletBinding()]
param(
    [string]$Host          = "localhost",
    [string]$Port          = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$DBSuperUser   = "postgres",
    [string]$DBPassword    = "",
    [string]$DBAppUser     = "ccdashboard_user",
    [string]$DBAppPassword = "",
    [string]$ShellExe      = "C:\RTMView\Shell\CcDashboard.Web.exe",
    [switch]$SkipMigrations
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$FunctionsDir = Join-Path $RepoRoot "db\functions"
$BaselineSql  = Join-Path $RepoRoot "db\baseline.sql"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
        $found = Get-ChildItem "$base\*\bin\$Name.exe" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$psql = Find-PGTool "psql"
if (-not $psql) { throw "psql not found." }

if ($DBPassword) { $env:PGPASSWORD = $DBPassword }

Write-Host "[ 1/4 ] Running EF migrations..." -ForegroundColor Cyan
if (-not $SkipMigrations -and (Test-Path $ShellExe)) {
    & $ShellExe migrate
    Write-Host "  Migrations applied." -ForegroundColor Green
} else {
    Write-Host "  Skipped (SkipMigrations or ShellExe not found)." -ForegroundColor Yellow
}

Write-Host "[ 2/4 ] Deploying SQL functions..." -ForegroundColor Cyan
foreach ($f in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        if ($DBAppPassword) { $env:PGPASSWORD = $DBAppPassword }
        & $psql -h $Host -p $Port -U $DBAppUser -d $Database -f $file -q
        Write-Host "  Applied: $f" -ForegroundColor Green
    } else {
        Write-Host "  Not found: $f" -ForegroundColor Yellow
    }
}

Write-Host "[ 3/4 ] Applying baseline seed data..." -ForegroundColor Cyan
if (Test-Path $BaselineSql) {
    if ($DBAppPassword) { $env:PGPASSWORD = $DBAppPassword }
    & $psql -h $Host -p $Port -U $DBAppUser -d $Database -f $BaselineSql -q
    Write-Host "  Baseline applied." -ForegroundColor Green
} else {
    Write-Host "  baseline.sql not found — run Export-Baseline.ps1 first." -ForegroundColor Yellow
}

Write-Host "[ 4/4 ] Done." -ForegroundColor Green
Write-Host ""
Write-Host "Next: start Shell service -> DatabaseInitializer creates Platform tenant + superadmin." -ForegroundColor Yellow
$env:PGPASSWORD = ""
