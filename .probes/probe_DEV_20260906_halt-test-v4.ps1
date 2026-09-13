#Requires -Version 5.1
<#
  PROBE DEV / halt-test wipe-step1-3-v4   -   LOCAL machine. Server 234 is NOT contacted.
  PURPOSE       : measure two abilities of the box instead of claiming them:
                    (1) it STOPS when -Proceed is absent;
                    (2) G0 REFUSES to run on the wrong machine.
                  Reading the file caught neither defect this morning. Running it caught both.
  ISOLATION     : in every variant the four service names are replaced by names that cannot
                  exist, and Stop-Service / Stop-Process / sc.exe delete are suppressed. Each
                  variant refuses to run if the substitution did not take.
  VARIANTS, all run WITHOUT -Proceed:
    A  real v4, G0 pointed at THIS machine   -> MUST stop at the declared line, no step 2
    B  A + the OLD broken Fin                -> MUST be caught by the sentinel
    C  A + both guards removed               -> MUST reach step 2  (positive control of the test)
    D  real v4 with the REAL 234 references  -> MUST fail G0 and never reach G1
                                                (positive control of G0 itself)
#>

$ErrorActionPreference = "Continue"
Write-Host ("PowerShell : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe, not pwsh."; exit 1 }

$src = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_wipe-step1-3-v4.ps1"
if (-not (Test-Path $src)) { Write-Host "STOP: box not found: $src"; exit 1 }

Write-Host ""
Write-Host "===== what of ours lives on THIS machine (read only, nothing is touched) ====="
foreach ($n in @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) {
        $w = Get-WmiObject Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue
        Write-Host ("  PRESENT  {0,-16} {1,-9} {2}" -f $n, $s.Status, $w.PathName)
    } else { Write-Host ("  absent   {0,-16}" -f $n) }
}
Write-Host ("  this machine : {0}   (the box's G0 expects RTM - that is the point of variant D)" -f $env:COMPUTERNAME)

$sand = Join-Path $env:TEMP ("halttest_{0}" -f [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $sand | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sand "output") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sand "preserve_20260906_1230") | Out-Null

$lines = [IO.File]::ReadAllLines($src)
$iG1 = -1; $iVerdict = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -like '*---------------- G1 ----------------*'      -and $iG1 -lt 0)      { $iG1 = $i }
    if ($lines[$i] -like '*---------------- verdict ----------------*' -and $iVerdict -lt 0) { $iVerdict = $i }
}
Write-Host ""
Write-Host ("gate block located : lines {0}..{1}   (both must be > 0)" -f $iG1, $iVerdict)
if ($iG1 -lt 1 -or $iVerdict -le $iG1) { Write-Host "STOP: cannot locate the gate block."; Remove-Item $sand -Recurse -Force; exit 1 }

$myUuid = "$((Get-WmiObject Win32_ComputerSystemProduct).UUID)".ToUpper()
$myMac  = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" | ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() })[0]

function Build([string]$name, [bool]$breakFin, [bool]$dropSentinel, [bool]$keepRealG0, [bool]$keepGates) {
    if ($keepGates) { $body = $lines }
    else {
        $head = $lines[0..($iG1-1)]
        $tail = $lines[$iVerdict..($lines.Count-1)]
        $body = @($head) + @('$fail = 0', 'Say "  [halt-test] gate block G1-G7 replaced - forced green"') + @($tail)
    }
    $txt = ($body -join "`r`n")
    $txt = $txt.Replace('$OpsRoot   = "C:\RTMView-Ops"', ('$OpsRoot   = "' + $sand + '"'))
    if (-not $keepRealG0) {
        $txt = $txt.Replace('$expName = "RTM"', ('$expName = "' + $env:COMPUTERNAME + '"'))
        $txt = $txt.Replace('$expUuid = "E9516FFB-3068-47EA-8860-6A9D764325E6"', ('$expUuid = "' + $myUuid + '"'))
        $txt = $txt.Replace('$expMac  = "000D3AD3061B"', ('$expMac  = "' + $myMac + '"'))
    }
    $txt = $txt.Replace("`$ours  = @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')", "`$ours  = @('ZZZNoSuchSvc_A','ZZZNoSuchSvc_B','ZZZNoSuchSvc_C','ZZZNoSuchSvc_D')")
    $txt = $txt.Replace("`$never = @('RTM.Twilio','RTM')", "`$never = @('ZZZNoSuchSvc_E','ZZZNoSuchSvc_F')")
    $txt = $txt.Replace('& sc.exe delete $n | Out-Null', 'Write-Host "  [halt-test] sc.exe delete SUPPRESSED for $n"')
    $txt = $txt.Replace('Stop-Service -Name $n -Force -ErrorAction SilentlyContinue', 'Write-Host "  [halt-test] Stop-Service SUPPRESSED for $n"')
    $txt = $txt.Replace("Stop-Process -Id `$o.Id -Force -ErrorAction SilentlyContinue", 'Write-Host "  [halt-test] Stop-Process SUPPRESSED"')
    if ($breakFin) { $txt = $txt.Replace('if ($pass) { exit 0 } else { exit 1 }', 'if (-not $pass) { exit 1 }') }
    if ($dropSentinel) {
        $txt = $txt.Replace('    Say "*** SENTINEL: execution reached STEP 2 without -Proceed. This must never happen."', '    Say "[sentinel removed]"')
        $txt = $txt.Replace('    Say "*** Nothing has been stopped. Aborting."', '    $null = $null')
        $txt = $txt.Replace('    Fin $false', '    $null = $null')
    }
    $f = Join-Path $sand ($name + ".ps1")
    [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($true)))
    $iso = (-not $txt.Contains("'RTMViewShell'")) -and (-not $txt.Contains('& sc.exe delete'))
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
$A = Build "variantA_real"      $false $false $false $false
$B = Build "variantB_brokenFin" $true  $false $false $false
$C = Build "variantC_noguards"  $true  $true  $false $false
$D = Build "variantD_wrongbox"  $false $false $true  $true

