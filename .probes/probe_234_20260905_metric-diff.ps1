#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / metric-diff  -  READ ONLY, BOTH DATABASES
#  WHERE IT RUNS : server 234.
#                  DB #1 = rtmviewdb @ 127.0.0.1:5432  (PG15, UNTOUCHED "before us")
#                  DB #2 = rtmviewdb @ 127.0.0.1:5433  (PG18, ours, after converge)
#  WRITES        : nothing to either database. Output files only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
#  WHY A SCRIPT  : the two catalogues live in two separate servers, so the set comparison
#                  cannot be done in SQL. Each database is only ASKED FOR ITS LIST; the
#                  comparison happens here, in the script. Nothing is installed anywhere.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OutDir = "C:\RTMView-Ops\output"
$cfg    = "C:\RTMView\Shell\appsettings.json"
$server = "234"
$topic  = "metric-diff"

Write-Host "WHERE IT RUNS : server $server, databases 5432 (untouched) AND 5433 (ours), READ ONLY"

$psql = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
if ($psql.Count -ne 1 -or -not (Test-Path $cfg)) {
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
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$errAll = New-Object System.Collections.ArrayList

function Ask([int]$port, [string]$sqlText) {
    $tmpSql = Join-Path $env:TEMP ("probe_{0}_{1}.sql" -f $port, [guid]::NewGuid().ToString("N"))
    $tmpErr = Join-Path $env:TEMP ("probe_{0}_{1}.err" -f $port, [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText($tmpSql, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $res = & $psql[0].FullName -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $tmpSql 2> $tmpErr
    $script:lastRc = $LASTEXITCODE
    $env:PGPASSWORD = $null
    if (Test-Path $tmpErr) {
        $e = [IO.File]::ReadAllText($tmpErr)
        if ($e.Trim().Length -gt 0) { [void]$errAll.Add("port $port :: $e") }
        Remove-Item $tmpErr -ErrorAction SilentlyContinue
    }
    Remove-Item $tmpSql -ErrorAction SilentlyContinue
    return @($res | Where-Object { $_ -ne $null -and $_.ToString().Trim().Length -gt 0 })
}

function Q([string]$s) { return "'" + ($s -replace "'", "''") + "'" }

$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s) }

Say "===== K0 IDENTITY - each database states what it is ====="
foreach ($p in 5432,5433) {
    $id = Ask $p "SELECT current_database()||' | port '||inet_server_port()||' | '||version();"
    Say ("  {0}" -f ($id -join ""))
}

Say ""
Say "===== K1 CATALOGUE SIZES ====="
$old = Ask 5432 'SELECT "MetricId" FROM "RTSGrid_Metric" ORDER BY "MetricId";'
$new = Ask 5433 'SELECT "MetricId" FROM "RTSGrid_Metric" ORDER BY "MetricId";'
Say ("  5432 untouched : {0} metrics" -f $old.Count)
Say ("  5433 ours      : {0} metrics" -f $new.Count)
Say ("  difference     : {0}" -f ($old.Count - $new.Count))

$onlyOld = @(Compare-Object -ReferenceObject $old -DifferenceObject $new | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object { $_.InputObject })
$onlyNew = @(Compare-Object -ReferenceObject $old -DifferenceObject $new | Where-Object { $_.SideIndicator -eq '=>' } | ForEach-Object { $_.InputObject })

Say ""
Say "===== K2 SET DIFFERENCE - both directions, because 'minus 5' may be 'minus 7 plus 2' ====="
Say ("  LOST  (on 5432, absent on 5433) : {0}" -f $onlyOld.Count)
foreach ($m in $onlyOld) { Say ("      - {0}" -f $m) }
Say ("  NEW   (on 5433, absent on 5432) : {0}" -f $onlyNew.Count)
foreach ($m in $onlyNew) { Say ("      + {0}" -f $m) }
Say "  NEGATIVE CONTROL - a name that is in neither list must appear in neither column above:"
Say ("      ZZZ_NO_SUCH_METRIC in LOST = {0} , in NEW = {1}  (both must be False)" -f ($onlyOld -contains 'ZZZ_NO_SUCH_METRIC'), ($onlyNew -contains 'ZZZ_NO_SUCH_METRIC'))

if ($onlyOld.Count -gt 0) {
    $inList = ($onlyOld | ForEach-Object { Q $_ }) -join ","

    Say ""
    Say "===== K3 THE LOST ONES IN FULL - read from 5432, where they still exist ====="
    $rows = Ask 5432 ("SELECT ""MetricId""||' | fn='||coalesce(""MetricFunction"",'<null>')||' | param='||coalesce(""MetricParameter"",'<null>')||' | display='||coalesce(""DisplayName"",'<null>')||' | status='||coalesce(""CatalogStatus"",'<null>')||' | type='||coalesce(""MetricType"",'<null>')||' | family='||coalesce(""Family"",'<null>') FROM ""RTSGrid_Metric"" WHERE ""MetricId"" IN ({0}) ORDER BY ""MetricId"";" -f $inList)
    foreach ($r in $rows) { Say ("      {0}" -f $r) }

    Say ""
    Say "===== K4 RENAME OR LOSS - does a metric with the SAME MetricFunction survive on 5433 ====="
    Say "      (a surviving twin means RENAME, and a rename must NOT be repaired by restoring the old row)"
    foreach ($m in $onlyOld) {
        $fn = (Ask 5432 ("SELECT coalesce(""MetricFunction"",'<null>') FROM ""RTSGrid_Metric"" WHERE ""MetricId"" = {0};" -f (Q $m))) -join ""
        if ($fn -eq '<null>' -or $fn -eq '') {
            Say ("      {0} | fn=<null> | cannot pair by function" -f $m)
        } else {
            $twins = Ask 5433 ("SELECT ""MetricId"" FROM ""RTSGrid_Metric"" WHERE ""MetricFunction"" = {0} ORDER BY ""MetricId"";" -f (Q $fn))
            if ($twins.Count -eq 0) {
                Say ("      {0} | fn={1} | survivor on 5433: NONE  -> LOSS" -f $m, $fn)
            } else {
                Say ("      {0} | fn={1} | survivor on 5433: {2}  -> likely RENAME" -f $m, $fn, ($twins -join ", "))
            }
        }
    }
    Say "      NEGATIVE CONTROL - a function that cannot exist must yield NONE:"
    $ncf = Ask 5433 "SELECT ""MetricId"" FROM ""RTSGrid_Metric"" WHERE ""MetricFunction"" = 'ZZZ_NO_SUCH_FUNCTION';"
    Say ("      ZZZ_NO_SUCH_FUNCTION | survivors: {0}  (must be 0)" -f $ncf.Count)

    Say ""
    Say "===== K5 WHO STILL REFERENCES THE LOST ONES - on 5433, our live data. Zeros printed too ====="
    $refs = Ask 5433 ("SELECT n.mid||' | grid cells: '||(SELECT count(*) FROM ""RTSGrid_Cell"" c WHERE c.""Value"" = n.mid)||' | distinct grids: '||coalesce((SELECT string_agg(DISTINCT r.""GridId""::text, ',' ORDER BY r.""GridId""::text) FROM ""RTSGrid_Cell"" c JOIN ""RTSGrid_Row"" r ON r.""RowId"" = c.""RowId"" WHERE c.""Value"" = n.mid),'-')||' | widget configs: '||(SELECT count(*) FROM dashboard_widgets w WHERE w.""ConfigJson""::text LIKE '%'||n.mid||'%') FROM (SELECT unnest(ARRAY[{0}]) AS mid) n ORDER BY n.mid;" -f $inList)
    foreach ($r in $refs) { Say ("      {0}" -f $r) }

    Say ""
    Say "      NEGATIVE CONTROL, same three predicates on a name that cannot exist:"
    $nc = Ask 5433 "SELECT 'ZZZ_NO_SUCH_METRIC | grid cells: '||(SELECT count(*) FROM ""RTSGrid_Cell"" WHERE ""Value"" = 'ZZZ_NO_SUCH_METRIC')||' | widget configs: '||(SELECT count(*) FROM dashboard_widgets WHERE ""ConfigJson""::text LIKE '%ZZZ_NO_SUCH_METRIC%');"
    foreach ($r in $nc) { Say ("      {0}" -f $r) }
}

Say ""
Say "===== END-OF-RUN MARKER: METRIC-DIFF-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))

$errSize = (Get-Item $errf).Length
$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$marker  = $content.Contains('METRIC-DIFF-COMPLETE')
$sane    = ($old.Count -gt 0 -and $new.Count -gt 0)

Write-Host ""
Write-Host "stderr size   : $errSize bytes   (must be 0 - GATE CONDITION)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "both lists non-empty : $sane  (must be True - an empty list would fake a huge diff)"
Write-Host ""
if ($errSize -eq 0 -and $marker -and $sane) { Write-Host "GATE: PASS - measurement is valid" }
else { Write-Host "GATE: FAIL - do NOT read the lists as a result" }
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
