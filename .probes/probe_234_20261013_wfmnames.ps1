<#
  PROBE  probe_234_20261013_wfmnames.ps1
  READ-ONLY, SELECT only. Nothing installed, restarted or re-configured; no log level touched.
  TASK   coordinator 2026-10-13T14:03:23Z, with backend's query quoted verbatim. The remaining
         suspect: lambda per BU is taken from a dictionary keyed by the Workgroup NAME, and the
         comparison is case- and whitespace-sensitive (WfmRealtimeLoop.cs:185-187). If the QueueId
         of a classification is written differently from the Workgroup in RTSData, that BU gets
         lambda = 0 and AHT = 0, the state becomes NoData, and the widget shows the zeros the
         operator is looking at.
  WHAT IS ALREADY SETTLED, and is not re-measured here:
         inputs are not zero (1248 / 1146 per hour, 3721 / 3619 per day); the tenant is enabled
         with a non-empty serving-state map; the loop queries its inputs every ~30 s; ALL exists
         for all 39 BU including BU 22; no widget has BusinessUnit and WfmQueueId in conflict.
         The silence of the log is lawful - backend has shown "processed" is LogDebug - so the
         absence of a snapshot line means nothing and is NOT a finding.
  THE NEGATIVE HALF IS THE POINT OF THIS READING, in the coordinator's own words:
         exact_match = cls_total is the pass;
         exact_match < loose_match means the names differ ONLY in case or whitespace, and the
         defect is exactly that rather than missing data;
         loose_match = 0 while cls_total > 0 and wg_total > 0 means the two name sets are
         unrelated, and the question becomes what filled the classification table in the first
         place - not how the comparison is done.
  THE EXAMPLES ARE PRINTED IN BRACKETS. Five classification QueueId of BU 22 and five Workgroup
         names from the hour, each wrapped in [ ] by the query itself, so leading and trailing
         spaces and the exact case are visible in the report rather than trimmed away by the eye.
         The same over 24 hours, because it is evening here and an hour can be thin.
  NAMES. Every table and column below was measured by the previous readings, not typed from a
         letter: public."NGC_BusinessUnitQueueClassification" (BusinessUnitId, QueueId, TenantId,
         ClassificationId) and public."RTSData_Interaction" ("Workgroup", "InQueueDateTime",
         "TimeZone"). This morning I reported a table as absent because I had typed its name.
  CONTROLS. Every query is preceded by a deliberately broken one that must return a non-zero rc,
         and no query runs unless its text is present (Assert-SqlPresent - at 16:56 an empty .sql
         produced rc 0 and zero rows, and I nearly read that as an empty table). The password is
         read as an object field and only its length and sha256 prefix are printed; every line is
         passed through a credential guard before it is written.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'

Start-Probe -Name 'wfmnames' -Title 'READING on 234: classification QueueId against the actual Workgroup names'
Say 'READ-ONLY, SELECT only. No restart, no config change, no log level change.'
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
  $sqlPath = Join-Path $SQL_DIR ('wfmnames_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmnames_' + $label + '_negctl.sql')
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

$matchSql = @'
-- 3. the key comparison: classification against the actual Workgroup names of the last hour
WITH cls AS (
  SELECT DISTINCT "TenantId", "QueueId" AS q
  FROM public."NGC_BusinessUnitQueueClassification" WHERE "ClassificationId" = 'ALL'),
wg AS (
  SELECT DISTINCT "TenantId", "Workgroup" AS q
  FROM public."RTSData_Interaction" WHERE "InQueueDateTime" >= now() - interval '60 minutes')
SELECT
  (SELECT COUNT(*) FROM cls)                                            AS cls_total,
  (SELECT COUNT(*) FROM wg)                                             AS wg_total,
  (SELECT COUNT(*) FROM cls JOIN wg USING ("TenantId", q))              AS exact_match,
  (SELECT COUNT(*) FROM cls JOIN wg ON cls."TenantId" = wg."TenantId"
     AND lower(btrim(cls.q)) = lower(btrim(wg.q)))                      AS loose_match;
'@

$matchSql24 = @'
WITH cls AS (
  SELECT DISTINCT "TenantId", "QueueId" AS q
  FROM public."NGC_BusinessUnitQueueClassification" WHERE "ClassificationId" = 'ALL'),
