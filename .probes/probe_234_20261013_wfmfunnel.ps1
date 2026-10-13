<#
  PROBE  probe_234_20261013_wfmfunnel.ps1
  READ-ONLY, SELECT only. Nothing installed, restarted or re-configured; no log level touched.
  TASK   coordinator 2026-10-13T14:26:35Z: cause No.1 is accepted (StatusGroup stored uppercase
         against a mixed-case serving map, exact comparison, N = 0). Before anything is fixed,
         backend steps 0-3, to find out whether a SECOND break is waiting behind the first.
  THE QUESTION OF STEP 0 DECIDES THE REST. The loop builds its window as UtcNow + the queue zone
         offset and labels it UTC (StampWallNow), assuming InQueueDateTime is stored in the queue's
         local time. If the column is actually UTC, the window sits three hours in the future and
         lambda is zero no matter what else is right. My earlier "24 in the hour" was taken with
         >= now() - 60 min and NO UPPER BOUND, so it proves neither case - the coordinator is right
         about that, and this probe fixes it by bounding the window at both ends.
  BOTH CANDIDATE WINDOWS ARE RUN, not one. The letter says to take the offset from tz_sample of
         step 0. This probe does that AND runs the same query with a zero offset, each labelled,
         because the pair is what distinguishes the two cases: if the data is local, the shifted
         window has rows and the UTC one does not; if the data is UTC, the reverse. A single
         window could only confirm whichever assumption I had started from.
  THE QUEUE NAME IS NEVER TYPED. It is taken from the classification of BU 22 inside each query.
         The name is Hebrew; typing it into this file would also put its encoding at the mercy of
         every hop between here and the server, and a mangled name would read as "no rows" - a
         false green about the very thing being measured.
  CONTROLS. Step 0 carries rows_24h as its negative half: a zero there makes every conclusion about
         time void, because then we are looking at the wrong queue or database. Steps 1 and 2 print
         winLo and winHi, without which they are not provable. Step 1 prints the distinct values of
         the three filtered columns, so a zero at s3 shows WHAT is actually stored rather than
         leaving "wrong filter" and "no data" indistinguishable. Every query is preceded by a
         deliberately broken one that must return a non-zero rc, and none runs with empty text.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmfunnel' -Title 'READING on 234: backend funnel, steps 0-3 - is there a second break'
Say 'READ-ONLY, SELECT only.'
Rule
Assert-Machine

if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}
function Assert-SqlPresent([string]$name, [string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) {
    Say ('    ' + $name + ' : THE QUERY TEXT IS EMPTY - not run. NOT MEASURED, states nothing.')
    return $false
  }
  return $true
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return @() }
  $sqlPath = Join-Path $SQL_DIR ('wfmfunnel_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmfunnel_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero)')
  }
  $output = @(Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -F '|' -f $sqlPath 2>&1 })
  $exitCode = $LASTEXITCODE
  $env:PGPASSWORD = $null
  Say ('    rc ' + $exitCode + '   (must be 0)')
  foreach ($outputLine in $output) { Say-Guarded ('    ' + $outputLine) }
  if ($exitCode -ne 0) { Say '    THIS QUERY FAILED, so this section states NOTHING about the data.' ; return @() }
  return (Select-DataRows $output)
}

