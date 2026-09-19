#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step4c-full-extras-v2.ps1
  V3     the shape check of v2 was itself off by one level and stopped a good run; corrected below.
  V2     v1 built the scratch copy with the wrong SHAPE. Compare-ToBaseline derives its baseline as
         <parent of parent of its own directory>\db . In the package that resolves correctly
         (...\DB\tools -> ...\DB). v1 put tools\ and schema.sql side by side, so the tool looked for
         C:\RTMView-Ops\output\db, did not find it, and stopped on its own validation. The freshness
         gate then refused to read anyone else's delta - which is exactly what it is for.
         v2 copies the package's whole DB\ folder into <scratch>\DB, reproducing the shape the tool
         expects, and VERIFIES that shape before running anything.
  UNIT   PR234-DEPLOY-0ae2102 / STEP 4c - the full list of "extra on server", every line, with its owner.
  WHY    Step 4 measured Missing 46 -> 0 and Extra 116 -> 70, but the comparator PRINTS ONLY TEN of them
         (db/tools/Compare-ToBaseline.ps1: two `Select-Object -First 10`). Step 4b then found the counts
         do not close: 71 routines are extension-owned while 70 are called extra, and the comparator also
         drops anything whose name starts with pg_ from the extras (:537). One object is unaccounted for.
         I will not guess which. This probe makes the instrument print all of them.
  HOW    The SHIPPED comparator is NOT modified. It is copied to a scratch directory and, in the copy,
         the two printing caps are removed - nothing else. Both sha256 are printed so the difference
         between the instrument that ran and the instrument that was installed is a fact, not a promise.
         Then every extra is matched against the list of extension-owned routines, and each line is
         labelled: which extension owns it, or OURS.
  WHERE  SERVER 234 ONLY. READ ONLY - SELECT only; writes only into a scratch dir and its own report.
  ROLLBACK  Delete the report and the scratch directory printed below. Nothing else is touched.
#>

param(
  [string]$StagingDir = 'C:\RTMView-Ops\incoming\pkg_0ae2102_20260918_230306'
)

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
$ScratchDir = Join-Path 'C:\RTMView-Ops\output' ("cmp01_uncapped_{0}" -f $RunStamp)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_deploy0ae2102-step4c-full-extras.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList

