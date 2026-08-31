#Requires -Version 5.1
<#  R1b - re-restore the copy PRESERVING ownership and privileges (the first pass used
    --no-owner --no-privileges, which made postgres the owner of everything and would have
    invalidated both the migrate step and the SEAM-4 ownership/GRANT check).
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Stop"
$pg  = "C:\Program Files\PostgreSQL\18\bin"
$dmp = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

Write-Host "===== 1. roles present on DEV =====" -ForegroundColor Cyan
& "$pg\psql.exe" -U postgres -d postgres -c "\du"

Write-Host "===== 2. owners recorded INSIDE the dump (first 15 distinct) =====" -ForegroundColor Cyan
& "$pg\pg_restore.exe" --list $dmp | Select-String -Pattern "^\d+;.*(TABLE|SCHEMA) " |
    ForEach-Object { ($_ -split "\s+")[-1] } | Sort-Object -Unique | Select-Object -First 15

Write-Host "===== 3. re-restore WITH ownership/privileges =====" -ForegroundColor Cyan
& "$pg\dropdb.exe"   -U postgres --if-exists rtmviewdb_reh
& "$pg\createdb.exe" -U postgres -E UTF8 rtmviewdb_reh
& "$pg\pg_restore.exe" -U postgres -d rtmviewdb_reh $dmp 2>&1 |
    Select-String -Pattern "error" | Select-Object -First 25
Write-Host "restore finished (errors above, if any)"

$sql = @"
\echo === owners after restore (should NOT be postgres for app objects) ===
SELECT tableowner, count(*) AS tables FROM pg_tables
 WHERE schemaname IN ('public','identity','audit') GROUP BY 1 ORDER BY 2 DESC;
\echo === privileges of ccdashboard_user ===
SELECT has_schema_privilege('ccdashboard_user','public','USAGE')  AS public_usage,
       has_table_privilege('ccdashboard_user','public."NGC_BusinessUnit"','SELECT,INSERT,UPDATE,DELETE') AS ngc_bu_crud;
\echo === counts re-verified after the second restore ===
SELECT 'NGC_BusinessUnit' t, count(*) n FROM "NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Queues', count(*) FROM "NGC_Queues"
UNION ALL SELECT 'NGC_UserAgentgroup', count(*) FROM "NGC_UserAgentgroup"
UNION ALL SELECT 'RTSGrid_Cell', count(*) FROM "RTSGrid_Cell"
UNION ALL SELECT 'RTSData_UserStatusLog', count(*) FROM "RTSData_UserStatusLog"
ORDER BY 1;
\echo === App ledger tip (public.__ef_migrations_history, confirmed by code) ===
SELECT count(*) AS rows FROM public.__ef_migrations_history;
SELECT "MigrationId" FROM public.__ef_migrations_history ORDER BY 1 DESC LIMIT 1;
"@
$f = Join-Path $env:TEMP "r1b_query.sql"
[System.IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f
$env:PGPASSWORD = ""
Write-Host "===== R1b done ====="
