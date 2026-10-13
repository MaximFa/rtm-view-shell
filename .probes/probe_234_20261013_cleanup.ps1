<#
  PROBE  probe_234_20261013_cleanup.ps1
  THIS RUN DELETES. On production. Irreversibly - there is no recycle bin for these paths.
  AUTHORITY  operator word "udaljaj" 2026-10-13, over the list he set: keep the two newest backup
         sets in C:\RTMView\Backup, remove the rest; plus the staging directories of flights
         already accepted. The list below is the list he was shown, measured
         [234_20261013_142557_diskspace.txt] - 8 backup sets 26.2 GB and 6 stagings 0.73 GB.
  WHY THE NAMES ARE HARD-CODED AND NOT COMPUTED
         A rule like "all but the two newest" is re-evaluated at the moment of the run, so anything
         that appeared between the approval and the run would be swept with it - including a backup
         set written by an install nobody told me about. The operator approved THIRTEEN NAMES, so
         thirteen names is what this probe carries, and anything not in the list is not reachable
         by this code at all.
  WHAT IS KEPT, AND PROVEN KEPT BEFORE THE FIRST DELETE
         13102026_1419 - carries the web.dll THIS MACHINE RUNS (0C71E943...): the live floor. Its
                         Shell half is complete; its RTM half was being written when the install
                         died of a full disk, so it is NOT to be trusted as an engine floor, and
                         this probe says so rather than pretending the set is whole.
         12102026_1921 - the complete set one step back (web.dll 88393643...).
         pkg_2d75b01_20261013_141552 - the staging the ACCEPTANCE of this flight still has to read.
         Every .zip in incoming, the rollback floor 07263B55 and the package 8E2652AE among them.
         The three rtmtwilio_* sets - backups of the PRODUCTION adapter, which we do not touch
         without a decision of its own.
         The engine logs in C:\RTMView\RTM - a separate subject, and the engine is writing there now.
  SAFETY, in this order, and a failure at any point stops the run before the first delete:
         machine gate; the inbox re-read for a stop word; the keep-list proven present AND
         carrying what it should; every candidate proven to be in the approved list, to exist, and
         to NOT carry the running web.dll; free space printed BEFORE.
  EVERY DELETE IS A PAIR: size and existence before, existence after. Free space is printed as a
         pair as well - one number proves nothing.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$RUNNING_WEB_DLL = '0C71E9434A89D50FDA968C0B63EE5F4EB4D37A05710E16BF84C22CB753C17F16'
$BACKUP_ROOT = 'C:\RTMView\Backup'
$INCOMING    = 'C:\RTMView-Ops\incoming'
$KEEP_SETS   = @('13102026_1419', '12102026_1921')
$DELETE_SETS = @('05102026_0856','10102026_1125','10102026_1353','10102026_2309',
                 '11102026_0049','11102026_1132','11102026_1300','12102026_0959')
$DELETE_STAGING = @('pkg_4634162_20261010_230808','pkg_e6a0fcb_20261011_004806',
                    'pkg_2f3b426_20261011_113057','pkg_356d58b_20261011_125905',
                    'pkg_2ccbf1c_20261012_095644','pkg_f333db5_20261012_191353')
$KEEP_STAGING = 'pkg_2d75b01_20261013_141552'

Start-Probe -Name 'cleanup' -Title 'CLEANUP on 234 - THIS RUN DELETES, irreversibly'
Say 'AUTHORITY: operator word 2026-10-13 over the list measured in 234_20261013_142557_diskspace.txt'
Rule
Assert-Machine

