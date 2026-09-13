#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / orphan-growth  -  READ ONLY, BOTH DATABASES
#  WHERE IT RUNS : server 234.
#     DB #1 = rtmviewdb @ 127.0.0.1:5432  (PG15, UNTOUCHED - second baseline)
#     DB #2 = rtmviewdb @ 127.0.0.1:5433  (PG18, ours, live)
#  WRITES        : nothing to either database. Output files only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 and no cell is modified.
#  PURPOSE       : the recorded baseline says Cell->Row dangling = 21 (RUN 2, 2026-08-30).
#                  Today 5433 shows 37 while Cell->Column stayed at 21. Find WHICH rows,
#                  which are new, and whether they cluster.
#  NOTE          : the baseline is a NUMBER, not a list - no list of those 21 exists in the
#                  artifacts. Novelty is therefore derived by comparing against 5432, which
#                  has not been touched since before the converge.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OutDir = "C:\RTMView-Ops\output"
$cfg    = "C:\RTMView\Shell\appsettings.json"
$server = "234"
$topic  = "orphan-growth"

Write-Host "WHERE IT RUNS : server $server, databases 5432 (untouched) AND 5433 (ours), READ ONLY"

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
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s) }

function Ask([int]$port, [string]$sqlText) {
    $t = Join-Path $env:TEMP ("og_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    $e = Join-Path $env:TEMP ("og_{0}.err" -f [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText($t, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $r = & $psql -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $t 2> $e
    $env:PGPASSWORD = $null
    if (Test-Path $e) {
        $c = [IO.File]::ReadAllText($e)
        if ($c.Trim().Length -gt 0) { [void]$errAll.Add("port $port :: $c") }
        Remove-Item $e -ErrorAction SilentlyContinue
    }
    Remove-Item $t -ErrorAction SilentlyContinue
    return @($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 })
}

$qOrphanRow = 'SELECT c."CellId" FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL ORDER BY c."CellId";'
$qCounts = 'SELECT ''cells total''||''|''||count(*) FROM "RTSGrid_Cell"
UNION ALL SELECT ''orphan Cell->Row''||''|''||(SELECT count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL)
UNION ALL SELECT ''orphan Cell->Column''||''|''||(SELECT count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Column" k ON k."ColumnId"=c."ColumnId" WHERE k."ColumnId" IS NULL)
UNION ALL SELECT ''NEGCTL orphan on a resolvable join (must be 0)''||''|''||(SELECT count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Cell" c2 ON c2."CellId"=c."CellId" WHERE c2."CellId" IS NULL);'

Say "===== G0 IDENTITY ====="
foreach ($p in 5432,5433) { Say ("  " + ((Ask $p "SELECT current_database()||' | port '||inet_server_port()||' | '||version();") -join "")) }

Say ""
Say "===== G1 COUNTS ON BOTH - the recorded baseline (RUN 2, 2026-08-30) was Cell->Row 21, Cell->Column 21 ====="
foreach ($p in 5432,5433) {
    Say ("  --- port {0} ---" -f $p)
    foreach ($line in (Ask $p $qCounts)) { Say ("      {0}" -f $line) }
}

$old = Ask 5432 $qOrphanRow
$new = Ask 5433 $qOrphanRow
Say ""
Say "===== G2 ORPHAN SETS COMPARED - the baseline is a NUMBER, no list of those 21 exists in the artifacts ====="
Say ("  orphan CellIds on 5432 untouched : {0}" -f $old.Count)
Say ("  orphan CellIds on 5433 ours      : {0}" -f $new.Count)
$onlyNew = @()
$onlyOld = @()
if ($old.Count -gt 0 -or $new.Count -gt 0) {
    $cmp = Compare-Object -ReferenceObject @($old) -DifferenceObject @($new)
    $onlyOld = @($cmp | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject })
    $onlyNew = @($cmp | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject })
}
Say ("  orphaned ONLY on 5433 (candidates for NEW) : {0}" -f $onlyNew.Count)
Say ("      {0}" -f ($onlyNew -join ", "))
Say ("  orphaned ONLY on 5432 (were, are not)      : {0}" -f $onlyOld.Count)
Say ("      {0}" -f ($onlyOld -join ", "))

