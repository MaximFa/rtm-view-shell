#Requires -Version 5.1
<#
  PROBE 234 / wipe-step4  -  THE POINT OF NO RETURN
  WHERE IT RUNS : server 234, and nowhere else - G0 enforces that by exiting, not warning.
  SCOPE         : step 4 of tools/procedure_234_clean_install.md - DELETE C:\RTMView\.
                  Step 5 (dropping the database) is NOT here: Provision-FreshDb.ps1 drops and
                  recreates it under the superuser as part of the install, so doing it twice
                  would mean handing a superuser password to this box for no gain.
  IRREVERSIBLE  : yes. After this box the files are gone and the way back is this procedure
                  plus the dumps. Everything it needs preserved is re-verified first, here,
                  at the last moment at which the originals still exist.
  SAFETY        : without -Proceed the script ONLY measures and prints. Three layers enforce it:
                    1) Fin() always exits - it never returns control to the caller;
                    2) a sentinel immediately before the deletion aborts if -Proceed is absent;
                    3) the parse-check refuses to release a box whose no-Proceed branch has no exit.
  NEVER TOUCHED : C:\IceDash\ ; C:\RTMView-Ops\ (the preservation zone - the deletion is
                  explicitly proven not to descend into it) ; PostgreSQL 15 on port 5432.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$AppPres   = Join-Path $Preserve "ApplyService"
$AppEnv    = Join-Path $AppPres "env"
$AppFiles  = Join-Path $AppPres "files"
$AppMan    = Join-Path $AppPres "manifest_applysvc.txt"
# Carried out on 2026-09-07 after the completeness gate found them: the second installer
# snapshot (the 29 August state, the only copy of it) and three json files. Each brought its
# own manifest, so each is verified against ITS OWN manifest - never by adding its file count
# to the evacuation's expected 884. A number bent to fit the result is a false green.
$Extra     = @(
  @{ dir = (Join-Path $Preserve "Backup_20260829_1129");      expect = 879 },
  @{ dir = (Join-Path $Preserve "parallel_20260711_130140");  expect = 3   }
)
$Manifest  = Join-Path $OutDir "234_20260906_121236_evacuation-manifest.txt"
$Target    = "C:\RTMView"
$stamp     = Get-Date -Format yyyyMMdd_HHmmss
$Report    = Join-Path $OutDir "234_$($stamp)_wipe-step4.txt"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($Report, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $Report)
    if ($pass) { exit 0 } else { exit 1 }
}
function Sha256OfString([string]$s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))
    $sha.Dispose()
    return (($h | ForEach-Object { $_.ToString("X2") }) -join "")
}

Say "WHERE IT RUNS : server 234. STEP 4 - DELETING C:\RTMView\. THIS IS THE POINT OF NO RETURN."
Say ("mode          : {0}" -f $(if ($Proceed) { "GATES + DELETE (-Proceed given)" } else { "GATES ONLY - nothing will be deleted" }))
Say ""

$fail = 0

# ---------------- G0 : WHICH MACHINE IS THIS ----------------
$expName = "RTM"
$expUuid = "E9516FFB-3068-47EA-8860-6A9D764325E6"
$expMac  = "000D3AD3061B"

Say "===== G0 which machine is this - three independent marks, ALL must agree ====="
$gotName = $env:COMPUTERNAME
$prod    = Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
$gotUuid = "$($prod.UUID)".ToUpper()
$macs    = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
             ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() })
$okName = ($gotName -eq $expName)
$okUuid = ($gotUuid -eq $expUuid)
$okMac  = ($macs -contains $expMac)
$okPres = (Test-Path $Preserve)
Say ("  host name      : {0,-20} expected {1,-10} {2}" -f $gotName, $expName, $(if ($okName) { "ok" } else { "*** MISMATCH" }))
Say ("  VM UUID        : {0}   {1}" -f $gotUuid, $(if ($okUuid) { "ok" } else { "*** MISMATCH" }))
Say ("  MAC {0} present : {1}" -f $expMac, $(if ($okMac) { "ok" } else { "*** NOT FOUND" }))
Say ("  our footprint  : {0} -> {1}" -f $Preserve, $(if ($okPres) { "ok" } else { "*** ABSENT" }))
if (-not ($okName -and $okUuid -and $okMac -and $okPres)) {
    Say ""
    Say "  *** G0 FAILED - THIS IS NOT SERVER 234. NOTHING WAS READ, NOTHING WAS DELETED."
    Say "  *** On the operator's workstation this box would have deleted a running installation."
    Fin $false
}
Say "  G0 PASS - this is server 234"

