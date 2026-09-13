#Requires -Version 5.1
<#
  PROBE DEV / halt-test wipe-step1-3-v3  v2   -   LOCAL machine. Server 234 is NOT contacted.
  PURPOSE       : measure, do not claim, that the box STOPS when -Proceed is absent.
                  On 2026-09-06 a box that printed "steps 2-3 were NOT executed" went on to
                  execute them. Reading the file did not catch it. Running it did.
  WHY v2        : v1 refused to run because services of ours exist on THIS machine. Refusing
                  leaves the guard unmeasured, which is the thing we are trying to stop doing.
                  So v2 ISOLATES instead: in every test variant the four service names are
                  replaced by names that cannot exist, and every sc.exe call is neutralised.
                  Even the variant with both guards removed can then touch nothing.
  VARIANTS, all run WITHOUT -Proceed, all with gates forced green:
    A  the real v3                    -> MUST stop at the declared line, MUST NOT reach step 2
    B  v3 with the OLD broken Fin     -> MUST be caught by the sentinel (layer 2 earns its place)
    C  both guards removed            -> MUST reach step 2. POSITIVE CONTROL: if C also stopped,
                                         the test cannot tell working from broken and its
                                         verdict on A would be worthless.
  ALSO REPORTS  : which services of ours live on this machine - v1 found two and that is a fact
                  about the environment worth carrying, not an obstacle to route around.
#>

$ErrorActionPreference = "Continue"
Write-Host ("PowerShell : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe, not pwsh."; exit 1 }

$src = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_wipe-step1-3-v3.ps1"
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
Write-Host "  (this probe neither starts, stops nor unregisters anything - it only names them)"

$sand = Join-Path $env:TEMP ("halttest_{0}" -f [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $sand | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sand "output") | Out-Null

$lines = [IO.File]::ReadAllLines($src)
$iG1 = -1; $iVerdict = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -like '*---------------- G1 ----------------*'      -and $iG1 -lt 0)      { $iG1 = $i }
    if ($lines[$i] -like '*---------------- verdict ----------------*' -and $iVerdict -lt 0) { $iVerdict = $i }
}
Write-Host ""
Write-Host ("gate block located : lines {0}..{1}   (both must be > 0)" -f $iG1, $iVerdict)
if ($iG1 -lt 1 -or $iVerdict -le $iG1) { Write-Host "STOP: cannot locate the gate block - the box changed shape."; Remove-Item $sand -Recurse -Force; exit 1 }

$fakeNames = "@('ZZZNoSuchSvc_A','ZZZNoSuchSvc_B','ZZZNoSuchSvc_C','ZZZNoSuchSvc_D')"

function Build([string]$name, [bool]$breakFin, [bool]$dropSentinel) {
    $head = $lines[0..($iG1-1)]
    $tail = $lines[$iVerdict..($lines.Count-1)]
    $body = @($head) + @('$fail = 0', 'Say "  [halt-test] gate block replaced - all gates forced green"') + @($tail)
    $txt  = ($body -join "`r`n")

    # --- isolation, applied to EVERY variant ---
    $txt = $txt.Replace('$OpsRoot   = "C:\RTMView-Ops"', ('$OpsRoot   = "' + $sand + '"'))
    $txt = $txt.Replace("`$ours  = @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')", ('$ours  = ' + $fakeNames))
    $txt = $txt.Replace("`$never = @('RTM.Twilio','RTM')", "`$never = @('ZZZNoSuchSvc_E','ZZZNoSuchSvc_F')")
    $txt = $txt.Replace('& sc.exe delete $n | Out-Null', 'Write-Host "  [halt-test] sc.exe delete SUPPRESSED for $n"')
    $txt = $txt.Replace('Stop-Service -Name $n -Force -ErrorAction SilentlyContinue', 'Write-Host "  [halt-test] Stop-Service SUPPRESSED for $n"')
    $txt = $txt.Replace("Stop-Process -Id `$o.Id -Force -ErrorAction SilentlyContinue", 'Write-Host "  [halt-test] Stop-Process SUPPRESSED"')

    if ($breakFin) { $txt = $txt.Replace('if ($pass) { exit 0 } else { exit 1 }', 'if (-not $pass) { exit 1 }') }
    if ($dropSentinel) {
        $txt = $txt.Replace('    Say "*** SENTINEL: execution reached STEP 2 without -Proceed. This must never happen."', '    Say "[sentinel removed for variant C]"')
        $txt = $txt.Replace('    Say "*** Nothing has been stopped. Aborting."', '    $null = $null')
        $txt = $txt.Replace('    Fin $false', '    $null = $null')
    }
    $f = Join-Path $sand ($name + ".ps1")
    [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($true)))

    # prove the isolation actually took, per variant - a failed Replace must not pass silently
    $iso = (-not $txt.Contains("'RTMViewShell'")) -and (-not $txt.Contains('& sc.exe delete'))
    Write-Host ("  {0,-20} isolation applied : {1}   (must be True)" -f $name, $iso)
    if (-not $iso) { Write-Host "  STOP: isolation did not apply - refusing to run this variant."; Remove-Item $sand -Recurse -Force; exit 1 }
    return $f
}