Say ""
Say "===== G3 ALL ORPHANS ON 5433, NAMED - CellId|RowId|ColumnId|ColNumber|CellType|StyleId|Value ====="
foreach ($r in (Ask 5433 'SELECT c."CellId"||''|''||c."RowId"||''|''||c."ColumnId"||''|''||coalesce(c."ColNumber"::text,''-'')||''|''||coalesce(c."CellType",''-'')||''|''||coalesce(c."StyleId"::text,''-'')||''|''||coalesce(c."Value",''<null>'') FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL ORDER BY c."RowId", c."ColumnId";')) { Say ("      {0}" -f $r) }

Say ""
Say "===== G4 DO THEY CLUSTER - grouped four ways, on 5433 ====="
foreach ($grp in @(
    @{n='by RowId';       q='SELECT ''RowId ''||c."RowId"||'' -> ''||count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL GROUP BY c."RowId" ORDER BY c."RowId";'},
    @{n='by ColumnId';    q='SELECT ''ColumnId ''||c."ColumnId"||'' -> ''||count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL GROUP BY c."ColumnId" ORDER BY c."ColumnId";'},
    @{n='by CellType';    q='SELECT ''CellType ''||coalesce(c."CellType",''<null>'')||'' -> ''||count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL GROUP BY c."CellType" ORDER BY 1;'},
    @{n='by StyleId';     q='SELECT ''StyleId ''||coalesce(c."StyleId"::text,''<null>'')||'' -> ''||count(*) FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL GROUP BY c."StyleId" ORDER BY 1;'}
)) {
    Say ("  --- {0} ---" -f $grp.n)
    foreach ($r in (Ask 5433 $grp.q)) { Say ("      {0}" -f $r) }
}

Say ""
Say "===== G5 OUR TWO (1496, 1504) - same group as the rest, or apart ====="
foreach ($r in (Ask 5433 'SELECT c."CellId"||'' | RowId ''||c."RowId"||'' | ColumnId ''||c."ColumnId"||'' | ''||coalesce(c."CellType",''-'')||'' | Style ''||coalesce(c."StyleId"::text,''-'')||'' | ''||coalesce(c."Value",''<null>'') FROM "RTSGrid_Cell" c WHERE c."CellId" IN (1496,1504) ORDER BY c."CellId";')) { Say ("      {0}" -f $r) }

Say ""
Say "===== G6 RowId RANGE CONTEXT - which RowIds exist at all, so gaps are visible ====="
foreach ($r in (Ask 5433 'SELECT ''existing RowId min/max: ''||min("RowId")||'' / ''||max("RowId")||'' , count ''||count(*) FROM "RTSGrid_Row";')) { Say ("      {0}" -f $r) }
foreach ($r in (Ask 5433 'SELECT ''orphan RowId min/max: ''||min(c."RowId")||'' / ''||max(c."RowId")||'' , distinct ''||count(DISTINCT c."RowId") FROM "RTSGrid_Cell" c LEFT JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."RowId" IS NULL;')) { Say ("      {0}" -f $r) }

Say ""
Say "===== END-OF-RUN MARKER: ORPHAN-GROWTH-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))

$errSize = (Get-Item $errf).Length
$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$marker  = $content.Contains('ORPHAN-GROWTH-COMPLETE')
$sane    = ($new.Count -gt 0)

Write-Host ""
Write-Host "stderr size   : $errSize bytes   (must be 0 - GATE CONDITION)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "5433 list non-empty : $sane  (must be True)"
Write-Host ""
if ($errSize -eq 0 -and $marker -and $sane) { Write-Host "GATE: PASS - measurement is valid" }
else { Write-Host "GATE: FAIL - do NOT read the numbers as a result" }
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