# ---------------- P1 the services are gone ----------------
Say ""
Say "===== P1 our four services are unregistered - steps 2-3 really happened ====="
$ours  = @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')
$never = @('RTM.Twilio','RTM')
foreach ($n in $ours) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) { Say ("  *** STILL REGISTERED: {0}  {1}   - step 3 is not complete" -f $n, $s.Status); $fail++ }
    else    { Say ("  {0,-16} unregistered  ok" -f $n) }
}
$extra = @(Get-WmiObject Win32_Service | Where-Object { $_.PathName -like '*C:\RTMView\*' })
Say ("  any service still pointing into C:\RTMView\ : {0}   (must be 0)" -f $extra.Count)
foreach ($e in $extra) { Say ("      {0}  {1}" -f $e.Name, $e.PathName) }
if ($extra.Count -ne 0) { $fail++ }
$orph = @(Get-Process | Where-Object { $_.Path -like 'C:\RTMView\*' } -ErrorAction SilentlyContinue)
Say ("  processes running from C:\RTMView\         : {0}   (must be 0)" -f $orph.Count)
foreach ($o in $orph) { Say ("      PID {0}  {1}" -f $o.Id, $o.Path) }
if ($orph.Count -ne 0) { $fail++ }

# ---------------- P2 everything that must survive, re-verified NOW ----------------
Say ""
Say "===== P2 everything that must outlive C:\RTMView\ - re-verified at the last moment ====="

# P2a - the evacuation
if (-not (Test-Path $Manifest)) { Say "  *** STOP: evacuation manifest missing"; $fail++ }
else {
    $man = @{}
    foreach ($line in [IO.File]::ReadAllLines($Manifest)) {
        if ($line.StartsWith("HASH|")) { $p = $line.Split("|",4); $man[$p[3].ToLower()] = $p[1] }
    }
    $exclude = @($AppPres) + @($Extra | ForEach-Object { $_.dir })
    $files = @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object {
                   $keep = ($_.Name -ne 'ZZZ_control.txt')
                   foreach ($x in $exclude) { if ($_.FullName -like "$x*") { $keep = $false } }
                   $keep
               })
    $unk = 0
    $hashes = @{}
    foreach ($f in $files) {
        $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
        $hashes[$h] = $true
        $hit = $false
        foreach ($kv in $man.GetEnumerator()) { if ($kv.Value -eq $h) { $hit = $true; break } }
        if (-not $hit) { $unk++ }
    }
    Say ("  evacuation (excluding the separately-manifested subtrees): {0} files, not in manifest {1}   (expect 884 / 0)" -f $files.Count, $unk)
    foreach ($x in $exclude) { Say ("      excluded from this count, checked by its own manifest: {0}" -f $x) }
    if ($files.Count -ne 884 -or $unk -ne 0) { Say "  *** P2a FAILED"; $fail++ }

    # P2b - data.sys must exist INSIDE the preservation, found BY HASH, not by name
    $dsHash = "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"
    $hasDs  = $hashes.ContainsKey($dsHash)
    Say ("  data.sys (sha256 24F0BFAC...) present in preserve_ : {0}   (must be True)" -f $hasDs)
    Say ("  NEGCTL a hash that must NOT be there              : {0}   (must be False)" -f $hashes.ContainsKey("0000000000000000000000000000000000000000000000000000000000000000"))
    if (-not $hasDs) { Say "  *** P2b FAILED - the machine's data.sys has no preserved copy"; $fail++ }
}

# P2c - the three configs
$curDir = Join-Path $Preserve 'configs\current'
$cfgN = @(Get-ChildItem $curDir -File -ErrorAction SilentlyContinue).Count
Say ("  preserved configs in configs\current : {0}   (must be >= 5)" -f $cfgN)
if ($cfgN -lt 5) { $fail++ }
foreach ($n in @('Shell__appsettings.json','RTM__appsettings.json','RTM.Twilio__appsettings.json')) {
    $p = Join-Path $curDir $n
    Say ("      {0,-34} {1}" -f $n, $(if (Test-Path $p) { "ok, " + (Get-Item $p).Length + " bytes" } else { "*** MISSING" }))
    if (-not (Test-Path $p)) { $fail++ }
}

# P2d - the dumps
Say ""
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
        Say ("  {0,-56} {1,12}  {2}" -f $d.n, $ss, $(if ($good) { "ok" } else { "*** MISMATCH" }))
        if (-not $good) { $fail++ }
    } else { Say ("  *** MISSING DUMP: {0}" -f $d.n); $fail++ }
}

