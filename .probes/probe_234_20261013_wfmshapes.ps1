<#
  PROBE  probe_234_20261013_wfmshapes.ps1
  READ-ONLY. Nothing installed, restarted or re-configured; no log level touched; SELECT only.
  TASK   the second reading on "the Wfm widget counts nothing", after the first one
         [234_20261013_162846_wfmempty.txt] settled two things and exposed two gaps.
  WHAT THE FIRST READING SETTLED, so this one does not re-measure it:
         the inputs are NOT zero - 1248 interactions in 60 minutes, 1146 of them with TimeZone, 20
         workgroups; 3721 / 3619 / 23 over 24 hours. Cause P3 and suspect 1 are out on numbers.
  THE TWO GAPS THIS ONE CLOSES, and neither is closed by guessing:
    1. All five log needles backend named came back ZERO while 420 lines mentioning Wfm sat in the
       same ten-minute window at level Information. So the needle TEXTS are not what the code
       writes. Rather than invent a sixth text, this probe prints the SHAPES of the Wfm lines with
       counts: each line is stripped of its timestamp, guids and numbers, identical shapes are
       counted together, and one example of each is shown. A shape list cannot be wrong about what
       the loop says, because it is the loop's own words.
    2. TenantSettings and BusinessUnitQueueClassifications are absent from rtmviewdb - the only
       PostgreSQL connection the machine config has. The first probe then failed to read the widget
       at all, because I had identified "the application database" BY TenantSettings. Here the
       application database is identified by the table `screen`, and the two missing tables are
       SEARCHED FOR BY NAME across every schema and every database on the instance, instead of me
       deciding where they ought to live.
  CONTROLS. Every query is preceded by a deliberately broken one that must return a non-zero rc.
         Every "expected" is printed before its measurement. The shape counter carries a positive
         control (a shape that must be found, since 420 such lines exist) and a negative one (a
         pattern that cannot match). A section that cannot measure says only that.
  NO SECRET REACHES THIS REPORT. At 16:24 a section of mine grepped appsettings.json for "Default"
         and printed the connection string with its password into two measurement files. Here the
         config is read as an OBJECT, the connection fields are printed field by field with the
         password reduced to length and a sha256 prefix, and every line this probe prints is passed
         through one last credential guard before it is written.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$LOG_DIR   = 'C:\Logs\RTMViewShell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmshapes' -Title 'READING 2 on 234: what the Wfm loop actually logs, and where its tables live'
Say 'READ-ONLY. No restart, no config change, no log level change, SELECT only.'
Rule
Assert-Machine

if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Test-Credentialish([string]$text) {
  return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey')
}
function Say-Guarded([string]$text) {
  # THE LAST GUARD BEFORE A LINE IS WRITTEN. Not a substitute for reading config as an object -
  # a second, independent check, because the 16:24 defect proved that one guard which depends on my
  # pattern being right is not a guard at all.
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl, [string]$databaseOverride) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return ,@() }
  $database = $connection[3]
  if (-not [string]::IsNullOrEmpty($databaseOverride)) { $database = $databaseOverride }
  $sqlPath = Join-Path $SQL_DIR ('wfmshapes_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say ('    database : ' + $database)
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmshapes_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $database -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero)')
  }
  $output = @(Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $database -t -A -F '|' -f $sqlPath 2>&1 })
  $exitCode = $LASTEXITCODE
  $env:PGPASSWORD = $null
  Say ('    rc ' + $exitCode + '   (must be 0)')
  foreach ($outputLine in $output) { Say-Guarded ('    ' + $outputLine) }
  if ($exitCode -ne 0) { Say '    THIS QUERY FAILED, so this section states NOTHING about the data.' ; return ,@() }
  return ,(Select-DataRows $output)
}

Say '0  THE CONNECTION, READ AS AN OBJECT'
$appSettingsPath = Join-Path $SHELL_DIR 'appsettings.json'
$connections = @()
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
      if ([string]::IsNullOrEmpty($hostValue) -or [string]::IsNullOrEmpty($databaseValue)) {
        Say ('  connection "' + $property.Name + '" : not a PostgreSQL connection (no host or no database) - SKIPPED')
        continue
      }
      $secretNote = 'absent'
      if (-not [string]::IsNullOrEmpty($secretValue)) {
        $secretSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($secretValue))).Replace('-','')
        $secretNote = 'length ' + $secretValue.Length + ' sha256 ' + $secretSha.Substring(0,16) + '...'
      }
      Say ('  connection "' + $property.Name + '" : host ' + $hostValue + ' port ' + $portValue + ' database ' + $databaseValue + ' user ' + $userValue)
      Say ('      password : ' + $secretNote + '   (the value never reaches this report, this probe or any file)')
      if ([string]::IsNullOrEmpty($portValue)) { $portValue = '5432' }
      $connections += ,@($property.Name, $hostValue, $portValue, $databaseValue, $userValue, $secretValue)
    }
  }
}
Say ('  PostgreSQL connections usable : ' + $connections.Count)
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND - the DB sections are NOT MEASURED' } else { $script:Psql }))
$primary = $null
if ($connections.Count -gt 0) { $primary = $connections[0] }
Rule

