<#
  PROBE  probe_234_20260920_cmp01-live-filter.ps1
  UNIT   PR234-CMP-01 part 1, the LIVE half. The fix was proven on a pg_dump 16 fixture; server 234
         runs PostgreSQL 18. This run answers one question: does the object filter behave the same
         on a real 18 dump. Until it does, part 1 stays DELIVERED and not CLOSED.
  WHAT   Takes a schema-only dump of the live database, runs the SHIPPED Select-RtmSchemaBlocks over
         it, and counts: blocks in, blocks kept, routine blocks kept (must be 0), whitelist table
         blocks kept (must not be 0).
  WHERE  SERVER 234. READ-ONLY: pg_dump --schema-only reads; no schema, no data, no service is
         touched; nothing is written outside C:\RTMView-Ops\output\ and the temp file it deletes.
  WORKAROUND, NAMED AS ONE  Compare-ToBaseline.ps1 is not used: its -BaselineDir is broken
         (CMP-BASEDIR-01) and that defect stays OPEN. This probe calls the filter function directly,
         which is the unit under test anyway. That is an AVOIDANCE, not a fix.
  SECRETS  The database password is read from the machine config and never printed: name, length only.
  OUT    C:\RTMView-Ops\output\234_<stamp>_cmp01-live-filter.txt
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_cmp01-live-filter.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("CMP-01 LIVE FILTER  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "READ-ONLY. pg_dump --schema-only only; no schema change, no data change, no service touched."
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  THE UNIT UNDER TEST - the shipped file, identified by hash before it is used"
$stagingDump = 'C:\RTMView-Ops\incoming\pkg_0f969d8_20260920_112957\db\tools\RtmSchemaDump.ps1'
if (-not (Test-Path -LiteralPath $stagingDump)) { Say ("  *** not found: " + $stagingDump); Finish $false }
$dumpHash = (Get-FileHash -LiteralPath $stagingDump -Algorithm SHA256).Hash
Say ("  file     : " + $stagingDump)
Say ("  sha256   : " + $dumpHash)
Say  "  expected : 3E31DD05BD18C36AC5C0236C9E511187C14CF7EC4B1C5A52AC38C0DE034F6738  (the fixed version)"
$rightFile = ($dumpHash -eq '3E31DD05BD18C36AC5C0236C9E511187C14CF7EC4B1C5A52AC38C0DE034F6738')
Say ("  match    : " + $rightFile)
if (-not $rightFile) { Say "  *** this is not the file the fix produced. STOP."; Finish $false }
. $stagingDump
$hasFilter = (Get-Command Select-RtmSchemaBlocks -ErrorAction SilentlyContinue) -ne $null
Say ("  Select-RtmSchemaBlocks available after dot-sourcing : " + $hasFilter)
if (-not $hasFilter) { Say "  *** the function did not load. STOP."; Finish $false }
Say ("  whitelist entries loaded : " + @($script:RtmTableNames).Count + "   (0 would make every count below meaningless)")
Rule

Say "2  EXPECTED, PRINTED BEFORE THE DUMP IS TAKEN"
Say  "  routine blocks among the KEPT blocks : 0        <- the whole point of the fix"
Say  "  whitelist TABLE blocks among the kept : not 0   <- otherwise the filter kept nothing at all"
Say  "  routine blocks present in the RAW dump : not 0  <- POSCTL: a dump without routines would make"
Say  "                                                     the zero above meaningless"
Say  "  On the pg_dump 16 fixture the same filter gave kept 5, routine 0, non-routine 5."
Say  "  This machine runs PostgreSQL 18 - that difference is the reason this run exists."
Rule

Say "3  THE DUMP - schema only, read-only, from the live database"
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
$dbUser = '' ; $dbName = '' ; $dbPort = '' ; $dbPassword = ''
if (Test-Path -LiteralPath $shellCfg) {
  $rawShell = Get-Content -LiteralPath $shellCfg -Raw -Encoding UTF8
  $configMatch = [regex]::Match($rawShell, '(?i)Password\s*=\s*([^;"]+)') ; if ($configMatch.Success) { $dbPassword = $configMatch.Groups[1].Value.Trim() }
  $configMatch = [regex]::Match($rawShell, '(?i)(?:Username|User ID)\s*=\s*([^;"]+)') ; if ($configMatch.Success) { $dbUser = $configMatch.Groups[1].Value.Trim() }
  $configMatch = [regex]::Match($rawShell, '(?i)Database\s*=\s*([^;"]+)') ; if ($configMatch.Success) { $dbName = $configMatch.Groups[1].Value.Trim() }
  $configMatch = [regex]::Match($rawShell, '(?i)Port\s*=\s*(\d+)') ; if ($configMatch.Success) { $dbPort = $configMatch.Groups[1].Value }
}
$pgDump = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgDir.FullName 'bin\pg_dump.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $pgDump)) { $pgDump = $candidate }
}
Say ("  pg_dump : " + $(if ($pgDump) { $pgDump } else { 'NOT FOUND' }))
Say ("  target  : user " + $dbUser + " / db " + $dbName + " / port " + $dbPort + " / password " + $dbPassword.Length + " chars (never printed)")
if ((-not $pgDump) -or (-not $dbPassword) -or (-not $dbName)) { Say "  *** cannot dump - STOP, nothing measured"; Finish $false }
$env:PGPASSWORD = $dbPassword
$dumpFile = Join-Path $env:TEMP ("cmp01_live_{0}.sql" -f $RunStamp)
& $pgDump --schema-only --no-owner --no-privileges -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -f $dumpFile 2>&1 | ForEach-Object { Say ("  | " + $_) }
$dumpRc = $LASTEXITCODE
$env:PGPASSWORD = ''
Say ("  pg_dump exit : " + $dumpRc)
if (($dumpRc -ne 0) -or (-not (Test-Path -LiteralPath $dumpFile))) { Say "  *** dump failed - STOP"; Finish $false }
$raw = [IO.File]::ReadAllText($dumpFile)
Say ("  dump bytes : " + $raw.Length)
Say ("  server version line from the dump : " + (($raw -split "`r?`n" | Where-Object { $_ -like '*Dumped by pg_dump*' -or $_ -like '*Dumped from database version*' }) -join ' | '))
Rule

