<#
  PROBE  probe_234_20261014_wfmgroups.ps1
  READ-ONLY, SELECT only. Nothing is written, nothing is configured.
  THE ONE QUESTION, from coordinator 2026-10-14T07:23:06Z: is the tenant serving map still the
         mixed-case {Available,"On Phone",Paperwork}, or has the operator already re-picked it to
         the stored uppercase form? My earlier sentence that it "is still mixed-case" was a
         READING, not a measurement, and this probe exists to replace it with one.
  EXPECTED, PRINTED BEFORE THE MEASUREMENT - the two outcomes and what each one means:
    A) the value holds UPPERCASE names (AVAILABLE / ONPHONE / PAPERWORK ...): the operator has
       re-picked, the intersection with the data is NOT empty, and the silence of the new warning
       is CORRECT behaviour. The negative half is then not observable in the field at all, and the
       340/340 security-and-behaviour tests are what close it.
    B) the value still holds {Available,"On Phone",Paperwork}: the intersection is empty, N=0 is
       the truth, and the warning WAS OBLIGED to fire. Its absence is then a defect, and step 2
       of the coordinator letter follows.
  THE DECIDING PAIR IS COMPUTED IN SQL, not by my eye: how many configured names match a stored
         StatusGroup EXACTLY, and how many match case-insensitively. exact 0 with insensitive > 0
         is outcome B proven; exact > 0 is outcome A.
  NOTHING IS GUESSED BY NAME: the table and column that hold the groups, and the table that holds
         StatusGroup, are found through information_schema by PATTERN. An exact match on a name I
         did not measure is not a measurement, and this project has paid for that twice.
  THE CONNECTION comes out of the machine own appsettings as an OBJECT - user, port and database
         included. I once typed a role name that does not exist and read PostgreSQL answer as a
         wrong password. The password travels as length and sha256 prefix only.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$SQL_DIR   = 'C:\RTMView-Ops\probes'
$TenantId  = '019e03e9-60dd-72da-bd01-648ffdb2b433'

Start-Probe -Name 'wfmgroups' -Title 'READING on 234: what the tenant serving map actually holds'
Say 'READ-ONLY, SELECT only. Nothing is written and nothing is configured.'
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
    Say ('    ' + $name + ' : THE QUERY TEXT IS EMPTY - not run. NOT MEASURED, states nothing.')
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
  if (($null -eq $script:Psql) -or ($null -eq $connection)) { Say ('    ' + $label + ' : NOT MEASURED') ; return ,@() }
  if (-not (Assert-SqlPresent $label $sqlText)) { return ,@() }
  $sqlPath = Join-Path $SQL_DIR ('wfmgroups_' + $label + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath -ErrorAction SilentlyContinue)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGPASSWORD = $connection[5]
  if ($withNegativeControl) {
    $badPath = Join-Path $SQL_DIR ('wfmgroups_' + $label + '_negctl.sql')
    [IO.File]::WriteAllText($badPath, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    [void](Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -f $badPath 2>&1 })
    Say ('    NEGCTL a deliberately broken query : rc ' + $LASTEXITCODE + '   (must be non-zero, else rc proves nothing)')
  }
  $output = @(Invoke-Native { & $script:Psql -v ON_ERROR_STOP=1 -h $connection[1] -p $connection[2] -U $connection[4] -d $connection[3] -t -A -F '|' -f $sqlPath 2>&1 })
  $exitCode = $LASTEXITCODE
  $env:PGPASSWORD = $null
  Say ('    rc ' + $exitCode + '   (must be 0)')
  foreach ($outputLine in $output) { Say-Guarded ('    ' + $outputLine) }
  if ($exitCode -ne 0) { Say '    THIS QUERY FAILED, so this section states NOTHING about the data.' ; return ,@() }
  return (Select-DataRows $output)
}

Say 'THE TWO OUTCOMES, WRITTEN DOWN BEFORE THE FIRST SELECT'
Say  '  A) uppercase in the map  -> operator re-picked -> intersection not empty -> silence is RIGHT'
Say  '  B) {Available,"On Phone",Paperwork} still -> intersection empty -> the warning was OBLIGED'
Say  '     to fire, and its absence is a defect.'
Say  '  The deciding pair: exact matches against stored StatusGroup, and case-insensitive matches.'
Rule

Say '0  THE CONNECTION, READ AS AN OBJECT FROM THE MACHINE OWN CONFIG'
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
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE (column_name ILIKE '%ServingState%' OR column_name ILIKE '%StatusGroup%'
       OR (table_name ILIKE '%tenant%settings%' AND (column_name ILIKE '%update%' OR column_name ILIKE '%modif%' OR column_name ILIKE '%changed%')))
