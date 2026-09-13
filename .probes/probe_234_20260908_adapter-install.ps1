#Requires -Version 5.1
<#
  PROBE 234 / adapter-install   -   installs the adapter BY HAND, as the procedure requires.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  SAFETY        : without -Proceed it ONLY reads and prints. Three layers enforce that.
  ORDER IS THE POINT : deploy files -> place the preserved config -> PROVE the config by READING
                  IT BACK FROM DISK -> only then register and start. On 30 August the config was
                  believed written, a restart came between the edit and the check, and our
                  service raised the PRODUCTION adapter. So nothing starts until the name on
                  disk has been read and shown.
  NEVER TOUCHED : the production service RTM.Twilio and the legacy RTM - not started, not stopped,
                  not reconfigured. Their state is recorded before and after and compared.
  SOURCE        : C:\RTMView-Ops\incoming\RTM.Twilio_8abd19a_pertarget.zip - the ONLY archive on
                  this machine containing RTM.Twilio.exe (measured 2026-09-08; the adapter's own
                  directory and both of its Backup snapshots went with the wipe).
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$CurDir    = Join-Path $Preserve "configs\current"
$Zip       = Join-Path $OpsRoot "incoming\RTM.Twilio_8abd19a_pertarget.zip"
$ZipHash   = "E7B53153009CECE5F1E5C5AE3DB147EC382A1AC080C27A967E3E768685EE45D1"
$CfgSrc    = Join-Path $CurDir "RTM.Twilio__appsettings.json"
$CfgHash   = "93060DFBAE26B93062473844C2578FD7209DFE75470D0FCEBDD944467737CC01"
$Dest      = "C:\RTMView\RTM.Twilio"
$SvcName   = "RTMTwilio_1"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_adapter-install.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say ("mode : {0}" -f $(if ($Proceed) { "INSTALL (-Proceed given)" } else { "PREVIEW ONLY - nothing will be installed" }))
Say ""
Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
Say ("  name {0} / uuid {1} / mac {2}" -f $n, $u, $m)
if (-not ($n -and $u -and $m)) { Say "  *** G0 FAILED - not server 234."; Fin $false }
Say "  G0 PASS"

$fail = 0

