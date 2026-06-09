# Run-Migration004.ps1  (SELF-CONTAINED — copy this single file anywhere and run)
# Adds StatusGroup column to RTSData_UserStatusLog + re-asserts RTSData_SetUserStatus
# (DayTrend agent metrics). PostgreSQL 18. Idempotent.
#
# DDL requires the TABLE OWNER -> run as postgres (RTSData_UserStatusLog is owned by postgres).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File "C:\Temp\run_migration_004.ps1" -DBPassword '<postgres_password>'

param(
    [Parameter(Mandatory=$true)][string]$DBPassword,
    [string]$DBName = "rtmviewdb",
    [string]$DBUser = "postgres",
    [string]$DBHost = "127.0.0.1",
    [int]   $DBPort = 5432
)

$ErrorActionPreference = "Stop"

$PgBin = "C:\Program Files\PostgreSQL\18\bin"
$Psql  = Join-Path $PgBin "psql.exe"
if (-not (Test-Path $Psql)) { throw "psql not found: $Psql" }

# --- migration SQL (embedded) ---
$migrationSql = @'
-- ============================================================================
-- Migration: Add StatusGroup column to RTSData_UserStatusLog
-- Date: 2026-06-06
--
-- Root cause: RTSData_UserStatusLog originally lacked "StatusGroup" column
-- (MSSQL never had it; pgloader migration didn't add it; patch_origin_v2.sql
-- added catalogue columns but NOT this one). The deployed RTSData_SetUserStatus
-- procedure writes StatusGroup into the Log -> INSERT fails on missing column
-- -> Log stays empty -> fn_daytrendagentstatus (filters usl."StatusGroup")
-- returns nothing -> DayTrend Agent Metrics are empty.
--
-- Fix: Add the column + supporting index, then re-assert the procedure so
-- column and writer are consistent.
-- ============================================================================

-- 1. Add StatusGroup column (idempotent)
ALTER TABLE "RTSData_UserStatusLog"
  ADD COLUMN IF NOT EXISTS "StatusGroup" varchar(50);

-- 2. Index definition (copied from db/schema.sql:3525)
CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
  ON "RTSData_UserStatusLog" USING btree ("TenantId", "StatusGroup", "StartTime", "EndTime");

-- ============================================================================
-- 3. Re-assert RTSData_SetUserStatus procedure
--    Copied VERBATIM from db/functions/02_rtsdata_functions.sql section 2
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text, uuid
);
DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, text, text,
    double precision, double precision, integer, text,
    timestamptz, timestamptz, text, timestamptz, uuid
);

CREATE PROCEDURE "RTSData_SetUserStatus"(
    p_user_id        text,
    p_status_id      text,
    p_server_id      text,
    p_on_date        text,
    p_status_name    text,
    p_status_group   text,
    p_total_duration double precision,
    p_max_duration   double precision,
    p_total_count    integer,
    p_display_name   text,
    p_start_time     timestamptz,
    p_end_time       timestamptz,
    p_time_zone      text,
    p_update_time    timestamptz,
    p_tenant_id      uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- (a) Append-only history (powers DayTrend agent metrics). StatusGroup + TenantId
    --     are required by fn_daytrendagentstatus and exist on the PG table.
    IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL
       AND p_end_time > p_start_time THEN
        INSERT INTO "RTSData_UserStatusLog" (
            "TenantId","UserId","StatusId","ServerId","OnDate",
            "StartTime","EndTime","Duration","UpdateTime","TimeZone","StatusGroup"
        )
        VALUES (
            p_tenant_id, p_user_id, p_status_id, p_server_id, p_on_date,
            p_start_time, p_end_time,
            (EXTRACT(EPOCH FROM (p_end_time - p_start_time)) * 1000)::integer,
            p_update_time, p_time_zone, p_status_group
        );
    END IF;

    -- (b) Current-state upsert (unchanged behaviour).
    INSERT INTO "RTSData_UserStatus" (
        "UserId","StatusId","ServerId","OnDate",
        "StatusName","StatusGroup","TotalDuration","MaxDuraction",
        "TotalCount","UpdateTime","DisplayName","TimeZone","TenantId"
    )
    VALUES (
        p_user_id, p_status_id, p_server_id, p_on_date,
        p_status_name, p_status_group, p_total_duration::integer, p_max_duration::integer,
        p_total_count, p_update_time, p_display_name, p_time_zone, p_tenant_id
    )
    ON CONFLICT ("UserId","StatusId","ServerId","OnDate")
    DO UPDATE SET
        "StatusName"    = EXCLUDED."StatusName",
        "StatusGroup"   = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuraction"  = EXCLUDED."MaxDuraction",
        "TotalCount"    = EXCLUDED."TotalCount",
        "UpdateTime"    = EXCLUDED."UpdateTime",
        "DisplayName"   = EXCLUDED."DisplayName",
        "TimeZone"      = EXCLUDED."TimeZone",
        "TenantId"      = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- End of migration
-- ============================================================================
'@

# --- verification SQL (embedded) ---
$verifySql = @'
\d "RTSData_UserStatusLog"
SELECT "StatusGroup", COUNT(*)
FROM "RTSData_UserStatusLog"
WHERE "OnDate" = to_char(current_date,'DD/MM/YYYY')
GROUP BY 1;
'@

$migFile    = Join-Path $env:TEMP "migration_004.sql"
$verifyFile = Join-Path $env:TEMP "verify_004.sql"
# psql chokes on a UTF-8 BOM (Set-Content -Encoding UTF8 adds one in Windows PowerShell 5).
# Write WITHOUT BOM via .NET.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($migFile,    $migrationSql, $utf8NoBom)
[System.IO.File]::WriteAllText($verifyFile, $verifySql,    $utf8NoBom)

$env:PGPASSWORD = $DBPassword
try {
    Write-Host "Applying migration_004 to $DBName@${DBHost}:$DBPort as $DBUser ..." -ForegroundColor Cyan
    & $Psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -v ON_ERROR_STOP=1 -f $migFile
    if ($LASTEXITCODE -ne 0) { throw "psql failed (exit $LASTEXITCODE)" }

    Write-Host "`n=== Verify: column present + today rows by StatusGroup ===" -ForegroundColor Cyan
    & $Psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -f $verifyFile

    Write-Host "`nDone. Migration applied." -ForegroundColor Green
}
finally {
    Remove-Item $migFile, $verifyFile -ErrorAction SilentlyContinue
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