Write-Host ""
Write-Host "===== A - real v4, run WITHOUT -Proceed ====="
$ra = RunIt $A
$aStopped = $ra.text.Contains("Steps 2-3 were NOT executed")
$aNoStep2 = -not $ra.text.Contains("STEP 2 stop our four services")
$aG0 = $ra.text.Contains("G0 PASS")
Write-Host ("  exit code                      : {0}" -f $ra.code)
Write-Host ("  G0 passed (pointed at this box): {0}   (must be True)" -f $aG0)
Write-Host ("  reached the declared stop line : {0}   (must be True)" -f $aStopped)
Write-Host ("  did NOT reach step 2           : {0}   (must be True)" -f $aNoStep2)

Write-Host ""
Write-Host "===== B - old broken Fin, sentinel intact ====="
$rb = RunIt $B
$bSentinel = $rb.text.Contains("SENTINEL: execution reached STEP 2 without -Proceed")
$bNoStep2  = -not $rb.text.Contains("STEP 2 stop our four services")
Write-Host ("  exit code                      : {0}" -f $rb.code)
Write-Host ("  sentinel caught it             : {0}   (must be True)" -f $bSentinel)
Write-Host ("  did NOT reach step 2           : {0}   (must be True)" -f $bNoStep2)

Write-Host ""
Write-Host "===== C - both guards removed  (positive control of the halt test) ====="
$rc = RunIt $C
$cReached = $rc.text.Contains("STEP 2 stop our four services")
Write-Host ("  exit code                      : {0}" -f $rc.code)
Write-Host ("  DID reach step 2               : {0}   (must be True - else the test proves nothing)" -f $cReached)

Write-Host ""
Write-Host "===== D - the REAL box on the WRONG machine  (positive control of G0) ====="
$rd = RunIt $D
$dFailed  = $rd.text.Contains("G0 FAILED - THIS IS NOT SERVER 234")
$dNoG1    = -not $rd.text.Contains("G1 the evacuation is intact")
$dNoStep2 = -not $rd.text.Contains("STEP 2 stop our four services")
Write-Host ("  exit code                      : {0}   (must be 1)" -f $rd.code)
Write-Host ("  G0 refused this machine        : {0}   (must be True)" -f $dFailed)
Write-Host ("  never reached G1               : {0}   (must be True - it exits, it does not warn)" -f $dNoG1)
Write-Host ("  never reached step 2           : {0}   (must be True)" -f $dNoStep2)

Remove-Item $sand -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host ("sandbox removed : {0}" -f (-not (Test-Path $sand)))

Write-Host ""
if ($aG0 -and $aStopped -and $aNoStep2 -and $bSentinel -and $bNoStep2 -and $cReached -and $dFailed -and $dNoG1 -and $dNoStep2 -and $rd.code -eq 1) {
    Write-Host "VERDICT: PASS - both abilities are measured, not claimed."
    Write-Host "         The box stops without -Proceed; stripped of its guards it does not, so the"
    Write-Host "         test can tell the difference. And on the wrong machine it refuses at G0,"
    Write-Host "         before reading anything at all."
} else {
    Write-Host "VERDICT: FAIL - do not issue this box."
}
