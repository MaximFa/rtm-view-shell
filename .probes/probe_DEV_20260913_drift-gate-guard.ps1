#Requires -Version 5.1
<#
  PROBE DEV / drift-gate-guard      the regression guard for PR234-INST-12.
  WHERE IT RUNS : any machine that has the CLONE - it is a static check over the OBJECT STORE, not over
                  a server. It touches no service, no config, no database and no production host. It
                  runs git only in read mode.

  WHY A GUARD AND NOT JUST A FIX. PR234-INST-12 was not a wrong path: it was a check that went GREEN
  precisely when it was not in force. `deploy/Update-RTMView.ps1` searched for the drift tool only in the
  PARENT of its own directory, which is correct in the repo layout and wrong in every package layout -
  and a deploy always runs from a package. So on every deployed server the mandatory gate (role-devops
  A.1) degraded to `[WARN] ... skipping drift gate` and the deploy continued. Nothing failed; the check
  simply never ran. A fix alone does not stop that from coming back, because the symptom of its return is
  SILENCE. This guard turns the silence into a red line.

  WHY IT READS THE STORE AND NOT THE DISK (NORM-CUR-13). What ships is the committed blob; the working
  tree can differ and has, in this project, differed before. The guard therefore reads
  `git show <rev>:deploy/Update-RTMView.ps1`, and separately proves the disk and the store agree, so a
  pass can never come from an uncommitted edit.

  WHAT IT ASSERTS - every expectation is a NUMBER named before the run:
    0. NEGCTL: a marker that cannot exist -> 0. Run first, so a broken harness cannot pass items 1-5.
    1. 'skipping drift gate'                       -> 0   the WARN-skip must be gone
    2. 'not found in either layout'                -> 1   a missing tool now THROWS
    3. lines with db\tools\Compare-ToBaseline.ps1  -> 2   BOTH layouts are searched
    4. '$ScriptDir "db\tools\Compare-ToBaseline'   -> 1   the package candidate exists
       '(Split-Path -Parent $ScriptDir) "db\tools' -> 1   the repo candidate exists
    5. 'ForceDeploy -or $SkipDrift'                -> 1   the operator escape hatch is still there, because
                                                          a throw without a recorded way past it would
                                                          trade a silent green for a hard block
    6. store == disk for that file                       a pass must describe what ships
  A FAIL here means the defect is back, or the fix was edited into a shape the guard does not recognise -
  in which case read the fix and update this guard deliberately, rather than relaxing the numbers.
#>

$ErrorActionPreference = 'Continue'
$REV = 'HEAD'
if ($args.Count -ge 1 -and "$($args[0])" -ne '') { $REV = "$($args[0])" }
$TARGET = 'deploy/Update-RTMView.ps1'
$SENTINEL = -999

$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
function Fin($pass) {
    Write-Host ''
    Write-Host $(if ($pass) { 'VERDICT: PASS (PR234-INST-12 stays fixed)' } else { 'VERDICT: FAIL (see the failed items above)' })
    if ($pass) { exit 0 } else { exit 1 }
}

Say ('===== drift-gate guard (PR234-INST-12) over ' + $REV + ':' + $TARGET + ' =====')
Say ('  now : ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} (want 0) , two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** assignment gate broken - measuring nothing'; Fin $false }

$blob = & git show ($REV + ':' + $TARGET) 2>&1
if ($LASTEXITCODE -ne 0) { Say ('  *** git show failed: ' + ($blob -join ' ')); Fin $false }
$lines = @($blob)
Say ('  lines in the stored blob : {0}' -f (Safe-Count $lines))
if ((Safe-Count $lines) -lt 50) { Say '  *** implausibly short - refusing to judge'; Fin $false }

$fail = 0
function Check($label, $actual, $expected) {
    $ok = ($actual -eq $expected)
    if (-not $ok) { $script:fail++ }
    Say ('  {0,-52} actual {1,-4} expected {2,-4} {3}' -f $label, $actual, $expected, $(if ($ok) { 'OK' } else { '*** FAIL' }))
}

Say ''
Say '  item 0  NEGCTL first, so a broken harness cannot pass the rest'
Check 'marker that cannot exist' (Safe-Count @($lines | Where-Object { $_.Contains('ThisMarkerMustNotExist') })) 0
if ($fail -gt 0) { Say '  *** the negative control matched - the harness is broken, items below mean nothing'; Fin $false }

Say ''
Say '  items 1-5  the fix itself'
Check "1 'skipping drift gate' (the WARN-skip is gone)" (Safe-Count @($lines | Where-Object { $_.Contains('skipping drift gate') })) 0
Check "2 'not found in either layout' (a miss THROWS)" (Safe-Count @($lines | Where-Object { $_.Contains('not found in either layout') })) 1
Check '3 lines naming db\tools\Compare-ToBaseline.ps1' (Safe-Count @($lines | Where-Object { $_.Contains('db\tools\Compare-ToBaseline.ps1') })) 2
Check '4a package candidate  $ScriptDir' (Safe-Count @($lines | Where-Object { $_.Contains('Join-Path $ScriptDir "db\tools\Compare-ToBaseline.ps1"') })) 1
Check '4b repo candidate     parent of $ScriptDir' (Safe-Count @($lines | Where-Object { $_.Contains('Join-Path (Split-Path -Parent $ScriptDir) "db\tools\Compare-ToBaseline.ps1"') })) 1
Check '5 operator escape hatch still present' (Safe-Count @($lines | Where-Object { $_.Contains('$ForceDeploy -or $SkipDrift') })) 1

Say ''
Say '  item 6  store == disk, so a pass describes what SHIPS (NORM-CUR-13)'
$storeHash = (& git rev-parse ($REV + ':' + $TARGET) 2>&1) | Select-Object -First 1
$diskHash  = $null
if (Test-Path -LiteralPath $TARGET) { $diskHash = (& git hash-object $TARGET 2>&1) | Select-Object -First 1 }
Say ('  store {0}' -f $storeHash)
Say ('  disk  {0}' -f $(if ($diskHash) { $diskHash } else { 'FILE NOT PRESENT (running outside the clone root?)' }))
if ($null -eq $diskHash) {
    Say '  *** cannot compare - run this from the clone root. Not counting it as a pass.'
    $fail++
} else {
    Check '6 store equals disk' $(if ($storeHash -eq $diskHash) { 1 } else { 0 }) 1
}

Say ''
Say ('  failed items : {0}' -f $fail)
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin ($fail -eq 0)
