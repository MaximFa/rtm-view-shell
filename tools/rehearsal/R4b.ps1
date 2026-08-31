#Requires -Version 5.1
<#  R4b - resolve the two numbers R4 did not settle:
      (a) the CORRECT signature check for WfmTenantSettings (six columns on tenant_settings, not a table)
      (b) which single RTSGrid_* table survived the CASCADE drop, and why
    READ-ONLY. Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Stop"
$pg = "C:\Program Files\PostgreSQL\18\bin"
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

$sql = @"
\echo === (a) WfmTenantSettings = SIX COLUMNS on tenant_settings - expect 6 ===
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_name='tenant_settings' AND column_name LIKE 'Wfm%' ORDER BY 1;
\echo === (b) which RTSGrid_* / RTSUserGrid_* tables still exist ===
SELECT table_schema, table_name FROM information_schema.tables
 WHERE table_name LIKE 'RTS%' ORDER BY 1,2;
\echo === (b2) is the survivor a TABLE or a VIEW, and who owns it ===
SELECT c.relname, c.relkind, pg_get_userbyid(c.relowner) AS owner
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relname LIKE 'RTS%' AND n.nspname='public' ORDER BY 1;
\echo === (b3) row count of the survivor, if it is a table ===
SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE relname LIKE 'RTS%' ORDER BY 1;
\echo === sanity: NGC_* must be zero ===
SELECT count(*) AS ngc_left FROM information_schema.tables
 WHERE table_schema='public' AND table_name LIKE 'NGC!_%' ESCAPE '!';
"@
$f = Join-Path $env:TEMP "r4b_query.sql"
[System.IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f
$env:PGPASSWORD = ""
Write-Host "===== R4b done ====="
