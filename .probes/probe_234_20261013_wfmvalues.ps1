<#
  PROBE  probe_234_20261013_wfmvalues.ps1
  READ-ONLY. Nothing installed, restarted or re-configured; no log level touched; SELECT only.
  THE THIRD READING on "the Wfm widget counts nothing". Each one closed something, and this one is
  written entirely from names the previous run MEASURED - not one table or column here was typed by
  me from a letter or from code.
  WHAT IS ALREADY SETTLED, so none of it is re-measured:
    inputs are not zero      1248 interactions in 60 min, 1146 with TimeZone, 20 workgroups
                             [234_20261013_162846_wfmempty.txt]
    the loop is ALIVE        1260 of 1380 log lines in a 30-minute window are its own, every one of
                             them the SAME warning: "WfmInputQueryService: workgroup <name> has
                             mixed TimeZones, using dominant +HH:MM", 60 per workgroup across 21
                             workgroups - so it queries the inputs every ~30 s and it is reading
                             them [234_20261013_164124_wfmshapes.txt]
    and NOT ONE line reports a snapshot, a tenant or a queue count at level Information. The five
                             needles backend named appear nowhere, in any wording.
  THE REAL NAMES, measured by that run and used below as given:
    public.tenant_settings                      25 columns, among them WfmEnableRealtime,
                                                WfmWindowMinutes, WfmSlTargetPct, WfmSlThresholdSec,
                                                WfmTrunkCapacity, WfmServingStateGroups,
                                                WfmThresholds, WfmDefaultShrinkage
    public."NGC_BusinessUnitQueueClassification" singular, with an NGC_ prefix - not the plural
                                                "BusinessUnitQueueClassifications" of the request
    public.report_screens                       TenantId, LayoutJson
    public.report_widgets / dashboard_widgets   TenantId, ConfigJson
    Tables are snake_case, columns are PascalCase. An equality on a name I have not seen measures my
    own spelling: at 16:28 I reported tenant_settings as absent for exactly that reason, and the
    operator corrected me.
  WHAT IT ASKS, in this order:
    1. the Wfm configuration of every tenant - is realtime on, is the serving-state map non-empty;
    2. the COLUMNS of the classification table, printed before anything is counted in it, because
       I do not know what its classification column is called and will not guess twice;
    3. where a Wfm widget actually lives - LayoutJson and ConfigJson are searched for the string
       wfm, case-insensitively, and only the keys of the matching widget config are printed;
    4. whether ANY line of the shell log, over a full hour, reports a snapshot being built - by
       shape, not by a needle of mine.
  CONTROLS. Every query is preceded by a deliberately broken one that must return a non-zero rc.
         Every expectation is printed before its measurement. A section that cannot measure says so
         and states nothing. No value from a connection string reaches this report: the password is
         read as an object field and printed only as length and a sha256 prefix, and every line is
         passed through a credential guard before it is written.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$LOG_DIR   = 'C:\Logs\RTMViewShell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmvalues' -Title 'READING 3 on 234: the Wfm configuration, the widget, and whether a snapshot is ever logged'
Say 'READ-ONLY. No restart, no config change, no log level change, SELECT only.'
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
  $sqlPath = Join-Path $SQL_DIR ('wfmvalues_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmvalues_' + $label + '_negctl.sql')
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
      if ([string]::IsNullOrEmpty($hostValue) -or [string]::IsNullOrEmpty($databaseValue)) {
        Say ('  connection "' + $property.Name + '" : not a PostgreSQL connection - SKIPPED')
        continue
      }
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
Say ('  psql : ' + $(if ($null -eq $script:Psql) { 'NOT FOUND - the DB sections are NOT MEASURED' } else { $script:Psql }))
Rule

$tenantSql = @'
SELECT "TenantId",
       "WfmEnableRealtime",
       "WfmWindowMinutes",
       "WfmSlTargetPct",
       "WfmSlThresholdSec",
       "WfmTrunkCapacity",
       coalesce(nullif(btrim("WfmServingStateGroups"::text), ''), '<EMPTY>') AS serving_state_groups,
       coalesce(nullif(btrim("WfmThresholds"::text), ''), '<EMPTY>') AS thresholds,
       "WfmDefaultShrinkage"
FROM public.tenant_settings;
'@

Say '1  THE Wfm CONFIGURATION OF EVERY TENANT'
Say  '  expected : WfmEnableRealtime true on at least one tenant (a false everywhere IS cause P2),'
Say  '  and serving_state_groups NOT <EMPTY> - an empty map is what makes every served state'
Say  '  unclassifiable, which would produce exactly the zeros the operator sees.'
$tenantRows = @(Invoke-Sql $primary 'tenant_settings' $tenantSql $true)
Say ('  measured : rows ' + $tenantRows.Count)
Rule

$classColumnsSql = @'
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('NGC_BusinessUnitQueueClassification','NGC_BusinessUnit','tenant_agent_state_groups','tenant_agent_state_definitions')
ORDER BY table_name, ordinal_position;
'@

Say '2  THE COLUMNS OF THE CLASSIFICATION AND STATE-GROUP TABLES, BEFORE ANYTHING IS COUNTED IN THEM'
Say  '  backend asked for a count where "ClassificationId" = ''ALL'' in a table called'
Say  '  "BusinessUnitQueueClassifications". The table on this machine is singular and prefixed:'
Say  '  NGC_BusinessUnitQueueClassification. I do not know what its classification column is called,'
Say  '  and I have already reported one absence today that was really my own spelling. So the'
Say  '  columns are printed first and counted in the next box, not guessed in this one.'
$classColumns = @(Invoke-Sql $primary 'classification_columns' $classColumnsSql $true)
Say ('  measured : rows ' + $classColumns.Count + '   (a zero would mean the four names above are wrong too)')
Rule

