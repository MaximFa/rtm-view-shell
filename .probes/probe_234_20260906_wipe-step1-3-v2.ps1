#Requires -Version 5.1
<#
  PROBE 234 / wipe-step1-3  v2  -  REVERSIBLE PART ONLY
  WHERE IT RUNS : server 234.
  SCOPE         : gates G1-G7 (read-only) + stop our FOUR services + unregister them.
                  Steps 1-3 of tools/procedure_234_clean_install.md.
  WHAT CHANGED SINCE v1 : RTMApplyService is now in scope (operator decision 2026-09-06).
                  G6 names four services, not three. G7 is new: it proves the ApplyService
                  directory AND its two ENV values are preserved, by READING THEM BACK.
                  All gates are re-run from scratch - none of v1's five green results are
                  carried over, because they were taken on the previous perimeter.
  STEP 4 (deleting C:\RTMView\) IS NOT IN THIS SCRIPT IN ANY FORM.
  SAFETY        : without -Proceed the script ONLY measures and prints. Nothing is stopped.
                  Services are stopped only when -Proceed is passed AND every gate is green.
  IRREVERSIBLE INSIDE STEP 3 : unregistering RTMApplyService destroys its ENV. Files can be
                  put back; the token cannot. G7 is re-checked immediately before that step.
  NOT TOUCHED   : C:\IceDash\, service RTM.Twilio (production), service RTM (legacy),
                  C:\RTMView-Ops\ (preservation zone), PostgreSQL 15 on port 5432.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$AppPres   = Join-Path $Preserve "ApplyService"
$AppFiles  = Join-Path $AppPres "files"
$AppEnv    = Join-Path $AppPres "env"
$AppMan    = Join-Path $AppPres "manifest_applysvc.txt"
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
function Sha256OfString([string]$s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))
    $sha.Dispose()
    return (($h | ForEach-Object { $_.ToString("X2") }) -join "")
}

Say "WHERE IT RUNS : server 234. Steps 1-3 only (REVERSIBLE). Step 4 is NOT in this script."
Say ("mode          : {0}" -f $(if ($Proceed) { "GATES + STOP/UNREGISTER (-Proceed given)" } else { "GATES ONLY - nothing will be stopped" }))
Say "scope         : FOUR services of ours. All gates re-run from scratch, nothing carried over."
Say ""

$fail = 0
$ours  = @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')
$never = @('RTM.Twilio','RTM')

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
    Say "  (the ApplyService subtree is NOT part of this evacuation and is checked by G7)"
    $files = @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'ZZZ_control.txt' -and $_.FullName -notlike "$AppPres*" })
    Say ("  files in preserve_ excluding ApplyService : {0}   (expect 884)" -f $files.Count)
    $ok=0; $unk=0
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
Say "===== G6 services - our FOUR by name, and the ones that must NOT be touched ====="
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { $w = Get-WmiObject Win32_Service -Filter "Name='$n'"; Say ("  OURS   {0,-16} {1,-9} {2}" -f $n, $s.Status, $w.PathName) }
    else { Say ("  OURS   {0,-16} NOT REGISTERED" -f $n) }
}
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { $w = Get-WmiObject Win32_Service -Filter "Name='$n'"; Say ("  NEVER  {0,-16} {1,-9} {2}" -f $n, $s.Status, $w.PathName) }
    else { Say ("  NEVER  {0,-16} not present" -f $n) }
}
$extra = @(Get-WmiObject Win32_Service | Where-Object { $_.PathName -like '*C:\RTMView\*' -and $ours -notcontains $_.Name })
if ($extra.Count -gt 0) {
    Say "  *** A FIFTH SERVICE OF OURS THAT IS NOT ON THE LIST:"
    foreach ($e in $extra) { Say ("      {0}  {1}" -f $e.Name, $e.PathName) }
    Say "  *** STOP - the machine is not what we think it is. Report, do not improvise."
    $fail++
} else { Say "  no unlisted service runs from C:\RTMView\  -> G6 PASS" }

