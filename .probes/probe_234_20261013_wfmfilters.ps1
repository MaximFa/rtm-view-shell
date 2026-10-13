<#
  PROBE  probe_234_20261013_wfmfilters.ps1
  READ-ONLY, SELECT only. Nothing installed, restarted or re-configured; no log level touched.
  TASK   coordinator 2026-10-13T14:14:55Z, after reading WfmInputQueryService.cs. A row reaches
         lambda only if it carries the exact strings Direction = 'Incoming', InteractionType IN
         ('Call','Callback'), CallType = 'External' (:63-70). An agent counts towards N only if
         RTSData_UserStatus."StatusGroup" is exactly one of {Available, "On Phone", Paperwork}
         (:244). The ASD legend on the same screen shows the groups as AVAILABLE, ONPHONE,
         PAPERWORK - and if that is how they are stored, N = 0, State = NoData, and the widget
         shows zeros on live traffic.
  SO THIS PROBE PRINTS THE VALUES AS THEY ARE STORED, IN BRACKETS, WITH COUNTS. Not whether they
         match a list I typed - the comparison is the easy part and the one I could get wrong by
         spelling. The report shows what is in the column; the match is then read off by eye and by
         backend against the code, which is where the expected spelling actually lives.
  THE QUEUE NAME IS NOT TYPED. It is taken from the classification of BU 22, the same way the
         previous reading did. This morning I reported a table as absent because I had typed its
         name; nothing here is typed that can be measured.
  THE NEGATIVE HALF of each section, as the letter requires: section 1 counts ALL rows of the
         tenant, so a short list of groups cannot be read as an empty table; section 2 sums its
         own rows, and that sum must equal the number of interactions in the same window for the
         same queue - the previous reading measured 27, and this one re-takes it rather than
         carrying the number, because the window moves.
  CONTROLS. A deliberately broken query first, which must return a non-zero rc. No query runs
         unless its text is present. The password is read as an object field and only its length
         and sha256 prefix are printed; every line passes a credential guard.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmfilters' -Title 'READING on 234: the filter funnel - stored StatusGroup and interaction attribute values'
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
    Say ('    ' + $name + ' : THE QUERY TEXT IS EMPTY - not run. This section is NOT MEASURED and states nothing.')
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
  $sqlPath = Join-Path $SQL_DIR ('wfmfilters_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmfilters_' + $label + '_negctl.sql')
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

$statusColumnsSql = @'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'RTSData_UserStatus'
ORDER BY ordinal_position;
'@

Say '1  THE COLUMNS OF RTSData_UserStatus - before anything is read out of it'
Say  '  expected : a non-zero number of columns, with something called StatusGroup among them. A'
Say  '  zero means the table name is wrong - the mistake I made this morning with tenant_settings.'
$statusColumns = @()
if (Assert-SqlPresent 'status_columns' $statusColumnsSql) { $statusColumns = @(Invoke-Sql $primary 'status_columns' $statusColumnsSql $true) }
Say ('  measured : columns ' + $statusColumns.Count)
Rule

$statusGroupsSql = @'
SELECT '[' || coalesce("StatusGroup", '<NULL>') || ']' AS status_group_as_stored,
       count(*) AS rows
FROM public."RTSData_UserStatus"
GROUP BY 1
UNION ALL
SELECT '== all rows of the table (the negative half) ==', count(*)
FROM public."RTSData_UserStatus"
ORDER BY 2 DESC;
'@

Say '2  THE StatusGroup VALUES AS THEY ARE STORED, IN BRACKETS, WITH COUNTS'
Say  '  The serving-state map of the tenant is {Available, "On Phone", Paperwork} and the comparison'
Say  '  in the loop is exact. The ASD legend on the same screen shows AVAILABLE, ONPHONE, PAPERWORK.'
Say  '  expected : if not one value here is exactly Available, On Phone or Paperwork, then N = 0 for'
Say  '  every agent, State becomes NoData, and the zeros on a live queue are explained.'
Say  '  The brackets are put there by the query, so a trailing space or a capital letter is visible'
Say  '  in the report rather than lost to the eye. The total row is the negative half: a short list'
Say  '  of groups beside a zero total would mean an empty table, not a naming problem.'
$statusGroups = @()
if (Assert-SqlPresent 'status_groups' $statusGroupsSql) { $statusGroups = @(Invoke-Sql $primary 'status_groups' $statusGroupsSql $true) }
Say ('  measured : rows ' + $statusGroups.Count + '   (distinct groups plus one total row)')
Rule

$attributesSql = @'
WITH q AS (
  SELECT "QueueId" AS name
  FROM public."NGC_BusinessUnitQueueClassification"
  WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22)
SELECT '[' || coalesce(r."Direction", '<NULL>') || ']'       AS direction,
       '[' || coalesce(r."InteractionType", '<NULL>') || ']' AS interaction_type,
       '[' || coalesce(r."CallType", '<NULL>') || ']'        AS call_type,
       count(*)                                              AS rows
FROM public."RTSData_Interaction" r
JOIN q ON r."Workgroup" = q.name
WHERE r."InQueueDateTime" >= now() - interval '60 minutes'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
'@

$attributesTotalSql = @'
WITH q AS (
  SELECT "QueueId" AS name
  FROM public."NGC_BusinessUnitQueueClassification"
  WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22)
SELECT count(*) AS interactions_of_bu22_in_60min
FROM public."RTSData_Interaction" r
JOIN q ON r."Workgroup" = q.name
WHERE r."InQueueDateTime" >= now() - interval '60 minutes';
'@

Say '3  THE INTERACTION ATTRIBUTES OF THE BU 22 QUEUE, AS STORED, LAST 60 MINUTES'
Say  '  The loop keeps a row only on Direction = Incoming, InteractionType in (Call, Callback) and'
Say  '  CallType = External, each compared exactly. These are the stored values with their counts.'
Say  '  The queue name is taken from the classification of BU 22, not typed into this probe.'
$attributeRows = @()
if (Assert-SqlPresent 'attributes' $attributesSql) { $attributeRows = @(Invoke-Sql $primary 'attributes' $attributesSql $true) }
Say ('  measured : distinct attribute combinations ' + $attributeRows.Count)
Say  '  THE NEGATIVE HALF: the same window and the same queue, counted without the grouping. The'
Say  '  sum of the rows above must equal it, or the grouping is dropping rows silently. The number'
Say  '  is re-taken here rather than carried from the 17:12 reading, because the window moves.'
$attributeTotal = @()
if (Assert-SqlPresent 'attributes_total' $attributesTotalSql) { $attributeTotal = @(Invoke-Sql $primary 'attributes_total' $attributesTotalSql $false) }
Say ('  measured : rows ' + $attributeTotal.Count + '   (expected 1)')
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run   : ' + (Test-TrapFired))
Say ('  RTSData_UserStatus columns  : ' + $statusColumns.Count)
Say ('  StatusGroup rows            : ' + $statusGroups.Count)
Say ('  attribute combinations      : ' + $attributeRows.Count)
Say  '  Values as stored, in brackets, with counts. Whether they match what the code compares'
Say  '  against is read off against the code itself, by backend - this probe does not decide it,'
Say  '  because the expected spelling lives there and not in anything I can measure.'
Say '===== END-OF-RUN MARKER: WFMFILTERS-COMPLETE ====='
Finish (-not (Test-TrapFired))
