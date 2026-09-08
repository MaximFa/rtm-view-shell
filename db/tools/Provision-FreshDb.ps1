#Requires -Version 5.1
<#
.SYNOPSIS
    Canonical Design-B fresh DB provisioning: drop -> init -> migrate(shell) -> schema.sql -> functions -> data.
.DESCRIPTION
    This is the ONE correct order for fresh DB creation (ADR-007 / Design B):
      1. Terminate connections + dropdb + createdb (superuser)
      2. 01_init_db.sql — extensions + app user (superuser)
      3. Shell migrate (CcDashboard.Web.exe migrate) — shell tables only (Production env, from Shell dir)
      4. schema.sql — backend tables (superuser) + ownership transfer to app user
      5. Functions — 01_ngc, 02_rtsdata, 03_rtsgrid_read, 04_misc (superuser)
      6. Data — db/data/*.sql name-sorted (superuser)
      7. Sequence resync + grants

    After CC-1 (DropAppOwnedBackendTables migration), Shell migrate yields SHELL-ONLY tables.
    Backend tables are created by schema.sql.

.PARAMETER ShellExe
    Path to CcDashboard.Web.exe. Must exist and be deployed before calling this script.
.EXAMPLE
    .\Provision-FreshDb.ps1 -SuperPassword "pgpw" -AppPassword "apppw" -ShellExe "C:\RTMView\Shell\CcDashboard.Web.exe"
#>
[CmdletBinding()]
param(
    [string]$DBHost        = "localhost",
    [string]$DBPort        = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$SuperUser     = "postgres",
    [string]$SuperPassword = "",
    [string]$AppUser       = "ccdashboard_user",
    [string]$AppPassword   = "",
    [string]$ShellExe      = "C:\RTMView\Shell\CcDashboard.Web.exe"
)

# Use Continue for psql NOTICE messages (role already exists, etc.)
$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# RepoRoot = parent of parent of ScriptDir (db/tools/ -> db/ -> repo)
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$DbDir = Join-Path $RepoRoot "db"
$SetupSql = Join-Path $DbDir "setup\01_init_db.sql"
$SchemaFile = Join-Path $DbDir "schema.sql"
$FunctionsDir = Join-Path $DbDir "functions"
$DataDir = Join-Path $DbDir "data"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in @("18","17","16","15","14","13")) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = "$base\$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

$psql = Find-PGTool "psql"
$dropdb = Find-PGTool "dropdb"
$createdb = Find-PGTool "createdb"
if (-not $psql) { throw "psql not found. Install PostgreSQL or add bin to PATH." }
if (-not $dropdb) { throw "dropdb not found." }
if (-not $createdb) { throw "createdb not found." }

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  RTM View Shell - Provision Fresh Database (Design B)" -ForegroundColor Cyan
Write-Host "  Target: ${AppUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

if ($SuperPassword) { $env:PGPASSWORD = $SuperPassword }

# ── Step 1: Terminate + Drop + Create ────────────────────────────────────────
Write-Host "[ 1/7 ] Terminate connections + Drop + Create database..." -ForegroundColor Cyan

# Terminate all connections
$termSql = "SELECT COUNT(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();"
$termResult = & $psql -h $DBHost -p $DBPort -U $SuperUser -d postgres -tAc $termSql 2>&1
Write-Host "  Terminated: $("$termResult".Trim()) connections" -ForegroundColor Gray

# Drop database
& $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $Database 2>&1 | Out-Null
Write-Host "  Dropped: $Database" -ForegroundColor Gray

# Create database
& $createdb -h $DBHost -p $DBPort -U $SuperUser -E UTF8 $Database 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] createdb failed" -ForegroundColor Red
    $env:PGPASSWORD = ""
    exit 1
}
Write-Host "  Created: $Database" -ForegroundColor Green

# ── Step 2: Init (extensions + app user) ─────────────────────────────────────
Write-Host "" ; Write-Host "[ 2/7 ] Applying 01_init_db.sql (extensions + app user)..." -ForegroundColor Cyan
if (Test-Path $SetupSql) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SetupSql -q 2>&1 | Out-Null
    Write-Host "  Extensions + user configured." -ForegroundColor Green
} else {
    Write-Host "  [WARN] $SetupSql not found - skipping." -ForegroundColor Yellow
}

# ── Step 3: Shell migrate (shell tables + seed) ─────────────────────────────
Write-Host "" ; Write-Host "[ 3/7 ] Running Shell migrate (shell tables only)..." -ForegroundColor Cyan
if (-not (Test-Path $ShellExe)) {
    Write-Host "  [ERROR] ShellExe not found: $ShellExe" -ForegroundColor Red
    Write-Host "  Deploy Shell binaries first, then run this script." -ForegroundColor Red
    $env:PGPASSWORD = ""
    exit 1
}

# CRITICAL: run migrate from the Shell directory (ASP.NET content-root = CWD)
$ShellDir = Split-Path -Parent $ShellExe
Write-Host "  Exe: $ShellExe" -ForegroundColor Gray
Write-Host "  CWD: $ShellDir" -ForegroundColor Gray

Push-Location $ShellDir
try {
    $env:ASPNETCORE_ENVIRONMENT = "Production"
    & $ShellExe migrate 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] migrate exited with code $LASTEXITCODE" -ForegroundColor Yellow
    } else {
        Write-Host "  Shell migrate complete (shell tables + seed)." -ForegroundColor Green
    }
} finally {
    Pop-Location
    $env:ASPNETCORE_ENVIRONMENT = ""
}

# ── Step 4: schema.sql (backend tables) + ownership ─────────────────────────
Write-Host "" ; Write-Host "[ 4/7 ] Applying schema.sql (backend tables)..." -ForegroundColor Cyan
if (Test-Path $SchemaFile) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SchemaFile -q 2>&1 | Out-Null
    Write-Host "  schema.sql applied." -ForegroundColor Green

    # Transfer ownership to app user (reused from Restore-All.ps1)
    $TmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
    $ownerSql = @'
DO $body$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT schemaname AS s, tablename AS t FROM pg_tables
             WHERE schemaname IN ('public','identity','audit') AND tableowner != 'ccdashboard_user'
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.s) || '.' || quote_ident(r.t) || ' OWNER TO ccdashboard_user';
    END LOOP;
    FOR r IN SELECT sequence_schema AS s, sequence_name AS n FROM information_schema.sequences
             WHERE sequence_schema IN ('public','identity','audit')
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.s) || '.' || quote_ident(r.n) || ' OWNER TO ccdashboard_user';
    END LOOP;
    FOR r IN SELECT nspname AS s, proname AS n, pg_get_function_identity_arguments(p.oid) AS a
             FROM pg_proc p JOIN pg_namespace ns ON p.pronamespace = ns.oid
             WHERE nspname IN ('public','identity','audit') AND p.prokind = 'f'
    LOOP
        EXECUTE 'ALTER FUNCTION ' || quote_ident(r.s) || '.' || quote_ident(r.n) || '(' || r.a || ') OWNER TO ccdashboard_user';
    END LOOP;
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'identity') THEN
        ALTER SCHEMA identity OWNER TO ccdashboard_user;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') THEN
        ALTER SCHEMA audit OWNER TO ccdashboard_user;
    END IF;
END $body$;
'@
    [System.IO.File]::WriteAllText($TmpSql, $ownerSql, (New-Object System.Text.UTF8Encoding($false)))
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q 2>&1 | Out-Null
    Remove-Item $TmpSql -ErrorAction SilentlyContinue
    Write-Host "  Ownership transferred to $AppUser." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] schema.sql not found: $SchemaFile" -ForegroundColor Red
    $env:PGPASSWORD = ""
    exit 1
}

# ── Step 5: Functions ────────────────────────────────────────────────────────
Write-Host "" ; Write-Host "[ 5/7 ] Applying SQL functions..." -ForegroundColor Cyan
$funcFiles = @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")
foreach ($f in $funcFiles) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $file -q 2>&1 | Out-Null
        Write-Host "  $f" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $f not found" -ForegroundColor Yellow
    }
}

# ── Step 6: Data (seed) ──────────────────────────────────────────────────────
Write-Host "" ; Write-Host "[ 6/7 ] Applying seed data (db/data/*.sql)..." -ForegroundColor Cyan
if (Test-Path $DataDir) {
    $dataFiles = @(Get-ChildItem $DataDir -Filter "*.sql" | Sort-Object Name)
    foreach ($f in $dataFiles) {
        & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $f.FullName -q 2>&1 | Out-Null
        Write-Host "  $($f.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "  [WARN] $DataDir not found" -ForegroundColor Yellow
}

# ── Step 7: Sequence resync + grants ─────────────────────────────────────────
Write-Host "" ; Write-Host "[ 7/7 ] Sequence resync + grants..." -ForegroundColor Cyan

# Sequence resync (reused from Restore-All.ps1)
$TmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
$seqResyncSql = @'
DO $$
DECLARE r record; seq_count int := 0;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid=s.oid AND d.deptype IN ('a','i')
    JOIN pg_class t ON t.oid=d.refobjid
    JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit')
  LOOP
    EXECUTE format('SELECT setval(%L, (SELECT COALESCE(MAX(%I),1) FROM %I.%I), true)',
                   quote_ident(r.sch)||'.'||quote_ident(r.seq), r.col, r.sch, r.tbl);
    seq_count := seq_count + 1;
  END LOOP;
  RAISE NOTICE 'RESYNC count=%', seq_count;
END $$;
'@
[System.IO.File]::WriteAllText($TmpSql, $seqResyncSql, (New-Object System.Text.UTF8Encoding($false)))
# RAISE NOTICE goes to stderr, so the combined stream is captured; -q would hide nothing useful here.
$resyncOut  = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -v ON_ERROR_STOP=1 -f $TmpSql 2>&1
$resyncRc   = $LASTEXITCODE
$resyncText = ($resyncOut | Out-String)
if ($resyncRc -ne 0) {
    Write-Host "  [FATAL] step 7: psql exit code $resyncRc - sequences were NOT resynced" -ForegroundColor Red
    Write-Host $resyncText
    exit 1
}
$resyncMatch = [regex]::Match($resyncText, 'RESYNC count=(\d+)')
if (-not $resyncMatch.Success) {
    Write-Host "  [FATAL] step 7 did not report a count: the output was not parsed" -ForegroundColor Red
    Write-Host $resyncText
    exit 1
}
$resyncN = [int]$resyncMatch.Groups[1].Value
if ($resyncN -eq 0) {
    Write-Host "  [FATAL] step 7 processed 0 sequences; the schema uses IDENTITY (deptype 'i') and the filter did not match - the database would collide on first insert" -ForegroundColor Red
    exit 1
}
Write-Host "  Sequences resynced: $resyncN" -ForegroundColor Green

# Grants
$grantSql = @"
GRANT USAGE ON SCHEMA public TO $AppUser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $AppUser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $AppUser;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $AppUser;
DO \$\$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'identity') THEN
        EXECUTE 'GRANT USAGE ON SCHEMA identity TO $AppUser';
        EXECUTE 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA identity TO $AppUser';
        EXECUTE 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA identity TO $AppUser';
        EXECUTE 'ALTER SCHEMA identity OWNER TO $AppUser';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') THEN
        EXECUTE 'GRANT USAGE ON SCHEMA audit TO $AppUser';
        EXECUTE 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO $AppUser';
        EXECUTE 'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit TO $AppUser';
        EXECUTE 'ALTER SCHEMA audit OWNER TO $AppUser';
    END IF;
END \$\$;
"@
[System.IO.File]::WriteAllText($TmpSql, $grantSql, (New-Object System.Text.UTF8Encoding($false)))
& $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q 2>&1 | Out-Null
Remove-Item $TmpSql -ErrorAction SilentlyContinue
Write-Host "  Grants applied." -ForegroundColor Green

# ── Verify ───────────────────────────────────────────────────────────────────
Write-Host "" ; Write-Host "[ VERIFY ] Checking database state..." -ForegroundColor Cyan

$verifyQueries = @(
    @{ Name = "RTSGrid_Metric exists"; Sql = 'SELECT to_regclass(''public."RTSGrid_Metric"'')::text' },
    @{ Name = "RTSData_Interaction exists"; Sql = 'SELECT to_regclass(''public."RTSData_Interaction"'')::text' },
    @{ Name = "tenants exists"; Sql = 'SELECT to_regclass(''public.tenants'')::text' },
    @{ Name = "RTSGrid_Metric count"; Sql = 'SELECT COUNT(*) FROM "RTSGrid_Metric"' },
    @{ Name = "tenants count"; Sql = 'SELECT COUNT(*) FROM tenants' },
    @{ Name = "superadmin exists"; Sql = 'SELECT COUNT(*) FROM identity.users WHERE "NormalizedUserName" = ''SUPERADMIN''' }
)

foreach ($q in $verifyQueries) {
    $result = & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -tAc $q.Sql 2>&1
    $val = "$result".Trim()
    if ($val -eq "" -or $val -eq "0" -or $val -match "does not exist") {
        Write-Host "  [FAIL] $($q.Name): $val" -ForegroundColor Red
    } else {
        Write-Host "  [OK] $($q.Name): $val" -ForegroundColor Green
    }
}

$env:PGPASSWORD = ""

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  PROVISION COMPLETE (Design B)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify appsettings.json (ConnectionStrings, Redis, Seed:SuperadminPassword)" -ForegroundColor Yellow
Write-Host "  2. Start Shell service: Start-Service RTMViewShell" -ForegroundColor Yellow
Write-Host "  3. Start RTM service: Start-Service RTMService" -ForegroundColor Yellow
Write-Host ""