# P2e - ApplyService
Say ""
$envSpec = @(
  @{ n='ConnectionStrings__CatalogueOwner'; len=126; sha='D6AA86519CFF5EA62256DF58E2BB3161DE65A4F9E428DD2B34240CA29F40158C' },
  @{ n='ApplyService__Token';               len=38;  sha='F52A010F9C73F7971875A1279929258D0C542913B57248B49FD91142D0DD8B04' }
)
foreach ($e in $envSpec) {
    $f = Join-Path $AppEnv ($e.n + ".value.txt")
    if (-not (Test-Path $f)) { Say ("  *** MISSING PRESERVED ENV: {0}" -f $e.n); $fail++; continue }
    $v = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f))
    $good = ($v.Length -eq $e.len -and (Sha256OfString $v) -eq $e.sha)
    Say ("  preserved ENV {0,-34} {1}" -f $e.n, $(if ($good) { "ok" } else { "*** MISMATCH" }))
    if (-not $good) { $fail++ }
}
Say ("  CONTROL the comparator can deny : {0}   (must be True)" -f ((Sha256OfString "not-the-token") -ne $envSpec[1].sha))
$appN = @(Get-ChildItem $AppFiles -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("  preserved ApplyService files : {0}   (must be 373)" -f $appN)
if ($appN -ne 373) { $fail++ }

# ---------------- P2f the subtrees carried out on 2026-09-07 ----------------
Say ""
Say "===== P2f what was carried out after the completeness gate - each against ITS OWN manifest ====="
foreach ($x in $Extra) {
    $name = Split-Path $x.dir -Leaf
    if (-not (Test-Path $x.dir)) { Say ("  *** MISSING PRESERVED SUBTREE: {0}" -f $name); $fail++; continue }
    $man = Join-Path $x.dir "manifest.txt"
    if (-not (Test-Path $man)) { Say ("  *** MISSING MANIFEST for {0}" -f $name); $fail++; continue }
    $rows = @([IO.File]::ReadAllLines($man) | Where-Object { $_.Trim().Length -gt 0 })
    $miss = 0; $diff = 0
    foreach ($r in $rows) {
        $p3 = $r.Split("|",3)
        $to = Join-Path $x.dir $p3[2]
        if (-not (Test-Path $to)) { $miss++; continue }
        if ((Get-FileHash $to -Algorithm SHA256).Hash -ne $p3[0]) { $diff++ }
    }
    $onDisk = @(Get-ChildItem $x.dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'manifest.txt' }).Count
    Say ("  {0,-30} manifest {1,4} / files {2,4} / expected {3,4} / missing {4} / differing {5}" -f $name, $rows.Count, $onDisk, $x.expect, $miss, $diff)
    if ($rows.Count -ne $x.expect -or $onDisk -ne $x.expect -or $miss -ne 0 -or $diff -ne 0) { Say ("  *** {0} FAILED" -f $name); $fail++ }
}
Say ("  NEGCTL a subtree that must NOT exist : {0}   (must be False)" -f (Test-Path (Join-Path $Preserve "ZZZNoSuchSubtree")))