ORDER BY table_schema, table_name, column_name;
'@

Say '1  WHERE THESE THINGS LIVE - found by PATTERN through information_schema, not typed by me'
$columnRows = @(Invoke-Sql $primary 'columns' $columnsSql $true)
Say ('  rows : ' + $columnRows.Count + '   (POSCTL - a zero means the pattern is wrong, not that the columns are absent)')
Rule

$valueSql = @"
SELECT '[' || COALESCE("WfmServingStateGroups"::text, '<NULL>') || ']' AS as_stored,
       length(COALESCE("WfmServingStateGroups"::text, '')) AS chars
FROM public.tenant_settings
WHERE "TenantId"::text = '$TenantId';
"@

Say '2  THE VALUE AS IT LIES, IN BRACKETS so whitespace and empty are visible'
$valueRows = @(Invoke-Sql $primary 'value' $valueSql $false)
Say ('  rows : ' + $valueRows.Count + '   (0 rows would mean the tenant has no settings row at all - a finding of its own)')
Rule

$decidingSql = @"
WITH configured AS (
  SELECT btrim(both_sides, ' "') AS name
  FROM public.tenant_settings ts,
       LATERAL regexp_split_to_table(regexp_replace(COALESCE(ts."WfmServingStateGroups"::text,''), '[\[\]{}]', '', 'g'), ',') AS both_sides
  WHERE ts."TenantId"::text = '$TenantId'
), stored AS (
  SELECT DISTINCT "StatusGroup" AS name FROM public."RTSData_UserStatus" WHERE "StatusGroup" IS NOT NULL
)
SELECT
  (SELECT count(*) FROM configured WHERE name <> '')                                          AS configured_names,
  (SELECT count(*) FROM stored)                                                               AS stored_distinct,
  (SELECT count(*) FROM configured c WHERE EXISTS (SELECT 1 FROM stored s WHERE s.name = c.name))               AS match_exact,
  (SELECT count(*) FROM configured c WHERE EXISTS (SELECT 1 FROM stored s WHERE upper(s.name) = upper(replace(c.name,' ','')))) AS match_insensitive;
"@

Say '3  THE DECIDING PAIR, computed in SQL: exact matches and case-insensitive matches'
Say  '  exact 0 and insensitive > 0  -> outcome B: the map was never re-picked, the warning was owed'
Say  '  exact > 0                    -> outcome A: re-picked, and the silence is correct behaviour'
Say  '  Both halves come from one query by one reader, so neither side is carried from elsewhere.'
$decidingRows = @(Invoke-Sql $primary 'deciding' $decidingSql $false)
Say ('  rows : ' + $decidingRows.Count)
$verdictWord = 'NOT MEASURED'
if ($decidingRows.Count -ge 1) {
  $fields = @("$($decidingRows[0])".Split('|'))
  Say ('  fields : ' + $fields.Count + '   (expected 4; fewer means the splitter is wrong and the numbers below are void)')
  if ($fields.Count -eq 4) {
    Say ('  configured names in the map : ' + $fields[0])
    Say ('  distinct StatusGroup stored : ' + $fields[1])
    Say ('  matching EXACTLY            : ' + $fields[2])
    Say ('  matching case-insensitively : ' + $fields[3])
    if ([int]$fields[2] -gt 0) { $verdictWord = 'A - re-picked: intersection not empty, the silence of the warning is CORRECT' }
    elseif ([int]$fields[3] -gt 0) { $verdictWord = 'B - still mixed case: intersection empty, the warning WAS OWED and its absence is a defect' }
    else { $verdictWord = 'NEITHER - the configured names match nothing even case-insensitively, which is a third finding' }
  }
}
Rule

Say '4  THE STORED SIDE SPELLED OUT, so the pair above can be checked by eye'
$storedSql = @'
SELECT "StatusGroup", count(*) FROM public."RTSData_UserStatus"
WHERE "StatusGroup" IS NOT NULL GROUP BY "StatusGroup" ORDER BY 2 DESC;
'@
$storedRows = @(Invoke-Sql $primary 'stored' $storedSql $false)
Say ('  rows : ' + $storedRows.Count + '   (yesterday this same table read 7 rows of StatusGroup over 13223 rows)')
Rule

Say 'VERDICT OF THE READING'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  OUTCOME : ' + $verdictWord)
Say  '  This reading decides only which of the two the coordinator letter asked for. It closes'
Say  '  nothing by itself, and if the outcome is B the next step is his point 2, not my fix.'
Say '===== END-OF-RUN MARKER: WFMGROUPS-COMPLETE ====='
Finish ($verdictWord -ne 'NOT MEASURED')