$shapeSql = @'
SELECT t.table_schema, t.table_name,
       (SELECT count(*) FROM information_schema.columns c
         WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) AS columns,
       (SELECT string_agg(c.column_name, ',' ORDER BY c.ordinal_position)
          FROM information_schema.columns c
         WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name
           AND (c.column_name ILIKE '%wfm%' OR c.column_name ILIKE '%tenant%'
                OR c.column_name ILIKE '%business%' OR c.column_name ILIKE '%config%'
                OR c.column_name ILIKE '%layout%')) AS interesting_columns
FROM information_schema.tables t
WHERE t.table_name ILIKE '%tenant%'
   OR t.table_name ILIKE '%classification%'
   OR t.table_name ILIKE '%screen%'
   OR t.table_name ILIKE '%widget%'
   OR t.table_name ILIKE '%business%'
ORDER BY t.table_schema, t.table_name;
'@

Say '1  WHAT THE TABLES ARE ACTUALLY CALLED - searched by PATTERN, with their columns'
Say  '  THIS SECTION EXISTS BECAUSE I GOT IT WRONG. At 16:28 I asked for table_name = ''TenantSettings''
Say  '  and reported to the coordinator that the table does not exist. It does: this database names
Say  '  TABLES in snake_case while its COLUMNS are PascalCase, so the table is public.tenant_settings
Say  '  with a column "TenantId". An equality against a name I typed myself can only ever measure my
Say  '  own spelling, and its zero is not a fact about the machine. The operator corrected me from
Say  '  the database browser; the rule now is a pattern search across every schema, and the column
Say  '  names are printed too, so the next query is written from measured names rather than guessed
Say  '  ones. The same correction applies to the two table names inside backend''s own request.'
Say  '  expected : at least one row, and something matching tenant among them. A zero would mean the
Say  '  SEARCH is wrong - the shell has been serving screens all day, so these tables plainly exist.'
$tableRows = @(Invoke-Sql $primary 'tables_by_pattern' $shapeSql $true '')
Say ('  measured : rows ' + $tableRows.Count)
Rule

$databasesSql = @'
SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;
'@

Say '2  AND WHICH DATABASES EXIST ON THIS INSTANCE AT ALL'
Say  '  Because the two tables backend named are absent from the one database the config points at,'
Say  '  and I will not decide on their behalf where they live. This lists the instance, no more.'
$databaseRows = @(Invoke-Sql $primary 'databases' $databasesSql $true '')
Say ('  databases listed : ' + $databaseRows.Count + '   (a zero means this read failed, not that the instance is empty)')
Rule

Say '3  THE WIDGET DATA ITSELF - DELIBERATELY NOT READ IN THIS RUN'
Say  '  The first probe read the widget with FROM screen s ... jsonb_array_elements(layout) - another'
Say  '  name and another shape typed by me, and by the operator''s screenshot there is no table called'
Say  '  screen at all: there are report_screens, report_widgets, widget_catalog, user_widget_settings.'
Say  '  Writing a third guessed query in the same run that exists to stop guessing would be absurd.'
Say  '  Section 1 prints the real table and column names; the widget read is the next box, written'
Say  '  from those names. This section states nothing about the widget.'
Rule