Say '0a  THE CONNECTION, READ AS AN OBJECT'
$appSettingsPath = Join-Path $SHELL_DIR 'appsettings.json'
$primary = $null
if (Test-Path -LiteralPath $appSettingsPath) {
  $settingsJson = $null
  try { $settingsJson = ([IO.File]::ReadAllText($appSettingsPath) | ConvertFrom-Json) } catch { Say ('  appsettings.json does not parse: ' + $_.Exception.Message) }
  if (($null -ne $settingsJson) -and ($null -ne $settingsJson.ConnectionStrings)) {
    foreach ($property in $settingsJson.ConnectionStrings.PSObject.Properties) {
      $raw = [string]$property.Value
      $hostValue = ''
      $portValue = ''
      $databaseValue = ''
      $userValue = ''
      $secretValue = ''
      $hostMatch = [regex]::Match($raw, '(?i)(?:Host|Server)\s*=\s*([^;]+)')
      if ($hostMatch.Success) { $hostValue = $hostMatch.Groups[1].Value.Trim() }
      $portMatch = [regex]::Match($raw, '(?i)Port\s*=\s*([^;]+)')
      if ($portMatch.Success) { $portValue = $portMatch.Groups[1].Value.Trim() }
      $databaseMatch = [regex]::Match($raw, '(?i)Database\s*=\s*([^;]+)')
      if ($databaseMatch.Success) { $databaseValue = $databaseMatch.Groups[1].Value.Trim() }
      $userMatch = [regex]::Match($raw, '(?i)(?:Username|User ID|UserId|User)\s*=\s*([^;]+)')
      if ($userMatch.Success) { $userValue = $userMatch.Groups[1].Value.Trim() }
      $secretMatch = [regex]::Match($raw, '(?i)Password\s*=\s*([^;]+)')
      if ($secretMatch.Success) { $secretValue = $secretMatch.Groups[1].Value.Trim() }
      if ([string]::IsNullOrEmpty($hostValue) -or [string]::IsNullOrEmpty($databaseValue)) { continue }
      if ([string]::IsNullOrEmpty($portValue)) { $portValue = '5432' }
      $secretNote = 'absent'
      if (-not [string]::IsNullOrEmpty($secretValue)) {
        $secretSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($secretValue))).Replace('-','')
        $secretNote = 'length ' + $secretValue.Length + ' sha256 ' + $secretSha.Substring(0,16) + '...'
      }
      Say ('  connection "' + $property.Name + '" : host ' + $hostValue + ' port ' + $portValue + ' database ' + $databaseValue + ' user ' + $userValue)
      Say ('      password : ' + $secretNote)
      if ($null -eq $primary) { $primary = @($property.Name, $hostValue, $portValue, $databaseValue, $userValue, $secretValue) }
    }
  }
}
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND - every section below is NOT MEASURED' } else { $script:Psql }))
Rule

$step0Sql = @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22)
SELECT (now() AT TIME ZONE 'UTC')                                 AS utc_now,
       max(i."InQueueDateTime")                                   AS max_inqueue,
       max(i."InQueueDateTime") - (now() AT TIME ZONE 'UTC')      AS skew,
       min(i."TimeZone")                                          AS tz_sample,
       count(*)                                                   AS rows_24h
FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name
WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours';
'@

Say '0  IN WHAT TIME THE DATA IS STORED - this decides everything that follows'
Say  '  expected if the data is LOCAL, as the code assumes : skew is about +the zone offset (+3h)'
Say  '  expected if the data is UTC                        : skew is about zero or slightly negative'
Say  '  NEGATIVE HALF : rows_24h must be > 0, or we are looking at the wrong queue or database and'
Say  '  every statement about time below is void.'
Say  '  tz_sample is printed beside skew deliberately: the offset must be compared with the actual'
Say  '  TimeZone field of the rows, not with my assumption that it is +03:00.'
$step0 = @()
if (Assert-SqlPresent 'step0' $step0Sql) { $step0 = @(Invoke-Sql $primary 'step0' $step0Sql $true) }
$tzSample = ''
$rows24 = ''
if ($step0.Count -gt 0) {
  $parts = ([string]$step0[0]).Split('|')
  if ($parts.Count -ge 5) {
    $tzSample = $parts[3]
    $rows24 = $parts[4]
    Say ('  tz_sample as stored : [' + $tzSample + ']    rows_24h : ' + $rows24)
  }
}
$offsetHours = $null
$offsetMatch = [regex]::Match($tzSample, '([+-])(\d{1,2}):?(\d{2})?')
if ($offsetMatch.Success) {
  $sign = $(if ($offsetMatch.Groups[1].Value -eq '-') { -1 } else { 1 })
  $hoursPart = [int]$offsetMatch.Groups[2].Value
  $minutesPart = 0
  if ($offsetMatch.Groups[3].Success) { $minutesPart = [int]$offsetMatch.Groups[3].Value }
  $offsetHours = $sign * ($hoursPart + ($minutesPart / 60.0))
  Say ('  offset parsed from tz_sample : ' + $offsetHours + ' hours')
} else {
  Say  '  THE OFFSET COULD NOT BE PARSED from tz_sample. Steps 1 and 2 below are therefore run with'
  Say  '  the offset the letter names (+3) AND with zero, both labelled - and the parsed value is'
  Say  '  NOT invented. Which window holds the rows is the answer either way.'
  $offsetHours = 3
}
Rule

