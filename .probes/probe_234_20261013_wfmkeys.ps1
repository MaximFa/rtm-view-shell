<#
  PROBE  probe_234_20261013_wfmkeys.ps1
  READ-ONLY, SELECT only. Nothing installed, restarted or re-configured; no log level touched.
  TASK   coordinator 13:22:30Z and 13:51:23Z, ahead of the rest of the Wfm reading. shell has
         changed the key order of the Wfm widget: it was WfmQueueId first and BusinessUnit as the
         fallback, it is now BusinessUnit first and WfmQueueId the reserve. That change is safe
         ONLY IF, on the widgets that already exist, BusinessUnit is empty or equal to WfmQueueId.
         So this reads exactly those two fields, and nothing else of the config.
  THE TWO FIELDS AND NOTHING MORE. The letter says it twice, so the query is built to make it
         structurally impossible to print anything else: it does not select ConfigJson, it expands
         the config and keeps only the keys whose NAME matches queue or business. Even the key
         names are matched case-insensitively, because I have not measured how this config is
         serialised and a guessed spelling would come back empty and look like "no value set" -
         which is precisely the answer the letter is asking for, so a wrong guess here would be
         read as a finding.
  THE NEGATIVE HALF, as the letter requires: the same table counted WITHOUT the type filter. If
         "Wfm widgets: 0" ever appears, it has to stand beside a non-zero total, or it is a blind
         answer rather than a measurement.
  NAMES. public.dashboard_widgets and public."NGC_BusinessUnitQueueClassification" were MEASURED in
         the previous run [234_20261013_164647_wfmvalues.txt], with its columns BusinessUnitId
         (integer), QueueId, TenantId (uuid), ClassificationId. The BU table is searched by pattern
         rather than named, as the letter asks. Tables here are snake_case and columns PascalCase,
         except the NGC_ ones which are PascalCase throughout - which is why nothing in this probe
         is typed from memory: at 16:28 I reported a table as absent because I had typed its name.
  CONTROLS. Every query is preceded by a deliberately broken one that must return a non-zero rc.
         Each expectation is printed before its measurement. A section that cannot measure says so
         and states nothing. The password is read as an object field and only its length and sha256
         prefix are printed; every line passes a credential guard before it is written.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmkeys' -Title 'READING on 234: the Wfm widget key - WfmQueueId against BusinessUnit'
Say 'READ-ONLY, SELECT only. Two config fields are read and no others.'
Rule
Assert-Machine

if (-not (Test-Path -LiteralPath $SQL_DIR)) { New-Item -ItemType Directory -Force -Path $SQL_DIR | Out-Null }

function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}

$script:Psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $script:Psql = $candidate ; break }
}

function Invoke-Sql($connection, [string]$label, [string]$sqlText, [bool]$withNegativeControl) {
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return @() }
  $sqlPath = Join-Path $SQL_DIR ('wfmkeys_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmkeys_' + $label + '_negctl.sql')
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

$columnsSql = @'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'dashboard_widgets'
ORDER BY ordinal_position;
'@

Say '1  THE COLUMNS OF dashboard_widgets - printed before anything is read out of it'
Say  '  So that the screen id, the widget id and the type column are named by the database rather'
Say  '  than by me. Expected: a non-zero number of columns; a zero would mean the table name is'
Say  '  wrong, which is exactly the mistake I made this morning with tenant_settings.'
$columnRows = @(Invoke-Sql $primary 'columns' $columnsSql $true)
Say ('  measured : columns ' + $columnRows.Count)
Rule

$totalSql = @'
SELECT 'all widgets'  AS scope, count(*) AS rows FROM public.dashboard_widgets
UNION ALL
SELECT 'wfm widgets', count(*) FROM public.dashboard_widgets WHERE "ConfigJson"::text ILIKE '%wfm%';
'@

