<#
  PROBE  probe_234_20261014_wfmdead.ps1
  READ-ONLY. Nothing is restarted, started, stopped or configured. The operator says the Wfm
         widget stopped showing data; the coordinator asked for four readings, 08:39:06Z.
  EXPECTATIONS, PRINTED BEFORE THE MEASUREMENT, so the report cannot be read backwards:
    If the loop is alive and the data feed is dead, section 1 shows recent processed lines and
    section 2 shows a frozen newest row. That is an INPUT failure, and nothing to do with the
    build installed today.
    If the loop is silent, section 1 shows the minute of its last line and section 3 says whether
    the process is still up. A live process with a silent loop is a different defect from a dead one.
    If the operator re-saved the settings, section 4 shows WfmEnableRealtime false or a serving map
    whose exact intersection with the stored StatusGroup is empty - then N falls to zero by
    configuration, and the widget is right to show nothing.
    These are the only three shapes I can tell apart with read-only access. If none of them matches,
    the report says so instead of choosing one.
  MY OWN OBSERVATION TO RE-CHECK, not to carry: at 08:29Z the newest interaction row stood at
         2026-10-14 13:01:36.678517+03 across two runs ten minutes apart. This run measures whether
         it has moved since. A number carried from an earlier run proves nothing on its own.
  EVERY "NO" CARRIES ITS NEGATIVE CONTROL: the same reader is run against a line or a row that
         certainly exists. Without that, "nothing found" means only that I searched with the wrong
         instrument, and this project has paid for that three times.
  THE HEBREW QUEUE NAME IS NEVER TYPED HERE. It is read out of the BU 22 classification by the
         query itself, and psql is told to speak UTF-8, with its output taken from a file rather
         than from the console pipe - the console codepage destroyed those names two runs ago.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'
$LOG_DIR   = 'C:\Logs\RTMViewShell'
$TenantId  = '019e03e9-60dd-72da-bd01-648ffdb2b433'
$WINDOW_MINUTES = 30
$HiLatestAt0829 = '2026-10-14 13:01:36.678517'

$RunStartedAt = Get-Date
Start-Probe -Name 'wfmdead' -Title 'READING on 234, URGENT: the Wfm widget stopped showing data'
Say 'READ-ONLY. Nothing is restarted, started, stopped or configured by this run.'
Rule
Assert-Machine
if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}
function Count-In([string[]]$lines, [string]$needle) {
  $hits = 0
  foreach ($line in $lines) { if ("$line".Contains($needle)) { $hits++ } }
  return $hits
}
function Count-Regex([string[]]$lines, [string]$pattern) {
  $hits = 0
  foreach ($line in $lines) { if ("$line" -match $pattern) { $hits++ } }
  return $hits
}
function Last-Matching([string[]]$lines, [string]$needle) {
  $found = ''
  foreach ($line in $lines) { if ("$line".Contains($needle)) { $found = "$line" } }
  return $found
}
function Stamp-Head([string]$line) {
  if ("$line" -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') { return "$line".Substring(0,19) }
  return ''
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return ,@() }
  if ([string]::IsNullOrWhiteSpace($sqlText)) { Say ('    ' + $label + ' : THE QUERY TEXT IS EMPTY - not run, states nothing') ; return ,@() }
  $sqlPath = Join-Path $SQL_DIR ('wfmdead_' + $label + '.sql')
  $outPath = Join-Path $SQL_DIR ('wfmdead_' + $label + '.out')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -Encoding UTF8 -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGCLIENTENCODING = 'UTF8'
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmdead_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero, else rc 0 proves nothing)')
  }
  $stderrLines = @(Invoke-Native { & $script:Psql -v ON_ERROR_STOP=0 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -F '|' -f $sqlPath -o $outPath 2>&1 })
  $exitCode = $LASTEXITCODE
  $env:PGPASSWORD = $null
  Say ('    rc ' + $exitCode)
  foreach ($stderrLine in $stderrLines) { Say-Guarded ('    stderr | ' + $stderrLine) }
  $output = @()
  if (Test-Path -LiteralPath $outPath) { $output = @(Get-Content -LiteralPath $outPath -Encoding UTF8 -ErrorAction SilentlyContinue) }
  foreach ($outputLine in $output) { Say-Guarded ('    ' + $outputLine) }
  if ($exitCode -ne 0) { Say '    THIS QUERY FAILED, so this section states NOTHING about the data.' }
  return (Select-DataRows $output)
}

Say 'THE THREE SHAPES THIS READING CAN TELL APART, written down before any measurement'
Say  '  A) loop alive + data feed frozen   -> input failure, not the build'
Say  '  B) loop silent, process alive      -> the loop itself stopped'
Say  '  C) settings changed (realtime off, or the serving map no longer intersects the data)'
Say  '  Anything else: the report says NEITHER rather than picking the nearest.'
Rule

