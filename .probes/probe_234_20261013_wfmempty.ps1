<#
  PROBE  probe_234_20261013_wfmempty.ps1
  READ-ONLY. Nothing is installed, restarted or re-configured; no log level is changed; the DB is
  touched with SELECT only. The only writes are this probe's report and its .sql files, each
  printed back from disk before it runs.
  TASK   coordinator 2026-10-13T13:04:12Z and 13:12:52Z, with his blessing on the reading. Operator:
         "the widget counts nothing, all data zeroed or absent". backend-0919 named four causes
         (P1 loop never started / P2 tenant disabled / P3 inputs are zero / P4 wrong key) and three
         suspects (empty TimeZone map, no ALL classification, snapshot key).
  WRITTEN FRESH, NOT PATCHED. The 16:0x version of this file died on the operator's parser with
         seven errors, and both causes were mine: I had rewritten its SQL call sites with a regular
         expression instead of writing them out, which left an unbalanced parenthesis and one call
         still unwrapped; and I had escaped single quotes inside PostgreSQL intervals the C way
         (\'60 minutes\') when PowerShell doubles them instead. Patching a patch is how both
         survived. Every query here is a HERE-STRING, where nothing needs escaping at all, and this
         file was parsed before it was handed out - see below.
  PARSED BEFORE HAND-OUT. Until today I had no PowerShell of my own and the parser gate lived only
         in the operator's box, so a syntax error cost him a run. PowerShell 7.4.6 now runs in my
         own environment and every probe is parsed there first. It is not 5.1, so it catches syntax
         rather than version differences - the box keeps its own ParseFile gate for that reason.
  NOTHING IS GUESSED. Two defects of mine today came from typing what I could have measured - nine
         wwwroot paths, and a DB role (ccdash) that does not exist on this machine. So:
           the log file is found by LISTING the directory, not by a name pattern. My disk probe
           searched *.log* in C:\Logs\RTMViewShell and reported 0 files; the shell writes
           log-YYYYMMDD.txt, so that zero was my pattern, not an empty directory;
           every connection is parsed out of the machine's own appsettings.json, each one NAMED
           with host/port/database/user - password only as length and a sha256 prefix - and the
           probe then ASKS each database which tables it has, instead of me deciding which one is
           "the emulation database";
           the BusinessUnitId key is asked for in both spellings, because I have not measured how
           that config is serialised and a guessed key would come back empty and look like data.
  THE NEGATIVE HALF OF EVERY ZERO, as the letter requires:
         each query is preceded by a deliberately broken one that must return a non-zero rc, or a
         zero from the real query only means psql started;
         for the log needles, a positive control - any line of the same logger in the same window.
         A log empty altogether means we measured log availability, not the loop;
         for the interactions, total is the live object: no interactions in the window makes a zero
         lambda correct and means there is no defect to find. The count is taken over 24 HOURS as
         well as 60 minutes, because it is evening here and an empty hour proves nothing;
         every "expected" is printed BEFORE its measurement.
  A SECTION THAT CANNOT MEASURE STATES NOTHING. At 15:47 a probe of mine printed "Wfm widgets
         found : 0" after its connection had been refused. Here every conclusion is gated on the
         flag of the read it rests on, and when a read fails the section says only that.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$LOG_DIR   = 'C:\Logs\RTMViewShell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmempty' -Title 'READING on 234: why the Wfm widget counts nothing'
Say 'READ-ONLY. No restart, no config change, no log level change, SELECT only.'
Rule
Assert-Machine

if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Show-FileFromDisk([string]$path) {
  foreach ($fileLine in (Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) { Say ('    | ' + $fileLine) }
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) {
    Say ('    ' + $label + ' : NOT MEASURED (no psql, or no connection carrying this table)')
    return @()
  }
  $sqlPath = Join-Path $SQL_DIR ('wfmempty_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  Show-FileFromDisk $sqlPath
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmempty_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero, or a zero below only means psql started)')
  }
  $output = @(Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -F '|' -f $sqlPath 2>&1 })
  $exitCode = $LASTEXITCODE
  $env:PGPASSWORD = $null
  Say ('    rc ' + $exitCode + '   (must be 0)')
  foreach ($outputLine in $output) { Say ('    ' + $outputLine) }
  if ($exitCode -ne 0) {
    Say '    THIS QUERY FAILED, so this section states NOTHING about the data.'
    return @()
  }
  return (Select-DataRows $output)
}