function Build-Step1([string]$offsetText) {
  return @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22),
w AS (SELECT (now() AT TIME ZONE 'UTC') + interval 'OFFSET_TEXT' AS hi)
SELECT (SELECT hi - interval '30 minutes' FROM w)                                  AS win_lo,
       (SELECT hi FROM w)                                                          AS win_hi,
       count(*)                                                                    AS s0_in_window,
       count(*) FILTER (WHERE i."Direction" = 'Incoming')                          AS s1_incoming,
       count(*) FILTER (WHERE i."Direction" = 'Incoming'
                          AND i."InteractionType" IN ('Call','Callback'))          AS s2_type,
       count(*) FILTER (WHERE i."Direction" = 'Incoming'
                          AND i."InteractionType" IN ('Call','Callback')
                          AND i."CallType" = 'External')                           AS s3_external,
       count(DISTINCT i."Direction")                                               AS distinct_direction,
       count(DISTINCT i."InteractionType")                                         AS distinct_type,
       count(DISTINCT i."CallType")                                                AS distinct_calltype
FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name, w
WHERE i."InQueueDateTime" >= w.hi - interval '30 minutes'
  AND i."InQueueDateTime" <  w.hi;
'@.Replace('OFFSET_TEXT', $offsetText)
}

function Build-Step2([string]$offsetText) {
  return @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22),
w AS (SELECT (now() AT TIME ZONE 'UTC') + interval 'OFFSET_TEXT' AS hi)
SELECT (SELECT hi - interval '30 minutes' FROM w)                                   AS win_lo,
       (SELECT hi FROM w)                                                           AS win_hi,
       count(*)                                                                     AS a0_in_window,
       count(*) FILTER (WHERE i."IsAnswered")                                       AS a1_answered,
       count(*) FILTER (WHERE i."IsAnswered" AND NOT i."IsInQueue")                  AS a2_not_inqueue,
       avg(nullif(i."TalkTime",0)) FILTER (WHERE i."IsAnswered" AND NOT i."IsInQueue") AS aht_sec
FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name, w
WHERE i."Direction" = 'Incoming'
  AND i."InteractionType" IN ('Call','Callback') AND i."CallType" = 'External'
  AND i."AnsweredDateTime" >= w.hi - interval '30 minutes'
  AND i."AnsweredDateTime" <  w.hi;
'@.Replace('OFFSET_TEXT', $offsetText)
}

Say '1  LAMBDA: the queue rows after EACH filter, in the order of the code, in a BOUNDED window'
Say  '  Two windows are run, each labelled. If the data is local the shifted window has the rows;'
Say  '  if it is UTC the zero-offset one does. One window alone could only confirm whatever'
Say  '  assumption I started with, which is exactly the fault the coordinator caught in my'
Say  '  "24 in the hour" - it had no upper bound at all.'
Say  '  win_lo and win_hi are printed by the query itself, or the step is not provable.'
Say  '  NEGATIVE HALF: the three distinct_* counters. If s3 is zero they show WHAT is stored there'
Say  '  instead - "wrong filter" and "no data" are different defects with different costs.'
$step1Shifted = @()
$shiftedText = ([string]$offsetHours) + ' hours'
Say ('  --- window A: offset from tz_sample / the letter : +' + $shiftedText + ' ---')
$step1ShiftedSql = Build-Step1 $shiftedText
if (Assert-SqlPresent 'step1_shifted' $step1ShiftedSql) { $step1Shifted = @(Invoke-Sql $primary 'step1_shifted' $step1ShiftedSql $true) }
Say  '  --- window B: zero offset, i.e. the data read as UTC ---'
$step1Utc = @()
$step1UtcSql = Build-Step1 '0 hours'
if (Assert-SqlPresent 'step1_utc' $step1UtcSql) { $step1Utc = @(Invoke-Sql $primary 'step1_utc' $step1UtcSql $false) }
Rule

