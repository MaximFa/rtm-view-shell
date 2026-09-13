#Requires -Version 5.1
<#
  PROBE 234 / wipe-step1-3  -  REVERSIBLE PART ONLY
  WHERE IT RUNS : server 234.
  SCOPE         : gates (read-only) + stop our three services + unregister them.
                  Steps 1-3 of tools/procedure_234_clean_install.md. ALL REVERSIBLE.
  ⛔ STEP 4 (deleting C:\RTMView\) IS NOT IN THIS SCRIPT IN ANY FORM.
  SAFETY        : without -Proceed the script ONLY measures and prints. Nothing is stopped.
                  Services are stopped only when -Proceed is passed AND every gate is green.
  NOT TOUCHED   : C:\IceDash\, service RTM.Twilio (production), service RTM (legacy),
                  C:\RTMView-Ops\ (preservation zone), PostgreSQL 15 on port 5432.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$Manifest  = Join-Path $OutDir "234_20260906_121236_evacuation-manifest.txt"
$stamp     = Get-Date -Format yyyyMMdd_HHmmss
$Report    = Join-Path $OutDir "234_$($stamp)_wipe-step1-3.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($Report, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $Report)
    if (-not $pass) { exit 1 }
}

Say "WHERE IT RUNS : server 234. Steps 1-3 only (REVERSIBLE). Step 4 is NOT in this script."
Say ("mode          : {0}" -f $(if ($Proceed) { "GATES + STOP/UNREGISTER (-Proceed given)" } else { "GATES ONLY - nothing will be stopped" }))
Say ""

$fail = 0

# ---------------- G1 ----------------
Say "===== G1 the evacuation is intact - re-verified NOW, while the originals still exist ====="
if (-not (Test-Path $Manifest)) { Say "  *** STOP: manifest missing"; $fail++ }
elseif (-not (Test-Path $Preserve)) { Say "  *** STOP: preserve directory missing"; $fail++ }
else {
    $man = @{}
    foreach ($line in [IO.File]::ReadAllLines($Manifest)) {
        if ($line.StartsWith("HASH|")) { $p = $line.Split("|",4); $man[$p[3].ToLower()] = $p[1] }
    }
    Say ("  manifest entries      : {0}" -f $man.Count)
    $files = @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'ZZZ_control.txt' })
    Say ("  files in preserve_    : {0}   (expect 884)" -f $files.Count)
    $ok=0; $bad=0; $unk=0
    foreach ($f in $files) {
        $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
        $hit = $false
        foreach ($kv in $man.GetEnumerator()) { if ($kv.Value -eq $h) { $hit = $true; break } }
        if ($hit) { $ok++ } else { $unk++; if ($unk -le 5) { Say ("      NOT IN MANIFEST: {0}" -f $f.FullName) } }
    }
    Say ("  hash found in manifest: {0}" -f $ok)
    Say ("  hash NOT in manifest  : {0}   (must be 0)" -f $unk)
    if ($files.Count -ne 884 -or $unk -ne 0) { Say "  *** G1 FAILED"; $fail++ } else { Say "  G1 PASS" }
}

# ---------------- G2 ----------------
Say ""
Say "===== G2 the machine's data.sys - present and the one we know ====="
$ds = "C:\RTMView\RTM\data.sys"
if (Test-Path $ds) {
    $h = (Get-FileHash $ds -Algorithm SHA256).Hash
    $sz = (Get-Item $ds).Length
    Say ("  {0}  size={1}  sha256={2}" -f $ds, $sz, $h)
    $okds = ($sz -eq 320 -and $h.StartsWith("24F0BFAC"))
    Say ("  expected size=320 sha256 starts 24F0BFAC  ->  {0}" -f $(if ($okds) { "G2 PASS" } else { "*** G2 FAILED" }))
    if (-not $okds) { $fail++ }
} else { Say ("  *** MISSING: {0}  -> G2 FAILED" -f $ds); $fail++ }

# ---------------- G3 ----------------
Say ""
Say "===== G3 current configs captured, on the machine AND in preserve_ ====="
$cfgs = @(
  @{ p='C:\RTMView\Shell\appsettings.json';      sz=3908; h='BCD865F7' },
  @{ p='C:\RTMView\RTM\appsettings.json';        sz=1214; h='99FBF308' },
  @{ p='C:\RTMView\RTM.Twilio\appsettings.json'; sz=5467; h='93060DFB' }
)
foreach ($c in $cfgs) {
    if (Test-Path $c.p) {
        $hh = (Get-FileHash $c.p -Algorithm SHA256).Hash; $ss = (Get-Item $c.p).Length
        $good = ($ss -eq $c.sz -and $hh.StartsWith($c.h))
        Say ("  {0,-42} size={1,-6} sha={2}  {3}" -f $c.p, $ss, $hh.Substring(0,8), $(if ($good) { "ok" } else { "*** MISMATCH (expected $($c.sz) / $($c.h))" }))
        if (-not $good) { $fail++ }
    } else { Say ("  *** MISSING: {0}" -f $c.p); $fail++ }
}
$curDir = Join-Path $Preserve 'configs\current'
Say ("  copies in preserve_\configs\current : {0} files" -f @(Get-ChildItem $curDir -File -ErrorAction SilentlyContinue).Count)