function RunIt([string]$path) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    return @{ code = $LASTEXITCODE; text = (($out | ForEach-Object { "$_" }) -join "`n") }
}

Write-Host ""
Write-Host "===== building the three variants (service names replaced by names that cannot exist) ====="
$A = Build "variantA_real"      $false $false
$B = Build "variantB_brokenFin" $true  $false
$C = Build "variantC_noguards"  $true  $true

Write-Host ""
Write-Host "===== VARIANT A - the real v3, run WITHOUT -Proceed ====="
$ra = RunIt $A
$aStopped = $ra.text.Contains("Steps 2-3 were NOT executed")
$aNoStep2 = -not $ra.text.Contains("STEP 2 stop our four services")
Write-Host ("  exit code                      : {0}" -f $ra.code)
Write-Host ("  reached the declared stop line : {0}   (must be True)" -f $aStopped)
Write-Host ("  did NOT reach step 2           : {0}   (must be True)" -f $aNoStep2)

Write-Host ""
Write-Host "===== VARIANT B - old broken Fin, sentinel intact ====="
$rb = RunIt $B
$bSentinel = $rb.text.Contains("SENTINEL: execution reached STEP 2 without -Proceed")
$bNoStep2  = -not $rb.text.Contains("STEP 2 stop our four services")
Write-Host ("  exit code                      : {0}" -f $rb.code)
Write-Host ("  sentinel caught it             : {0}   (must be True)" -f $bSentinel)
Write-Host ("  did NOT reach step 2           : {0}   (must be True)" -f $bNoStep2)

Write-Host ""
Write-Host "===== VARIANT C - both guards removed  (POSITIVE CONTROL) ====="
$rc = RunIt $C
$cReached = $rc.text.Contains("STEP 2 stop our four services")
$cSafe    = $rc.text.Contains("SUPPRESSED") -or (-not $rc.text.Contains("unregistered"))
Write-Host ("  exit code                      : {0}" -f $rc.code)
Write-Host ("  DID reach step 2               : {0}   (must be True - else this test proves nothing)" -f $cReached)
Write-Host ("  and touched nothing while there: {0}   (must be True)" -f $cSafe)

Remove-Item $sand -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host ("sandbox removed : {0}" -f (-not (Test-Path $sand)))

Write-Host ""
if ($aStopped -and $aNoStep2 -and $bSentinel -and $bNoStep2 -and $cReached -and $cSafe) {
    Write-Host "VERDICT: PASS - the box's ability to STOP is measured, not claimed."
    Write-Host "         A stops. B is caught by the second layer. C, stripped of both, does not stop"
    Write-Host "         - so the test can tell working from broken, and A's result means something."
} else {
    Write-Host "VERDICT: FAIL - do not issue this box."
}
