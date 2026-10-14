<#
  PROBE  probe_234_20261014_feedstall.ps1
  READ-ONLY. The production adapter is NOT ours: nothing is restarted, stopped, reconfigured or
         even opened for writing. Logs are read, nothing else.
  TWO READINGS, from coordinator 2026-10-14T08:46:50Z:
    1. PR234-FEED-STALL-01: the adapter log and the RTMService engine log over the stall window -
       a break, errors, reconnects to the source.
    2. For the backend N stage: how many agents carry the BU 22 skill, and what the BU 22
       supergroup is made of.
  THE CLOCKS, AND WHY THE WINDOW IS WIDE. The feed stores stamps about two hours AHEAD of db_now
         (measured twice today: db_now 11:43:17+03 against a newest row of 13:43:14+03). So the
         stall, seen in DATA time as 13:01:36 -> 13:43:14, has two possible readings in real time:
           taken at face value, +03 offset  : 10:01:36Z -> 10:43:14Z
           corrected by the measured 2 h    : 08:01:36Z -> 08:43:14Z
         I do not know which clock the LOGS use, and guessing picks one hour to search and
         guarantees "no trace" from the other. So the search window is the UNION of both, widened
         by 20 minutes at each end, and it is printed before the measurement. A "no trace" verdict
         is stated together with the window it covers, never alone.
  THE LOG FORMAT IS DISCOVERED, NOT ASSUMED: the first lines of each file are printed so the
         reader can check the timestamp shape the counters rely on, and the count of lines whose
         stamp PARSED is its own positive control. A zero there means my parse is wrong, not that
         the adapter was silent - those are different findings and this probe keeps them apart.
  THE BREAK IS FOUND BY ARITHMETIC, not by eye: the largest gaps between consecutive parsed
         timestamps are printed with their boundaries. A silent adapter leaves a gap; a busy one
         does not.
  THE HEBREW SKILL NAME IS NEVER TYPED: it is read out of the BU 22 classification by the query.
  CARRIED, NOT RE-MEASURED, and labelled as such: roster 41 and 25 agents fresher than 15 min,
         from the metrics run of 08:17Z. I state them as comparison only.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR   = 'C:\RTMView\Shell'
$SQL_DIR     = 'C:\RTMView-Ops\probes'
$ADAPTER_DIR = 'C:\RTMView\RTM.Twilio'
$ENGINE_DIR  = 'C:\RTMView\RTM'
$TenantId    = '019e03e9-60dd-72da-bd01-648ffdb2b433'
$RosterCarried    = 41
$FreshCarried     = 25
$StallFromData = '2026-10-14 13:01:36'
$StallToData   = '2026-10-14 13:43:14'
$MeasuredAheadHours = 2