Say '2  AHT, the same order, windowed on AnsweredDateTime'
Say  '  AHT = 0 is enough on its own to make State NoData (WfmRealtimeLoop.cs:242-246), even with a'
Say  '  live lambda. aht_sec NULL while a2 > 0 means every TalkTime is zero - a separate defect.'
Say ('  --- window A: +' + $shiftedText + ' ---')
$step2Shifted = @()
$step2ShiftedSql = Build-Step2 $shiftedText
if (Assert-SqlPresent 'step2_shifted' $step2ShiftedSql) { $step2Shifted = @(Invoke-Sql $primary 'step2_shifted' $step2ShiftedSql $true) }
Say  '  --- window B: zero offset ---'
$step2Utc = @()
$step2UtcSql = Build-Step2 '0 hours'
if (Assert-SqlPresent 'step2_utc' $step2UtcSql) { $step2Utc = @(Invoke-Sql $primary 'step2_utc' $step2UtcSql $false) }
Rule

$step3Sql = @'
SELECT
 (SELECT count(*) FROM public."NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = 22 AND "ClassificationId" = 'ALL')                         AS n1_queues_of_bu,
 (SELECT count(*) FROM public."NGC_BusinessUnitSupergroup" WHERE "BusinessUnitId" = 22) AS n2_sg_of_bu,
 (SELECT count(*) FROM public."NGC_SupergroupAgentgroup" sag
    JOIN public."NGC_BusinessUnitSupergroup" bs ON bs."SupergroupId" = sag."SupergroupId"
    WHERE bs."BusinessUnitId" = 22)                                                     AS n3_ag_of_sg,
 (SELECT count(DISTINCT uag."UserId") FROM public."NGC_UserAgentgroup" uag
    WHERE uag."AgentgroupId" IN (
      SELECT sag."AgentgroupId" FROM public."NGC_SupergroupAgentgroup" sag
      JOIN public."NGC_BusinessUnitSupergroup" bs ON bs."SupergroupId" = sag."SupergroupId"
      WHERE bs."BusinessUnitId" = 22))                                                  AS n4_users;
'@

$step3bSql = @'
SELECT bs."SupergroupId", count(DISTINCT sag."AgentgroupId") AS ag_count
FROM public."NGC_BusinessUnitSupergroup" bs
JOIN public."NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bs."SupergroupId"
WHERE bs."BusinessUnitId" = 22
GROUP BY bs."SupergroupId";
'@

Say '3  N: the chain BU -> supergroup -> agent group -> user'
Say  '  expected : all four counters > 0. The FIRST zero in the chain is where it breaks.'
$step3 = @()
if (Assert-SqlPresent 'step3' $step3Sql) { $step3 = @(Invoke-Sql $primary 'step3' $step3Sql $true) }
Say  '  AND THE ONE THE LETTER CALLS OUT SEPARATELY: inside one supergroup the code takes the'
Say  '  INTERSECTION of the agent-group memberships (:214-222), not the union. Two agent groups with'
Say  '  nobody in common give an EMPTY intersection while n3 and n4 are both non-zero - N = 0 with'
Say  '  no error anywhere. So the agent-group count per supergroup is read as well: any value above'
Say  '  1 is the flag to check the intersection by hand.'
$step3b = @()
if (Assert-SqlPresent 'step3b' $step3bSql) { $step3b = @(Invoke-Sql $primary 'step3b' $step3bSql $false) }
Say ('  measured : supergroup rows ' + $step3b.Count)
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  step 0 rows               : ' + $step0.Count + '   tz_sample [' + $tzSample + ']   rows_24h ' + $rows24)
Say ('  step 1 window A / B rows  : ' + $step1Shifted.Count + ' / ' + $step1Utc.Count)
Say ('  step 2 window A / B rows  : ' + $step2Shifted.Count + ' / ' + $step2Utc.Count)
Say ('  step 3 rows / supergroups : ' + $step3.Count + ' / ' + $step3b.Count)
Say  '  Which window holds the data answers whether the loop window is shifted; the first zero in'
Say  '  the funnel answers where a second break would be. Both are stated in the letter from these'
Say  '  numbers, with backend-0919 in copy - not here.'
Say '===== END-OF-RUN MARKER: WFMFUNNEL-COMPLETE ====='
Finish (-not (Test-TrapFired))