# ---------------- the untouchables, BEFORE ----------------
Say ""
Say "===== the production contour, BEFORE - recorded so that 'we did not touch it' is a measurement ====="
$prodBefore = @{}
foreach ($nm in @('RTM.Twilio','RTM')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $st = $(if ($s) { "$($s.Status)" } else { "not present" })
    $prodBefore[$nm] = $st
    $w = Get-WmiObject Win32_Service -Filter "Name='$nm'" -ErrorAction SilentlyContinue
    Say ("  {0,-12} {1,-12} {2}" -f $nm, $st, $(if ($w) { $w.PathName } else { "" }))
}
$iceBefore = @(Get-ChildItem 'C:\IceDash' -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("  files under C:\IceDash\ : {0}" -f $iceBefore)

# ---------------- sources ----------------
Say ""
Say "===== the two sources, proved by content ====="
if (-not (Test-Path $Zip)) { Say ("  *** MISSING: {0}" -f $Zip); Fin $false }
$zh = (Get-FileHash $Zip -Algorithm SHA256).Hash
Say ("  archive : {0}" -f $Zip)
Say ("  sha256  : {0}" -f $zh)
Say ("  matches the inventoried archive : {0}   (must be True)" -f ($zh -eq $ZipHash))
if ($zh -ne $ZipHash) { Say "  *** STOP - not the archive we inventoried."; $fail++ }

if (-not (Test-Path $CfgSrc)) { Say ("  *** MISSING: {0}" -f $CfgSrc); $fail++ }
else {
    $ch = (Get-FileHash $CfgSrc -Algorithm SHA256).Hash
    Say ("  config  : {0}" -f $CfgSrc)
    Say ("  sha256  : {0}   matches preserved : {1}   (must be True)" -f $ch, ($ch -eq $CfgHash))
    if ($ch -ne $CfgHash) { Say "  *** STOP - the preserved adapter config is not the one we evacuated."; $fail++ }
}
Say ("  destination {0} exists : {1}   (expected False before install)" -f $Dest, (Test-Path $Dest))
$svc0 = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
Say ("  service {0} : {1}   (expected: not registered)" -f $SvcName, $(if ($svc0) { $svc0.Status } else { "not registered" }))
if ($svc0) { Say "  *** the service already exists - report, do not overwrite blindly."; $fail++ }

Say ""
Say "===== what the deployed RTM expects, read FROM DISK ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$expName = $null
if (Test-Path $rtmCfg) {
    $rt = [IO.File]::ReadAllText($rtmCfg)
    $mm = [regex]::Match($rt, '"AdaptorServiceName"\s*:\s*"([^"]*)"')
    if ($mm.Success) { $expName = $mm.Groups[1].Value }
    Say ("  AdaptorServiceName on disk : {0}" -f $(if ($expName) { $expName } else { "key absent" }))
    Say ("  equals the name we will register ({0}) : {1}   (must be True)" -f $SvcName, ($expName -eq $SvcName))
    Say ("  NEGCTL equals the PRODUCTION name (RTM.Twilio) : {0}   (must be False - that is the 30 August accident)" -f ($expName -eq 'RTM.Twilio'))
    if ($expName -ne $SvcName) { Say "  *** STOP - RTM points at a different adapter than the one we are about to create."; $fail++ }
} else { Say "  *** deployed RTM config missing"; $fail++ }

if ($fail -gt 0) { Say ""; Say ("===== CHECKS FAILED ({0}). NOTHING INSTALLED. =====" -f $fail); Fin $false }

if (-not $Proceed) {
    Say ""
    Say "PREVIEW ONLY. Nothing was installed. Run again with -Proceed to deploy the files, place the"
    Say "preserved config, PROVE it by reading it back, then register and start the service."
    Fin $true
}
if (-not $Proceed) { Say "*** SENTINEL: reached the install without -Proceed."; Fin $false }

# ---------------- deploy ----------------
Say ""
Say "===== 1  deploying files ====="
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$tmp = Join-Path $env:TEMP ("adp_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
try { [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $tmp) }
catch { Say ("  *** unpack failed: {0}" -f $_.Exception.Message); Fin $false }
$src = @(Get-ChildItem $tmp -Recurse -File)
Say ("  extracted : {0} files" -f $src.Count)
$exe = @(Get-ChildItem $tmp -Recurse -File -Filter "RTM.Twilio.exe")
if ($exe.Count -ne 1) { Say ("  *** expected exactly one RTM.Twilio.exe, found {0}" -f $exe.Count); Fin $false }
$root = Split-Path $exe[0].FullName -Parent
Say ("  payload root : {0}" -f $root)
Copy-Item -Path (Join-Path $root "*") -Destination $Dest -Recurse -Force
$dst = @(Get-ChildItem $Dest -Recurse -File)
Say ("  deployed  : {0} files" -f $dst.Count)
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# ---------------- config ----------------
Say ""
Say "===== 2  the preserved config, then PROVED by reading it back ====="
$cfgDst = Join-Path $Dest "appsettings.json"
Copy-Item -LiteralPath $CfgSrc -Destination $cfgDst -Force
$backHash = (Get-FileHash $cfgDst -Algorithm SHA256).Hash
Say ("  written : {0}" -f $cfgDst)
Say ("  sha256 read back from disk : {0}" -f $backHash)
Say ("  equals the preserved config : {0}   (must be True)" -f ($backHash -eq $CfgHash))
if ($backHash -ne $CfgHash) { Say "  *** STOP - the config on disk is not the preserved one. Nothing is started."; Fin $false }

Say ""
Say "  and once more, the name RTM will call - read from disk, not assumed:"
$rt2 = [IO.File]::ReadAllText($rtmCfg)
$m2 = [regex]::Match($rt2, '"AdaptorServiceName"\s*:\s*"([^"]*)"')
$nameOnDisk = $(if ($m2.Success) { $m2.Groups[1].Value } else { "<absent>" })
Say ("      AdaptorServiceName = {0}" -f $nameOnDisk)
Say ("      is ours ({0}) : {1}   (must be True)" -f $SvcName, ($nameOnDisk -eq $SvcName))
Say ("      is production (RTM.Twilio) : {0}   (must be False)" -f ($nameOnDisk -eq 'RTM.Twilio'))
if ($nameOnDisk -ne $SvcName) { Say "  *** STOP - nothing is started."; Fin $false }

# ---------------- register ----------------
Say ""
Say "===== 3  registering the service - only now, with the name proved ====="
$exePath = Join-Path $Dest "RTM.Twilio.exe"
if (-not (Test-Path $exePath)) { Say ("  *** MISSING: {0}" -f $exePath); Fin $false }
& sc.exe create $SvcName binPath= "`"$exePath`"" start= auto | Out-Null
Start-Sleep -Seconds 2
& sc.exe description $SvcName "RTM Twilio adaptor (ours, RTMTwilio_1)" | Out-Null
$svc1 = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
Say ("  {0} registered : {1}" -f $SvcName, ($svc1 -ne $null))
if (-not $svc1) { Say "  *** registration failed"; Fin $false }
$w1 = Get-WmiObject Win32_Service -Filter "Name='$SvcName'"
Say ("  binPath : {0}" -f $w1.PathName)
Say ("  points inside our directory : {0}   (must be True)" -f ("$($w1.PathName)" -like "*C:\RTMView\RTM.Twilio*"))

Say ""
Say "===== 4  starting ====="
Start-Service -Name $SvcName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 6
$svc2 = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
Say ("  {0} : {1}" -f $SvcName, $svc2.Status)
if ($svc2.Status -ne 'Running') { Say "  *** did not start - report, do not retry blindly"; $fail++ }

# ---------------- the untouchables, AFTER ----------------
Say ""
Say "===== the production contour, AFTER - compared, not asserted ====="
foreach ($nm in @('RTM.Twilio','RTM')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $st = $(if ($s) { "$($s.Status)" } else { "not present" })
    $same = ($st -eq $prodBefore[$nm])
    Say ("  {0,-12} before {1,-12} after {2,-12} unchanged: {3}" -f $nm, $prodBefore[$nm], $st, $same)
    if (-not $same) { Say ("  *** {0} CHANGED - report immediately" -f $nm); $fail++ }
}
$iceAfter = @(Get-ChildItem 'C:\IceDash' -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("  files under C:\IceDash\ : before {0} after {1} - identical: {2}" -f $iceBefore, $iceAfter, ($iceBefore -eq $iceAfter))
if ($iceBefore -ne $iceAfter) { $fail++ }

Say ""
Say "===== state of all four ====="
foreach ($nm in @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    Say ("  {0,-16} {1}" -f $nm, $(if ($s) { $s.Status } else { "not registered" }))
}
Say "  (RTMApplyService is expected to be absent - the installer does not register it)"

Say ""
Say "===== END-OF-RUN MARKER: ADAPTER-INSTALL-COMPLETE ====="
Say ""
Say "Liveness (/health 200 AND the named pipe) is the NEXT step, deliberately not folded in here."
Fin ($fail -eq 0)
