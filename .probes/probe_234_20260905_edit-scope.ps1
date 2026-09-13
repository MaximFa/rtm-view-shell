#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / edit-scope  -  READ ONLY
#  WHERE IT RUNS : server 234, database rtmviewdb @ 127.0.0.1:5433 (PG18, live)
#  WRITES        : nothing. Output file only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PURPOSE       : the FULL scope of a future edit, in ONE document -
#                  every cell and every widget config that still names a retired metric.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OutDir = "C:\RTMView-Ops\output"
$cfg    = "C:\RTMView\Shell\appsettings.json"
$server = "234"
$topic  = "edit-scope"

Write-Host "WHERE IT RUNS : server $server, db rtmviewdb @ 127.0.0.1:5433, READ ONLY"

$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
if ($psqlExe.Count -ne 1 -or -not (Test-Path $cfg)) {
    Write-Host "STOP: psql matches=$($psqlExe.Count), config exists=$(Test-Path $cfg). Nothing was run."
    exit 1
}
$psql = $psqlExe[0].FullName
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$txt = [IO.File]::ReadAllText($cfg)
$pw  = ([regex]::Match($txt,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr = ([regex]::Match($txt,'Username\s*=\s*([^";]+)')).Groups[1].Value
if ($pw.Length -eq 0) { Write-Host "STOP: password not found in $cfg. Nothing was run."; exit 1 }
Write-Host ("user          : {0}  (password length {1}, never printed)" -f $usr, $pw.Length)

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$sqlf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).sql"
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"

$sql = @'
\qecho ===== E0 NEGATIVE CONTROLS - all MUST be zero/false =====
SELECT 'cells naming ZZZ_NO_SUCH' AS probe, count(*)::text AS result FROM "RTSGrid_Cell" WHERE "Value" = 'ZZZ_NO_SUCH_METRIC'
UNION ALL
SELECT 'widget configs naming ZZZ_NO_SUCH', count(*)::text FROM dashboard_widgets WHERE "ConfigJson"::text LIKE '%ZZZ_NO_SUCH_METRIC%'
UNION ALL
SELECT 'replacement metric ZZZ exists', (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId"='ZZZ_NO_SUCH_METRIC'))::text
UNION ALL
SELECT 'control - cells naming the LIVE replacement (proves the predicate can find)',
       count(*)::text FROM "RTSGrid_Cell" WHERE "Value" = 'QueueLoginDataNumLoggedUsers';

\qecho ===== E1 THE NINE CELLS - every field, named one by one =====
SELECT c.*, r."GridId", r."RowNumber", g."Title" AS grid_title
FROM "RTSGrid_Cell" c
JOIN "RTSGrid_Row"  r ON r."RowId"  = c."RowId"
JOIN "RTSGrid_Grid" g ON g."GridId" = r."GridId"
WHERE c."Value" = 'QueueNumberOfLoggedAgents'
ORDER BY r."GridId", r."RowNumber", c."ColumnId";

\qecho -- the same, counted per grid, so the total is checkable against 9
SELECT r."GridId", count(*) AS cells
FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId"
WHERE c."Value" = 'QueueNumberOfLoggedAgents'
GROUP BY r."GridId" ORDER BY r."GridId";

\qecho ===== E2 STRUCTURE of dashboard_widgets and any dashboard-ish table =====
SELECT table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN ('dashboard_widgets','dashboards')
ORDER BY table_name, ordinal_position;

\qecho ===== E3 THE ONE WIDGET CONFIG - the row itself =====
SELECT * FROM dashboard_widgets w
WHERE w."ConfigJson"::text LIKE '%QueueNumberOfLoggedAgents%';

\qecho -- its ConfigJson, readable
SELECT jsonb_pretty(w."ConfigJson") AS config
FROM dashboard_widgets w WHERE w."ConfigJson"::text LIKE '%QueueNumberOfLoggedAgents%';

\qecho -- WHERE inside the JSON the name sits: every path whose leaf equals the retired name
SELECT w."Id" AS widget_id, p.path, p.value
FROM dashboard_widgets w,
     LATERAL (SELECT string_agg(k::text,' -> ') AS path, v AS value
              FROM jsonb_each(w."ConfigJson") AS t(k,v)
              WHERE v::text LIKE '%QueueNumberOfLoggedAgents%'
              GROUP BY v) p
WHERE w."ConfigJson"::text LIKE '%QueueNumberOfLoggedAgents%';

\qecho ===== E4 THE REPLACEMENT IN THE CATALOGUE - and its translations =====
SELECT "MetricId", "DisplayName", "MetricFunction", "MetricParameter", "CatalogStatus", "MetricType"
FROM "RTSGrid_Metric" WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers';

SELECT "MetricId", "Locale", "DisplayName", "ShortDescription"
FROM "RTSGrid_MetricTranslation" WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers' ORDER BY "Locale";

\qecho -- translations counted, so "no translation" is a printed zero and not an empty screen
SELECT count(*) AS translation_rows_for_replacement
FROM "RTSGrid_MetricTranslation" WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers';

\qecho ===== E5 COVERAGE - ALL SIX retired names, cells and configs, zeros printed =====
SELECT n.old_name,
       (SELECT count(*) FROM "RTSGrid_Cell" c WHERE c."Value" = n.old_name) AS cells,
       coalesce((SELECT string_agg(DISTINCT r."GridId"::text, ',' ORDER BY r."GridId"::text)
                 FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId"
                 WHERE c."Value" = n.old_name),'-') AS grids,
       (SELECT count(*) FROM dashboard_widgets w WHERE w."ConfigJson"::text LIKE '%'||n.old_name||'%') AS widget_configs,
       (SELECT count(*) FROM "RTSGrid_MetricTranslation" t WHERE t."MetricId" = n.old_name) AS stale_translations
FROM (VALUES
 ('QueueNumAbandonefCalls'),('QueueNumAbandonefCallbacks'),('QueueNumAcceptedCallbacks'),
 ('QueueNumberOfLoggedAgents'),('QueueNumOnCallAgents'),('QueuePctAnsweredCalls60secIncLast30min')
) AS n(old_name) ORDER BY n.old_name;

\qecho ===== END-OF-RUN MARKER: EDIT-SCOPE-COMPLETE =====
'@

[IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
$env:PGPASSWORD = $pw
& $psql -h 127.0.0.1 -p 5433 -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -f $sqlf -o $outf 2> $errf
$rc = $LASTEXITCODE
$env:PGPASSWORD = $null

$content = ""
if (Test-Path $outf) { $content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8) }
$errSize = 0; if (Test-Path $errf) { $errSize = (Get-Item $errf).Length }
$marker  = $content.Contains('EDIT-SCOPE-COMPLETE')
$errOut  = ([regex]::Matches($content,'\bERROR\b')).Count

Write-Host ""
Write-Host "psql exit     : $rc      (must be 0)"
Write-Host "stderr size   : $errSize bytes   (must be 0 - GATE CONDITION)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "ERROR in out  : $errOut  (must be 0)"
Write-Host ""
if ($rc -eq 0 -and $errSize -eq 0 -and $marker -and $errOut -eq 0) { Write-Host "GATE: PASS - measurement is valid" }
else { Write-Host "GATE: FAIL - do NOT read the numbers as a result" }
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
