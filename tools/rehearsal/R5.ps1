#Requires -Version 5.1
<#  R5 - schema.sql (BE-owned tables) + ownership transfer, then verify BOTH layers (SEAM-4).
    Ownership block is REUSED VERBATIM from db/tools/Provision-FreshDb.ps1 (step 4), not reinvented.
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Stop"
$pg  = "C:\Program Files\PostgreSQL\18\bin"
$pkg = "D:\RTMView-Ops\rehearsal\pkg"
$db  = "rtmviewdb_reh"

$schema = Get-ChildItem $pkg -Recurse -Filter schema.sql | Select-Object -First 1
if (-not $schema) { Write-Host "STOP: schema.sql not found inside the package" -ForegroundColor Red; exit 1 }
Write-Host ("schema.sql: {0} ({1} bytes)" -f $schema.FullName, $schema.Length)

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

Write-Host "===== apply schema.sql as superuser =====" -ForegroundColor Cyan
& "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -f $schema.FullName 2>&1 |
    Select-String -Pattern "ERROR|FATAL" | Select-Object -First 25
Write-Host ("psql exit: {0}" -f $LASTEXITCODE)

Write-Host "===== ownership transfer (verbatim from Provision-FreshDb step 4) =====" -ForegroundColor Cyan
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
$t1 = Join-Path $env:TEMP "r5_owner.sql"
[System.IO.File]::WriteAllText($t1, $ownerSql, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -f $t1
Write-Host ("ownership exit: {0}" -f $LASTEXITCODE)

$verify = @"
\echo === SEAM-4 layer 1: OWNERSHIP - expect a single row, ccdashboard_user ===
SELECT tableowner, count(*) AS tables FROM pg_tables
 WHERE schemaname IN ('public','identity','audit') GROUP BY 1 ORDER BY 2 DESC;
\echo === SEAM-4 layer 2: PRIVILEGES of ccdashboard_user (separate layer, neither implies the other) ===
SELECT has_schema_privilege('ccdashboard_user','public','USAGE') AS public_usage;
SELECT count(*) AS tables_without_full_crud FROM information_schema.tables t
 WHERE t.table_schema='public' AND t.table_type='BASE TABLE'
   AND NOT has_table_privilege('ccdashboard_user', format('public.%I', t.table_name), 'SELECT,INSERT,UPDATE,DELETE');
\echo === backend tables recreated EMPTY by schema.sql - expect 9 NGC, 8 RTSGrid-family, 4 RTSData ===
SELECT count(*) FILTER (WHERE table_name LIKE 'NGC!_%' ESCAPE '!')      AS ngc,
       count(*) FILTER (WHERE table_name LIKE 'RTSGrid!_%' ESCAPE '!')  AS rtsgrid,
       count(*) FILTER (WHERE table_name LIKE 'RTSUserGrid!_%' ESCAPE '!') AS rtsusergrid,
       count(*) FILTER (WHERE table_name LIKE 'RTSData!_%' ESCAPE '!')  AS rtsdata
  FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';
\echo === and they must be EMPTY at this point (data comes in R6) ===
SELECT (SELECT count(*) FROM "NGC_BusinessUnit") AS bu_rows,
       (SELECT count(*) FROM "RTSGrid_Cell")     AS cell_rows;
"@
$t2 = Join-Path $env:TEMP "r5_verify.sql"
[System.IO.File]::WriteAllText($t2, $verify, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -f $t2
$env:PGPASSWORD = ""
Write-Host "===== R5 done ====="