$widgetSql = @'
SELECT 'report_screens' AS source, "TenantId"::text AS tenant, count(*) AS rows_with_wfm
FROM public.report_screens WHERE "LayoutJson"::text ILIKE '%wfm%' GROUP BY 1,2
UNION ALL
SELECT 'report_widgets', "TenantId"::text, count(*)
FROM public.report_widgets WHERE "ConfigJson"::text ILIKE '%wfm%' GROUP BY 1,2
UNION ALL
SELECT 'dashboard_widgets', "TenantId"::text, count(*)
FROM public.dashboard_widgets WHERE "ConfigJson"::text ILIKE '%wfm%' GROUP BY 1,2
UNION ALL
SELECT 'widget_templates', "TenantId"::text, count(*)
FROM public.widget_templates WHERE "ConfigJson"::text ILIKE '%wfm%' GROUP BY 1,2;
'@

Say '3  WHERE A Wfm WIDGET ACTUALLY LIVES - searched by content, across the four tables that carry config'
Say  '  expected : at least one row somewhere. A zero everywhere means no Wfm widget is configured'
Say  '  at all, and then the behavioural half has nothing to look at - which would be the answer,'
Say  '  not a failure. Only counts are read here; no config content is printed.'
$widgetRows = @(Invoke-Sql $primary 'wfm_widget_locations' $widgetSql $true)
Say ('  measured : rows ' + $widgetRows.Count)
Rule

Say '4  DOES ANY LINE IN A FULL HOUR REPORT A SNAPSHOT - by shape, not by a needle of mine'
Say  '  In the 30-minute window every one of 1260 Wfm lines was the same mixed-TimeZones warning.'
Say  '  Over an hour, this asks whether anything else is written AT ALL by that part of the product:'
Say  '  lines carrying snapshot, tenant, queue, realtime or loop, counted by shape.'
$logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if ($logFiles.Count -eq 0) {
  Say '  NO LOG FILE - NOT MEASURED.'
} else {
  $RunStartedAt = Get-Date
  $windowStart = $RunStartedAt.AddMinutes(-60)
  $newestLog = $logFiles[0].FullName
  $newestWritten = (Get-Item -LiteralPath $newestLog).LastWriteTime
  Say ('  reading : ' + $newestLog)
  Say ('  FRESHNESS : last written ' + $newestWritten.ToString('yyyy-MM-dd HH:mm:ss') + ' local; the window opens ' + $windowStart.ToString('yyyy-MM-dd HH:mm:ss') + ' local')
  Say ('  covers the window : ' + ($newestWritten -ge $windowStart))
  $interesting = @()
  $windowLines = 0
  foreach ($rawLine in (Get-Content -LiteralPath $newestLog -ErrorAction SilentlyContinue)) {
    $stamp = Stamp-Of $rawLine
    if ($null -eq $stamp) { continue }
    if ($stamp.LocalDateTime -lt $windowStart) { continue }
    $windowLines++
    if ($rawLine -match '(?i)snapshot|tenant|queue|realtime|loop') { $interesting += $rawLine }
  }
  Say ('  lines in the hour : ' + $windowLines + '   of them carrying one of those five words : ' + $interesting.Count)
  Say  '  POSCTL : the hour must contain lines at all - a zero means the reader is broken.'
  if ($interesting.Count -eq 0) {
    Say  '  NOT ONE line in a full hour mentions a snapshot, a tenant, a queue, realtime or a loop.'
    Say  '  Stated as a measured absence with its window named - not as a conclusion about why.'
  } else {
    $shapes = @{}
    foreach ($line in $interesting) {
      $shape = $line
      $shape = [regex]::Replace($shape, '^\s*\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2}\s*', '')
      $shape = [regex]::Replace($shape, '[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}', '<guid>')
      $shape = [regex]::Replace($shape, '[0-9a-fA-F]{32}', '<hex32>')
      $shape = [regex]::Replace($shape, '\d+([.,]\d+)?', '<n>')
      $shape = $shape.Trim()
      if ($shape.Length -gt 180) { $shape = $shape.Substring(0,180) + ' ...' }
      if ($shapes.ContainsKey($shape)) { $shapes[$shape] = $shapes[$shape] + 1 } else { $shapes[$shape] = 1 }
    }
    Say ('  distinct shapes : ' + $shapes.Keys.Count)
    foreach ($shape in @($shapes.Keys | Sort-Object { -$shapes[$_] })) {
      Say-Guarded ('    x' + ([string]$shapes[$shape]).PadLeft(5) + '  ' + $shape)
    }
    $negShape = @($interesting | Where-Object { $_ -match 'ZzzNoSuchShapeHere' }).Count
    Say ('  NEGCTL a shape that cannot be there : ' + $negShape + '   (must be 0)')
  }
}
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  tenant rows read          : ' + $tenantRows.Count)
Say ('  classification columns    : ' + $classColumns.Count)
Say ('  widget location rows      : ' + $widgetRows.Count)
Say  '  Every table and column named in this probe was MEASURED by the previous run, not typed from'
Say  '  a letter. Sections that could not measure say so. The cause is named in the letter that'
Say  '  carries these numbers, with backend-0919 in copy.'
Say '===== END-OF-RUN MARKER: WFMVALUES-COMPLETE ====='
Finish (-not (Test-TrapFired))
