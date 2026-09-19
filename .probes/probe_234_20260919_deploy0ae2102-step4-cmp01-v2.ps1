#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step4-cmp01-v2.ps1
  V2     v1 produced numbers that were not measured today. Two separate faults:
   (a) THE COMPARATOR NEVER RAN TO THE ROUTINE BLOCK. It died in dimension A with
       'Cannot bind argument to parameter Path because it is null'. Cause, from its own source:
       Compare-ToBaseline.ps1 assigns $ScriptDir ONLY in the branch taken when -BaselineDir is NOT
       passed (:57-64), yet later dot-sources . (Join-Path $ScriptDir 'RtmSchemaDump.ps1'). So the
       tool fails WHENEVER -BaselineDir is used - the very usage its own help gives as an example.
       That is a defect of the shipped 0ae2102 and is filed as its own queue item, not patched here.
       v2 works around it honestly: it does NOT pass -BaselineDir. The comparator then derives its
       own directory, and the baseline resolves to <staging>\db, which on Windows is the package's DB\.
   (b) v1 then read 'the newest delta file in the output directory' and reported 46/115 as today's
       numbers. That file was dated 29 AUGUST. A newest file is not a fresh file.
       v2 records the run start and REFUSES any delta written before it.
  Both classes are now caught by tools/lint_probe.py, which this file passes.
  UNIT   PR234-DEPLOY-0ae2102 / STEP 4 - live acceptance of CMP-01 parts 2 and 2b (routine notation).
  WHERE  SERVER 234 ONLY. G0 refuses to run anywhere else.
  CHANGES  NOTHING. Compare-ToBaseline is a read-only comparator (SELECT only); it and this probe write
         only report files under C:\RTMView-Ops\output\.
  ROLLBACK  Delete the reports. There is nothing else to undo.
  PASSWORD Read-Host -AsSecureString, never printed.

  WHAT IS BEING DECIDED
    On 13.09 the [A-R] ROUTINE PRESENCE CHECK read:  Missing on server 46 · Extra on server 116.
    Those numbers came from the two sides writing argument types in different notations, not from
    real drift. Commits 082506b and 5efbcf5 changed how both sides spell a routine signature.
    This run decides whether that is true ON THE LIVE SERVER, with the comparator FROM THE PACKAGE.
    The bar is NOT "smaller than 46/116". The bar is: every line that remains is named individually
    and explained. A number that merely fell is not an accepted number.

  KNOWN BLIND SPOT, stated before the run, not after
    The package carries DB\schema.sql, functions\, data\, setup\, tools\ - but NO migrations\ folder.
    Compare-ToBaseline reads that folder with -ErrorAction SilentlyContinue (v3:db/tools/Compare-ToBaseline.ps1:754),
    so dimension D will happily print "All migrations appear applied" over ZERO files. This probe counts
    the files itself and reports D as NOT MEASURED when the count is zero, instead of repeating a
    green that rests on an empty directory.
#>

param(
  [string]$StagingDir = 'C:\RTMView-Ops\incoming\pkg_0ae2102_20260918_230306'
)

$ErrorActionPreference = 'Continue'
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_deploy0ae2102-step4-cmp01.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
$RunStartedAt = Get-Date

$BaselineMissing1309 = 46
$BaselineExtra1309   = 116

