#Requires -Version 5.1
<#
.SYNOPSIS
    Restores a clean database from git: schema + functions + data.
    Runs ALL steps as PostgreSQL superuser to avoid ownership issues.
.EXAMPLE
    .\Restore-All.ps1 -AppPassword "pw" -SuperPassword "pgpw" -DropAndRecreate
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
    [switch]$DropAndRecreate
)
$ErrorActionPreference = "Stop"
# R0c fix: Set UTF-8 encoding for psql to avoid WIN1252 byte-sequence errors
$env:PGCLIENTENCODING = "UTF8"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot     = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$DbDir        = Join-Path $RepoRoot "db"
$SchemaFile   = Join-Path $DbDir "schema.sql"
$FunctionsDir = Join-Path $DbDir "functions"
$DataDir      = Join-Path $DbDir "data"
$SetupSql     = Join-Path $DbDir "setup\01_init_db.sql"
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
$psql    = Find-PGTool "psql"
$dropdb  = Find-PGTool "dropdb"
$createdb = Find-PGTool "createdb"
if (-not $psql) { throw "psql not found." }

Write-Host "" ; Write-Host "RTM View Shell — Restore Database from Git" -ForegroundColor Cyan
Write-Host "Target: ${AppUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Gray
Write-Host ""

if ($SuperPassword) { $env:PGPASSWORD = $SuperPassword }

function Run-Super([string]$sql, [string]$db = "postgres") {
    [System.IO.File]::WriteAllText($TmpSql, $sql, (New-Object System.Text.UTF8Encoding($false)))
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $db -f $TmpSql 2>&1 | Out-Null
}

# ── Step 1: Terminate connections + Drop + Recreate ──────────────────────
if ($DropAndRecreate) {
    Write-Host "[ 1/4 ] Terminate connections + Drop + Recreate..." -ForegroundColor Cyan
    # Terminate all connections to the DB
    Run-Super ("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();")
    Write-Host "  Connections terminated." -ForegroundColor Gray
    # Drop
    & $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $Database
    Write-Host "  Dropped: $Database" -ForegroundColor Gray
    # Create owned by superuser (we will grant to app user later)
    & $createdb -h $DBHost -p $DBPort -U $SuperUser -E UTF8 $Database
    Write-Host "  Created: $Database" -ForegroundColor Green
    # Init: extensions + app user
    if (Test-Path $SetupSql) {
        & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SetupSql -q
        Write-Host "  Extensions + user configured." -ForegroundColor Green
    }
} else {
    Write-Host "[ 1/4 ] Using existing database." -ForegroundColor Gray
}

# ── Step 2: Schema (as superuser) ────────────────────────────────────────
Write-Host "" ; Write-Host "[ 2/4 ] Applying schema..." -ForegroundColor Cyan
if (Test-Path $SchemaFile) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $SchemaFile -q
    Write-Host "  schema.sql applied." -ForegroundColor Green
    # Transfer ownership of user-created objects to app user
    # Generate ALTER statements dynamically and run as superuser
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
    -- Conditionally set schema ownership (schemas may not exist if RTM-only restore)
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'identity') THEN
        ALTER SCHEMA identity OWNER TO ccdashboard_user;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'audit') THEN
        ALTER SCHEMA audit OWNER TO ccdashboard_user;
    END IF;
END $body$;
'@
    [System.IO.File]::WriteAllText($TmpSql, $ownerSql, (New-Object System.Text.UTF8Encoding($false)))
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q
    Write-Host "  Ownership transferred to $AppUser." -ForegroundColor Green
} else { Write-Host "  schema.sql not found." -ForegroundColor Yellow }

# ── Step 3: Functions (as superuser) ─────────────────────────────────────
Write-Host "" ; Write-Host "[ 3/4 ] Applying SQL functions..." -ForegroundColor Cyan
foreach ($f in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $file -q
        Write-Host "  $f" -ForegroundColor Green
    }
}

# ── Step 4: Data (RTM-only post-R0c — app data seeded by Web.exe migrate) ───────
Write-Host "" ; Write-Host "[ 4/5 ] Applying data..." -ForegroundColor Cyan
foreach ($f in (Get-ChildItem $DataDir -Filter "*.sql" | Sort-Object Name)) {
    & $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $f.FullName -q
    Write-Host "  $($f.Name)" -ForegroundColor Green
}

# ── Step 5: E3 Sequence resync (setval to column max — prevents 23505) ────
Write-Host "" ; Write-Host "[ 5/5 ] Resyncing sequences to column max (E3)..." -ForegroundColor Cyan
$seqResyncSql = @'
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
    JOIN pg_class t ON t.oid=d.refobjid
    JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit')
  LOOP
    EXECUTE format('SELECT setval(%L, (SELECT COALESCE(MAX(%I),1) FROM %I.%I), true)',
                   r.sch||'.'||r.seq, r.col, r.sch, r.tbl);
  END LOOP;
END $$;
'@
[System.IO.File]::WriteAllText($TmpSql, $seqResyncSql, (New-Object System.Text.UTF8Encoding($false)))
& $psql -h $DBHost -p $DBPort -U $SuperUser -d $Database -f $TmpSql -q
Write-Host "  [E3] sequences resynced." -ForegroundColor Green

# ── Grant app user access ────────────────────────────────────────────────
Write-Host "" ; Write-Host "[  +  ] Granting access to $AppUser..." -ForegroundColor Cyan
# RTM-only grants (identity/audit may not exist without Web.exe migrate)
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
Run-Super $grantSql $Database
Write-Host "  Grants applied." -ForegroundColor Green

$env:PGPASSWORD = ""
Remove-Item $TmpSql -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Done. Database restored from git." -ForegroundColor Green
Write-Host "Start Shell service to verify." -ForegroundColor Yellow
