#Requires -Version 5.1
<#
  PROBE 234 / restore-datasys   -   returns the machine's own data.sys
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  SAFETY        : without -Proceed it ONLY reads and prints. Three layers enforce that.
  WHAT IT DOES  : stops RTMService, replaces C:\RTMView\RTM\data.sys with the preserved file,
                  verifies by hash, starts RTMService again. Nothing else.
  THREE HASHES  : the report carries all three, because two of them are only meaningful together:
                    A - what the INSTALLER left        (already measured 2026-09-08: 7745C5CA...476D)
                    B - what is there AFTER our return
                    C - the reference from preserve_   (24F0BFAC...DE43)
                  B == C means the return worked. A != C is the standing proof that the installer
                  overwrites a machine's licence file - the observation that took a week to obtain.
  FOUND BY HASH : the preserved copy is located by CONTENT, not by filename. A file called
                  data.sys is not evidence that it IS the data.sys.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$Target    = "C:\RTMView\RTM\data.sys"
$RefHash   = "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"
$InstHash  = "7745C5CA4DF0DD4AE24584343A16A38180CB3E930D1630CD88766C66C44F476D"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_restore-datasys.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say ("mode : {0}" -f $(if ($Proceed) { "RESTORE (-Proceed given)" } else { "PREVIEW ONLY - nothing will be changed" }))
Say ""
Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f $n, $u, $m, (Test-Path $Preserve))
if (-not ($n -and $u -and $m -and (Test-Path $Preserve))) { Say "  *** G0 FAILED - not server 234."; Fin $false }
Say "  G0 PASS"

$fail = 0

# ---------------- A: what is on the machine right now ----------------
Say ""
Say "===== A  what is on the machine right now - what the installer left ====="
if (Test-Path $Target) {
    $hA = (Get-FileHash $Target -Algorithm SHA256).Hash
    Say ("  {0}" -f $Target)
    Say ("  size {0}, sha256 {1}, written {2}" -f (Get-Item $Target).Length, $hA, (Get-Item $Target).LastWriteTime)
    Say ("  equals the installer's file measured right after the install : {0}" -f ($hA -eq $InstHash))
    Say ("  equals OUR preserved file                                    : {0}   (expected False - that is the defect)" -f ($hA -eq $RefHash))
    if ($hA -eq $RefHash) { Say "  NOTE: already ours - the return may have been done before. Not an error; the numbers say so." }
} else {
    $hA = "<absent>"
    Say ("  {0} : ABSENT - the installer left no data.sys." -f $Target)
    Say  "  That is an answer, not a failure. Our file will simply be placed there."
}

# ---------------- C: the preserved copy, found BY HASH ----------------
Say ""
Say "===== C  the preserved copy - located by CONTENT, not by name ====="
$cands = @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Length -eq 320 })
Say ("  files of the right size (320 bytes) under preserve_ : {0}" -f $cands.Count)
$src = $null
foreach ($c in $cands) {
    if ((Get-FileHash $c.FullName -Algorithm SHA256).Hash -eq $RefHash) {
        Say ("      MATCHES the reference hash : {0}" -f $c.FullName)
        if (-not $src) { $src = $c.FullName }
    }
}
if (-not $src) { Say "  *** STOP: no preserved file matches the reference hash. Nothing to restore."; Fin $false }
Say ("  chosen source : {0}" -f $src)
Say ("  NEGCTL a hash that must NOT be found : {0}   (must be False)" -f (@($cands | Where-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq "0000000000000000000000000000000000000000000000000000000000000000" }).Count -gt 0))

Say ""
Say "===== the service that holds the file ====="
$svc = Get-Service -Name RTMService -ErrorAction SilentlyContinue
Say ("  RTMService : {0}" -f $(if ($svc) { $svc.Status } else { "not registered" }))

if (-not $Proceed) {
    Say ""
    Say "PREVIEW ONLY. Nothing was changed. Run again with -Proceed to stop RTMService, place our"
    Say "file, verify by hash and start the service again."
    Fin $true
}

# ---------------- LAYER 2: SENTINEL ----------------
if (-not $Proceed) { Say "*** SENTINEL: reached the restore without -Proceed. Aborting."; Fin $false }

# ---------------- restore ----------------
Say ""
Say "===== RESTORING ====="
if ($svc -and $svc.Status -ne 'Stopped') {
    Stop-Service -Name RTMService -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $s2 = Get-Service -Name RTMService -ErrorAction SilentlyContinue
    Say ("  RTMService stopped : {0}" -f $s2.Status)
    if ($s2.Status -ne 'Stopped') { Say "  *** STOP - service did not stop; the file may be locked."; $fail++; Fin $false }
}

$dir = Split-Path $Target -Parent
if (-not (Test-Path $dir)) { Say ("  *** STOP: {0} does not exist." -f $dir); Fin $false }
Copy-Item -LiteralPath $src -Destination $Target -Force -ErrorAction SilentlyContinue

# ---------------- B: after the return ----------------
Say ""
Say "===== B  after the return - read back from disk ====="
if (-not (Test-Path $Target)) { Say "  *** STOP: the file is not there after the copy."; $fail++ }
else {
    $hB = (Get-FileHash $Target -Algorithm SHA256).Hash
    Say ("  size {0}, sha256 {1}" -f (Get-Item $Target).Length, $hB)
    Say ("  B equals C (our reference) : {0}   (must be True)" -f ($hB -eq $RefHash))
    if ($hB -ne $RefHash) { Say "  *** RESTORE FAILED - the file on disk is not ours."; $fail++ }
}

Say ""
Say "===== THE THREE HASHES, together - this is the point of the whole exercise ====="
Say ("  A installer left : {0}" -f $hA)
Say ("  B after return   : {0}" -f $(if (Test-Path $Target) { (Get-FileHash $Target -Algorithm SHA256).Hash } else { "<absent>" }))
Say ("  C reference      : {0}" -f $RefHash)
Say ("  A == C : {0}   <- False means the installer OVERWROTE the machine's licence file" -f ($hA -eq $RefHash))
Say ("  B == C : {0}   <- True means our file is back" -f ($(if (Test-Path $Target) { (Get-FileHash $Target -Algorithm SHA256).Hash }) -eq $RefHash))

Say ""
Say "===== starting the service again ====="
if ($svc) {
    Start-Service -Name RTMService -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    $s3 = Get-Service -Name RTMService -ErrorAction SilentlyContinue
    Say ("  RTMService : {0}" -f $s3.Status)
    if ($s3.Status -ne 'Running') { Say "  *** service did not start - report, do not retry blindly"; $fail++ }
    $hAfterStart = (Get-FileHash $Target -Algorithm SHA256).Hash
    Say ("  data.sys still ours after the service started : {0}   (must be True - if the service rewrites it, we must know)" -f ($hAfterStart -eq $RefHash))
    if ($hAfterStart -ne $RefHash) { $fail++ }
}
foreach ($n2 in @('RTM.Twilio','RTM')) {
    $s4 = Get-Service -Name $n2 -ErrorAction SilentlyContinue
    Say ("  NEVER {0,-14} {1}" -f $n2, $(if ($s4) { $s4.Status } else { "not present" }))
}

Say ""
Say "===== END-OF-RUN MARKER: RESTORE-DATASYS-COMPLETE ====="
Fin ($fail -eq 0)