function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("STEP 4  CMP-01 LIVE ACCEPTANCE  " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "READ ONLY - the comparator runs SELECT only; nothing on this server is modified."
Write-Report
Rule

Say "G0  machine identity"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Rule

Say "THE INSTRUMENT - taken from the package that was installed, not from anywhere else"
$baselineDir = Join-Path $StagingDir 'DB'
$comparatorPath = Join-Path $baselineDir 'tools\Compare-ToBaseline.ps1'
Say ("  staging      : " + $StagingDir)
Say ("  baseline dir : " + $baselineDir)
Say ("  comparator   : " + $comparatorPath)
if (-not (Test-Path -LiteralPath $comparatorPath)) { Say "  *** comparator not found in the package. STOP."; Finish $false }
Say ("  comparator sha256 : " + (Get-FileHash -LiteralPath $comparatorPath -Algorithm SHA256).Hash)
Say ("  schema.sql present : " + (Test-Path -LiteralPath (Join-Path $baselineDir 'schema.sql')))
$migrationFiles = @(Get-ChildItem -LiteralPath (Join-Path $baselineDir 'migrations') -Filter '*.sql' -ErrorAction SilentlyContinue)
Say ("  migration files in the baseline : " + $migrationFiles.Count)
$dimensionDMeasured = ($migrationFiles.Count -gt 0)
if (-not $dimensionDMeasured) {
  Say  "  => DIMENSION D IS NOT MEASURED IN THIS RUN. Whatever the comparator prints about migrations"
  Say  "     below rests on an empty directory and is NOT evidence. Said before the run, not after."
}
Rule

Say "PASSWORD"
$securePassword = Read-Host -Prompt 'Password for ccdashboard_user@127.0.0.1:5433/rtmviewdb (SELECT only)' -AsSecureString
$plainPassword = $null
if ($securePassword -and $securePassword.Length -gt 0) {
  $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  try { $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
  Say ("  supplied, " + $plainPassword.Length + " characters (NOT printed)")
} else { Say "  nothing supplied - STOP"; Finish $false }
Write-Report
Rule

Say "RUN"
Say ("  Compare-ToBaseline.ps1 -DBHost 127.0.0.1 -DBPort 5433 -Database rtmviewdb -User ccdashboard_user -OutDir " + $OutputDir)
  Say  "  -BaselineDir is deliberately NOT passed: with it the tool dot-sources a null path and dies (see header)."
$comparatorOutput = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $comparatorPath -DBHost 127.0.0.1 -DBPort 5433 -Database rtmviewdb -User ccdashboard_user -Password $plainPassword -OutDir $OutputDir 2>&1
$comparatorExit = $LASTEXITCODE
$plainPassword = $null
foreach ($outputLine in @($comparatorOutput | ForEach-Object { "$_" })) { Say ("  | " + $outputLine) }
Say ("  comparator exit code : " + $comparatorExit + "   (0 = no real drift, 2 = drift reported)")
Write-Report
Rule

Say "THE DELTA FILE, READ BACK FROM DISK - not from what the run printed"
$candidateDeltas = @(Get-ChildItem -LiteralPath $OutputDir -Filter 'baseline_delta_rtmviewdb_*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ("  delta files in the output directory : " + $candidateDeltas.Count)
$deltaFile = $null
foreach ($candidate in $candidateDeltas) {
  $isFresh = ($candidate.LastWriteTime -gt $RunStartedAt)
  Say ("    " + $candidate.Name + "   written " + $candidate.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "   fresh: " + $isFresh)
  if ($isFresh -and ($null -eq $deltaFile)) { $deltaFile = $candidate }
}
Say ("  run started at " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock, same clock as the file times above)")
if (-not $deltaFile) {
  Say  "  *** NO DELTA FILE WAS WRITTEN BY THIS RUN. The comparison did not happen."
  Say  "  Older files are present and are deliberately NOT read: a newest file is not a fresh file."
  Finish $false
}
Say ("  using " + $deltaFile.FullName + "   " + $deltaFile.Length + " B")
$deltaLines = @(Get-Content -LiteralPath $deltaFile.FullName)
Say ("  lines : " + $deltaLines.Count)
Rule

Say "[A-R] ROUTINE PRESENCE CHECK - printed VERBATIM, every remaining line named"
$sectionStart = -1
for ($lineIndex = 0; $lineIndex -lt $deltaLines.Count; $lineIndex++) {
  if ($deltaLines[$lineIndex] -match '^\[A-R\]') { $sectionStart = $lineIndex; break }
}
$missingNow = -1
$extraNow = -1
if ($sectionStart -lt 0) { Say "  *** the [A-R] section is absent from the delta file - the predicate is blind. STOP."; Finish $false }
for ($lineIndex = $sectionStart; $lineIndex -lt $deltaLines.Count; $lineIndex++) {
  $currentLine = $deltaLines[$lineIndex]
  if (($lineIndex -gt $sectionStart) -and ($currentLine -match '^\[[A-Z]')) { break }
  Say ("  | " + $currentLine)
  if ($currentLine -match 'Missing on server:\s*(\d+)') { $missingNow = [int]$Matches[1] }
  if ($currentLine -match 'Extra on server:\s*(\d+)')   { $extraNow   = [int]$Matches[1] }
}
Rule

Say "COMPARISON WITH 13.09 - before and after, side by side"
Say ("  Missing on server : " + $BaselineMissing1309 + "  ->  " + $missingNow)
Say ("  Extra on server   : " + $BaselineExtra1309   + "  ->  " + $extraNow)
Say  "  A number that merely fell is not an accepted number. Each line above is either zero or named."
$bothZero = (($missingNow -eq 0) -and ($extraNow -eq 0))
$bothFell = (($missingNow -ge 0) -and ($extraNow -ge 0) -and ($missingNow -lt $BaselineMissing1309) -and ($extraNow -lt $BaselineExtra1309))
Rule

Say "OTHER DIMENSIONS, as the comparator reported them"
foreach ($deltaLine in $deltaLines) {
  if ($deltaLine -match '^\[[A-Z]' -or $deltaLine -match 'realDrift|A objects|DRIFT|OK - no drift|Unapplied migrations') { Say ("  | " + $deltaLine) }
}
if (-not $dimensionDMeasured) { Say "  REMINDER: dimension D above is NOT evidence in this run - zero migration files in the baseline." }
Rule

Say "VERDICT OF STEP 4"
Say ("  comparator exit        : " + $comparatorExit)
Say ("  [A-R] Missing / Extra  : " + $missingNow + " / " + $extraNow + "   (13.09: " + $BaselineMissing1309 + " / " + $BaselineExtra1309 + ")")
Say ("  dimension D measured   : " + $dimensionDMeasured)
if ($bothZero) {
  Say  "  CMP-01 parts 2 and 2b : CLOSED on the live server - the notation difference is gone, both counts are zero."
} elseif ($bothFell) {
  Say  "  CMP-01 parts 2 and 2b : NOT CLOSED YET. The counts fell but are not zero; every remaining line is"
  Say  "  printed above and must be explained one by one before anyone calls this accepted."
} else {
  Say  "  CMP-01 parts 2 and 2b : RED - the counts did not fall. Report, change nothing."
}
Say  "  This step does not prove the seven fixes work; it proves what the corpus comparison now says."
Say "===== END-OF-RUN MARKER: STEP4-COMPLETE ====="
Finish $bothZero