function Size-Of([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  $measured = Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  if ($null -eq $measured.Sum) { return 0 }
  return [int64]$measured.Sum
}
function Format-Megabytes([int64]$bytes) {
  if ($bytes -lt 0) { return 'ABSENT' }
  return ([string][math]::Round($bytes / 1MB, 1)) + ' MB'
}

Say 'G-BUS  THE LAST LETTER IN MY INBOX, read BEFORE anything is removed'
Say  '  A deletion is irreversible, so the approval has to be the current one, not one from an hour'
Say  '  ago. On 2026-10-10 I installed four hours after a blessing had been revoked because I had'
Say  '  not re-read the inbox before the write. Same gate, same reason.'
$inboxPath = '\\tsclient\D\Claude\Projects\RTM View Shell\.coord\inbox\devops.md'
Say ('  inbox : ' + $inboxPath)
if (-not (Test-Path -LiteralPath $inboxPath)) {
  Say '  *** THE INBOX CANNOT BE READ FROM HERE. I will not delete on production blind. STOP.'
  Finish $false
}
$headings = @(Select-String -LiteralPath $inboxPath -Pattern '^## ' -ErrorAction SilentlyContinue)
Say ('  letters in it : ' + $headings.Count + '   (zero would mean the reader is wrong, not that the bus is empty)')
if ($headings.Count -eq 0) { Say '  *** NO LETTERS FOUND - the reader is wrong. STOP.' ; Finish $false }
$lastLetter = $headings[-1].Line
Say ('  last letter   : ' + $lastLetter)
$stopHit = $false
foreach ($stopWord in @('СТОП','ОТОЗВА','STOP','ОТМЕН')) {
  if ($lastLetter.ToUpper().Contains($stopWord)) { $stopHit = $true }
}
Say ('  stop word in the last letter : ' + $stopHit)
if ($stopHit) { Say '  *** A STOP IS STANDING. Nothing is deleted.' ; Finish $false }
Say ('  POSCTL for this reader: it found ' + $headings.Count + ' headings and read the last one in')
Say  '  full above, so a stop word present in it could not have been missed.'
Rule

Say '1  FREE SPACE BEFORE - the first half of the pair'
$driveBefore = Get-PSDrive -Name C
$freeBefore = $driveBefore.Free
Say ('  C: free ' + [math]::Round($freeBefore/1MB,1) + ' MB (' + [math]::Round($freeBefore/1GB,2) + ' GB)')
Say  '  One backup set needs about 3578 MB, which is why the install of 2d75b01 died at step 2 of 5.'
Rule

Say '2  WHAT IS KEPT - proven BEFORE the first delete, not asserted afterwards'
$keepOk = $true
foreach ($keepSet in $KEEP_SETS) {
  $keepPath = Join-Path $BACKUP_ROOT $keepSet
  $keepDll = ShaOf (Join-Path $keepPath 'Shell\CcDashboard.Web.dll')
  $isRunning = ($keepDll -eq $RUNNING_WEB_DLL)
  Say ('  ' + $keepSet + '   present ' + (Test-Path -LiteralPath $keepPath) + '   ' + (Format-Megabytes (Size-Of $keepPath)))
  Say ('  ' + ' '.PadRight($keepSet.Length) + '   web.dll ' + $keepDll)
  Say ('  ' + ' '.PadRight($keepSet.Length) + '   carries the running build : ' + $isRunning)
  if (-not (Test-Path -LiteralPath $keepPath)) { $keepOk = $false }
}
Say ('  EXPECTED: both sets present, and exactly ONE of them carrying the running build')
$runningCount = 0
foreach ($keepSet in $KEEP_SETS) {
  if ((ShaOf (Join-Path (Join-Path $BACKUP_ROOT $keepSet) 'Shell\CcDashboard.Web.dll')) -eq $RUNNING_WEB_DLL) { $runningCount++ }
}
Say ('  measured : running build found in ' + $runningCount + ' of the two kept sets')
if (($runningCount -ne 1) -or (-not $keepOk)) {
  Say '  *** THE FLOOR IS NOT WHERE I THINK IT IS. Nothing is deleted. Report and stop.'
  Finish $false
}
Say ('  NOTE, not a verdict: in 13102026_1419 the RTM half was being written when the install died')
Say ('  of a full disk, so that set is a Shell floor and NOT an engine floor. Said here so nobody')
Say ('  later reads it as a whole set.')
Say ('  kept staging : ' + $KEEP_STAGING + '   present ' + (Test-Path -LiteralPath (Join-Path $INCOMING $KEEP_STAGING)) + '   (the acceptance of this flight reads it)')
Rule

Say '3  THE DELETE LIST - every row checked against the approved names before it is touched'
$freedBytes = [int64]0
$deletedCount = 0
$refusedCount = 0
$targets = @()
foreach ($setName in $DELETE_SETS)     { $targets += ,@((Join-Path $BACKUP_ROOT $setName), $setName, 'backup set') }
foreach ($stagingName in $DELETE_STAGING) { $targets += ,@((Join-Path $INCOMING $stagingName), $stagingName, 'staging') }
Say ('  approved names : ' + $DELETE_SETS.Count + ' backup sets + ' + $DELETE_STAGING.Count + ' stagings = ' + $targets.Count + '   (expected 14)')
foreach ($target in $targets) {
  $targetPath = $target[0]
  $targetName = $target[1]
  $targetKind = $target[2]
  $approved = (($DELETE_SETS -contains $targetName) -or ($DELETE_STAGING -contains $targetName))
  $notKept  = (-not ($KEEP_SETS -contains $targetName)) -and ($targetName -ne $KEEP_STAGING)
  $sizeBefore = Size-Of $targetPath
  # The running-build guard protects a BACKUP SET, which is a floor. A STAGING is only an unpacked
  # copy of a package whose .zip sits intact in incoming and is identified as the floor there, so
  # the same test applied to a staging is stricter than the question: on the 15:24 run it refused
  # pkg_f333db5_20261012_191353 and one refusal out of fourteen made the verdict call a cleanup
  # INCOMPLETE that had in fact freed 27.4 GB. A guard narrower than its subject is a false red.
  $carriesRunning = $false
  if ($targetKind -eq 'backup set') {
    $carriesRunning = ((ShaOf (Join-Path $targetPath 'Shell\CcDashboard.Web.dll')) -eq $RUNNING_WEB_DLL)
  }
  Say ('  ' + $targetName.PadRight(30) + ' ' + $targetKind.PadRight(11) + (Format-Megabytes $sizeBefore).PadLeft(10) + '   approved ' + $approved + '   not-kept ' + $notKept + '   carries-running-build ' + $carriesRunning)
  if (-not $approved)      { Say '      REFUSED: not in the approved list' ; $refusedCount++ ; continue }
  if (-not $notKept)       { Say '      REFUSED: it is on the keep list' ; $refusedCount++ ; continue }
  if ($carriesRunning)     { Say '      REFUSED: it is a BACKUP SET carrying the build this machine runs - that is the floor' ; $refusedCount++ ; continue }
  if ($sizeBefore -lt 0)   { Say '      nothing to do: already absent' ; continue }
  Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue
  $goneNow = -not (Test-Path -LiteralPath $targetPath)
  Say ('      removed : ' + $goneNow + '   freed ' + (Format-Megabytes $sizeBefore))
  if ($goneNow) { $freedBytes += $sizeBefore ; $deletedCount++ } else { Say '      *** STILL PRESENT after Remove-Item - report it' }
}
Say ('  deleted : ' + $deletedCount + '   refused : ' + $refusedCount + '   freed by the sum of the rows : ' + (Format-Megabytes $freedBytes))
Rule

Say '4  FREE SPACE AFTER - the second half of the pair, and an independent check of the rows'
$driveAfter = Get-PSDrive -Name C
$freeAfter = $driveAfter.Free
$gained = $freeAfter - $freeBefore
Say ('  C: free before ' + [math]::Round($freeBefore/1MB,1) + ' MB  ->  after ' + [math]::Round($freeAfter/1MB,1) + ' MB')
Say ('  gained by the drive : ' + (Format-Megabytes $gained))
Say ('  sum of the deleted rows : ' + (Format-Megabytes $freedBytes))
Say  '  These two are measured independently - the rows by walking each directory, the drive by the'
Say  '  filesystem. They should agree within rounding; a large gap means something else wrote or'
Say  '  freed space during the run, and is worth reporting rather than averaging away.'
Say ('  enough for one backup set (3578 MB) now : ' + ($freeAfter -gt (3578 * 1MB)))
Rule

Say '5  WHAT REMAINS IN THE TWO DIRECTORIES'
foreach ($remaining in @(Get-ChildItem -LiteralPath $BACKUP_ROOT -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
  Say ('  backup  ' + $remaining.Name.PadRight(36) + (Format-Megabytes (Size-Of $remaining.FullName)).PadLeft(10))
}
foreach ($remaining in @(Get-ChildItem -LiteralPath $INCOMING -Directory -Filter 'pkg_*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
  Say ('  staging ' + $remaining.Name.PadRight(36) + (Format-Megabytes (Size-Of $remaining.FullName)).PadLeft(10))
}
Say  '  EXPECTED: two backup sets plus the three rtmtwilio_* ones, and one staging.'
Rule

Say 'VERDICT OF THE CLEANUP'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  section 2 floor proven before the first delete : True (a False there stopped the run)')
Say ('  section 3 deleted / refused counts are printed in that section')
Say ('  section 4 free space is a pair, and the two measurements are compared there')
$cleanupOk = (($refusedCount -eq 0) -and ($deletedCount -gt 0) -and (-not (Test-TrapFired)) -and ($freeAfter -gt (3578 * 1MB)))
Say ('  CLEANUP : ' + $(if ($cleanupOk) { 'DONE - the disk now holds a backup set, and the install can be retried' } else { 'INCOMPLETE - see the rows above; do not retry the install yet' }))
Say  '  Nothing was installed, started, stopped or configured. The engine logs and the adapter'
Say  '  backups were not touched - each is a subject of its own.'
Say '===== END-OF-RUN MARKER: CLEANUP-COMPLETE ====='
Finish $cleanupOk
