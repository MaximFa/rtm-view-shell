<#
  PROBE  probe_234_20261013_wfmbu22.ps1
  READ-ONLY, SELECT only. Nothing installed, restarted or re-configured; no log level touched.
  WHY THIS ONE EXISTS. The name comparison came out clean: exact_match equals loose_match - 21 of
  21 over the hour, 23 of 23 over the day - so not one Workgroup is lost to case or whitespace, and
  that suspect is closed. classification covers 39 queues while only 21-23 carried traffic in the
  window, which is the ordinary difference between "a queue exists" and "a queue was busy".
  What that leaves is one question, and it is specific: the widget is keyed on BU 22, BU 22 has
  exactly ONE classified queue, and if that queue had no interactions in the window then lambda is
  legitimately zero, AHT is legitimately zero, the state is NoData for a correct reason, and there
  is no defect to chase. If it DID carry traffic, the zeros are a defect and the search goes back
  to the loop.
  THE SHAPE OF THE ANSWER IS A PAIR, per BU, and the BU of the widget is not treated specially:
  classified queues, how many of them carried interactions, and how many interactions - over both
  windows. A number for BU 22 alone could not tell "this BU is quiet" from "every BU is quiet".
  CONTROLS. A deliberately broken query first, which must return a non-zero rc. No query runs
  unless its text is present. Every expectation is printed before its measurement. The password is
  read as an object field and only its length and sha256 prefix are printed; every line passes a
  credential guard. Table and column names come from the measurements of the previous readings.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmbu22' -Title 'READING on 234: did the queues of each BU carry any traffic'
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
  $sqlPath = Join-Path $SQL_DIR ('wfmbu22_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmbu22_' + $label + '_negctl.sql')
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

$perBuSql = @'
WITH cls AS (
  SELECT "BusinessUnitId" AS bu, "QueueId" AS q
  FROM public."NGC_BusinessUnitQueueClassification"
  WHERE "ClassificationId" = 'ALL'),
hour AS (
  SELECT "Workgroup" AS q, count(*) AS n
  FROM public."RTSData_Interaction"
  WHERE "InQueueDateTime" >= now() - interval '60 minutes' GROUP BY 1),
day AS (
  SELECT "Workgroup" AS q, count(*) AS n
  FROM public."RTSData_Interaction"
  WHERE "InQueueDateTime" >= now() - interval '24 hours' GROUP BY 1)
SELECT cls.bu,
       count(*)                                        AS classified_queues,
       count(hour.q)                                   AS queues_with_traffic_60min,
       coalesce(sum(hour.n), 0)                        AS interactions_60min,
       count(day.q)                                    AS queues_with_traffic_24h,
       coalesce(sum(day.n), 0)                         AS interactions_24h
FROM cls
LEFT JOIN hour ON hour.q = cls.q
LEFT JOIN day  ON day.q  = cls.q
GROUP BY cls.bu
ORDER BY cls.bu;
'@

Say '1  PER BUSINESS UNIT: classified queues, how many carried traffic, and how many interactions'
Say  '  expected, stated before the measurement: if BU 22 shows queues_with_traffic = 0 and'
Say  '  interactions = 0 over BOTH windows, then its zeros are CORRECT and there is nothing wrong'
Say  '  with the widget - the queue simply had no calls. If it shows traffic, the zeros on screen'
Say  '  are a defect and the search goes back to the loop.'
Say  '  The whole table is printed, not BU 22 alone: a single number could not tell "this BU is'
Say  '  quiet" from "every BU is quiet", and the difference decides where to look next.'
$buRows = @()
if (Assert-SqlPresent 'per_bu' $perBuSql) { $buRows = @(Invoke-Sql $primary 'per_bu' $perBuSql $true) }
Say ('  measured : rows ' + $buRows.Count + '   (expected 39, one per BU with an ALL classification)')
Rule

$bu22Sql = @'
SELECT '[' || c."QueueId" || ']' AS queue_of_bu22,
       (SELECT count(*) FROM public."RTSData_Interaction" r
         WHERE r."Workgroup" = c."QueueId"
           AND r."InQueueDateTime" >= now() - interval '60 minutes')  AS interactions_60min,
       (SELECT count(*) FROM public."RTSData_Interaction" r
         WHERE r."Workgroup" = c."QueueId"
           AND r."InQueueDateTime" >= now() - interval '24 hours')    AS interactions_24h,
       (SELECT count(*) FROM public."RTSData_Interaction" r
         WHERE r."Workgroup" = c."QueueId")                           AS interactions_all_time
FROM public."NGC_BusinessUnitQueueClassification" c
WHERE c."ClassificationId" = 'ALL' AND c."BusinessUnitId" = 22;
'@

Say '2  THE QUEUE OF BU 22 BY NAME, WITH ITS TRAFFIC - including an all-time count'
Say  '  The all-time column is the control that the join itself works: if this queue has never had'
Say  '  a single interaction in the whole table, then a zero in the two windows says nothing about'
Say  '  today, and the question moves to why that queue is classified for a widget at all.'
$bu22Rows = @()
if (Assert-SqlPresent 'bu22' $bu22Sql) { $bu22Rows = @(Invoke-Sql $primary 'bu22' $bu22Sql $true) }
Say ('  measured : rows ' + $bu22Rows.Count + '   (expected 1, since BU 22 has exactly one classified queue)')
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  per-BU rows               : ' + $buRows.Count)
Say ('  BU 22 queue rows          : ' + $bu22Rows.Count)
Say  '  Counts only. Whether the zeros on the screen are correct or a defect is decided from these'
Say  '  numbers in the letter that carries them, with backend-0919 in copy.'
Say '===== END-OF-RUN MARKER: WFMBU22-COMPLETE ====='
Finish (-not (Test-TrapFired))