wg AS (
  SELECT DISTINCT "TenantId", "Workgroup" AS q
  FROM public."RTSData_Interaction" WHERE "InQueueDateTime" >= now() - interval '24 hours')
SELECT
  (SELECT COUNT(*) FROM cls)                                            AS cls_total,
  (SELECT COUNT(*) FROM wg)                                             AS wg_total,
  (SELECT COUNT(*) FROM cls JOIN wg USING ("TenantId", q))              AS exact_match,
  (SELECT COUNT(*) FROM cls JOIN wg ON cls."TenantId" = wg."TenantId"
     AND lower(btrim(cls.q)) = lower(btrim(wg.q)))                      AS loose_match;
'@

Say '1  THE COMPARISON OVER 60 MINUTES - backend query, verbatim'
Say  '  expected : exact_match = cls_total.'
Say  '  exact_match < loose_match  -> the names differ ONLY in case or whitespace, and THAT is the'
Say  '                                defect - not missing data.'
Say  '  loose_match = 0 with both totals > 0 -> the two name sets are unrelated, and the question'
Say  '                                becomes what filled the classification table.'
$matchRows = @()
if (Assert-SqlPresent 'match_60min' $matchSql) { $matchRows = @(Invoke-Sql $primary 'match_60min' $matchSql $true) }
Say ('  measured : rows ' + $matchRows.Count + '   (expected 1)')
Rule

Say '2  THE SAME OVER 24 HOURS - because an evening hour can be thin'
$matchRows24 = @()
if (Assert-SqlPresent 'match_24h' $matchSql24) { $matchRows24 = @(Invoke-Sql $primary 'match_24h' $matchSql24 $true) }
Say ('  measured : rows ' + $matchRows24.Count + '   (expected 1)')
Rule

$examplesSql = @'
SELECT 'cls BU22' AS source, '[' || "QueueId" || ']' AS name_as_stored
FROM (SELECT DISTINCT "QueueId" FROM public."NGC_BusinessUnitQueueClassification"
      WHERE "ClassificationId" = 'ALL' AND "BusinessUnitId" = 22 ORDER BY 1 LIMIT 5) a
UNION ALL
SELECT 'wg 60min', '[' || "Workgroup" || ']'
FROM (SELECT DISTINCT "Workgroup" FROM public."RTSData_Interaction"
      WHERE "InQueueDateTime" >= now() - interval '60 minutes' ORDER BY 1 LIMIT 5) b
UNION ALL
SELECT 'wg 24h', '[' || "Workgroup" || ']'
FROM (SELECT DISTINCT "Workgroup" FROM public."RTSData_Interaction"
      WHERE "InQueueDateTime" >= now() - interval '24 hours' ORDER BY 1 LIMIT 5) c;
'@

Say '3  THE NAMES THEMSELVES, IN BRACKETS'
Say  '  Five classification QueueId of BU 22, five Workgroup of the hour and five of the day, each'
Say  '  wrapped in [ ] BY THE QUERY, so a leading or trailing space and the exact case are visible'
Say  '  in the report instead of being swallowed by the reader eye. This is the row that will show'
Say  '  a trailing blank or a capital letter if that is what the difference is.'
$exampleRows = @()
if (Assert-SqlPresent 'examples' $examplesSql) { $exampleRows = @(Invoke-Sql $primary 'examples' $examplesSql $true) }
Say ('  measured : rows ' + $exampleRows.Count + '   (expected up to 15; fewer means one of the three sets is smaller, which is itself readable)')
Rule

Say 'WHAT THIS READING MEASURED'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  comparison rows, 60 min   : ' + $matchRows.Count)
Say ('  comparison rows, 24 h     : ' + $matchRows24.Count)
Say ('  example name rows         : ' + $exampleRows.Count)
Say  '  The four counters of sections 1 and 2 decide between three readings, and which one holds is'
Say  '  stated in the letter from these numbers - not here. A section that could not measure says'
Say  '  so in its own place.'
Say '===== END-OF-RUN MARKER: WFMNAMES-COMPLETE ====='
Finish (-not (Test-TrapFired))