Say "4  POSITIVE CONTROL ON THE MATERIAL - are there routines in the raw dump at all"
$rawBlocks = @($raw -split "(?m)\r?\n\r?\n")
$rawRoutineHeaders = @($rawBlocks | Where-Object { $_ -match '--\s*Name:\s*[^;]+;\s*Type:\s*(FUNCTION|PROCEDURE);' }).Count
Say ("  blocks in the raw dump        : " + $rawBlocks.Count)
Say ("  FUNCTION/PROCEDURE headers    : " + $rawRoutineHeaders + "   (0 here would make the zero below meaningless)")
$posControlOk = ($rawRoutineHeaders -gt 0)
Say ("  POSCTL : " + $posControlOk)
Rule

Say "5  THE FILTER ON LIVE MATERIAL"
$kept = @(Select-RtmSchemaBlocks -Raw $raw)
Say ("  blocks kept : " + $kept.Count)
$keptRoutine = 0
$keptTable   = 0
foreach ($block in $kept) {
  if ($block -match '(?im)^\s*CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\b') { $keptRoutine++ }
  if ($block -match '(?im)^\s*CREATE\s+TABLE\b') { $keptTable++ }
}
Say ("  of them, blocks that CREATE a routine : " + $keptRoutine + "   (expected 0)")
Say ("  of them, blocks that CREATE a table   : " + $keptTable + "   (expected non-zero)")
Say  "  A routine BODY tail carries neither header nor CREATE, so the count above is a lower bound."
Say  "  The stronger statement is the next one: nothing kept sits inside a routine object."
$routineBodyLeak = 0
foreach ($block in $kept) {
  if ($block -match '(?im)(\$\$|LANGUAGE\s+plpgsql|RETURNS\s+(SETOF\s+)?\w)') { $routineBodyLeak++ }
}
Say ("  kept blocks carrying routine-body marks (\$\$ / LANGUAGE plpgsql / RETURNS) : " + $routineBodyLeak + "   (expected 0)")
Rule

Say "6  NEGATIVE HALF - an object the filter MUST NOT drop"
Say  "  A filter that drops everything also reports zero routines. So: a whitelisted table must survive."
$survivor = @($kept | Where-Object { $_ -match '(?im)^\s*CREATE\s+TABLE\s+public\."NGC_BusinessUnit"' })
Say ('  CREATE TABLE of the whitelisted table NGC_BusinessUnit among the kept blocks : ' + $survivor.Count + '   (expected 1)')
$droppedByMistake = ($survivor.Count -eq 0)
if ($droppedByMistake) { Say "  *** the filter dropped a whitelisted table - RED, and the zero above proves nothing" }
Rule

Say "7  CLEAN-UP of the temp dump (it is a schema, but it is not ours to leave lying about)"
Remove-Item -LiteralPath $dumpFile -Force -ErrorAction SilentlyContinue
Say ("  temp dump removed : " + (-not (Test-Path -LiteralPath $dumpFile)))
Rule

Say "VERDICT"
Say ("  right file under test      : " + $rightFile)
Say ("  POSCTL routines in the dump: " + $posControlOk)
Say ("  routines kept              : " + $keptRoutine + " (expected 0)")
Say ("  routine-body marks kept    : " + $routineBodyLeak + " (expected 0)")
Say ("  whitelisted table survived : " + (-not $droppedByMistake))
$verdict = ($rightFile -and $posControlOk -and ($keptRoutine -eq 0) -and ($routineBodyLeak -eq 0) -and (-not $droppedByMistake))
Say  "  Compare-ToBaseline was NOT used: its -BaselineDir is broken (CMP-BASEDIR-01), and that defect"
Say  "  stays OPEN. This run avoided it by calling the unit under test directly - an avoidance, not a fix."
Say ("  LAST LINE : " + $(if ($verdict) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: CMP01-LIVE-FILTER-COMPLETE ====="
Finish $verdict
