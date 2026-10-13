<#
  PROBE  probe_234_20261013_wfmtime.ps1
  READ-ONLY, SELECT only.
  WHY THIS ONE EXISTS, AND IT IS A CORRECTION OF MY OWN INSTRUMENT. The funnel probe ran both
  candidate windows - shifted by the zone offset and unshifted - expecting one of them to be empty
  and so to tell local storage from UTC storage. BOTH came back with rows (2 and 3), every one of
  them passing all three filters. The pair cannot discriminate, and the reason is obvious in
  hindsight: this queue carries traffic around the clock, so ANY half-hour window of the last day
  holds rows. A test whose two outcomes look the same under both hypotheses is not a test.
  And step 0, which was supposed to settle it by skew, was spoiled by the data itself: the maximum
  InQueueDateTime of the window came back as 10000-01-01 01:59:59.997+02 - a sentinel row - so the
  skew read 2912157 days and said nothing about the storage zone. min("TimeZone") came back EMPTY,
  while the loop's own log says the workgroups carry mixed zones with +03:00 dominant: some rows
  have no zone at all.
  WHAT ACTUALLY DISCRIMINATES, and it is one count: if InQueueDateTime is stored in the queue's
  LOCAL time (+03:00), then rows written in the last minutes sit UP TO THREE HOURS AHEAD of UTC
  now, and a count of rows strictly in the future relative to UTC is large. If it is stored in UTC,
  that count is essentially zero. The same question asked from the other side: the newest sane row
  against utc_now. Both are below, and the sentinel rows are excluded by an explicit bound rather
  than by hoping they are rare - with their own count printed, because an exclusion that hides
  something is how a measurement lies.
  NEGATIVE HALVES. The future count stands beside the total of the same window, so it cannot be
  read as a share of nothing. The sentinel count stands beside the sane maximum. The zone census
  counts rows per distinct TimeZone value, printed in brackets, including the empty one.
  The queue name is taken from the classification of BU 22 inside each query, never typed.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmtime' -Title 'READING on 234: is InQueueDateTime stored local or UTC - the one count that tells them apart'
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
  if ([string]::IsNullOrWhiteSpace($text)) { Say ('    ' + $name + ' : QUERY TEXT EMPTY - not run, NOT MEASURED.') ; return $false }
  return $true
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return @() }
  $sqlPath = Join-Path $SQL_DIR ('wfmtime_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmtime_' + $label + '_negctl.sql')
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

Say '0  THE CONNECTION, READ AS AN OBJECT'
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

$futureSql = @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22),
r AS (SELECT i."InQueueDateTime" AS t
      FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name
      WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours'
        AND i."InQueueDateTime" <  (now() AT TIME ZONE 'UTC') + interval '365 days')
SELECT (now() AT TIME ZONE 'UTC')                                              AS utc_now,
       count(*)                                                                AS rows_window,
       count(*) FILTER (WHERE t > (now() AT TIME ZONE 'UTC'))                   AS rows_in_the_future,
       count(*) FILTER (WHERE t > (now() AT TIME ZONE 'UTC') + interval '2 hours') AS rows_more_than_2h_ahead,
       max(t)                                                                  AS newest_sane_row,
       max(t) - (now() AT TIME ZONE 'UTC')                                      AS skew_of_newest
FROM r;
'@

Say '1  THE ONE COUNT THAT TELLS LOCAL FROM UTC: rows standing in the FUTURE relative to UTC now'
Say  '  If InQueueDateTime is stored in the queue local time (+03:00), rows written minutes ago sit'
Say  '  up to three hours ahead of utc_now, so rows_in_the_future is LARGE and skew_of_newest is'
Say  '  close to +3h. If it is stored in UTC, rows_in_the_future is essentially zero and the skew'
Say  '  of the newest row is near zero or slightly negative.'
Say  '  Sentinel rows are excluded by an explicit upper bound of one year, not by hoping they are'
Say  '  rare: the funnel probe got max = 10000-01-01 and a skew of 2912157 days, which measured'
Say  '  nothing. Their own count is section 2, so the exclusion hides nothing.'
Say  '  NEGATIVE HALF: rows_window stands beside the future count, so a zero cannot be a share of'
Say  '  an empty set.'
$futureRows = @()
if (Assert-SqlPresent 'future' $futureSql) { $futureRows = @(Invoke-Sql $primary 'future' $futureSql $true) }
Say ('  measured : rows ' + $futureRows.Count + '   (expected 1)')
Rule

$sentinelSql = @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22)
SELECT count(*)                                                                      AS rows_all_time,
       count(*) FILTER (WHERE i."InQueueDateTime" > (now() AT TIME ZONE 'UTC') + interval '365 days') AS sentinel_rows,
       min(i."InQueueDateTime") FILTER (WHERE i."InQueueDateTime" > (now() AT TIME ZONE 'UTC') + interval '365 days') AS sentinel_sample,
       count(*) FILTER (WHERE i."AnsweredDateTime" IS NULL)                           AS answered_is_null
FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name;
'@

Say '2  THE SENTINEL ROWS, COUNTED RATHER THAN STEPPED AROUND'
Say  '  The funnel probe met one of these as the maximum of its window. An excluded value that is'
Say  '  never counted is how a measurement quietly lies, so here they have their own number and a'
Say  '  sample. Whether a row dated year 10000 is lawful in this table is for backend to say; this'
Say  '  probe only reports that they exist and how many.'
$sentinelRows = @()
if (Assert-SqlPresent 'sentinel' $sentinelSql) { $sentinelRows = @(Invoke-Sql $primary 'sentinel' $sentinelSql $true) }
Say ('  measured : rows ' + $sentinelRows.Count + '   (expected 1)')
Rule

$zoneSql = @'
WITH q AS (SELECT "QueueId" AS name FROM public."NGC_BusinessUnitQueueClassification"
           WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22)
SELECT '[' || coalesce(i."TimeZone", '<NULL>') || ']' AS timezone_as_stored,
       count(*)                                       AS rows
FROM public."RTSData_Interaction" i JOIN q ON i."Workgroup" = q.name
WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours'
GROUP BY 1
ORDER BY 2 DESC;
'@

Say '3  THE TimeZone VALUES OF THIS QUEUE, AS STORED, IN BRACKETS'
Say  '  The funnel probe read min("TimeZone") and got an EMPTY string, while the loop logs that the'
Say  '  workgroups carry mixed zones with +03:00 dominant. Both can be true only if some rows have'
Say  '  no zone at all - which matters, because the loop derives its window from this field. A'
Say  '  census answers it; a min() never could.'
$zoneRows = @()
if (Assert-SqlPresent 'zones' $zoneSql) { $zoneRows = @(Invoke-Sql $primary 'zones' $zoneSql $true) }
Say ('  measured : distinct zone values ' + $zoneRows.Count)
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  future-count rows         : ' + $futureRows.Count)
Say ('  sentinel rows read        : ' + $sentinelRows.Count)
Say ('  distinct TimeZone values  : ' + $zoneRows.Count)
Say  '  This replaces the pair of windows of the funnel probe, which could not discriminate because'
Say  '  this queue has traffic around the clock and therefore fills any half-hour window under both'
Say  '  hypotheses. The conclusion goes in the letter, from these numbers.'
Say '===== END-OF-RUN MARKER: WFMTIME-COMPLETE ====='
Finish (-not (Test-TrapFired))