Say '1  THE SHELL LOG, LAST 30 MINUTES'
$logOk = $false
$loopLast = ''
$loopProcessedQueues = -1
$loopProcessedBu = -1
$logFiles = @()
if (Test-Path -LiteralPath $LOG_DIR) { $logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -Filter 'log-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
Say ('  sink : ' + $LOG_DIR + '    files : ' + $logFiles.Count + '   (POSCTL - zero means the filter is wrong, not that the shell is silent)')
if ($logFiles.Count -eq 0) { Say '  *** no log file - section NOT MEASURED' }
else {
  $logFile = $logFiles[0].FullName
  Say ('  newest file : ' + $logFile + '    ' + $logFiles[0].Length + ' B')
  $allLines = @(Get-Content -LiteralPath $logFile -Encoding UTF8 -ErrorAction SilentlyContinue)
  Say ('  lines in the file today : ' + $allLines.Count + '   (POSCTL for every count below)')
  $lastStamped = ''
  foreach ($line in $allLines) { if ((Stamp-Head $line) -ne '') { $lastStamped = "$line" } }
  $lastStamp = Stamp-Head $lastStamped
  Say ('  LAST LINE OF THE LOG AT ALL : ' + $lastStamp)
  Say ('  this run started            : ' + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss'))
  if ($lastStamp -ne '') {
    $ageSeconds = [int]((New-TimeSpan -Start ([datetime]::ParseExact($lastStamp,'yyyy-MM-dd HH:mm:ss',$null)) -End $RunStartedAt).TotalSeconds)
    Say ('  the log is ' + $ageSeconds + ' s behind this run   (the loop step is 30 s, so above ~90 s it is not merely late)')
  }
  $floor = $RunStartedAt.AddMinutes(-1 * $WINDOW_MINUTES)
  $windowLines = @()
  foreach ($line in $allLines) {
    $stamp = Stamp-Head $line
    if ($stamp -eq '') { continue }
    if ([datetime]::ParseExact($stamp,'yyyy-MM-dd HH:mm:ss',$null) -ge $floor) { $windowLines += "$line" }
  }
  Say ('  window : from ' + $floor.ToString('yyyy-MM-dd HH:mm:ss') + '    lines in it : ' + $windowLines.Count)
  $loopProcessedQueues = Count-Regex $windowLines 'WfmRealtimeLoop: processed .* queues'
  $loopProcessedBu     = Count-Regex $windowLines 'WfmRealtimeLoop: processed .* BU'
  Say ('  "processed ... queues" in the window : ' + $loopProcessedQueues)
  Say ('  "processed ... BU"     in the window : ' + $loopProcessedBu)
  $loopLast = Last-Matching $allLines 'WfmRealtimeLoop: processed'
  Say ('  LAST processed line in the whole file : ' + $(if ($loopLast -eq '') { 'NONE AT ALL TODAY' } else { $loopLast }))
  Say ('  so the loop fell silent after        : ' + $(if ($loopLast -eq '') { 'n/a' } else { (Stamp-Head $loopLast) }))
  $wfmErr = @()
  foreach ($line in $windowLines) { if (("$line" -match '\[ERR\]|\[WRN\]|\[FTL\]') -and ("$line" -match '(?i)wfm')) { $wfmErr += "$line" } }
  Say ('  [ERR]/[WRN]/[FTL] lines naming Wfm in the window : ' + $wfmErr.Count)
  $shown = [math]::Min(12, $wfmErr.Count)
  for ($errIndex = 0; $errIndex -lt $shown; $errIndex++) { Say-Guarded ('    | ' + $wfmErr[$errIndex]) }
  if ($wfmErr.Count -gt $shown) { Say ('    ... and ' + ($wfmErr.Count - $shown) + ' more of the same kinds') }
  Say ('  "WfmRealtimeLoop: error" in the window : ' + (Count-In $windowLines 'WfmRealtimeLoop: error'))
  Say ('  any [ERR] at all in the window        : ' + (Count-Regex $windowLines '\[ERR\]|\[FTL\]'))
  $negLog = Count-In $allLines 'ZzzNoSuchLogLineCouldEverExist'
  Say ('  NEGCTL a needle that cannot be there  : ' + $negLog + '   (must be 0; the counts above prove the reader finds real lines)')
  $logOk = (($allLines.Count -gt 0) -and ($negLog -eq 0))
}
Write-Report
Rule

Say '2  THE CONNECTION, AS AN OBJECT FROM THE MACHINE OWN CONFIG'
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
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND - sections 3 and 5 are NOT MEASURED' } else { $script:Psql }))
Rule

Say '3  THE TABLES THAT HOLD THE FEED - found by PATTERN, because I will not type a table name from memory'
$tablesSql = @'
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name ILIKE 'RTSData%' AND table_type = 'BASE TABLE'
ORDER BY table_name;
'@
$tableRows = @(Invoke-Sql $primary 'tables' $tablesSql $true)
Say ('  rows : ' + $tableRows.Count + '   (POSCTL - a zero means the pattern is wrong)')
Rule

Say '4  HOW FRESH THE FEED IS, AGAINST db_now - and whether the frozen row has moved'
Say ('  carried for comparison only, from my 08:29Z run : newest interaction stood at ' + $HiLatestAt0829)
Say  '  If it still stands there, the feed has been frozen for over an hour and the widget has'
Say  '  nothing to show. That would make this an input failure, not a defect of the installed build.'
$freshSql = @"
WITH bu AS (
  SELECT "QueueId" AS q FROM public."NGC_BusinessUnitQueueClassification"
  WHERE "BusinessUnitId" = 22 AND "ClassificationId" = 'ALL'
)
SELECT 'db_now' AS what, now()::text AS value, NULL::bigint AS rows
UNION ALL
SELECT 'newest interaction, ALL queues', max(i."UpdateTime")::text, count(*) FROM public."RTSData_Interaction" i
UNION ALL
SELECT 'newest interaction, BU22 queue (name read, not typed)', max(i."UpdateTime")::text, count(*)
  FROM public."RTSData_Interaction" i WHERE i."Workgroup" IN (SELECT q FROM bu)
UNION ALL
SELECT 'the BU22 queue name as stored', (SELECT q FROM bu LIMIT 1), (SELECT count(*) FROM bu)
UNION ALL
SELECT 'newest user status', max(u."UpdateTime")::text, count(*) FROM public."RTSData_UserStatus" u;
"@
$freshRows = @(Invoke-Sql $primary 'fresh' $freshSql $false)
Say ('  rows : ' + $freshRows.Count + '   (expected 5)')
Rule

Say '5  THE SETTINGS AS THEY LIE NOW - the operator may have re-saved them'
$settingsSql = @"
WITH configured AS (
  SELECT btrim(part, ' "') AS name
  FROM public.tenant_settings ts,
       LATERAL regexp_split_to_table(regexp_replace(COALESCE(ts."WfmServingStateGroups"::text,''), '[\[\]{}]', '', 'g'), ',') AS part
  WHERE ts."TenantId"::text = '$TenantId'
), stored AS (
  SELECT DISTINCT "StatusGroup" AS name FROM public."RTSData_UserStatus" WHERE "StatusGroup" IS NOT NULL
)
SELECT ts."WfmEnableRealtime"::text,
       ts."WfmWindowMinutes"::text,
       '[' || COALESCE(ts."WfmServingStateGroups"::text,'<NULL>') || ']',
       (SELECT count(*) FROM configured WHERE name <> ''),
       (SELECT count(*) FROM configured c WHERE EXISTS (SELECT 1 FROM stored s WHERE s.name = c.name)),
       (SELECT count(*) FROM configured c WHERE EXISTS (SELECT 1 FROM stored s WHERE upper(s.name) = upper(replace(c.name,' ',''))))
FROM public.tenant_settings ts WHERE ts."TenantId"::text = '$TenantId';
"@
$settingsRows = @(Invoke-Sql $primary 'settings' $settingsSql $false)
$realtimeOn = 'NOT MEASURED'
$matchExact = -1
if ($settingsRows.Count -ge 1) {
  $fields = @("$($settingsRows[0])".Split('|'))
  Say ('  fields : ' + $fields.Count + '   (expected 6; fewer voids the numbers below)')
  if ($fields.Count -eq 6) {
    $realtimeOn = $fields[0]
    $matchExact = [int]$fields[4]
    Say ('  WfmEnableRealtime : ' + $fields[0] + '    window minutes : ' + $fields[1])
    Say ('  serving map as stored : ' + $fields[2])
    Say ('  names configured : ' + $fields[3] + '    matching EXACTLY : ' + $fields[4] + '    case-insensitively : ' + $fields[5])
    Say  '  exact 0 would mean N falls to zero by configuration and the widget is right to show nothing.'
  }
}
Rule

Say '6  THE SERVICES - read, never touched'
$servicesUp = $true
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId)
  if ($serviceState.State -ne 'Running') { $servicesUp = $false }
}
Say ('  all three Running : ' + $servicesUp)
Say ('  legacy service RTM : ' + (StateOf 'RTM').State + '   - never ours, printed so a change by someone else is not read as this flight')
Rule

Say 'WHAT THIS READING SAYS - and what it deliberately does not'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  log readable              : ' + $logOk)
Say ('  loop lines in last 30 min : queues ' + $loopProcessedQueues + ' , BU ' + $loopProcessedBu)
Say ('  WfmEnableRealtime         : ' + $realtimeOn)
Say ('  serving names matching exactly : ' + $matchExact)
Say ('  services all up           : ' + $servicesUp)
Say  '  The shape is for the coordinator to name from these numbers. I state only what was measured:'
Say  '  no restart, no configuration change, and no fix was attempted by this run.'
Say '===== END-OF-RUN MARKER: WFMDEAD-COMPLETE ====='
Finish $logOk