# ---------------- G7 ----------------
Say ""
Say "===== G7 ApplyService is preserved - and the preservation is READ BACK, not assumed ====="
$g7 = $true
$envSpec = @(
  @{ n='ConnectionStrings__CatalogueOwner'; len=126; sha='D6AA86519CFF5EA62256DF58E2BB3161DE65A4F9E428DD2B34240CA29F40158C' },
  @{ n='ApplyService__Token';               len=38;  sha='F52A010F9C73F7971875A1279929258D0C542913B57248B49FD91142D0DD8B04' }
)
foreach ($e in $envSpec) {
    $f = Join-Path $AppEnv ($e.n + ".value.txt")
    if (-not (Test-Path $f)) { Say ("  *** MISSING PRESERVED ENV: {0}" -f $f); $g7 = $false; continue }
    $v = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f))
    $h = Sha256OfString $v
    $good = ($v.Length -eq $e.len -and $h -eq $e.sha)
    Say ("  {0,-34} length={1,-4} sha256={2}  {3}" -f $e.n, $v.Length, $h.Substring(0,8), $(if ($good) { "ok" } else { "*** MISMATCH (expected length $($e.len) / $($e.sha.Substring(0,8)))" }))
    if (-not $good) { $g7 = $false }
}
Say ("  CONTROL the comparator can deny (a wrong string must not match) : {0}   (must be True)" -f ((Sha256OfString "not-the-token") -ne $envSpec[1].sha))
if ((Sha256OfString "not-the-token") -eq $envSpec[1].sha) { $g7 = $false }

if (-not (Test-Path $AppMan)) { Say ("  *** MISSING MANIFEST: {0}" -f $AppMan); $g7 = $false }
else {
    $rows = @([IO.File]::ReadAllLines($AppMan) | Where-Object { $_.Trim().Length -gt 0 })
    Say ("  manifest entries : {0}   (expect 373)" -f $rows.Count)
    $miss = 0; $diff = 0
    foreach ($r in $rows) {
        $p = $r.Split("|",3)
        $to = Join-Path $AppFiles $p[2]
        if (-not (Test-Path $to)) { $miss++; if ($miss -le 5) { Say ("      MISSING IN PRESERVE: {0}" -f $p[2]) }; continue }
        if ((Get-FileHash $to -Algorithm SHA256).Hash -ne $p[0]) { $diff++; if ($diff -le 5) { Say ("      HASH DIFFERS: {0}" -f $p[2]) } }
    }
    Say ("  preserved files missing : {0}   (must be 0)" -f $miss)
    Say ("  preserved files differing: {0}   (must be 0)" -f $diff)
    if ($rows.Count -ne 373 -or $miss -ne 0 -or $diff -ne 0) { $g7 = $false }
}
Say ("  NEGCTL a file that must NOT be in the copy : {0}   (must be False)" -f (Test-Path (Join-Path $AppFiles "NoSuchFile_xyz.bin")))
Say ("  G7 : {0}" -f $(if ($g7) { "PASS - the token has a second copy, the service may be taken down" } else { "*** FAILED - DO NOT unregister RTMApplyService, the token would be lost" }))
if (-not $g7) { $fail++ }

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
Say "===== GATES G1-G7: ALL PASS ====="

if (-not $Proceed) {
    Say ""
    Say "Steps 2-3 were NOT executed - run again with -Proceed to stop and unregister the services."
    Say "Read the parameters above first: they are what the install will use."
    Fin $true
}

