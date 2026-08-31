#Requires -Version 5.1
<#  R5a + R5b + R5c - the DB product layer, in the canonical order:
      functions (all 4) -> data (02 + 05 ONLY) -> db/migrations (3 named files)
    03_rtsgrid.sql and 04_catalog.sql are NEVER applied here: they TRUNCATE the transfer set
    (04 truncates NGC_Site CASCADE -> wipes NGC_BusinessUnit and the whole human composition).
    Also re-runs the SEAM-4 privilege check by OID (the previous name-based query was wrong).
    Authored by devops-0829, 2026-08-29.
#>
# NOTE: NOT "Stop": psql writes NOTICE to stderr, and under Stop PowerShell turns any native
# stderr line into a terminating error. Success is judged by $LASTEXITCODE, not by stderr being empty.
$ErrorActionPreference = "Continue"
$pg   = "C:\Program Files\PostgreSQL\18\bin"
$pkg  = "D:\RTMView-Ops\rehearsal\pkg"
$repo = "D:\Claude\Projects\RTM View Shell"
$db   = "rtmviewdb_reh"

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

function Apply-Sql([string]$path, [string]$label) {
    if (-not (Test-Path $path)) { Write-Host "MISSING: $label -> $path" -ForegroundColor Red; return $false }
    Write-Host ("--- {0} : {1}" -f $label, (Split-Path $path -Leaf)) -ForegroundColor Cyan
    & "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -f $path 2>&1 |
        Select-String -Pattern "ERROR|FATAL" | Select-Object -First 10
    Write-Host ("    exit {0}" -f $LASTEXITCODE)
    return ($LASTEXITCODE -eq 0)
}

# --- R5a FUNCTIONS: prefer the package copy, fall back to the repo (same tree: db/ on v3 == d1982de)
$fnDir = Join-Path $pkg "DB\functions"
if (-not (Test-Path $fnDir)) { $fnDir = Join-Path $repo "db\functions" }
Write-Host ("===== R5a FUNCTIONS from {0} =====" -f $fnDir) -ForegroundColor Yellow
$ok = $true
foreach ($n in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    if (-not (Apply-Sql (Join-Path $fnDir $n) "functions")) { $ok = $false }
}

# --- R5b DATA: 02 and 05 ONLY
$dataDir = Join-Path $pkg "DB\data"
if (-not (Test-Path $dataDir)) { $dataDir = Join-Path $repo "db\data" }
Write-Host ("===== R5b DATA (02 + 05 ONLY) from {0} =====" -f $dataDir) -ForegroundColor Yellow
Write-Host "    03_rtsgrid.sql and 04_catalog.sql deliberately NOT applied (they truncate the transfer set)"
foreach ($n in @("02_metrics.sql","05_metric_translations.sql")) {
    if (-not (Apply-Sql (Join-Path $dataDir $n) "data")) { $ok = $false }
}

# --- R5c DB MIGRATIONS: the three named files
$migDir = Join-Path $repo "db\migrations"
Write-Host "===== R5c DB MIGRATIONS (3 named files) =====" -ForegroundColor Yellow
foreach ($n in @("20260713_001_add_completed_incoming_calls.sql","20260721_001_wfm_indexes.sql")) {
    if (-not (Apply-Sql (Join-Path $migDir $n) "db-migration")) { $ok = $false }
}
Write-Host "--- arch_contour_indexes uses CREATE INDEX CONCURRENTLY: must NOT run inside a transaction ---"
& "$pg\psql.exe" -U postgres -d $db -f (Join-Path $migDir "20260622_001_arch_contour_indexes.sql") 2>&1 |
    Select-String -Pattern "ERROR|FATAL" | Select-Object -First 10
Write-Host ("    exit {0}" -f $LASTEXITCODE)

$verify = @"
\echo === routines present after the functions layer ===
SELECT count(*) FILTER (WHERE prokind='f') AS functions, count(*) FILTER (WHERE prokind='p') AS procedures
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
\echo === the two PROCEDUREs that must stay procedures (RTM-SEC-002 CALL) ===
SELECT proname, prokind FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND proname IN ('NGC_SetUserAgentgroup','NGC_DeleteUserAgentgroup') ORDER BY 1;
\echo === metric seed: baseline metrics loaded, and the client-parity metric present ===
SELECT count(*) AS metrics FROM "RTSGrid_Metric";
SELECT count(*) AS completed_incoming FROM "RTSGrid_Metric" WHERE "MetricId"='QueueNumberOfCompletedIncomingCalls';
SELECT count(*) AS translations FROM "RTSGrid_MetricTranslation";
\echo === WFM indexes (83ce56b) - NOT in schema.sql, only from db/migrations - expect 3 ===
SELECT indexname FROM pg_indexes
 WHERE indexname IN ('ix_rtsint_wfm_inq','ix_rtsint_wfm_ans','ix_rtsus_wfm') ORDER BY 1;
\echo === transfer-set tables MUST still be empty (03/04 were not applied) ===
SELECT (SELECT count(*) FROM "RTSGrid_Grid") AS grids, (SELECT count(*) FROM "NGC_Site") AS sites,
       (SELECT count(*) FROM "NGC_BusinessUnit") AS bus;
\echo === SEAM-4 privileges, re-done BY OID (schema cannot drift from name) - expect 0 ===
SELECT count(*) AS tables_without_full_crud
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r'
   AND NOT has_table_privilege('ccdashboard_user', c.oid, 'SELECT,INSERT,UPDATE,DELETE');
\echo === diagnostic: where does audit_logs actually live ===
SELECT n.nspname, c.relname, c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relname='audit_logs';
"@
$f = Join-Path $env:TEMP "r5abc_verify.sql"
[System.IO.File]::WriteAllText($f, $verify, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -f $f
$env:PGPASSWORD = ""
Write-Host ("===== R5a/b/c done (all applies clean: {0}) =====" -f $ok)
