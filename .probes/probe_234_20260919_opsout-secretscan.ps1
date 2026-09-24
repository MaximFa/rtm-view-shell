<#
  PROBE  probe_234_20260919_opsout-secretscan.ps1
  UNIT   PR234-OPSOUT-SECRETS-01, step 1b - build a predicate that answers THE ACTUAL QUESTION.
  WHY    Step 1 marked by NAME and returned 52 where the register expects 6: the marker asked
         "is this name ours" while the question is "does this file carry secrets". The register's
         six is an inherited NUMBER with no list behind it - nobody ever wrote the names down.
  WHAT   Per file: the COUNT of matches against secret-shaped patterns. Name and count leave this
         machine, nothing else. No value, no masked value, no substring, no line - a number.
  WHERE  SERVER 234. READ-ONLY. Deletions in this probe: zero, and no Remove-Item is executed.
  OUT    C:\RTMView-Ops\output\234_<stamp>_opsout-secretscan.txt
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
$ReportPath = Join-Path $OutputDir ("234_{0}_opsout-secretscan.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

# The needles. Printed below next to the numbers: a count whose needle is not shown is an opinion.
$Needles = @(
  'requirepass', 'masterauth', 'masterauth_', 'user default',
  'password\s*[:=]', '"password"', 'pwd\s*=', 'passwd\s*[:=]',
  'secret\s*[:=]', 'api[_-]?key\s*[:=]', 'token\s*[:=]',
  'AUTH\s+\S', 'Password=[^;\s]'
)

Say ("OPS OUTPUT SECRET SCAN  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "WHAT LEAVES THIS MACHINE: file name and a COUNT. No value, no masked value, no matched line."
Say  "Deletions: zero. Stated so it can be checked instead of believed - every occurrence of a"
Say  "deletion verb in this source sits inside a printed sentence, none of them is executed code."
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  THE NEEDLES, PRINTED BEFORE ANY NUMBER"
foreach ($needle in $Needles) { Say ("    " + $needle) }
Say  "  They are shapes of secret DECLARATIONS, not of secret values: a password is unguessable,"
Say  "  the word in front of it is not. That is why the needle can be printed and the match cannot."
Rule

Say "2  POSITIVE CONTROL - on a synthetic line held in memory, never written to disk"
$syntheticHit = 'requirepass ExampleNotARealValue'
$posHits = 0
foreach ($needle in $Needles) { $posHits += ([regex]::Matches($syntheticHit, $needle, 'IgnoreCase')).Count }
Say ("  synthetic line matches : " + $posHits + "   (0 here means the instrument is blind and every zero below is meaningless)")
$posControlOk = ($posHits -gt 0)
Say ("  POSCTL : " + $posControlOk)
if (-not $posControlOk) { Say "  *** STOP - a blind scanner must not produce a deletion list."; Finish $false }
Rule

Say "3  THE SCAN"
if (-not (Test-Path -LiteralPath $OutputDir)) { Say ("  *** " + $OutputDir + " ABSENT"); Finish $false }
$allFiles = @(Get-ChildItem -LiteralPath $OutputDir -File -ErrorAction SilentlyContinue | Sort-Object Name)
Say ("  files scanned : " + $allFiles.Count)
$carriers = @()
$ourPattern = '^(234|45|140|DEV|WS)_\d{8}_\d{6}_'
$negControlFile = $null
foreach ($file in $allFiles) {
  if ($file.FullName -eq $ReportPath) { continue }
  $text = ''
  try {
    $stream = New-Object System.IO.FileStream($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $reader = New-Object System.IO.StreamReader($stream); try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() } }
    finally { $stream.Dispose() }
  } catch { Say ("  " + $file.Name.PadRight(52) + " READ FAILED - reported, not skipped silently"); continue }
  $total = 0
  foreach ($needle in $Needles) { $total += ([regex]::Matches($text, $needle, 'IgnoreCase')).Count }
  $text = $null
  if ($total -gt 0) {
    $carriers += [pscustomobject]@{ Name = $file.Name; Path = $file.FullName; Count = $total; Size = $file.Length; Modified = $file.LastWriteTime }
  }
  if (($null -eq $negControlFile) -and ($file.Name -match $ourPattern) -and ($total -eq 0)) { $negControlFile = $file.Name }
}
Say ("  files with at least one match : " + $carriers.Count)
Rule

Say "4  CARRIERS - name and count only"
foreach ($carrier in ($carriers | Sort-Object -Property @{Expression='Count';Descending=$true}, Name)) {
  Say ("  " + $carrier.Count.ToString().PadLeft(5) + "  " + $carrier.Name)
  Say ("         " + $carrier.Size.ToString().PadLeft(12) + " B   " + $carrier.Modified.ToString('yyyy-MM-dd HH:mm:ss'))
}
Rule

Say "5  NEGATIVE CONTROL - one of our own measurement reports must score ZERO"
if ($null -ne $negControlFile) {
  Say ("  our own report scoring zero : " + $negControlFile)
  Say  "  A needle that also fires on our ordinary reports would be wider than the question,"
  Say  "  which is exactly the defect that made step 1 return 52."
  $negControlOk = $true
} else {
  Say  "  *** NO report of ours scored zero. Either the needles are too wide, or our reports do carry"
  Say  "  declarations. Both are findings; neither permits a deletion list from this run."
  $negControlOk = $false
}
Say ("  NEGCTL : " + $negControlOk)
Rule

Say "6  AGAINST THE INHERITED NUMBER"
Say ("  register expects (2026-09-15, a number with no list behind it) : 6")
Say ("  measured carriers                                             : " + $carriers.Count)
Say ("  agrees : " + ($carriers.Count -eq 6))
Say  "  A disagreement is NOT an error of this run: nobody ever wrote the six names down, so the"
Say  "  number itself is the weakest link. The list below goes to the operator, who decides."
Rule

Say "VERDICT"
Say ("  POSCTL instrument sees a known declaration : " + $posControlOk)
Say ("  NEGCTL our own report scores zero          : " + $negControlOk)
Say ("  carriers found                             : " + $carriers.Count)
Say  "  Deleted by this run: 0 files. Nothing in this script deletes anything."
Say ("  LAST LINE : " + $(if ($posControlOk -and $negControlOk) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: OPSOUT-SECRETSCAN-COMPLETE ====="
Finish ($posControlOk -and $negControlOk)