# ---------------- P3 what is about to be deleted ----------------
Say ""
Say "===== P3 what exactly will be deleted ====="
if (-not (Test-Path $Target)) { Say ("  {0} does not exist - nothing to delete. Step 4 already done?" -f $Target); $fail++ }
else {
    $tf = @(Get-ChildItem $Target -Recurse -File -ErrorAction SilentlyContinue)
    $tb = ($tf | Measure-Object -Property Length -Sum).Sum
    if ($tb -eq $null) { $tb = 0 }
    Say ("  {0}   {1} files, {2:N1} MB" -f $Target, $tf.Count, ($tb/1MB))
    foreach ($d in @(Get-ChildItem $Target -Directory -ErrorAction SilentlyContinue)) {
        $n = @(Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        Say ("      {0,-20} {1} files" -f $d.Name, $n)
    }
}
Say ""
Say "  the deletion must NOT be able to touch the preservation zone:"
$sameRoot = ($OpsRoot.ToLower().StartsWith($Target.ToLower() + "\")) -or ($OpsRoot.ToLower() -eq $Target.ToLower())
Say ("      is {0} inside {1} ? {2}   (must be False)" -f $OpsRoot, $Target, $sameRoot)
Say ("      target path is exactly           : {0}" -f $Target)
Say ("      target is not a drive root       : {0}   (must be True)" -f ($Target.TrimEnd('\').Length -gt 3))
if ($sameRoot -or $Target.TrimEnd('\').Length -le 3) { Say "  *** REFUSING - unsafe target"; $fail++ }
$iceBefore = @(Get-ChildItem 'C:\IceDash' -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("      files under C:\IceDash\ before   : {0}   (must be identical afterwards)" -f $iceBefore)

# ---------------- verdict ----------------
Say ""
if ($fail -gt 0) {
    Say ("===== GATES: FAILED ({0} problem(s)). NOTHING WAS DELETED. Do not proceed. =====" -f $fail)
    Fin $false
}
Say "===== GATES: ALL PASS - everything that must survive has been re-verified ====="

if (-not $Proceed) {
    Say ""
    Say "Step 4 was NOT executed - run again with -Proceed to delete C:\RTMView\."
    Say "READ THE NUMBERS ABOVE FIRST. After -Proceed the files are gone."
    Fin $true
}

# ---------------- LAYER 2: SENTINEL ----------------
if (-not $Proceed) {
    Say ""
    Say "*** SENTINEL: execution reached the deletion without -Proceed. This must never happen."
    Say "*** Nothing has been deleted. Aborting."
    Fin $false
}

# ---------------- STEP 4 ----------------
Say ""
Say "===== STEP 4  DELETING C:\RTMView\  - THE POINT OF NO RETURN ====="
Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$gone = -not (Test-Path $Target)
Say ("  {0} deleted : {1}" -f $Target, $gone)
if (-not $gone) {
    $leftF = @(Get-ChildItem $Target -Recurse -File -ErrorAction SilentlyContinue)
    Say ("  *** {0} files remain - something held them:" -f $leftF.Count)
    foreach ($f in ($leftF | Select-Object -First 10)) { Say ("      {0}" -f $f.FullName) }
    $fail++
}

Say ""
Say "===== STATE AFTER STEP 4 ====="
Say ("  C:\RTMView\ gone            : {0}" -f (-not (Test-Path $Target)))
Say ("  C:\RTMView-Ops\ intact      : {0}   (must be True)" -f (Test-Path $OpsRoot))
Say ("  preserve_ intact            : {0}   (must be True)" -f (Test-Path $Preserve))
$exclAfter = @($AppPres) + @($Extra | ForEach-Object { $_.dir })
Say ("  preserved evacuation files  : {0}   (must be 884)" -f @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $k = ($_.Name -ne 'ZZZ_control.txt'); foreach ($y in $exclAfter) { if ($_.FullName -like "$y*") { $k = $false } }; $k }).Count)
Say ("  preserved ApplyService files: {0}   (must be 373)" -f @(Get-ChildItem $AppFiles -Recurse -File -ErrorAction SilentlyContinue).Count)
foreach ($x in $Extra) {
    $name = Split-Path $x.dir -Leaf
    Say ("  preserved {0,-28}: {1}   (must be {2})" -f $name, @(Get-ChildItem $x.dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'manifest.txt' }).Count, $x.expect)
}
Say ("  preserved ENV files         : {0}   (must be 2)" -f @(Get-ChildItem $AppEnv -File -ErrorAction SilentlyContinue).Count)
Say ("  dumps in backup\            : {0}   (must be >= 5)" -f @(Get-ChildItem (Join-Path $OpsRoot 'backup') -File -ErrorAction SilentlyContinue).Count)
$iceAfter = @(Get-ChildItem 'C:\IceDash' -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("  files under C:\IceDash\     : {0}   (was {1} - must be identical)" -f $iceAfter, $iceBefore)
if ($iceAfter -ne $iceBefore) { Say "  *** C:\IceDash\ CHANGED - report immediately"; $fail++ }
foreach ($n in $never) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    Say ("  {0,-16} {1}" -f $n, $(if ($s) { $s.Status } else { "not present" }))
}

Say ""
Say "===== END-OF-RUN MARKER: WIPE-STEP4-COMPLETE ====="
Say ""
Say "THE BOUNDARY IS BEHIND US. The way back is this procedure plus the dumps."
Say "Next: installation with the FIXED installer, and -FreshDb is MANDATORY - without it the"
Say "installer restores a dump from the package instead of creating a clean database."
Say "The database on port 5433 is dropped and recreated BY the installer (Provision-FreshDb),"
Say "so no separate drop is needed and none was done here."

if ($fail -eq 0) { Write-Host ""; Write-Host "GATE: PASS - step 4 complete" }
else { Write-Host ""; Write-Host ("GATE: FAIL - {0} problem(s); read the report" -f $fail) }
Fin ($fail -eq 0)
