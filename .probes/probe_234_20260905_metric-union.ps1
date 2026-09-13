#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / metric-union  -  READ ONLY
#  WHERE IT RUNS : server 234, database rtmviewdb on port 5433 (PostgreSQL 18)
#  WRITES        : nothing to the database. Output files only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OpsRoot = "C:\RTMView-Ops"
$OutDir  = Join-Path $OpsRoot "output"
$cfg     = "C:\RTMView\Shell\appsettings.json"
$server  = "234"
$topic   = "metric-union"

Write-Host "WHERE IT RUNS : server $server, db rtmviewdb @ 127.0.0.1:5433, READ ONLY"

$psql = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
$ready = ($psql.Count -eq 1) -and (Test-Path $cfg)
if (-not $ready) {
    Write-Host "STOP: psql matches=$($psql.Count), config exists=$(Test-Path $cfg). Nothing was run."
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$txt = [IO.File]::ReadAllText($cfg)
$pw  = ([regex]::Match($txt,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr = ([regex]::Match($txt,'Username\s*=\s*([^";]+)')).Groups[1].Value
if ($pw.Length -eq 0) { Write-Host "STOP: password not found in $cfg. Nothing was run."; exit 1 }
Write-Host ("user          : {0}" -f $usr)
Write-Host ("password      : length={0} (value never printed)" -f $pw.Length)

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$sqlf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).sql"
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"

$sql = @'
\qecho ===== H0 NEGATIVE CONTROLS FIRST - all MUST be zero/false =====
SELECT 'rows of GridId 99999' AS probe, count(*)::text AS result FROM "RTSGrid_Row" WHERE "GridId"=99999
UNION ALL
SELECT 'metric ZZZ_NO_SUCH exists',
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" m, jsonb_each_text(to_jsonb(m)) kv
                WHERE kv.value = 'ZZZ_NO_SUCH_METRIC'))::text
UNION ALL
SELECT 'RTSGrid_Metric total rows', count(*)::text FROM "RTSGrid_Metric";

\qecho ===== H1 STRUCTURE - metric catalogue and every table carrying a UnionId =====
SELECT table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='RTSGrid_Metric'
ORDER BY ordinal_position;

\qecho -- every table with a UnionId column, plus anything named like a union
SELECT table_name, column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND (column_name = 'UnionId' OR table_name ILIKE '%union%')
ORDER BY table_name, column_name;

\qecho ===== H2 IS QueueNumberOfLoggedAgents IN THE CATALOGUE AT ALL =====
SELECT * FROM "RTSGrid_Metric" m
WHERE EXISTS (SELECT 1 FROM jsonb_each_text(to_jsonb(m)) kv WHERE kv.value = 'QueueNumberOfLoggedAgents');

\qecho -- plain yes/no, so an empty result above is not read as "the query failed"
SELECT (EXISTS (SELECT 1 FROM "RTSGrid_Metric" m, jsonb_each_text(to_jsonb(m)) kv
                WHERE kv.value = 'QueueNumberOfLoggedAgents')) AS logged_agents_metric_exists;

\qecho ===== H3 ALL TWELVE METRIC NAMES OF ROW 316 vs THE CATALOGUE - found AND not-found =====
\qecho -- matched by VALUE across every catalogue column, so no column name is guessed
SELECT c."ColumnId", c."Value" AS metric_name,
       EXISTS (SELECT 1 FROM "RTSGrid_Metric" m, jsonb_each_text(to_jsonb(m)) kv
               WHERE kv.value = c."Value") AS in_catalogue
FROM "RTSGrid_Cell" c WHERE c."RowId" = 316 ORDER BY c."ColumnId";

SELECT in_catalogue, count(*) AS metrics FROM (
  SELECT EXISTS (SELECT 1 FROM "RTSGrid_Metric" m, jsonb_each_text(to_jsonb(m)) kv
                 WHERE kv.value = c."Value") AS in_catalogue
  FROM "RTSGrid_Cell" c WHERE c."RowId" = 316
) q GROUP BY in_catalogue ORDER BY in_catalogue;

\qecho ===== H4 DO GridId AND UnionId LIVE IN THE SAME NUMBER RANGE =====
SELECT 'GridId  (RTSGrid_Grid)' AS id_kind, min("GridId") AS min_id, max("GridId") AS max_id, count(*) AS n
FROM "RTSGrid_Grid"
UNION ALL
SELECT 'UnionId (RTSGrid_Row, distinct, excl. -1 header marker)',
       min("UnionId"), max("UnionId"), count(DISTINCT "UnionId")
FROM "RTSGrid_Row" WHERE "UnionId" <> -1;

\qecho -- the actual overlap: union ids that are ALSO valid grid ids
SELECT DISTINCT r."UnionId" AS id_used_as_both
FROM "RTSGrid_Row" r
WHERE r."UnionId" <> -1
  AND EXISTS (SELECT 1 FROM "RTSGrid_Grid" g WHERE g."GridId" = r."UnionId")
ORDER BY 1;

\qecho ===== H5 THE DEFECT UNIONS 74/75/76/78 - which grids own rows carrying them =====
SELECT r."UnionId", r."GridId", r."RowId", r."RowNumber", g."Title"
FROM "RTSGrid_Row" r LEFT JOIN "RTSGrid_Grid" g ON g."GridId" = r."GridId"
WHERE r."UnionId" IN (74,75,76,78) ORDER BY r."UnionId", r."GridId", r."RowNumber";

\qecho ===== END-OF-RUN MARKER: METRIC-UNION-COMPLETE =====
'@

[IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))

$env:PGPASSWORD = $pw
& $psql[0].FullName -h 127.0.0.1 -p 5433 -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -f $sqlf -o $outf 2> $errf
$rc = $LASTEXITCODE
$env:PGPASSWORD = $null

$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$errSize = (Get-Item $errf).Length
$marker  = $content.Contains('METRIC-UNION-COMPLETE')
$errOut  = ([regex]::Matches($content,'\bERROR\b')).Count

Write-Host ""
Write-Host "psql exit     : $rc      (must be 0)"
Write-Host "stderr size   : $errSize bytes   (must be 0 - GATE CONDITION)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "ERROR in out  : $errOut  (must be 0)"
Write-Host ""
if ($rc -eq 0 -and $errSize -eq 0 -and $marker -and $errOut -eq 0) {
    Write-Host "GATE: PASS - measurement is valid"
} else {
    Write-Host "GATE: FAIL - do NOT read the numbers as a result"
}
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