Say '0  THE CONNECTIONS, DISCOVERED FROM THE MACHINE CONFIG - not typed into this probe'
$appSettingsPath = Join-Path $SHELL_DIR 'appsettings.json'
Say ('  source : ' + $appSettingsPath + '   present ' + (Test-Path -LiteralPath $appSettingsPath))
$connections = @()
if (Test-Path -LiteralPath $appSettingsPath) {
  $settingsText = [IO.File]::ReadAllText($appSettingsPath)
  $settingsJson = $null
  try { $settingsJson = $settingsText | ConvertFrom-Json } catch { Say ('  appsettings.json does not parse as JSON: ' + $_.Exception.Message) }
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
      $secretNote = 'absent'
      if (-not [string]::IsNullOrEmpty($secretValue)) {
        $secretSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($secretValue))).Replace('-','')
        $secretNote = 'length ' + $secretValue.Length + ' sha256 ' + $secretSha.Substring(0,16) + '...'
      }
      Say ('  connection "' + $property.Name + '"')
      Say ('      host ' + $hostValue + '  port ' + $portValue + '  database ' + $databaseValue + '  user ' + $userValue)
      Say ('      password : ' + $secretNote + '   (the value never reaches this report or any file)')
      if ([string]::IsNullOrEmpty($portValue)) { $portValue = '5432' ; Say '      port absent in the string - using 5432 and saying so' }
      $connections += ,@($property.Name, $hostValue, $portValue, $databaseValue, $userValue, $secretValue)
    }
  } else { Say '  no ConnectionStrings section found' }
}
Say ('  connections found : ' + $connections.Count + '   (a zero means this section measured nothing and every DB row below is NOT MEASURED)')
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND under 18/17/16/15/14 - the DB sections are NOT MEASURED' } else { $script:Psql }))
Rule

$tablesSql = @'
SELECT
  (SELECT count(*) FROM information_schema.tables WHERE table_name = 'TenantSettings') AS tenant_settings,
  (SELECT count(*) FROM information_schema.tables WHERE table_name = 'RTSData_Interaction') AS interactions,
  (SELECT count(*) FROM information_schema.tables WHERE table_name = 'BusinessUnitQueueClassifications') AS classifications,
  (SELECT count(*) FROM information_schema.tables WHERE table_name = 'zzz_no_such_table') AS negctl;
'@

Say '1  WHICH CONNECTION HOLDS WHICH TABLE - asked, not assumed'
$appConnection = $null
$emulationConnection = $null
foreach ($connection in $connections) {
  Say ('  "' + $connection[0] + '" -> database ' + $connection[3])
  # A connection with no host or no database is not a PostgreSQL one - the Redis entry is in this
  # same section of appsettings.json. Running psql against it at 16:24 produced
  # 'could not translate host name "-p" to address', because an empty -h value let psql swallow the
  # next switch as the host name. A doomed query printed into a report is noise that looks like a
  # measurement, so such a connection is named and skipped.
  if ([string]::IsNullOrEmpty($connection[1]) -or [string]::IsNullOrEmpty($connection[3])) {
    Say '    not a PostgreSQL connection (no host or no database) - SKIPPED, not queried'
    continue
  }
  $rows = @(Invoke-Sql $connection ('tables_' + $connection[0]) $tablesSql $true)
  if ($rows.Count -gt 0) {
    $parts = ([string]$rows[0]).Split('|')
    Say ('    fields parsed from the row : ' + $parts.Count + '   (expected 4; a 1 here means the row came back as a string and was never really read - the unroll defect of 16:24)')
    if ($parts.Count -ge 4) {
      Say ('    TenantSettings ' + $parts[0] + '   RTSData_Interaction ' + $parts[1] + '   BusinessUnitQueueClassifications ' + $parts[2] + '   NEGCTL a table that cannot exist ' + $parts[3] + ' (must be 0)')
      if ($parts[0] -eq '1') { $appConnection = $connection }
      if ($parts[1] -eq '1') { $emulationConnection = $connection }
    }
  }
}
Say ('  the connection carrying TenantSettings      : ' + $(if ($null -eq $appConnection) { 'NONE FOUND' } else { $appConnection[0] }))
Say ('  the connection carrying RTSData_Interaction : ' + $(if ($null -eq $emulationConnection) { 'NONE FOUND' } else { $emulationConnection[0] }))
Rule

