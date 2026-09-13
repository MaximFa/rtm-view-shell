#Requires -Version 5.1
<#
  PROBE DEV / halt-test wipe-step4   -   LOCAL machine. Server 234 is NOT contacted.
  This box deletes a directory. Before it is issued, two abilities are MEASURED, not claimed:
    (1) it stops when -Proceed is absent;
    (2) G0 refuses to run on the wrong machine.
  ISOLATION : in every variant the deletion target is redirected into a throw-away sandbox tree
              and Remove-Item is replaced by a print. Nothing on this machine can be deleted by
              this test, and each variant refuses to run if the substitution did not take.
  VARIANTS (all without -Proceed):
    A  real box, G0 aimed at THIS machine  -> MUST stop at the declared line, no deletion
    B  A + the OLD broken Fin              -> MUST be caught by the sentinel
    C  A + both guards removed             -> MUST reach the deletion  (positive control)
    D  real box with the REAL 234 marks    -> MUST fail G0 and never reach P1
#>
$ErrorActionPreference = "Continue"
Write-Host ("PowerShell : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }

$src = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260907_wipe-step4-v2.ps1"
if (-not (Test-Path $src)) { Write-Host "STOP: box not found."; exit 1 }

$b = [IO.File]::ReadAllBytes($src)
$bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
$nul = @($b | Where-Object { $_ -eq 0 }).Count
$sha = (Get-FileHash $src -Algorithm SHA256).Hash
$hashOk = ($sha -eq "17A31910EA90245AAEC0DB1BF1AEE811EB27B326FE90E235C372A5C5C8914C6E")
Write-Host ""
Write-Host "===== BYTES ====="
Write-Host ("  bytes  : {0}   (expect 17581)" -f $b.Length)
Write-Host ("  BOM    : {0}   NUL : {1}" -f $bom, $nul)
Write-Host ("  sha256 : {0}" -f $sha)
Write-Host ("  matches expected : {0}" -f $hashOk)

$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$null, [ref]$e)
$errs = @($e)
Write-Host ("  parse errors : {0}" -f $errs.Count)
foreach ($er in $errs) { Write-Host ("    line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) }

$sand = Join-Path $env:TEMP ("halt4_{0}" -f [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path (Join-Path $sand "output") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sand "preserve_20260906_1230") | Out-Null
$fakeTarget = Join-Path $sand "FakeRTMView"
New-Item -ItemType Directory -Force -Path $fakeTarget | Out-Null
Set-Content -Path (Join-Path $fakeTarget "x.txt") -Value "sandbox" -Encoding ASCII

$lines = [IO.File]::ReadAllLines($src)
$iP1 = -1; $iVerdict = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -like '*P1 the services are gone*'      -and $iP1 -lt 0)      { $iP1 = $i }
    if ($lines[$i] -like '*---------------- verdict ----------------*' -and $iVerdict -lt 0) { $iVerdict = $i }
}
Write-Host ""
Write-Host ("gate block located : lines {0}..{1}   (both must be > 0)" -f $iP1, $iVerdict)
if ($iP1 -lt 1 -or $iVerdict -le $iP1) { Write-Host "STOP: cannot locate the gate block."; Remove-Item $sand -Recurse -Force; exit 1 }

$myUuid = "$((Get-WmiObject Win32_ComputerSystemProduct).UUID)".ToUpper()
$myMac  = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" | ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() })[0]

function Build([string]$name, [bool]$breakFin, [bool]$dropSentinel, [bool]$keepRealG0, [bool]$keepGates) {
    if ($keepGates) { $body = $lines }
    else {
        $head = $lines[0..($iP1-1)]
        $tail = $lines[$iVerdict..($lines.Count-1)]
        $body = @($head) + @('$fail = 0', '$iceBefore = 0', 'Say "  [halt-test] gate block replaced - forced green"') + @($tail)
    }
    $txt = ($body -join "`r`n")
    $txt = $txt.Replace('$OpsRoot   = "C:\RTMView-Ops"', ('$OpsRoot   = "' + $sand + '"'))
    $txt = $txt.Replace('$Target    = "C:\RTMView"',      ('$Target    = "' + $fakeTarget + '"'))
    $txt = $txt.Replace('Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue',
                        'Write-Host "  [halt-test] Remove-Item SUPPRESSED for $Target"')
    if (-not $keepRealG0) {
        $txt = $txt.Replace('$expName = "RTM"', ('$expName = "' + $env:COMPUTERNAME + '"'))
        $txt = $txt.Replace('$expUuid = "E9516FFB-3068-47EA-8860-6A9D764325E6"', ('$expUuid = "' + $myUuid + '"'))
        $txt = $txt.Replace('$expMac  = "000D3AD3061B"', ('$expMac  = "' + $myMac + '"'))
    }
    if ($breakFin) { $txt = $txt.Replace('if ($pass) { exit 0 } else { exit 1 }', 'if (-not $pass) { exit 1 }') }
    if ($dropSentinel) {
        $txt = $txt.Replace('    Say "*** SENTINEL: execution reached the deletion without -Proceed. This must never happen."', '    Say "[sentinel removed]"')
        $txt = $txt.Replace('    Say "*** Nothing has been deleted. Aborting."', '    $null = $null')
        $txt = $txt.Replace('    Fin $false', '    $null = $null')
    }
    $f = Join-Path $sand ($name + ".ps1")
    [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($true)))
    $iso = (-not $txt.Contains('$Target    = "C:\RTMView"')) -and (-not $txt.Contains('Remove-Item -LiteralPath $Target'))
    Write-Host ("  {0,-20} isolation applied : {1}   (must be True)" -f $name, $iso)
    if (-not $iso) { Write-Host "  STOP: isolation did not apply."; Remove-Item $sand -Recurse -Force; exit 1 }
    return $f
}
function RunIt([string]$path) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    return @{ code = $LASTEXITCODE; text = (($out | ForEach-Object { "$_" }) -join "`n") }
}