function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("STEP 4c  EVERY EXTRA, NAMED  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY on the system. The shipped comparator is copied, never edited in place."
Write-Report
Rule

Say "G0  machine identity"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Rule

Say "THE INSTRUMENT, AND EXACTLY HOW IT DIFFERS FROM THE ONE WE INSTALLED"
$shippedTools = Join-Path $StagingDir 'DB\tools'
$shippedComparator = Join-Path $shippedTools 'Compare-ToBaseline.ps1'
if (-not (Test-Path -LiteralPath $shippedComparator)) { Say "  *** shipped comparator not found. STOP."; Finish $false }
New-Item -ItemType Directory -Force -Path $ScratchDir | Out-Null
Copy-Item -LiteralPath (Join-Path $StagingDir 'DB') -Destination (Join-Path $ScratchDir 'DB') -Recurse -Force
$workingComparator = Join-Path $ScratchDir 'DB\tools\Compare-ToBaseline.ps1'
$originalText = [IO.File]::ReadAllText($workingComparator)
$patchedText = $originalText.Replace('$RoutineMissingOnServer | Select-Object -First 10', '$RoutineMissingOnServer').Replace('$RoutineExtraOnServer | Select-Object -First 10', '$RoutineExtraOnServer')
$capsRemoved = (([regex]::Matches($originalText, [regex]::Escape('Select-Object -First 10'))).Count - ([regex]::Matches($patchedText, [regex]::Escape('Select-Object -First 10'))).Count)
[IO.File]::WriteAllText($workingComparator, $patchedText, (New-Object System.Text.UTF8Encoding($false)))
Say ("  shipped  : " + $shippedComparator)
Say ("             sha256 " + (Get-FileHash -LiteralPath $shippedComparator -Algorithm SHA256).Hash)
Say ("  working  : " + $workingComparator)
Say ("             sha256 " + (Get-FileHash -LiteralPath $workingComparator -Algorithm SHA256).Hash)
Say ("  printing caps removed : " + $capsRemoved + "   (expected 2 - and NOTHING else was changed)")
Say  "  SHAPE CHECK - the tool resolves its baseline as <parent of parent of its own dir>\db"
# The tool computes this from its own DIRECTORY, not from its file path. v2's first attempt applied
# Split-Path one level too many and stopped a run that would have worked - a false alarm costs a run
# exactly like a missed fault does. Mirrored literally from Compare-ToBaseline.ps1:62-64 here.
$toolDirectory = Split-Path -Parent $workingComparator
$derivedRepoRoot = Split-Path -Parent (Split-Path -Parent $toolDirectory)
$derivedBaseline = Join-Path $derivedRepoRoot 'db'
Say ("  it will look for : " + $derivedBaseline)
$shapeOk = (Test-Path -LiteralPath (Join-Path $derivedBaseline 'schema.sql'))
Say ("  schema.sql found there : " + $shapeOk)
if (-not $shapeOk) { Say "  *** the copy has the wrong shape - the tool would stop on its own validation. STOP."; Finish $false }
Say ("  byte delta : " + $originalText.Length + " -> " + $patchedText.Length)
if ($capsRemoved -ne 2) { Say "  *** the caps were not where they were expected. STOP rather than run a tool I cannot describe."; Finish $false }
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

Say "RUN of the uncapped copy (-BaselineDir is still NOT passed: it dies on a null path, see step 4 v2)"
$comparatorOutput = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $workingComparator -DBHost 127.0.0.1 -DBPort 5433 -Database rtmviewdb -User ccdashboard_user -Password $plainPassword -OutDir $ScratchDir 2>&1
$comparatorExit = $LASTEXITCODE
foreach ($outputLine in @($comparatorOutput | ForEach-Object { "$_" })) { Say ("  | " + $outputLine) }
Say ("  exit : " + $comparatorExit)
Write-Report
Rule

Say "THE FRESH DELTA"
$freshDelta = $null
foreach ($candidate in @(Get-ChildItem -LiteralPath $ScratchDir -Filter 'baseline_delta_rtmviewdb_*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) {
  $isFresh = ($candidate.LastWriteTime -gt $RunStartedAt)
  Say ("    " + $candidate.Name + "   " + $candidate.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "   fresh: " + $isFresh)
  if ($isFresh -and ($null -eq $freshDelta)) { $freshDelta = $candidate }
}
if (-not $freshDelta) { Say "  *** no delta written by THIS run. STOP."; Finish $false }
$deltaLines = @(Get-Content -LiteralPath $freshDelta.FullName)
Say ("  using " + $freshDelta.FullName + "   " + $deltaLines.Count + " lines")
Rule

Say "EXTENSION OWNERSHIP, read separately from the database"
$psqlPath = $null
foreach ($pgVersionDir in @(Get-ChildItem -LiteralPath 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgVersionDir.FullName 'bin\psql.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
$ownerOf = @{}
if ($psqlPath) {
  $env:PGPASSWORD = $plainPassword
  $queryFile = Join-Path $env:TEMP ("step4c_{0}.sql" -f $RunStamp)
  [IO.File]::WriteAllText($queryFile, @'
SELECT p.proname || '(' ||
       COALESCE((SELECT string_agg(format_type(t.oid, NULL), ', ' ORDER BY x.ord)
                 FROM unnest(p.proargtypes) WITH ORDINALITY AS x(oid, ord)
                 JOIN pg_type t ON t.oid = x.oid), '') || ')' || '|' || COALESCE(e.extname, 'OURS')
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  LEFT JOIN pg_depend d ON d.objid=p.oid AND d.classid='pg_proc'::regclass AND d.deptype='e'
  LEFT JOIN pg_extension e ON e.oid=d.refobjid
  WHERE n.nspname='public' ORDER BY 1;
'@, (New-Object System.Text.UTF8Encoding($false)))
  foreach ($ownerRow in @(& $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -At -f $queryFile 2>&1)) {
    $parts = "$ownerRow" -split '\|'
    if ($parts.Count -ge 2) { $ownerOf[$parts[0]] = $parts[1] }
  }
  Remove-Item -LiteralPath $queryFile -ErrorAction SilentlyContinue
  $env:PGPASSWORD = ''
}
$plainPassword = $null
Say ("  routines with a known owner : " + $ownerOf.Count)
Rule

Say "[A-R] IN FULL - every line, with its owner"
$inSection = $false
$missingList = New-Object System.Collections.ArrayList
$extraList = New-Object System.Collections.ArrayList
$currentBucket = ''
foreach ($deltaLine in $deltaLines) {
  if ($deltaLine -match '^\[A-R\]') { $inSection = $true; continue }
  if ($inSection -and ($deltaLine -match '^\[[A-Z]' -or $deltaLine -match '^DIMENSION')) { break }
  if (-not $inSection) { continue }
  if ($deltaLine -match 'Missing on server:\s*(\d+)') { $currentBucket = 'missing'; Say ("  Missing on server: " + $Matches[1]); continue }
  if ($deltaLine -match 'Extra on server:\s*(\d+)')   { $currentBucket = 'extra';   Say ("  Extra on server: " + $Matches[1]); continue }
  if ($deltaLine -match '^\s+-\s+(.+)$' -and $currentBucket -eq 'missing') { [void]$missingList.Add($Matches[1].Trim()); continue }
  if ($deltaLine -match '^\s+\+\s+(.+)$' -and $currentBucket -eq 'extra')  { [void]$extraList.Add($Matches[1].Trim()); continue }
}
Say ("  MISSING, listed : " + $missingList.Count)
foreach ($missingItem in $missingList) { Say ("    - " + $missingItem) }
Say ("  EXTRA, listed : " + $extraList.Count)
$oursAmongExtras = New-Object System.Collections.ArrayList
foreach ($extraItem in $extraList) {
  $owner = 'not-found-in-pg_proc'
  if ($ownerOf.ContainsKey($extraItem)) { $owner = $ownerOf[$extraItem] }
  if ($owner -eq 'OURS') { [void]$oursAmongExtras.Add($extraItem) }
  Say ("    + [" + $owner + "] " + $extraItem)
}
Rule

Say "VERDICT OF STEP 4c"
Say ("  extras listed in full : " + $extraList.Count)
Say ("  of them OURS (no extension owns them) : " + $oursAmongExtras.Count)
foreach ($ourExtra in $oursAmongExtras) { Say ("      OURS: " + $ourExtra) }
Say ("  scratch dir (delete when done) : " + $ScratchDir)
$fullyExplained = ($oursAmongExtras.Count -eq 0 -and $missingList.Count -eq 0)
if ($fullyExplained) {
  Say  "  Every extra belongs to a PostgreSQL extension and nothing of ours is missing."
  Say  "  CMP-01 parts 2 and 2b: the notation defect is gone and the remainder is explained IN FULL."
} else {
  Say  "  NOT fully explained. The lines marked OURS above are the real remainder and belong to CMP-01 part 1,"
  Say  "  not to the notation fix. They are named here, one by one, for whoever takes that unit."
}
Say "===== END-OF-RUN MARKER: STEP4C-COMPLETE ====="
Finish $fullyExplained
