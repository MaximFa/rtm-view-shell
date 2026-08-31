#Requires -Version 5.1
<#  R4 - apply the 3 pending App migrations to the rehearsal copy, then prove EXACTLY those 3 applied.
    This is the first step that CHANGES the copy: DropAppOwnedBackendTables removes 26 backend tables
    (the data is restored later in R6 from the same dump - the dump is untouched on disk).
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Stop"
$pg       = "C:\Program Files\PostgreSQL\18\bin"
$shellDir = "D:\RTMView-Ops\rehearsal\pkg\Shell"
$live     = "C:\RTMView\Shell\appsettings.json"

if (-not (Test-Path "$shellDir\CcDashboard.Web.exe")) { Write-Host "STOP: migrate exe missing" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $live)) { Write-Host "STOP: cannot read the DEV connection string at $live" -ForegroundColor Red; exit 1 }

# reuse the DEV connection string, swapping ONLY the database name -> no password is typed or echoed
$raw = (Select-String -Path $live -Pattern '"Default"\s*:\s*"([^"]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
$cs  = $raw -replace 'Database=[^;]+', 'Database=rtmviewdb_reh'
if ($cs -notmatch 'Database=rtmviewdb_reh') { Write-Host "STOP: could not retarget the connection string" -ForegroundColor Red; exit 1 }
Write-Host ("connection retargeted -> {0}" -f ($cs -replace 'Password=[^;]*','Password=***'))

$env:ConnectionStrings__Default = $cs
$env:ASPNETCORE_ENVIRONMENT     = "Production"

Write-Host "===== migrate (CWD = Shell dir, lesson 140) =====" -ForegroundColor Cyan
Push-Location $shellDir
& ".\CcDashboard.Web.exe" migrate 2>&1 | Select-Object -Last 40
$code = $LASTEXITCODE
Pop-Location
Write-Host ("migrate exit code: {0}" -f $code)

$env:ConnectionStrings__Default = ""
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

$sql = @"
\echo === App ledger: expect 30 rows (was 27) ===
SELECT count(*) AS ledger_rows FROM public.__ef_migrations_history;
\echo === the 3 expected migrations - each must appear exactly once ===
SELECT "MigrationId" FROM public.__ef_migrations_history
 WHERE "MigrationId" LIKE '%DropAppOwnedBackendTables%'
    OR "MigrationId" LIKE '%PerTenantUserNameIndex%'
    OR "MigrationId" LIKE '%WfmTenantSettings%' ORDER BY 1;
\echo === anything applied BEYOND AddReportEntities that is NOT one of the 3 = STOP ===
SELECT "MigrationId" FROM public.__ef_migrations_history
 WHERE "MigrationId" > '20260624093015_AddReportEntities' ORDER BY 1;
\echo === signature objects AFTER migrate ===
SELECT indexname FROM pg_indexes WHERE schemaname='identity' AND tablename='users' ORDER BY 1;
SELECT indexname, indisunique FROM pg_indexes i
  JOIN pg_class c ON c.relname = i.indexname
  JOIN pg_index x ON x.indexrelid = c.oid
 WHERE i.schemaname='identity' AND i.tablename='users' AND i.indexname='UserNameIndex';
SELECT to_regclass('public."WfmTenantSettings"') AS wfm_tenant_settings;
\echo === backend tables after the CASCADE drop: expect 0 of each (data returns in R6) ===
SELECT count(*) FILTER (WHERE table_name LIKE 'NGC!_%' ESCAPE '!') AS ngc_tables,
       count(*) FILTER (WHERE table_name LIKE 'RTSGrid!_%' ESCAPE '!') AS rtsgrid_tables,
       count(*) FILTER (WHERE table_name LIKE 'RTSData!_%' ESCAPE '!') AS rtsdata_tables
  FROM information_schema.tables WHERE table_schema='public';
"@
$f = Join-Path $env:TEMP "r4_query.sql"
[System.IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f
$env:PGPASSWORD = ""
Write-Host "===== R4 done ====="
