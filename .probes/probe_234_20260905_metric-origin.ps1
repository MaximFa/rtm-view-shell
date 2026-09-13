#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / metric-origin  -  READ ONLY, BOTH DATABASES
#  WHERE IT RUNS : server 234.
#                  DB #1 = rtmviewdb @ 127.0.0.1:5433  (PG18, ours, after converge)
#                  DB #2 = rtmviewdb @ 127.0.0.1:5432  (PG15, the UNTOUCHED "before us" copy)
#  WRITES        : nothing to either database. Output files only, into C:\RTMView-Ops\output\
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
#  NOTE          : each database gets its OWN output and error file and its OWN gate,
#                  so a refused login on 5432 can never be read as "the metric is absent".
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OpsRoot = "C:\RTMView-Ops"
$OutDir  = Join-Path $OpsRoot "output"
$cfg     = "C:\RTMView\Shell\appsettings.json"
$server  = "234"
$topic   = "metric-origin"

Write-Host "WHERE IT RUNS : server $server, databases 5433 (ours) AND 5432 (untouched), READ ONLY"

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

$sql = @'
\qecho ===== J0 NEGATIVE CONTROLS - all MUST be false/zero =====
SELECT 'exact  ZZZ_NO_SUCH' AS probe,
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId" = 'ZZZ_NO_SUCH_METRIC'))::text AS result
UNION ALL
SELECT 'ilike  ZZZ_NO_SUCH',
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE lower(btrim("MetricId")) = lower('ZZZ_NO_SUCH_METRIC')))::text
UNION ALL
SELECT 'catalogue total rows', count(*)::text FROM "RTSGrid_Metric";

\qecho ===== J1 QueueNumberOfLoggedAgents - EXACT vs CASE-INSENSITIVE + TRIMMED =====
SELECT 'exact match'            AS how,
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId" = 'QueueNumberOfLoggedAgents'))::text AS found
UNION ALL
SELECT 'lower + btrim',
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE lower(btrim("MetricId")) = lower('QueueNumberOfLoggedAgents')))::text
UNION ALL
SELECT 'substring anywhere in MetricId',
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId" ILIKE '%LoggedAgents%'))::text
UNION ALL
SELECT 'the REPLACEMENT QueueLoginDataNumLoggedUsers',
       (EXISTS (SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers'))::text;

\qecho -- anything whose MetricId merely looks like it, printed in full
SELECT "MetricId", "DisplayName", "CatalogStatus", "MetricFunction"
FROM "RTSGrid_Metric" WHERE "MetricId" ILIKE '%Logged%' ORDER BY "MetricId";

\qecho ===== J2 ALL TWELVE NAMES OF ROW 316 vs CATALOGUE - case-insensitive this time =====
\qecho -- the twelve are hard-coded here so this section works on BOTH databases,
\qecho -- including 5432 where grid 78 may not exist in the same shape
SELECT n.metric_name,
       EXISTS (SELECT 1 FROM "RTSGrid_Metric" m WHERE m."MetricId" = n.metric_name) AS exact,
       EXISTS (SELECT 1 FROM "RTSGrid_Metric" m WHERE lower(btrim(m."MetricId")) = lower(n.metric_name)) AS ci
FROM (VALUES
 ('QueueNumIncomingOnlineCalls'),('QueueCurMaxWaitTimeCalls'),('QueuePctAnsweredCallsTotal'),
 ('QueueNumAnsweredCalls60sec'),('QueueAvgWaitTimeCalls'),('QueueNumberOfLoggedAgents'),
 ('StateCountAvailable'),('QueueCPH'),('QueueNumIncomingCompletedCalls'),
 ('QueueNumAnsweredCalls'),('QueueNumAbandonedCalls'),('QueueAvgTalkingDurationCalls')
) AS n(metric_name) ORDER BY n.metric_name;

SELECT ci AS found_case_insensitive, count(*) AS metrics FROM (
  SELECT EXISTS (SELECT 1 FROM "RTSGrid_Metric" m WHERE lower(btrim(m."MetricId")) = lower(n.metric_name)) AS ci
  FROM (VALUES
   ('QueueNumIncomingOnlineCalls'),('QueueCurMaxWaitTimeCalls'),('QueuePctAnsweredCallsTotal'),
   ('QueueNumAnsweredCalls60sec'),('QueueAvgWaitTimeCalls'),('QueueNumberOfLoggedAgents'),
   ('StateCountAvailable'),('QueueCPH'),('QueueNumIncomingCompletedCalls'),
   ('QueueNumAnsweredCalls'),('QueueNumAbandonedCalls'),('QueueAvgTalkingDurationCalls')
  ) AS n(metric_name)
) q GROUP BY ci ORDER BY ci;

\qecho ===== J3 WHICH DATABASE AM I - stated by the server, not assumed =====
SELECT current_database() AS db, inet_server_port() AS port, version() AS server_version;

\qecho ===== END-OF-RUN MARKER: METRIC-ORIGIN-COMPLETE =====
'@

[IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))

function Run-One([int]$port, [string]$label) {
    $outf = Join-Path $OutDir "$($server)_$($stamp)_$($topic)_$($label).txt"
    $errf = Join-Path $OutDir "$($server)_$($stamp)_$($topic)_$($label).err.txt"
    $env:PGPASSWORD = $pw
    & $psql[0].FullName -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -f $sqlf -o $outf 2> $errf
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = $null

    $content = ""
    if (Test-Path $outf) { $content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8) }
    $errSize = 0
    if (Test-Path $errf) { $errSize = (Get-Item $errf).Length }
    $marker  = $content.Contains('METRIC-ORIGIN-COMPLETE')
    $errOut  = ([regex]::Matches($content,'\bERROR\b')).Count
    $pass    = ($rc -eq 0 -and $errSize -eq 0 -and $marker -and $errOut -eq 0)

    Write-Host ""
    Write-Host "--- port $port ($label) ---"
    Write-Host "psql exit     : $rc      (must be 0)"
    Write-Host "stderr size   : $errSize bytes   (must be 0 - GATE CONDITION)"
    Write-Host "END marker    : $marker  (must be True)"
    Write-Host "ERROR in out  : $errOut  (must be 0)"
    if ($pass) { Write-Host "GATE $label : PASS" } else { Write-Host "GATE $label : FAIL - do NOT read this database's numbers as a result" }
    Write-Host "   $outf"
    Write-Host "   $errf"
    return $pass
}

$okNew = Run-One 5433 "5433-ours"
$okOld = Run-One 5432 "5432-untouched"

Write-Host ""
if ($okNew -and $okOld) {
    Write-Host "OVERALL GATE: PASS - both databases measured"
} else {
    Write-Host "OVERALL GATE: FAIL - at least one database did not measure cleanly; bring all four files anyway"
}
Write-Host ""
Write-Host "COPY BACK EVERY FILE LISTED ABOVE."