$RunStartedAt = Get-Date
Start-Probe -Name 'feedstall' -Title 'READING on 234: PR234-FEED-STALL-01 in the adapter and engine logs, and the BU 22 skill roster'
Say 'READ-ONLY. The production adapter is not ours - nothing is restarted, stopped or reconfigured.'
Rule
Assert-Machine
if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey|authtoken') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}
function Parse-Stamp([string]$line) {
  $match = [regex]::Match("$line", '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})')
  if ($match.Success) {
    $candidate = $match.Groups[1].Value.Replace('T',' ')
    try { return [datetime]::ParseExact($candidate, 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
  }
  $dotted = [regex]::Match("$line", '(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2})')
  if ($dotted.Success) {
    try { return [datetime]::ParseExact($dotted.Groups[1].Value, 'dd.MM.yyyy HH:mm:ss', $null) } catch { return $null }
  }
  return $null
}
function Count-Regex([string[]]$lines, [string]$pattern) {
  $hits = 0
  foreach ($line in $lines) { if ("$line" -match $pattern) { $hits++ } }
  return $hits
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return ,@() }
  if ([string]::IsNullOrWhiteSpace($sqlText)) { Say ('    ' + $label + ' : THE QUERY TEXT IS EMPTY - not run, states nothing') ; return ,@() }
  $sqlPath = Join-Path $SQL_DIR ('feedstall_' + $label + '.sql')
  $outPath = Join-Path $SQL_DIR ('feedstall_' + $label + '.out')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -Encoding UTF8 -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGCLIENTENCODING = 'UTF8'
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('feedstall_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero)')
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

Say '0  THE CLOCKS, AND THE SEARCH WINDOW DERIVED FROM THEM - printed before any log is opened'
$stallFrom = [datetime]::ParseExact($StallFromData, 'yyyy-MM-dd HH:mm:ss', $null)
$stallTo   = [datetime]::ParseExact($StallToData,   'yyyy-MM-dd HH:mm:ss', $null)
Say ('  the stall, in DATA time (stamps as they are stored, offset +03) : ' + $stallFrom.ToString('HH:mm:ss') + ' -> ' + $stallTo.ToString('HH:mm:ss'))
Say  '  reading 1, stamps taken at face value: real local = data time, so'
Say ('    local ' + $stallFrom.ToString('HH:mm:ss') + ' -> ' + $stallTo.ToString('HH:mm:ss') + '   = UTC ' + $stallFrom.AddHours(-3).ToString('HH:mm:ss') + ' -> ' + $stallTo.AddHours(-3).ToString('HH:mm:ss') + 'Z')
Say ('  reading 2, corrected by the measured ' + $MeasuredAheadHours + ' h the feed runs ahead of db_now:')
Say ('    local ' + $stallFrom.AddHours(-1*$MeasuredAheadHours).ToString('HH:mm:ss') + ' -> ' + $stallTo.AddHours(-1*$MeasuredAheadHours).ToString('HH:mm:ss') + '   = UTC ' + $stallFrom.AddHours(-1*$MeasuredAheadHours-3).ToString('HH:mm:ss') + ' -> ' + $stallTo.AddHours(-1*$MeasuredAheadHours-3).ToString('HH:mm:ss') + 'Z')
$searchFrom = $stallFrom.AddHours(-1*$MeasuredAheadHours).AddMinutes(-20)
$searchTo   = $stallTo.AddMinutes(20)
Say  '  I do not know which clock the LOGS keep, and picking one guarantees a false "no trace"'
Say  '  from the other hour. So the window searched below is the UNION of both readings, widened'
Say  '  by 20 minutes at each end, in MACHINE LOCAL time, which is what the logs are written in:'
Say ('    SEARCH WINDOW (local) : ' + $searchFrom.ToString('yyyy-MM-dd HH:mm:ss') + '  ->  ' + $searchTo.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('    the same window in UTC : ' + $searchFrom.AddHours(-3).ToString('HH:mm:ss') + 'Z -> ' + $searchTo.AddHours(-3).ToString('HH:mm:ss') + 'Z')
Say  '  Every "no trace" below is stated together with this window, never on its own.'
Rule

function Read-LogSection([string]$title, [string]$root) {
  Say $title
  if (-not (Test-Path -LiteralPath $root)) { Say ('  ' + $root + ' does not exist - NOT MEASURED') ; Rule ; return }
  $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Include *.log,*.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  Say ('  files under ' + $root + ' : ' + $files.Count + '   (POSCTL - a zero means the filter is wrong, not that the component is silent)')
  $listed = [math]::Min(6, $files.Count)
  for ($fileIndex = 0; $fileIndex -lt $listed; $fileIndex++) {
    Say ('    ' + $files[$fileIndex].FullName + '   ' + $files[$fileIndex].Length + ' B   ' + $files[$fileIndex].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
  }
  if ($files.Count -eq 0) { Rule ; return }
  $logFile = $files[0].FullName
  Say ('  reading the newest : ' + $logFile)
  $allLines = @(Get-Content -LiteralPath $logFile -Encoding UTF8 -ErrorAction SilentlyContinue -Tail 60000)
  Say ('  lines read (tail 60000) : ' + $allLines.Count)
  Say  '  the first three lines as they are, so the timestamp shape my counters rely on is visible:'
  $sampleCount = [math]::Min(3, $allLines.Count)
  for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) { Say-Guarded ('    | ' + $allLines[$sampleIndex]) }
  $stamps = @()
  $windowLines = @()
  $parsed = 0
  foreach ($line in $allLines) {
    $stamp = Parse-Stamp $line
    if ($null -eq $stamp) { continue }
    $parsed++
    if (($stamp -ge $searchFrom) -and ($stamp -le $searchTo)) {
      $stamps += $stamp
      $windowLines += "$line"
    }
  }
  Say ('  lines whose stamp PARSED : ' + $parsed + '   (POSCTL - zero means my parse is wrong, NOT that the log is empty)')
  Say ('  lines inside the search window : ' + $windowLines.Count)
  if ($parsed -eq 0) { Say '  *** the timestamp shape is not one I parse - this section is NOT MEASURED' ; Rule ; return }
  if ($windowLines.Count -eq 0) {
    Say ('  NO LINE AT ALL inside ' + $searchFrom.ToString('HH:mm:ss') + ' -> ' + $searchTo.ToString('HH:mm:ss') + ' local, while ' + $parsed + ' lines elsewhere parsed fine.')
    Say  '  That is itself a measurement: the component wrote nothing in the window searched.'
  } else {
    $sorted = @($stamps | Sort-Object)
    Say ('  first in window : ' + $sorted[0].ToString('yyyy-MM-dd HH:mm:ss') + '    last in window : ' + $sorted[$sorted.Count-1].ToString('yyyy-MM-dd HH:mm:ss'))
    $gaps = @()
    for ($gapIndex = 1; $gapIndex -lt $sorted.Count; $gapIndex++) {
      $seconds = [int](New-TimeSpan -Start $sorted[$gapIndex-1] -End $sorted[$gapIndex]).TotalSeconds
      if ($seconds -gt 0) { $gaps += ,@($seconds, $sorted[$gapIndex-1], $sorted[$gapIndex]) }
    }
    Say  '  THE BREAK IS FOUND BY ARITHMETIC: the largest gaps between consecutive stamps in the'
    Say  '  window. A silent component leaves a gap; a busy one does not.'
    $ranked = @($gaps | Sort-Object { -1 * $_[0] })
    $topCount = [math]::Min(5, $ranked.Count)
    if ($topCount -eq 0) { Say '    no measurable gap (all stamps within the same second)' }
    for ($rankIndex = 0; $rankIndex -lt $topCount; $rankIndex++) {
      Say ('    gap ' + ([string]$ranked[$rankIndex][0]).PadLeft(6) + ' s   from ' + $ranked[$rankIndex][1].ToString('HH:mm:ss') + ' to ' + $ranked[$rankIndex][2].ToString('HH:mm:ss'))
    }
    Say ('  lines naming an error    : ' + (Count-Regex $windowLines '(?i)\bERROR\b|\[ERR\]|\bFATAL\b|\bexception\b'))
    Say ('  lines naming a reconnect : ' + (Count-Regex $windowLines '(?i)reconnect|re-connect|connection lost|disconnected|closed|retry|resubscrib'))
    Say ('  lines naming the source  : ' + (Count-Regex $windowLines '(?i)twilio|signalr|websocket|subscri'))
    $negNeedle = Count-Regex $windowLines 'ZzzNoSuchLogLineCouldEverExist'
    Say ('  NEGCTL a needle that cannot be there : ' + $negNeedle + '   (must be 0, and the counts above prove the reader finds real lines)')
    $interesting = @()
    foreach ($line in $windowLines) { if ("$line" -match '(?i)\bERROR\b|\[ERR\]|\bFATAL\b|\bexception\b|reconnect|connection lost|disconnected|retry') { $interesting += "$line" } }
    $showCount = [math]::Min(15, $interesting.Count)
    if ($showCount -gt 0) { Say '  the lines themselves, up to fifteen:' }
    for ($showIndex = 0; $showIndex -lt $showCount; $showIndex++) { Say-Guarded ('    | ' + $interesting[$showIndex]) }
    if ($interesting.Count -gt $showCount) { Say ('    ... and ' + ($interesting.Count - $showCount) + ' more') }
  }
  Write-Report
  Rule
}

Read-LogSection '1a  THE ADAPTER LOG - read only, the production adapter is not ours' $ADAPTER_DIR
Read-LogSection '1b  THE ENGINE LOG (RTMService) - read only' $ENGINE_DIR

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
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND - the SQL sections are NOT MEASURED' } else { $script:Psql }))
Rule

Say '3  THE BU 22 SKILL ROSTER - for the backend N stage'
Say ('  CARRIED for comparison only, from the metrics run at 08:17Z, NOT re-measured here:')
Say ('    roster ' + $RosterCarried + ' , of them fresher than 15 min ' + $FreshCarried)
Say  '  EXPECTED, from the coordinator: one agent group in the BU 22 supergroup, and it is the'
Say  '  same name as the BU 22 queue. The skill name is read by the query, never typed by me.'
$skillSql = @"
WITH bu AS (
  SELECT "QueueId" AS q FROM public."NGC_BusinessUnitQueueClassification"
  WHERE "BusinessUnitId" = 22 AND "ClassificationId" = 'ALL'
)
SELECT 'the BU22 queue name as stored' AS what, (SELECT q FROM bu LIMIT 1) AS value, (SELECT count(*) FROM bu) AS n
UNION ALL
SELECT 'agents in NGC_UserAgentgroup with that agentgroup', NULL, count(*)
  FROM public."NGC_UserAgentgroup" ua WHERE ua."AgentgroupId" IN (SELECT q FROM bu)
UNION ALL
SELECT 'distinct users there', NULL, count(DISTINCT ua."UserId")
  FROM public."NGC_UserAgentgroup" ua WHERE ua."AgentgroupId" IN (SELECT q FROM bu)
UNION ALL
SELECT 'rows in NGC_UserAgentgroup altogether (POSCTL)', NULL, count(*) FROM public."NGC_UserAgentgroup";
"@
$skillRows = @(Invoke-Sql $primary 'skill' $skillSql $true)
Say ('  rows : ' + $skillRows.Count + '   (expected 4)')
Rule

Say '4  THE BU 22 SUPERGROUP - how many agent groups, and which'
$supergroupSql = @"
SELECT sg."SupergroupId"::text, ag."AgentgroupId"::text
FROM public."NGC_BusinessUnitSupergroup" sg
LEFT JOIN public."NGC_SupergroupAgentgroup" ag ON ag."SupergroupId" = sg."SupergroupId"
WHERE sg."BusinessUnitId" = 22
ORDER BY 1, 2;
"@
$supergroupRows = @(Invoke-Sql $primary 'supergroup' $supergroupSql $false)
Say ('  rows : ' + $supergroupRows.Count + '   (the coordinator expects one agent group, named as the BU 22 queue)')
Say ('  POSCTL, so a small number above cannot be read as an empty table:')
$posctlSql = @'
SELECT 'rows in NGC_BusinessUnitSupergroup' AS what, count(*)::text FROM public."NGC_BusinessUnitSupergroup"
UNION ALL
SELECT 'rows in NGC_SupergroupAgentgroup', count(*)::text FROM public."NGC_SupergroupAgentgroup";
'@
[void](Invoke-Sql $primary 'posctl' $posctlSql $false)
Rule

Say 'WHAT THIS READING SAYS'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  search window (local)     : ' + $searchFrom.ToString('HH:mm:ss') + ' -> ' + $searchTo.ToString('HH:mm:ss') + '   - every "no trace" above means ONLY inside this window')
Say  '  No restart, no configuration change, nothing written. The production adapter was read and'
Say  '  nothing else. Naming the cause of the stall is the coordinator call, not mine.'
Say '===== END-OF-RUN MARKER: FEEDSTALL-COMPLETE ====='
Finish (-not (Test-TrapFired))
