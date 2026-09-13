#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / orphan-cells  -  READ ONLY
#  WHERE IT RUNS : server 234, database rtmviewdb @ 127.0.0.1:5433 (PG18, live)
#  WRITES        : nothing. Output file only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PURPOSE       : close the 7-vs-9 gap. LEFT JOIN, so orphaned cells appear AS ROWS
#                  instead of being silently dropped, and the total is cross-checked
#                  against an independent count that uses no join at all.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OutDir = "C:\RTMView-Ops\output"
$cfg    = "C:\RTMView\Shell\appsettings.json"
$server = "234"
$topic  = "orphan-cells"

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
\qecho ===== O0 THE TWO COUNTS SIDE BY SIDE - they must agree at the end =====
SELECT 'independent count, NO join at all' AS how, count(*)::text AS n
FROM "RTSGrid_Cell" WHERE "Value" = 'QueueNumberOfLoggedAgents'
UNION ALL
SELECT 'rows the LEFT JOIN will print',
       (SELECT count(*)::text FROM "RTSGrid_Cell" c
        LEFT JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId"
        WHERE c."Value" = 'QueueNumberOfLoggedAgents')
UNION ALL
SELECT 'of those, cells whose RowId does NOT resolve',
       (SELECT count(*)::text FROM "RTSGrid_Cell" c
        LEFT JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId"
        WHERE c."Value" = 'QueueNumberOfLoggedAgents' AND r."RowId" IS NULL);

\qecho ===== O1 ALL CELLS, LEFT JOIN - orphans appear AS ROWS with empty parent =====
SELECT c."CellId", c."RowId", c."ColumnId", c."ColNumber", c."CellType", c."StyleId", c."Value",
       r."GridId", r."RowNumber",
       CASE WHEN r."RowId" IS NULL THEN 'ORPHAN - RowId does not resolve' ELSE 'ok' END AS parent_state,
       g."Title" AS grid_title
FROM "RTSGrid_Cell" c
LEFT JOIN "RTSGrid_Row"  r ON r."RowId"  = c."RowId"
LEFT JOIN "RTSGrid_Grid" g ON g."GridId" = r."GridId"
WHERE c."Value" = 'QueueNumberOfLoggedAgents'
ORDER BY (r."RowId" IS NULL) DESC, r."GridId", r."RowNumber", c."CellId";

\qecho ===== O2 THE ORPHANS ALONE, so they cannot be missed in a long list =====
SELECT c."CellId", c."RowId", c."ColumnId", c."CellType", c."StyleId", c."Value"
FROM "RTSGrid_Cell" c
LEFT JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId"
WHERE c."Value" = 'QueueNumberOfLoggedAgents' AND r."RowId" IS NULL
ORDER BY c."CellId";

\qecho ===== O3 CONTEXT - is orphaning specific to this metric or general in this table =====
SELECT 'cells in the whole table' AS scope, count(*)::text AS n FROM "RTSGrid_Cell"
UNION ALL
SELECT 'cells whose RowId does NOT resolve (whole table)',
       (SELECT count(*)::text FROM "RTSGrid_Cell" c
        LEFT JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId" WHERE r."RowId" IS NULL)
UNION ALL
SELECT 'cells whose ColumnId does NOT resolve (whole table)',
       (SELECT count(*)::text FROM "RTSGrid_Cell" c
        LEFT JOIN "RTSGrid_Column" k ON k."ColumnId" = c."ColumnId" WHERE k."ColumnId" IS NULL);

\qecho ===== O4 NEGATIVE CONTROLS =====
SELECT 'cells naming ZZZ_NO_SUCH (must be 0)' AS probe, count(*)::text AS result
FROM "RTSGrid_Cell" WHERE "Value" = 'ZZZ_NO_SUCH_METRIC'
UNION ALL
SELECT 'control - LEFT JOIN on a row that DOES resolve returns non-null parent (must be > 0)',
       (SELECT count(*)::text FROM "RTSGrid_Cell" c
        LEFT JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId"
        WHERE c."Value" = 'QueueLoginDataNumLoggedUsers' AND r."RowId" IS NOT NULL);

\qecho ===== END-OF-RUN MARKER: ORPHAN-CELLS-COMPLETE =====
'@

[IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
$env:PGPASSWORD = $pw
& $psql -h 127.0.0.1 -p 5433 -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -f $sqlf -o $outf 2> $errf
$rc = $LASTEXITCODE
$env:PGPASSWORD = $null

$content = ""
if (Test-Path $outf) { $content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8) }
$errSize = 0; if (Test-Path $errf) { $errSize = (Get-Item $errf).Length }
$marker  = $content.Contains('ORPHAN-CELLS-COMPLETE')
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
