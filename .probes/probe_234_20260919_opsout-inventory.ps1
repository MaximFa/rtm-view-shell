<#
  PROBE  probe_234_20260919_opsout-inventory.ps1
  UNIT   PR234-OPSOUT-SECRETS-01, step 1 of 2 - THE INVENTORY. NOTHING IS DELETED BY THIS RUN.
  WHY    Six files in C:\RTMView-Ops\output\ carry other people's secrets in the clear. The operator
         allowed deleting exactly those six on 2026-09-15; everything else in C:\RTMView-Ops\ stays.
         The form was fixed BEFORE the work: inventory first, deletion second, by explicit paths.
  SECRETS  NO FILE CONTENT IS PRINTED, under any condition. Not a masked value, not a first character,
         not a field name next to a value. Masking by field name has already leaked a password into the
         chat in the clear, so this probe does not read content at all - only name, size, sha256, mtime.
  WHERE  SERVER 234. READ-ONLY. No file is created, moved, renamed or deleted. No service is touched.
  OUT    C:\RTMView-Ops\output\234_<stamp>_opsout-inventory.txt
         (the report lands in the same directory it describes and is NOT itself a candidate)
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
$ReportPath = Join-Path $OutputDir ("234_{0}_opsout-inventory.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("OPS OUTPUT INVENTORY  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "THIS RUN DELETES NOTHING. It lists, hashes and counts. Deletion is a separate run by explicit paths."
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  EXPECTED, PRINTED BEFORE MEASURED"
Say  "  The register says SIX files carry secrets [operator, 2026-09-15]. That six comes from a WRITTEN"
Say  "  RECORD, not from a measurement taken in this awakening - so it is an expectation, not a fact."
Say  "  If the count of candidates below is not 6, this run STOPS the line: no deletion follows a"
Say  "  disagreement between the register and the disk."
Rule

Say "2  THE WHOLE DIRECTORY, so the six are seen against their background"
if (-not (Test-Path -LiteralPath $OutputDir)) { Say ("  *** " + $OutputDir + " ABSENT"); Finish $false }
$allFiles = @(Get-ChildItem -LiteralPath $OutputDir -File -ErrorAction SilentlyContinue)
Say ("  files in " + $OutputDir + " : " + $allFiles.Count + "   (this number is the 'before' half of the deletion acceptance)")
Rule

Say "3  INVENTORY - name, size, sha256, mtime. NO CONTENT."
Say  "  Candidate marking is by NAME ONLY: a file is a candidate when its name is not one of our own"
Say  "  measurement reports, which are named <SERVER>_<stamp>_<topic>.txt by our own convention."
$ourPattern = '^(234|45|140|DEV|WS)_\d{8}_\d{6}_'
$candidates = @()
foreach ($file in ($allFiles | Sort-Object Name)) {
  $isOurs = ($file.Name -match $ourPattern)
  $hash = try { (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash } catch { 'HASH-FAILED' }
  $mark = if ($isOurs) { 'ours (measurement report)' } else { 'CANDIDATE' }
  if (-not $isOurs) { $candidates += $file }
  Say ("  " + $file.Name)
  Say ("      " + $file.Length.ToString().PadLeft(12) + " B   " + $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "   " + $mark)
  Say ("      sha256 " + $hash)
}
Rule

Say "4  THE COUNT AGAINST THE EXPECTATION"
Say ("  expected candidates : 6   (from the register, 2026-09-15)")
Say ("  measured candidates : " + $candidates.Count)
$countAgrees = ($candidates.Count -eq 6)
Say ("  AGREES : " + $countAgrees)
if (-not $countAgrees) {
  Say  "  *** STOP THE LINE. The register and the disk disagree, and the register is four days old."
  Say  "  Deletion is NOT prepared. Report the list above to the coordinator and wait."
}
Rule

Say "5  NEGATIVE CONTROL ON THE MARKER ITSELF"
Say  "  If every file were marked the same way, the marker would not be separating anything."
$ours = @($allFiles | Where-Object { $_.Name -match $ourPattern })
Say ("  marked ours      : " + $ours.Count)
Say ("  marked CANDIDATE : " + $candidates.Count)
$discriminates = (($ours.Count -gt 0) -and ($candidates.Count -gt 0))
Say ("  DISCRIMINATES : " + $discriminates + "   (False means the marker sorts nothing and its list proves nothing)")
Rule

Say "6  THE DELETION LINES, WRITTEN OUT BUT NOT RUN"
Say  "  Explicit paths, one per line, no wildcards: a mask has already cost us a round by matching"
Say  "  more than it was meant to. These lines are for the NEXT run, after the coordinator sees them."
if ($candidates.Count -gt 0) {
  foreach ($candidate in $candidates) { Say ('    Remove-Item -LiteralPath "' + $candidate.FullName + '" -Force') }
} else { Say "    (no candidates - nothing to write out)" }
Rule

Say "VERDICT"
Say ("  files in directory   : " + $allFiles.Count)
Say ("  candidates           : " + $candidates.Count + "   expected 6   agrees: " + $countAgrees)
Say ("  marker discriminates : " + $discriminates)
Say  "  Deleted by this run  : 0 files. Checkable claim, stated precisely: the text Remove-Item appears"
Say  "  twice in this file and BOTH occurrences are inside strings that are printed in section 6."
Say  "  Not one of them is an executed statement. Count them in the file rather than believe this line."
Say ("  LAST LINE : " + $(if ($countAgrees -and $discriminates) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: OPSOUT-INVENTORY-COMPLETE ====="
Finish ($countAgrees -and $discriminates)