# ---------------- STEP 2 ----------------
Say ""
Say "===== STEP 2 stop our four services (REVERSIBLE - they can be started again) ====="
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if (-not $s) { Say ("  {0,-16} not registered, nothing to stop" -f $n); continue }
    if ($s.Status -eq 'Stopped') { Say ("  {0,-16} already Stopped" -f $n); continue }
    Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    $s2 = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-16} -> {1}" -f $n, $s2.Status)
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
    if ($s) { Say ("      {0,-16} {1}" -f $n, $s.Status) } else { Say ("      {0,-16} not present" -f $n) }
}
$ice = @(Get-Process | Where-Object { $_.Path -like 'C:\IceDash\*' } -ErrorAction SilentlyContinue)
Say ("      processes running from C:\IceDash\ : {0}   (we neither started nor stopped any)" -f $ice.Count)

# ---------------- G7 AGAIN, immediately before the ENV is destroyed ----------------
Say ""
Say "===== G7 RE-CHECKED - the last moment at which the ENV still exists ====="
$g7b = $true
foreach ($e in $envSpec) {
    $f = Join-Path $AppEnv ($e.n + ".value.txt")
    if (-not (Test-Path $f)) { Say ("  *** MISSING: {0}" -f $f); $g7b = $false; continue }
    $v = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f))
    $good = ($v.Length -eq $e.len -and (Sha256OfString $v) -eq $e.sha)
    Say ("  {0,-34} {1}" -f $e.n, $(if ($good) { "still matches" } else { "*** MISMATCH" }))
    if (-not $good) { $g7b = $false }
}
if (-not $g7b) {
    Say ""
    Say "  *** STOP: the preserved ENV no longer verifies. SERVICES ARE NOT UNREGISTERED."
    Say "      Services are stopped but still registered - start them again to return to the previous state."
    $fail++
    Fin $false
}
Say "  G7 holds. Unregistering may proceed."

# ---------------- STEP 3 ----------------
Say ""
Say "===== STEP 3 unregister our four services (files reversible; ApplyService ENV is NOT) ====="
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if (-not $s) { Say ("  {0,-16} not registered" -f $n); continue }
    if ($n -eq 'RTMApplyService') { Say "  (RTMApplyService: its ENV is destroyed by this delete - G7 above is what makes it safe)" }
    & sc.exe delete $n | Out-Null
    Start-Sleep -Seconds 2
    $s2 = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-16} -> {1}" -f $n, $(if ($s2) { "STILL PRESENT *** " + $s2.Status } else { "unregistered" }))
    if ($s2) { $fail++ }
}

Say ""
Say "===== STATE AFTER STEPS 1-3 ====="
Say ("  C:\RTMView\ still on disk : {0}   (yes - step 4 is a separate box)" -f (Test-Path 'C:\RTMView'))
Say ("  C:\RTMView-Ops\ intact    : {0}" -f (Test-Path $OpsRoot))
Say ("  preserve_ intact          : {0}" -f (Test-Path $Preserve))
Say ("  preserved ApplyService env: {0} file(s)" -f @(Get-ChildItem $AppEnv -File -ErrorAction SilentlyContinue).Count)
Say ("  preserved ApplyService files: {0}" -f @(Get-ChildItem $AppFiles -Recurse -File -ErrorAction SilentlyContinue).Count)
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-16} {1}" -f $n, $(if ($s) { $s.Status } else { "not present" }))
}

Say ""
Say "===== END-OF-RUN MARKER: WIPE-STEP1-3-COMPLETE ====="
Say ""
Say "NEXT BOX CROSSES THE POINT OF NO RETURN."
Say "   Step 4 deletes C:\RTMView\ and step 5 drops the database on port 5433."
Say "   Everything up to here can still be undone by re-registering and starting the services"
Say "   - except RTMApplyService's ENV, which is why it was preserved and verified first."
Say "   The next box will not be issued until this report is read and approved."

if ($fail -eq 0) { Write-Host ""; Write-Host "GATE: PASS - steps 1-3 complete, machine is at the boundary" }
else { Write-Host ""; Write-Host ("GATE: FAIL - {0} problem(s); read the report" -f $fail) }
Fin ($fail -eq 0)
