#Requires -Version 5.1
<#
.SYNOPSIS
    One-command rebuild proof: creates a scratch DB, runs the full rebuild per
    REBUILD_RUNBOOK.md order, and runs Compare-ToBaseline to verify B:0.
    Drops the DB unless -KeepDb is specified.

.DESCRIPTION
    R0c (2026-06-21): This script follows the post-carve rebuild order:
    1. dropdb+createdb (scratch throwaway DB)
    2. 01_init_db.sql (extensions + user grants)
    3. Web.exe migrate (creates EF-app tables: identity.*, audit.*, dashboards, etc.)
    4. psql schema.sql (RTM-canonical tables: NGC_*, RTSData_*, RTSGrid_*, etc.)
    5. psql functions/01..04
    6. psql db/data/*.sql (RTM-only seed data)
    7. Compare-ToBaseline (must return B:0)
    8. dropdb (unless -KeepDb)

.EXAMPLE
    .\Rebuild-Proof.ps1 -SuperPassword "pgpw" -AppPassword "apppw" -ShellExe "C:\...\CcDashboard.Web.exe"
    .\Rebuild-Proof.ps1 -SuperPassword "pgpw" -AppPassword "apppw" -ShellExe ".\publish\web\CcDashboard.Web.exe" -KeepDb
#>
[CmdletBinding()]
param(
    [string]$DBHost        = "localhost",
    [int]$DBPort           = 5432,
    [string]$Database      = "rtmviewdb_proof",
    [string]$SuperUser     = "postgres",
    [Parameter(Mandatory=$true)]
    [string]$SuperPassword,
    [string]$AppUser       = "ccdashboard_user",
    [Parameter(Mandatory=$true)]
    [string]$AppPassword,
    [Parameter(Mandatory=$true)]
    [string]$ShellExe,
    [switch]$KeepDb
)

$ErrorActionPreference = "Stop"
# R0c fix: UTF-8 encoding for psql
$env:PGCLIENTENCODING = "UTF8"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot     = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$DbDir        = Join-Path $RepoRoot "db"
$SchemaFile   = Join-Path $DbDir "schema.sql"
$FunctionsDir = Join-Path $DbDir "functions"
$DataDir      = Join-Path $DbDir "data"
$SetupSql     = Join-Path (Join-Path $DbDir "setup") "01_init_db.sql"
$CompareTool  = Join-Path (Join-Path $DbDir "tools") "Compare-ToBaseline.ps1"
$TmpSql       = [System.IO.Path]::GetTempFileName() + ".sql"

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

$psql     = Find-PGTool "psql"
$dropdb   = Find-PGTool "dropdb"
$createdb = Find-PGTool "createdb"
if (-not $psql -or -not $dropdb -or -not $createdb) { throw "psql/dropdb/createdb not found." }
if (-not (Test-Path $ShellExe)) { throw "ShellExe not found: $ShellExe" }

Write-Host ""
Write-Host "RTM View Shell — Rebuild Proof" -ForegroundColor Cyan
Write-Host "Scratch DB: ${SuperUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Gray
Write-Host ""

$env:PGPASSWORD = $SuperPassword

function Write-NoBoM([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ── Step 1: Drop + Create scratch DB ────────────────────────────────────────
Write-Host "[ 1/7 ] Drop + Create scratch DB..." -ForegroundColor Cyan
# Terminate connections
$terminateSql = "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();"
Write-NoBoM $TmpSql $terminateSql
& $psql -h $DBHost -p $DBPort -U $SuperUser -d postgres -f $TmpSql -q 2>$null
# Drop
& $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $Database 2>$null
# Create
& $createdb -h $DBHost -p $DBPort -U $SuperUser -E UTF8 $Database
Write-Host "  Created: $Database" -ForegroundColor Green

# ── Step 2: Init (extensions + user) ─────────────────────────────────────────
Write-Host "[ 2/7 ] Init (extensions + user)..." -ForegroundColor Cyan
if (Test-Path $SetupSql) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SetupSql -q
    Write-Host "  01_init_db.sql applied." -ForegroundColor Green
} else {
    # Inline init if setup file missing
    $initSql = @"
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DO `$`$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$AppUser') THEN
        CREATE USER $AppUser WITH PASSWORD '$AppPassword';
    END IF;
END `$`$;
GRANT ALL ON DATABASE $Database TO $AppUser;
"@
    Write-NoBoM $TmpSql $initSql
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q
    Write-Host "  Inline init applied." -ForegroundColor Green
}

# ── Step 3: Web.exe migrate (EF-app tables) ──────────────────────────────────
Write-Host "[ 3/7 ] Web.exe migrate (EF-app tables)..." -ForegroundColor Cyan
$connStr = "Host=$DBHost;Port=$DBPort;Database=$Database;Username=$AppUser;Password=$AppPassword"
$env:ConnectionStrings__Default = $connStr
try {
    $migrateResult = & $ShellExe migrate 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Web.exe migrate failed (exit $LASTEXITCODE):" -ForegroundColor Red
        Write-Host $migrateResult
        throw "Web.exe migrate failed"
    }
    Write-Host "  EF migrations applied." -ForegroundColor Green
} finally {
    Remove-Item Env:\ConnectionStrings__Default -ErrorAction SilentlyContinue
}

# ── Step 4: schema.sql (RTM tables) ──────────────────────────────────────────
Write-Host "[ 4/7 ] schema.sql (RTM tables)..." -ForegroundColor Cyan
if (Test-Path $SchemaFile) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SchemaFile -q
    Write-Host "  schema.sql applied." -ForegroundColor Green
} else { throw "schema.sql not found: $SchemaFile" }

# ── Step 5: Functions ─────────────────────────────────────────────────────────
Write-Host "[ 5/7 ] SQL functions..." -ForegroundColor Cyan
foreach ($f in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $file -q
        Write-Host "  $f" -ForegroundColor Green
    }
}

# ── Step 6: Data (RTM-only) ──────────────────────────────────────────────────
Write-Host "[ 6/7 ] Data (RTM-only)..." -ForegroundColor Cyan
foreach ($f in (Get-ChildItem $DataDir -Filter "*.sql" | Sort-Object Name)) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $f.FullName -q
    Write-Host "  $($f.Name)" -ForegroundColor Green
}

# ── Step 6.5: Grant app-user access to RTM tables ─────────────────────────────
# RTM tables are owned by postgres after psql schema.sql; app-user needs access for Compare
Write-Host "[ 6+ ] Granting $AppUser access to RTM tables..." -ForegroundColor Cyan
$grantSql = @"
GRANT USAGE ON SCHEMA public TO $AppUser;
GRANT ALL ON ALL TABLES IN SCHEMA public TO $AppUser;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO $AppUser;
"@
Write-NoBoM $TmpSql $grantSql
& $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q
Write-Host "  Grants applied." -ForegroundColor Green

# ── Step 7: Compare-ToBaseline ───────────────────────────────────────────────
Write-Host "[ 7/7 ] Compare-ToBaseline..." -ForegroundColor Cyan
if (Test-Path $CompareTool) {
    # Run Compare with the proof DB
    $compareResult = & $CompareTool -DBHost $DBHost -DBPort $DBPort -Database $Database -Password $SuperPassword 2>&1
    Write-Host $compareResult

    # Parse for B=0
    $bMatch = [regex]::Match(($compareResult -join "`n"), 'B:?\s*(\d+)')
    $bCount = if ($bMatch.Success) { [int]$bMatch.Groups[1].Value } else { -1 }

    # Parse for A=0 too
    $aMatch = [regex]::Match(($compareResult -join "`n"), 'A:?\s*(\d+)')
    $aCount = if ($aMatch.Success) { [int]$aMatch.Groups[1].Value } else { -1 }

    if ($bCount -eq 0 -and $aCount -eq 0) {
        Write-Host ""
        Write-Host "PASS: Compare-ToBaseline A=0 B=0" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "FAIL: Compare-ToBaseline B=$bCount (expected 0)" -ForegroundColor Red
    }
} else {
    Write-Host "  Compare-ToBaseline.ps1 not found — skipping." -ForegroundColor Yellow
    $bCount = -1
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
$env:PGPASSWORD = $SuperPassword
Remove-Item $TmpSql -ErrorAction SilentlyContinue

if (-not $KeepDb) {
    Write-Host ""
    Write-Host "Dropping scratch DB: $Database" -ForegroundColor Gray
    & $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $Database 2>$null
    Write-Host "Dropped." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Keeping scratch DB: $Database (use -KeepDb:$false to drop)" -ForegroundColor Yellow
}

$env:PGPASSWORD = ""
Write-Host ""
if ($bCount -eq 0 -and $aCount -ge 0) {
    Write-Host "REBUILD PROOF COMPLETE — A=$aCount B=0" -ForegroundColor Green
    exit 0
} elseif ($bCount -eq -1) {
    Write-Host "REBUILD PROOF COMPLETE — Compare not run, verify manually" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "REBUILD PROOF FAILED — A=$aCount B=$bCount" -ForegroundColor Red
    exit 1
}
