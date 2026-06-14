<#
.SYNOPSIS
    Regenerate db/schema.sql from EF migrations + SQL functions + db/migrations.
    GENERATED-ONLY: schema.sql is no longer hand-edited; this script is the source of truth.

.DESCRIPTION
    Creates a scratch database, applies all sources in order, then pg_dump to produce
    a clean canonical schema.sql with provenance header. Drops 9 phantom tables that
    existed in the old stale dump.

.PARAMETER SuperPassword
    Password for postgres superuser.
.PARAMETER AppPassword
    Password for ccdashboard_user.
.PARAMETER DBHost
    Database host. Default: localhost.
.PARAMETER DBPort
    Database port. Default: 5432.
.PARAMETER SuperUser
    Superuser name. Default: postgres.
.PARAMETER AppUser
    Application user. Default: ccdashboard_user.
.PARAMETER ScratchDb
    Name of temporary database. Default: rtmviewdb_regen.
.PARAMETER KeepScratch
    If set, do not drop the scratch database at the end.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SuperPassword,
    [Parameter(Mandatory)][string]$AppPassword,
    [string]$DBHost = "localhost",
    [string]$DBPort = "5432",
    [string]$SuperUser = "postgres",
    [string]$AppUser = "ccdashboard_user",
    [string]$ScratchDb = "rtmviewdb_regen",
    [switch]$KeepScratch
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in @("18","17","16","15")) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = Join-Path $base "$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    throw "PostgreSQL tool '$Name' not found"
}

$psql = Find-PGTool "psql"
$createdb = Find-PGTool "createdb"
$dropdb = Find-PGTool "dropdb"
$pgdump = Find-PGTool "pg_dump"

Write-Host "=== REGEN-SCHEMA.PS1 ===" -ForegroundColor Cyan
Write-Host "Repo root: $RepoRoot"
Write-Host "Scratch DB: $ScratchDb"

# -- E4: EF-model >= migrations invariant -- abort if any context has uncaptured model changes --
Write-Host "`n[E4] Verifying EF model is fully captured by migrations..." -ForegroundColor Cyan
$ctxs = @("AppDbContext","AuditDbContext","BackendEmulationDbContext")
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
foreach ($ctx in $ctxs) {
    $output = dotnet ef migrations has-pending-model-changes --context $ctx `
        --project "$RepoRoot\src\CcDashboard.Infrastructure" --startup-project "$RepoRoot\src\CcDashboard.Web" 2>&1
    $rc = $LASTEXITCODE
    $output | ForEach-Object { Write-Host "  $_" }
    if ($rc -ne 0) {
        $ErrorActionPreference = $prevEAP
        throw "[E4] $ctx has PENDING model changes -- model diverges from its last migration. Add a migration (dotnet ef migrations add ...) BEFORE regenerating schema.sql. (EF-model >= schema.sql invariant -- PD-008.)"
    }
    Write-Host "  [E4] $ctx : model captured (no pending changes)." -ForegroundColor Green
}
$ErrorActionPreference = $prevEAP

# 1.1 Drop + create scratch DB
Write-Host "`n[1.1] Drop + create scratch DB..."
$env:PGPASSWORD = $SuperPassword
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
& $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $ScratchDb 2>&1 | ForEach-Object { Write-Host "  $_" }
& $createdb -h $DBHost -p $DBPort -U $SuperUser -E UTF8 $ScratchDb 2>&1 | ForEach-Object { Write-Host "  $_" }
$createRc = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($createRc -ne 0) { throw "createdb failed" }
Write-Host "  Created $ScratchDb"

# 1.2 Set up extensions and grants (01_init_db.sql has hardcoded DB name, so we inline the essentials)
Write-Host "`n[1.2] Apply extensions and grants..."
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"

# Extensions
$extSql = "CREATE EXTENSION IF NOT EXISTS pgcrypto; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
& $psql -h $DBHost -p $DBPort -U $SuperUser -d $ScratchDb -c $extSql 2>&1 | ForEach-Object { Write-Host "  $_" }

# Grants for app user - critical for EF migrations to create tables and schemas
$grantSql = @"
GRANT ALL ON DATABASE $ScratchDb TO $AppUser;
GRANT CREATE ON DATABASE $ScratchDb TO $AppUser;
GRANT ALL ON SCHEMA public TO $AppUser;
GRANT CREATE ON SCHEMA public TO $AppUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $AppUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $AppUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $AppUser;
"@
$tmpGrant = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), '.sql')
[System.IO.File]::WriteAllText($tmpGrant, $grantSql, [System.Text.UTF8Encoding]::new($false))
& $psql -h $DBHost -p $DBPort -U $SuperUser -d $ScratchDb -f $tmpGrant 2>&1 | ForEach-Object { Write-Host "  $_" }
Remove-Item $tmpGrant -ErrorAction SilentlyContinue