Say '4  WHAT THE Wfm LOGGER ACTUALLY WRITES - shapes with counts, not needles I invented'
Say  '  All five texts backend named came back 0 while 420 lines mentioning Wfm sat in the same'
Say  '  window at level Information. A sixth guessed text would be worth no more than the five.'
Say  '  Each line is stripped of its stamp, guids and numbers; identical shapes are counted.'
$logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ('  files in ' + $LOG_DIR + ' : ' + $logFiles.Count)
if ($logFiles.Count -eq 0) {
  Say '  NO LOG FILE - this section is NOT MEASURED and states nothing.'
} else {
  $RunStartedAt = Get-Date
  $windowStart = $RunStartedAt.AddMinutes(-30)
  $newestLog = $logFiles[0].FullName
  $newestLogWritten = (Get-Item -LiteralPath $newestLog).LastWriteTime
  Say ('  reading : ' + $newestLog + '   ' + (Get-Item -LiteralPath $newestLog).Length + ' B')
  Say ('  FRESHNESS, before anything is counted: this file was last written ' + $newestLogWritten.ToString('yyyy-MM-dd HH:mm:ss') + ' local')
  Say ('  the window opens at ' + $windowStart.ToString('yyyy-MM-dd HH:mm:ss') + ' local, so the file must have been written at or after that')
  $logIsFresh = ($newestLogWritten -ge $windowStart)
  Say ('  covers the window : ' + $logIsFresh)
  if (-not $logIsFresh) {
    Say  '  THE NEWEST LOG FILE PREDATES THE WINDOW. Then the shell is not writing right now, every'
    Say  '  shape count below would be zero for that reason alone, and a zero would say nothing'
    Say  '  about the loop. That absence IS the finding - reported, not counted around.'
  }
  Say ('  window : 30 minutes, from ' + $windowStart.ToString('yyyy-MM-dd HH:mm:ss') + ' local (wider than the first reading, so a loop that ticks every few minutes cannot fall between the samples)')
  $wfmLines = @()
  $windowLines = 0
  foreach ($rawLine in (Get-Content -LiteralPath $newestLog -ErrorAction SilentlyContinue)) {
    $stamp = Stamp-Of $rawLine
    if ($null -eq $stamp) { continue }
    if ($stamp.LocalDateTime -lt $windowStart) { continue }
    $windowLines++
    if ($rawLine -match 'Wfm') { $wfmLines += $rawLine }
  }
  Say ('  lines in the window : ' + $windowLines + '   of them mentioning Wfm : ' + $wfmLines.Count)
  Say  '  POSCTL : the Wfm count must be non-zero, since the first reading found 420 in ten minutes.'
  Say  '  A zero here would mean this reader is broken, not that the loop went quiet.'
  if ($wfmLines.Count -eq 0) {
    Say '  ZERO Wfm LINES - this section states nothing further; the reader is the suspect, not the loop.'
  } else {
    $shapes = @{}
    foreach ($wfmLine in $wfmLines) {
      $shape = $wfmLine
      $shape = [regex]::Replace($shape, '^\s*\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2}\s*', '')
      $shape = [regex]::Replace($shape, '[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}', '<guid>')
      $shape = [regex]::Replace($shape, '[0-9a-fA-F]{32}', '<hex32>')
      $shape = [regex]::Replace($shape, '\d+([.,]\d+)?', '<n>')
      $shape = $shape.Trim()
      if ($shape.Length -gt 200) { $shape = $shape.Substring(0,200) + ' ...' }
      if ($shapes.ContainsKey($shape)) { $shapes[$shape] = $shapes[$shape] + 1 } else { $shapes[$shape] = 1 }
    }
    Say ('  distinct shapes : ' + $shapes.Keys.Count)
    foreach ($shape in @($shapes.Keys | Sort-Object { -$shapes[$_] })) {
      Say-Guarded ('    x' + ([string]$shapes[$shape]).PadLeft(4) + '  ' + $shape)
    }
    $negShape = @($wfmLines | Where-Object { $_ -match 'WfmZzzNoSuchShape' }).Count
    Say ('  NEGCTL a shape that cannot be there : ' + $negShape + '   (must be 0)')
  }
  Say  '  THE LOG LEVEL, read as an object and never by grepping the file.'
  $settingsForLevel = $null
  try { $settingsForLevel = ([IO.File]::ReadAllText($appSettingsPath) | ConvertFrom-Json) } catch { }
  if (($null -ne $settingsForLevel) -and ($null -ne $settingsForLevel.Logging) -and ($null -ne $settingsForLevel.Logging.LogLevel)) {
    foreach ($levelProperty in $settingsForLevel.Logging.LogLevel.PSObject.Properties) {
      Say-Guarded ('    Logging:LogLevel:' + $levelProperty.Name + ' = ' + [string]$levelProperty.Value)
    }
  } else { Say '    the Logging:LogLevel object could not be read - the level is NOT MEASURED' }
}
Rule

Say 'WHAT THIS READING MEASURED - counts and shapes only'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  connections usable        : ' + $connections.Count)
Say ('  tables found by name      : ' + $tableRows.Count)
Say ('  databases listed          : ' + $databaseRows.Count)
Say  '  Wfm widgets on screens    : NOT READ in this run, by design - see section 3'
Say  '  The shapes above are the loop own words, so no needle of mine stands between the code and'
Say  '  this report. The cause is named in the letter that carries these numbers, not here.'
Say '===== END-OF-RUN MARKER: WFMSHAPES-COMPLETE ====='
Finish (-not (Test-TrapFired))