Say '2  THE SHELL LOG - the five needles, counted separately, over the last 10 minutes'
Say  '  The file is found by LISTING the directory. My disk probe searched *.log* here and reported'
Say  '  0 files; the shell writes log-YYYYMMDD.txt, so that zero was my pattern.'
$logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ('  files in ' + $LOG_DIR + ' : ' + $logFiles.Count)
foreach ($logFile in @($logFiles | Select-Object -First 5)) {
  Say ('    ' + $logFile.Name.PadRight(28) + ([string]$logFile.Length).PadLeft(12) + ' B   last written ' + $logFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + ' local')
}
$logLines = @()
$windowStart = (Get-Date).AddMinutes(-10)
if ($logFiles.Count -eq 0) {
  Say '  NO LOG FILE AT ALL - the needles below are NOT MEASURED, and that is a finding of its own'
} else {
  $newestLog = $logFiles[0].FullName
  Say ('  reading : ' + $newestLog)
  Say ('  window  : lines stamped at or after ' + $windowStart.ToString('yyyy-MM-dd HH:mm:ss') + ' local (this machine is UTC+3 and every line carries its own offset, which is parsed, not assumed)')
  foreach ($rawLine in (Get-Content -LiteralPath $newestLog -ErrorAction SilentlyContinue)) {
    $stamp = Stamp-Of $rawLine
    if ($null -eq $stamp) { continue }
    if ($stamp.LocalDateTime -ge $windowStart) { $logLines += $rawLine }
  }
  Say ('  lines inside the window : ' + $logLines.Count)
  Say  '  POSITIVE CONTROL: if this count is zero the log is simply not being written in this window,'
  Say  '  and we are measuring log availability rather than the loop.'
  $needles = @(
    @('WfmRealtimeLoop: starting', '>= 1, otherwise the loop never started'),
    @('processed .* queues for tenant', '> 0 while a tenant is enabled'),
    @('no TenantSettings for', '0'),
    @('WFM key collision', '0'),
    @('WfmRealtimeLoop: error', '0')
  )
  foreach ($needle in $needles) {
    $hits = @($logLines | Where-Object { $_ -match $needle[0] })
    Say ('    needle "' + $needle[0] + '"   expected ' + $needle[1])
    Say ('      measured : ' + $hits.Count)
    foreach ($hit in @($hits | Select-Object -First 3)) { Say ('        ' + $hit) }
  }
  $negNeedle = @($logLines | Where-Object { $_ -match 'WfmZzzNoSuchNeedle' }).Count
  Say ('    NEGCTL a needle that cannot be there : ' + $negNeedle + '   (must be 0, which proves the counts above are not matching everything)')
  $wfmAny = @($logLines | Where-Object { $_ -match 'Wfm' }).Count
  Say ('    POSCTL any line of this logger at all in the window : ' + $wfmAny + '   (a zero here with a non-zero line count above means the loop is silent, not that the log is dead)')
}
Say  '  THE ACTUAL LOG LEVEL - named, because Debug lines may simply not be written, and that is'
Say  '  itself an answer rather than a missing needle.'
if (Test-Path -LiteralPath $appSettingsPath) {
  foreach ($levelLine in @(Select-String -LiteralPath $appSettingsPath -Pattern 'LogLevel|"Default"|"Microsoft"|"CcDashboard"' -ErrorAction SilentlyContinue | Select-Object -First 12)) {
    Say ('    ' + $levelLine.Line.Trim())
  }
}
Rule

$tenantSql = @'
SELECT "TenantId","WfmEnableRealtime","WfmWindowMinutes","WfmSlTargetPct","WfmSlThresholdSec",
       "WfmTrunkCapacity","WfmServingStateGroups"
FROM "TenantSettings";
'@

Say '3  TenantSettings - is realtime on, and is the serving-state map non-empty'
Say  '  expected : WfmEnableRealtime true on at least one tenant, and WfmServingStateGroups NOT empty'
$tenantRows = @(Invoke-Sql $appConnection 'tenantsettings' $tenantSql $true)
Say ('  measured : rows ' + $tenantRows.Count)
if ($tenantRows.Count -eq 0) {
  Say '  NOT MEASURED or no rows - this section states nothing further.'
} else {
  $enabledCount = @($tenantRows | Where-Object { ([string]$_) -match '\|t\|' -or ([string]$_) -match '\|true\|' }).Count
  Say ('  rows with realtime enabled : ' + $enabledCount + '   (a zero here with rows present confirms cause P2, the tenant is disabled)')
}
Rule

$interactionSql = @'
SELECT
  '60min' AS window,
  COUNT(*) AS total,
  COUNT("TimeZone") AS with_tz,
  COUNT(DISTINCT "Workgroup") AS wg_total,
  COUNT(DISTINCT CASE WHEN "TimeZone" IS NOT NULL THEN "Workgroup" END) AS wg_with_tz
FROM public."RTSData_Interaction"
WHERE "InQueueDateTime" >= now() - interval '60 minutes'
UNION ALL
SELECT
  '24h' AS window,
  COUNT(*),
  COUNT("TimeZone"),
  COUNT(DISTINCT "Workgroup"),
  COUNT(DISTINCT CASE WHEN "TimeZone" IS NOT NULL THEN "Workgroup" END)
FROM public."RTSData_Interaction"
WHERE "InQueueDateTime" >= now() - interval '24 hours';
'@