# ---------------- G4 ----------------
Say ""
Say "===== G4 the dumps are whole (this directory is NOT wiped) ====="
$dumps = @(
  @{ n='rtmviewdb_5432-untouched-EVIDENCE_20260905_171440.dump'; sz=19950554; h='E8BD0408' },
  @{ n='rtmviewdb_5433-live_20260905_171440.dump';               sz=16011413; h='74931275' },
  @{ n='rtmviewdb_20260829_1129.dump';                           sz=19949183; h='EEA7B798' },
  @{ n='rtmviewdb_pre_converge_03072026_1200.dump';               sz=9723867; h='242DE687' },
  @{ n='rtmviewdb_pre_reconcile_20260704-122600.dump';           sz=11189083; h='A1706DB1' }
)
foreach ($d in $dumps) {
    $p = Join-Path (Join-Path $OpsRoot 'backup') $d.n
    if (Test-Path $p) {
        $hh = (Get-FileHash $p -Algorithm SHA256).Hash; $ss = (Get-Item $p).Length
        $good = ($ss -eq $d.sz -and $hh.StartsWith($d.h))
        Say ("  {0,-56} {1,12}  {2}  {3}" -f $d.n, $ss, $hh.Substring(0,8), $(if ($good) { "ok" } else { "*** MISMATCH" }))
        if (-not $good) { $fail++ }
    } else { Say ("  *** MISSING: {0}" -f $d.n); $fail++ }
}

# ---------------- G5 ----------------
Say ""
Say "===== G5 free space ====="
$free = [math]::Round((Get-PSDrive C).Free/1GB,2)
Say ("  free on C: {0} GB   (need >= 5)  ->  {1}" -f $free, $(if ($free -ge 5) { "G5 PASS" } else { "*** G5 FAILED" }))
if ($free -lt 5) { $fail++ }

# ---------------- G6 ----------------
Say ""
Say "===== G6 services - ours by name, and the ones that must NOT be touched ====="
$ours = @('RTMViewShell','RTMService','RTMTwilio_1')
$never = @('RTM.Twilio','RTM')
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { $w = Get-WmiObject Win32_Service -Filter "Name='$n'"; Say ("  OURS   {0,-14} {1,-9} {2}" -f $n, $s.Status, $w.PathName) }
    else { Say ("  OURS   {0,-14} NOT REGISTERED" -f $n) }
}
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { $w = Get-WmiObject Win32_Service -Filter "Name='$n'"; Say ("  NEVER  {0,-14} {1,-9} {2}" -f $n, $s.Status, $w.PathName) }
    else { Say ("  NEVER  {0,-14} not present" -f $n) }
}
$extra = @(Get-WmiObject Win32_Service | Where-Object { $_.PathName -like '*C:\RTMView\*' -and $ours -notcontains $_.Name })
if ($extra.Count -gt 0) {
    Say "  *** A SERVICE OF OURS THAT IS NOT ON THE LIST:"
    foreach ($e in $extra) { Say ("      {0}  {1}" -f $e.Name, $e.PathName) }
    Say "  *** STOP - the machine is not what we think it is. Report, do not improvise."
    $fail++
} else { Say "  no unlisted service runs from C:\RTMView\  -> ok" }

# ---------------- install parameters ----------------
Say ""
Say "===== INSTALL PARAMETERS as they will be read at install time (passwords shown as length only) ====="
foreach ($n in @('Shell__appsettings.json','RTM__appsettings.json')) {
    $p = Join-Path $curDir $n
    if (-not (Test-Path $p)) { Say ("  *** MISSING: {0}" -f $p); $fail++; continue }
    Say ("  --- {0}   (saved {1}) ---" -f $n, (Get-Item $p).LastWriteTime)
    $raw = [IO.File]::ReadAllText($p)
    foreach ($k in @('DefaultTenantSlug','PlatformTenantSlug','Fqdn','CertSubject','PipeName','TenantId','AdaptorServiceName')) {
        $m = [regex]::Match($raw, '"' + $k + '"\s*:\s*"([^"]*)"')
        if ($m.Success) {
            if ($m.Groups[1].Value.Trim() -eq '') { Say ("      {0,-20} = <EMPTY>   *** STOP: empty value" -f $k); $fail++ }
            else { Say ("      {0,-20} = {1}" -f $k, $m.Groups[1].Value) }
        } else { Say ("      {0,-20} : key absent" -f $k) }
    }
    foreach ($m in [regex]::Matches($raw, '(Host|Port|Database|Username)\s*=\s*([^;"]+)')) {
        Say ("      conn {0,-10} = {1}" -f $m.Groups[1].Value, $m.Groups[2].Value)
    }
    $pw = [regex]::Match($raw, 'Password\s*=\s*([^;"]+)')
    if ($pw.Success) { Say ("      conn Password    = <length {0}, never printed>" -f $pw.Groups[1].Value.Length) }
    foreach ($m in [regex]::Matches($raw, '"Url"\s*:\s*"([^"]*)"')) { Say ("      Kestrel Url      = {0}" -f $m.Groups[1].Value) }
}