Write-Host ""
Write-Host "===== building the variants ====="
$A = Build "A_real"      $false $false $false $false
$B = Build "B_brokenFin" $true  $false $false $false
$C = Build "C_noguards"  $true  $true  $false $false
$D = Build "D_wrongbox"  $false $false $true  $true

$ra = RunIt $A; $rb = RunIt $B; $rc = RunIt $C; $rd = RunIt $D
$aG0      = $ra.text.Contains("G0 PASS")
$aStopped = $ra.text.Contains("Step 4 was NOT executed")
# NOTE 2026-09-06: this first read "DELETING", which also appears in the box's OWN HEADER line
# ("STEP 4 - DELETING C:\RTMView\ ..."), so variant A was failed by its own banner rather than by
# any deletion. The marker must be the line that begins the STEP, not a word that describes it.
$aNoDel   = -not $ra.text.Contains("STEP 4  DELETING")
$bSent    = $rb.text.Contains("SENTINEL: execution reached the deletion")
$bNoDel   = -not $rb.text.Contains("STEP 4  DELETING")
$cReached = $rc.text.Contains("STEP 4  DELETING")
$dFailed  = $rd.text.Contains("G0 FAILED - THIS IS NOT SERVER 234")
$dNoP1    = -not $rd.text.Contains("P1 our four services are unregistered")

Write-Host ""
Write-Host "===== A - real box, no -Proceed ====="
Write-Host ("  exit {0}   G0 PASS {1}   stopped at declared line {2}   no deletion {3}" -f $ra.code, $aG0, $aStopped, $aNoDel)
Write-Host "===== B - old broken Fin ====="
Write-Host ("  exit {0}   sentinel caught {1}   no deletion {2}" -f $rb.code, $bSent, $bNoDel)
Write-Host "===== C - both guards removed (positive control) ====="
Write-Host ("  exit {0}   DID reach the deletion {1}   (must be True)" -f $rc.code, $cReached)
Write-Host "===== D - real box on the WRONG machine (positive control of G0) ====="
Write-Host ("  exit {0}   G0 refused {1}   never reached P1 {2}" -f $rd.code, $dFailed, $dNoP1)

$sandboxFileSurvived = (Test-Path (Join-Path $fakeTarget "x.txt"))
Write-Host ""
Write-Host ("  the sandbox file was never actually deleted : {0}   (must be True)" -f $sandboxFileSurvived)
Remove-Item $sand -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($bom -and $nul -eq 0 -and $hashOk -and $errs.Count -eq 0 -and $aG0 -and $aStopped -and $aNoDel -and $bSent -and $bNoDel -and $cReached -and $dFailed -and $dNoP1 -and $sandboxFileSurvived) {
    Write-Host "VERDICT: PASS - the box stops without -Proceed, refuses the wrong machine, and the"
    Write-Host "         stripped variant does reach the deletion, so the test can tell them apart."
} else { Write-Host "VERDICT: FAIL - do NOT copy it to 234." }