Say '2  THE NEGATIVE HALF FIRST - the whole table counted, then the Wfm subset'
Say  '  The letter asks for this explicitly: a "Wfm widgets 0" that does not stand beside a non-zero'
Say  '  total is a blind answer. Expected: all widgets > 0; the Wfm subset was 90 in the previous'
Say  '  run and should be of that order.'
$countRows = @(Invoke-Sql $primary 'counts' $totalSql $true)
Say ('  measured : rows ' + $countRows.Count + '   (expected 2)')
Rule

Say '3  THE TWO FIELDS, AND ONLY THEM'
Say  '  expected, in the words of the letter : WfmQueueId is a number (a BU id), and BusinessUnit is'
Say  '  either empty or the SAME number. A BusinessUnit set to a DIFFERENT value is what makes the'
Say  '  key-order change unsafe, and is the finding this reading exists for. The log line'
Say  '  SaveLayout ... hasBU=false from the previous reading points at empty.'
Say  '  Only keys whose NAME matches queue or business are expanded, so no other config value can'
Say  '  reach this report by the SHAPE of the query rather than by my care.'
Say  ''
Say  '  THE IDENTIFYING COLUMNS COME FROM SECTION 1, NOT FROM MY MEMORY. My first draft wrote'
Say  '  w.id and w.ScreenId from memory - the same move that had me report tenant_settings as'
Say  '  absent this morning. These names are taken from the measurement above.'
$columnNames = @()
foreach ($columnRow in $columnRows) { $columnNames += ([string]$columnRow).Split('|')[0] }
$widgetIdColumn = @($columnNames | Where-Object { $_ -match '(?i)^id$|widgetid' } | Select-Object -First 1)
$screenIdColumn = @($columnNames | Where-Object { $_ -match '(?i)screen' } | Select-Object -First 1)
$configColumn   = @($columnNames | Where-Object { $_ -match '(?i)config' } | Select-Object -First 1)
Say ('  widget id column : ' + $(if ($widgetIdColumn.Count -gt 0) { $widgetIdColumn[0] } else { 'NOT FOUND among the measured columns' }))
Say ('  screen id column : ' + $(if ($screenIdColumn.Count -gt 0) { $screenIdColumn[0] } else { 'NOT FOUND among the measured columns' }))
Say ('  config column    : ' + $(if ($configColumn.Count -gt 0) { $configColumn[0] } else { 'NOT FOUND among the measured columns' }))
$keyRows = @()
if (($configColumn.Count -eq 0) -or ($columnRows.Count -eq 0)) {
  Say  '  THE CONFIG COLUMN WAS NOT MEASURED, so this section is NOT MEASURED and states nothing.'
} else {
  $widgetSelect = $(if ($widgetIdColumn.Count -gt 0) { '"' + $widgetIdColumn[0] + '"::text' } else { '''<no id column>''' })
  $screenSelect = $(if ($screenIdColumn.Count -gt 0) { '"' + $screenIdColumn[0] + '"::text' } else { '''<no screen column>''' })
  $configName = $configColumn[0]
  $newline = [char]13 + [string][char]10
  $keysSql = 'SELECT ' + $widgetSelect + ' AS widget_id,' + $newline +
             '       ' + $screenSelect + ' AS screen_id,' + $newline +
             '       kv.key AS config_key,' + $newline +
             '       left(kv.value, 64) AS config_value' + $newline +
             'FROM public.dashboard_widgets w,' + $newline +
             '     LATERAL jsonb_each_text(w."' + $configName + '"::jsonb) AS kv' + $newline +
             'WHERE w."' + $configName + '"::text ILIKE ''%wfm%''' + $newline +
             '  AND (kv.key ILIKE ''%queue%'' OR kv.key ILIKE ''%business%'')' + $newline +
             'ORDER BY 1, 3;'
  $keyRows = @(Invoke-Sql $primary 'wfm_keys' $keysSql $true)
  Say ('  measured : key rows ' + $keyRows.Count)
  if ($keyRows.Count -eq 0) {
    Say  '  NO key named like queue or business on any Wfm widget. Read together with the counts of'
    Say  '  section 2 that means the field is ABSENT rather than empty - and with a non-zero Wfm'
    Say  '  subset there, the absence is the measurement, not a failure to look.'
  }
}
Rule