# ---------------- verdict ----------------
Say ""
if ($fail -gt 0) {
    Say ("===== GATES: FAILED ({0} problem(s)). NOTHING WAS STOPPED. Do not proceed. =====" -f $fail)
    Fin $false
}
Say "===== GATES: ALL PASS ====="

if (-not $Proceed) {
    Say ""
    Say "Steps 2-3 were NOT executed - run again with -Proceed to stop and unregister the services."
    Say "Read the parameters above first: they are what the install will use."
    Fin $true
}

# ---------------- STEP 2 ----------------
Say ""
Say "===== STEP 2 stop our three services (REVERSIBLE - they can be started again) ====="
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if (-not $s) { Say ("  {0,-14} not registered, nothing to stop" -f $n); continue }
    if ($s.Status -eq 'Stopped') { Say ("  {0,-14} already Stopped" -f $n); continue }
    Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $s2 = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-14} -> {1}" -f $n, $s2.Status)
    if ($s2.Status -ne 'Stopped') { Say ("  *** {0} did not stop" -f $n); $fail++ }
}

Say ""
Say "  orphan processes still holding C:\RTMView\ - killed BY PATH, not by service status:"
$orph = @(Get-Process | Where-Object { $_.Path -like 'C:\RTMView\*' } -ErrorAction SilentlyContinue)
if ($orph.Count -eq 0) { Say "      none" }
foreach ($o in $orph) {
    Say ("      PID {0}  {1}" -f $o.Id, $o.Path)
    Stop-Process -Id $o.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
$left = @(Get-Process | Where-Object { $_.Path -like 'C:\RTMView\*' } -ErrorAction SilentlyContinue)
Say ("      remaining after kill: {0}   (must be 0)" -f $left.Count)
if ($left.Count -ne 0) { $fail++ }

Say ""
Say "  the untouchables, re-checked AFTER our stops:"
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { Say ("      {0,-14} {1}" -f $n, $s.Status) } else { Say ("      {0,-14} not present" -f $n) }
}
$ice = @(Get-Process | Where-Object { $_.Path -like 'C:\IceDash\*' } -ErrorAction SilentlyContinue)
Say ("      processes running from C:\IceDash\ : {0}   (we neither started nor stopped any)" -f $ice.Count)

# ---------------- STEP 3 ----------------
Say ""
Say "===== STEP 3 unregister our three services (REVERSIBLE - they can be re-registered) ====="
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if (-not $s) { Say ("  {0,-14} not registered" -f $n); continue }
    & sc.exe delete $n | Out-Null
    Start-Sleep -Seconds 2
    $s2 = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-14} -> {1}" -f $n, $(if ($s2) { "STILL PRESENT *** " + $s2.Status } else { "unregistered" }))
    if ($s2) { $fail++ }
}

Say ""
Say "===== STATE AFTER STEPS 1-3 ====="
Say ("  C:\RTMView\ still on disk : {0}   (yes - step 4 is a separate box)" -f (Test-Path 'C:\RTMView'))
Say ("  C:\RTMView-Ops\ intact    : {0}" -f (Test-Path $OpsRoot))
Say ("  preserve_ intact          : {0}" -f (Test-Path $Preserve))
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-14} {1}" -f $n, $(if ($s) { $s.Status } else { "not present" }))
}

Say ""
Say "===== END-OF-RUN MARKER: WIPE-STEP1-3-COMPLETE ====="
Say ""
Say "⛔ NEXT BOX CROSSES THE POINT OF NO RETURN."
Say "   Step 4 deletes C:\RTMView\ and step 5 drops the database on port 5433."
Say "   Everything up to here can still be undone by re-registering and starting the services."
Say "   The next box cannot. It will not be issued until this report is read and approved."

if ($fail -eq 0) { Write-Host ""; Write-Host "GATE: PASS - steps 1-3 complete, machine is at the boundary" }
else { Write-Host ""; Write-Host ("GATE: FAIL - {0} problem(s); read the report" -f $fail) }
Fin ($fail -eq 0)