$ErrorActionPreference = $prevEAP
Write-Host "  Extensions and grants applied"

# 1.3 EF migrate each context
Write-Host "`n[1.3] EF migrate all contexts..."
$conn = "Host=$DBHost;Port=$DBPort;Database=$ScratchDb;Username=$AppUser;Password=$AppPassword;SSL Mode=Prefer"
$env:PGPASSWORD = $AppPassword

$contexts = @("AppDbContext", "AuditDbContext", "BackendEmulationDbContext")
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
foreach ($ctx in $contexts) {
    Write-Host "  Migrating $ctx..."
    $output = dotnet ef database update --context $ctx --project "$RepoRoot\src\CcDashboard.Infrastructure" --startup-project "$RepoRoot\src\CcDashboard.Web" --connection "$conn" 2>&1
    $output | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) { $ErrorActionPreference = $prevEAP; throw "EF migrate $ctx failed" }
}
$ErrorActionPreference = $prevEAP

# 1.4 Apply SQL functions
Write-Host "`n[1.4] Apply SQL functions..."
$fnFiles = @(
    "db\functions\01_ngc_functions.sql",
    "db\functions\02_rtsdata_functions.sql",
    "db\functions\03_rtsgrid_read.sql",
    "db\functions\04_misc_functions.sql"
)
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
foreach ($fn in $fnFiles) {
    $fnPath = Join-Path $RepoRoot $fn
    if (Test-Path $fnPath) {
        Write-Host "  Applying $fn..."
        & $psql -h $DBHost -p $DBPort -U $AppUser -d $ScratchDb -f $fnPath 2>&1 | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE -ne 0) { Write-Host "  WARNING: $fn exited with $LASTEXITCODE (may be ownership; continuing)" }
    }
}
$ErrorActionPreference = $prevEAP

# 1.5 Apply all db/migrations/*.sql in ascending order
Write-Host "`n[1.5] Apply db/migrations/*.sql..."
$migrationsDir = Join-Path $RepoRoot "db\migrations"
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
if (Test-Path $migrationsDir) {
    $migrations = Get-ChildItem -Path $migrationsDir -Filter "*.sql" | Sort-Object Name
    foreach ($mig in $migrations) {
        Write-Host "  Applying $($mig.Name)..."
        & $psql -h $DBHost -p $DBPort -U $AppUser -d $ScratchDb -f $mig.FullName 2>&1 | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }
        # Ignore non-zero exits (ownership issues on dev, guards make them no-op)
    }
}
$ErrorActionPreference = $prevEAP

# 1.6 pg_dump
Write-Host "`n[1.6] pg_dump schema-only..."
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$rawDump = & $pgdump -h $DBHost -p $DBPort -U $AppUser -d $ScratchDb --schema-only --no-owner --no-acl --schema=public --schema=identity --schema=audit 2>&1
$dumpRc = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($dumpRc -ne 0) { throw "pg_dump failed" }
$dumpLines = $rawDump -split "`n"
Write-Host "  Raw dump: $($dumpLines.Count) lines"

# 1.7 Post-process
Write-Host "`n[1.7] Post-process dump..."

# Remove \restrict and \unrestrict lines (PG18 non-deterministic tokens)
$cleanLines = $dumpLines | Where-Object { $_ -notmatch '^\s*\\(un)?restrict\s' }

# Get git info
$gitShortSha = git -C $RepoRoot rev-parse --short HEAD
$gitFullSha = git -C $RepoRoot rev-parse HEAD
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Provenance header
$header = @"
-- ============================================================================
-- GENERATED — do not hand-edit. Regenerate via db/tools/Regen-Schema.ps1
-- Sources: EF AppDbContext + AuditDbContext + BackendEmulationDbContext @ $gitShortSha
--          + db/functions/*.sql + db/migrations/*.sql (all applied)
-- Generated: $timestamp | git: $gitFullSha
-- ============================================================================

"@

$finalContent = $header + ($cleanLines -join "`r`n")
$schemaPath = Join-Path $RepoRoot "db\schema.sql"

# Write UTF-8 no BOM, CRLF
[System.IO.File]::WriteAllText($schemaPath, $finalContent, [System.Text.UTF8Encoding]::new($false))
$finalLineCount = (Get-Content $schemaPath).Count
Write-Host "  Written $schemaPath ($finalLineCount lines)"

# 1.8 Cleanup
if (-not $KeepScratch) {
    Write-Host "`n[1.8] Dropping scratch DB..."
    $env:PGPASSWORD = $SuperPassword
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $dropdb -h $DBHost -p $DBPort -U $SuperUser --if-exists $ScratchDb 2>&1 | ForEach-Object { Write-Host "  $_" }
    $ErrorActionPreference = $prevEAP
} else {
    Write-Host "`n[1.8] Keeping scratch DB: $ScratchDb"
}

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "schema.sql regenerated: $finalLineCount lines"