Say '4  THE INPUTS - interactions over 60 MINUTES and over 24 HOURS'
Say  '  The 24-hour row is here because it is evening on this machine and an empty hour proves'
Say  '  nothing on its own. total is the live object: with no interactions in the window a zero'
Say  '  lambda is correct and there is no defect to find.'
Say  '  expected : total > 0 at least in the 24-hour row; with_tz > 0 and wg_with_tz > 0.'
Say  '  If total > 0 while with_tz = 0, suspect 1 - the empty TimeZone map - is CONFIRMED.'
$interactionRows = @(Invoke-Sql $emulationConnection 'interactions' $interactionSql $true)
Say ('  measured : rows ' + $interactionRows.Count)
Rule

$allSql = @'
SELECT COUNT(*) AS all_rows FROM "BusinessUnitQueueClassifications" WHERE "ClassificationId" = 'ALL';
'@
$allNegSql = @'
SELECT COUNT(*) AS zzz_rows FROM "BusinessUnitQueueClassifications" WHERE "ClassificationId" = 'ZZZ_NO_SUCH_ID';
'@

Say '5  THE ALL CLASSIFICATION - suspect 2'
Say  '  expected : > 0. A zero CONFIRMS suspect 2.'
$classRows = @(Invoke-Sql $emulationConnection 'classifications' $allSql $true)
Say  '  NEGCTL IN THE SAME SHAPE: the same count for an id that cannot exist must be 0, or the'
Say  '  predicate is matching everything rather than counting that one id.'
[void](Invoke-Sql $emulationConnection 'classifications_negctl' $allNegSql $false)
Rule

$widgetSql = @'
SELECT s.id AS screen_id,
       w -> 'config' ->> 'businessUnitId' AS bu_lower,
       w -> 'config' ->> 'BusinessUnitId' AS bu_upper
FROM screen s, jsonb_array_elements(s.layout::jsonb -> 'widgets') w
WHERE w ->> 'type' = 'wfm';
'@

Say '6  THE WIDGET BUSINESS UNIT - shell asked for this: does the loop build a snapshot for THAT key'
Say  '  Only the BusinessUnitId key of the widget config is read and printed, as the letter requires.'
Say  '  Both spellings are asked for because I have not measured how this config is serialised, and'
Say  '  a guessed key would come back empty and look like an answer.'
$buRows = @(Invoke-Sql $appConnection 'widget_bu' $widgetSql $true)
Say ('  Wfm widgets read : ' + $buRows.Count)
$buIds = @()
foreach ($buRow in $buRows) {
  foreach ($part in ([string]$buRow).Split('|')) {
    $trimmed = $part.Trim()
    if (($trimmed.Length -gt 0) -and ($trimmed -notmatch '^[0-9]+$')) { $buIds += $trimmed }
  }
}
$buIds = @($buIds | Sort-Object -Unique)
if ($buRows.Count -eq 0) {
  Say '  NOT MEASURED or no Wfm widget read - this section states nothing about whether a snapshot'
  Say '  is built, and nothing about whether a widget exists.'
} else {
  Say ('  distinct BusinessUnitId values : ' + $buIds.Count)
  foreach ($buId in $buIds) { Say ('    ' + $buId) }
  if ($logLines.Count -eq 0) {
    Say '  the log window is empty, so the snapshot question is NOT MEASURED here.'
  } else {
    foreach ($buId in $buIds) {
      $buHits = @($logLines | Where-Object { $_ -match [regex]::Escape($buId) })
      Say ('  log lines in the window mentioning ' + $buId + ' : ' + $buHits.Count)
      foreach ($buHit in @($buHits | Select-Object -First 3)) { Say ('      ' + $buHit) }
    }
    $setHits = @($logLines | Where-Object { $_ -match 'Set|processed' }).Count
    Say ('  log lines in the window carrying Set or processed : ' + $setHits)
  }
}
Rule

Say 'WHAT THIS READING MEASURED - counts only; the conclusion travels in the letter that carries it'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  connections discovered    : ' + $connections.Count)
Say ('  psql resolved             : ' + ($null -ne $script:Psql))
Say ('  log lines in the window   : ' + $logLines.Count)
Say ('  TenantSettings rows read  : ' + $tenantRows.Count)
Say ('  interaction rows read     : ' + $interactionRows.Count)
Say ('  classification rows read  : ' + $classRows.Count)
Say ('  Wfm widgets read          : ' + $buRows.Count)
Say  '  Every section that could not measure says so in its own place and states nothing about the'
Say  '  data. No row here is a verdict on the four causes - the numbers go to the coordinator and to'
Say  '  backend-0919, and the cause is named there, from these numbers.'
Say '===== END-OF-RUN MARKER: WFMEMPTY-COMPLETE ====='
Finish (-not (Test-TrapFired))