# THESE TWO DEFINITIONS WERE DELETED BY MY OWN EDIT, AND SECTION 4 RAN WITH EMPTY VARIABLES.
# The run of 16:56 wrote an EMPTY .sql file, psql executed it, returned rc 0 and no rows, and the
# section reported 0 (BU, classification) pairs - which I read as an empty table. It measured
# nothing at all. What exposed it was this probe's own convention of printing the query back FROM
# DISK: no query text in the report means no query was run. Keep that convention; it is the only
# reason a silent nothing did not become a fact in a letter.
$classSql = @'
SELECT "BusinessUnitId", "ClassificationId", count(*) AS rows
FROM public."NGC_BusinessUnitQueueClassification"
GROUP BY 1, 2
ORDER BY 1, 2;
'@

$classAllSql = @'
SELECT 'ALL rows' AS scope, count(*) AS rows FROM public."NGC_BusinessUnitQueueClassification" WHERE "ClassificationId" = 'ALL'
UNION ALL
SELECT 'rows in total', count(*) FROM public."NGC_BusinessUnitQueueClassification"
UNION ALL
SELECT 'NEGCTL id that cannot exist', count(*) FROM public."NGC_BusinessUnitQueueClassification" WHERE "ClassificationId" = 'ZZZ_NO_SUCH_ID';
'@

# AND A GUARD, so an empty query can never again be run as if it were one.
function Assert-SqlPresent([string]$name, [string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) {
    Say ('    ' + $name + ' : THE QUERY TEXT IS EMPTY - not run. This section is NOT MEASURED and states nothing.')
    return $false
  }
  return $true
}
Say '4  THE CLASSIFICATIONS - by BU and by classification, then the ALL count with its controls'
Say  '  expected : for the BU of the widget in section 3 there is at least one ALL row. A zero'
Say  '  there means the aggregate for that BU is never built - which would be a cause, not a'
Say  '  detail. The total and the impossible id stand beside it so neither zero can be blind.'
$classRows = @()
if (Assert-SqlPresent 'classifications_by_bu' $classSql) { $classRows = @(Invoke-Sql $primary 'classifications_by_bu' $classSql $true) }
Say ('  measured : (BU, classification) pairs ' + $classRows.Count)
$classAllRows = @()
if (Assert-SqlPresent 'classifications_all' $classAllSql) { $classAllRows = @(Invoke-Sql $primary 'classifications_all' $classAllSql $true) }
Say ('  measured : rows ' + $classAllRows.Count + '   (expected 3)')
Rule

$buSql = @'
SELECT t.table_name,
       (SELECT string_agg(c.column_name, ',' ORDER BY c.ordinal_position)
          FROM information_schema.columns c
         WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name) AS columns
FROM information_schema.tables t
WHERE t.table_schema = 'public' AND t.table_name ILIKE '%business%unit%'
ORDER BY t.table_name;
'@

Say '5  THE BUSINESS-UNIT TABLE ITSELF - found by pattern, as the letter asks, with its columns'
Say  '  Its id and its active flag are what section 4 has to be read against. The columns are'
Say  '  printed here; the values are the next box, not a guess in this one.'
$buRows = @(Invoke-Sql $primary 'business_unit_tables' $buSql $true)
Say ('  measured : tables ' + $buRows.Count + '   (a zero would mean the pattern is wrong, not that there is no BU table)')
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run      : ' + (Test-TrapFired))
Say ('  dashboard_widgets columns      : ' + $columnRows.Count)
Say ('  count rows (all vs wfm)        : ' + $countRows.Count)
Say ('  config key rows (queue/business only) : ' + $keyRows.Count)
Say ('  (BU, classification) pairs     : ' + $classRows.Count)
Say ('  business-unit tables found     : ' + $buRows.Count)
Say  '  Two config fields were read and no others, by the shape of the query. Every table and column'
Say  '  was measured before it was used. The conclusion travels in the letter, not here.'
Say '===== END-OF-RUN MARKER: WFMKEYS-COMPLETE ====='
Finish (-not (Test-TrapFired))
