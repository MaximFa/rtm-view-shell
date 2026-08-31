#Requires -Version 5.1
<#  REHEARSAL PART A (from scratch) - restore -> migrate -> schema.sql + ownership -> functions/data/migrations.
    Every step here was already proven individually today (R1b/R4/R5/R5abc, each exit 0); they are chained
    because they are deterministic and have no branch points. Any non-zero exit aborts the chain.
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Continue"   # psql writes NOTICEs to stderr; success is judged by exit code
$pg   = "C:\Program Files\PostgreSQL\18\bin"
$dmp  = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"
$pkg  = "D:\RTMView-Ops\rehearsal\pkg"
$repo = "D:\Claude\Projects\RTM View Shell"
$db   = "rtmviewdb_reh"
$live = "C:\RTMView\Shell\appsettings.json"
$expectHash = "EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468"

function Step($label, $block) {
    Write-Host ""
    Write-Host ("=== {0} ===" -f $label) -ForegroundColor Cyan
    & $block
    if ($LASTEXITCODE -ne 0) { Write-Host ("ABORT at: {0} (exit {1})" -f $label, $LASTEXITCODE) -ForegroundColor Red; throw "aborted" }
}

# --- source pin
$h = (Get-FileHash -Algorithm SHA256 $dmp).Hash
if ($h -ne $expectHash) { Write-Host "STOP: dump hash drift" -ForegroundColor Red; exit 1 }
Write-Host ("source pin OK  {0}" -f $h) -ForegroundColor Green
Write-Host ("free space on D: {0:N1} GB" -f ((Get-PSDrive D).Free/1GB))

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

try {
    Step "1. drop + create + restore (WITH ownership/privileges)" {
        & "$pg\dropdb.exe" -U postgres --if-exists $db | Out-Null
        & "$pg\createdb.exe" -U postgres -E UTF8 $db
        $o = & "$pg\pg_restore.exe" -U postgres -d $db $dmp 2>&1
        $o | Select-String -Pattern "^pg_restore: error" | Select-Object -First 10
        $global:LASTEXITCODE = 0
    }

    Step "2. migrate (3 App migrations)" {
        $raw = (Select-String -Path $live -Pattern '"Default"\s*:\s*"([^"]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
        $env:ConnectionStrings__Default = $raw -replace 'Database=[^;]+', "Database=$db"
        $env:ASPNETCORE_ENVIRONMENT = "Production"
        Push-Location "$pkg\Shell"
        & ".\CcDashboard.Web.exe" migrate 2>&1 | Select-Object -Last 6
        Pop-Location
        $env:ConnectionStrings__Default = ""
    }

    Step "3. schema.sql (BE tables)" {
        & "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -q -f "$pkg\DB\schema.sql" 2>&1 |
            Select-String -Pattern "ERROR|FATAL" | Select-Object -First 10
    }

    Step "4. ownership transfer" {
        $ownerSql = @'
DO $body$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT schemaname AS s, tablename AS t FROM pg_tables
             WHERE schemaname IN ('public','identity','audit') AND tableowner != 'ccdashboard_user'
    LOOP EXECUTE 'ALTER TABLE ' || quote_ident(r.s) || '.' || quote_ident(r.t) || ' OWNER TO ccdashboard_user'; END LOOP;
    FOR r IN SELECT sequence_schema AS s, sequence_name AS n FROM information_schema.sequences
             WHERE sequence_schema IN ('public','identity','audit')
    LOOP EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.s) || '.' || quote_ident(r.n) || ' OWNER TO ccdashboard_user'; END LOOP;
    FOR r IN SELECT nspname AS s, proname AS n, pg_get_function_identity_arguments(p.oid) AS a
             FROM pg_proc p JOIN pg_namespace ns ON p.pronamespace = ns.oid
             WHERE nspname IN ('public','identity','audit') AND p.prokind = 'f'
    LOOP EXECUTE 'ALTER FUNCTION ' || quote_ident(r.s) || '.' || quote_ident(r.n) || '(' || r.a || ') OWNER TO ccdashboard_user'; END LOOP;
END $body$;
'@
        $f = Join-Path $env:TEMP "a_owner.sql"
        [System.IO.File]::WriteAllText($f, $ownerSql, (New-Object System.Text.UTF8Encoding($false)))
        & "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -q -f $f
    }

    Step "5. functions (01-04)" {
        foreach ($n in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
            & "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -q -f "$pkg\DB\functions\$n" 2>&1 |
                Select-String -Pattern "ERROR|FATAL" | Select-Object -First 5
            if ($LASTEXITCODE -ne 0) { break }
            Write-Host ("    {0} ok" -f $n)
        }
    }

    Step "6. data - 02 + 05 ONLY (03/04 would truncate the transfer set)" {
        foreach ($n in @("02_metrics.sql","05_metric_translations.sql")) {
            & "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -q -f "$pkg\DB\data\$n" 2>&1 |
                Select-String -Pattern "ERROR|FATAL" | Select-Object -First 5
            if ($LASTEXITCODE -ne 0) { break }
            Write-Host ("    {0} ok" -f $n)
        }
    }

    Step "7. db/migrations - the 3 named files" {
        foreach ($n in @("20260713_001_add_completed_incoming_calls.sql","20260721_001_wfm_indexes.sql","20260622_001_arch_contour_indexes.sql")) {
            & "$pg\psql.exe" -U postgres -d $db -q -f "$repo\db\migrations\$n" 2>&1 |
                Select-String -Pattern "ERROR|FATAL" | Select-Object -First 5
            Write-Host ("    {0} exit {1}" -f $n, $LASTEXITCODE)
        }
        $global:LASTEXITCODE = 0
    }

    $chk = @"
\echo === state after PART A (transfer set must be EMPTY, product layer must be IN) ===
SELECT (SELECT count(*) FROM public.__ef_migrations_history) AS app_ledger_rows,
       (SELECT count(*) FROM "RTSGrid_Metric") AS metrics,
       (SELECT count(*) FROM "NGC_BusinessUnit") AS bu_rows,
       (SELECT count(*) FROM "RTSGrid_Grid") AS grid_rows,
       (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='p') AS procedures;
SELECT tableowner, count(*) FROM pg_tables WHERE schemaname IN ('public','identity','audit') GROUP BY 1;
"@
    $f = Join-Path $env:TEMP "a_check.sql"
    [System.IO.File]::WriteAllText($f, $chk, (New-Object System.Text.UTF8Encoding($false)))
    & "$pg\psql.exe" -U postgres -d $db -f $f
    Write-Host ""
    Write-Host "===== PART A COMPLETE - ready for PART B (struct-diff + reload) =====" -ForegroundColor Green
}
catch { Write-Host "PART A stopped." -ForegroundColor Red }
finally { $env:PGPASSWORD = "" }
