#Requires -Version 5.1
<#
  PROBE 234 / preserve-backup2   -   WRITES ONLY INTO C:\RTMView-Ops\preserve_...
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  WRITES        : preserve_20260906_1230\Backup_20260829_1129\      (879 files)
                  preserve_20260906_1230\parallel_20260711_130140\  (3 files)
                  plus their manifests, plus one report in output\.
  DOES NOT      : delete or move anything; touch C:\RTMView\ other than reading it;
                  touch C:\IceDash\; stop any service; touch any database.
  WHY           : C:\RTMView\Backup holds TWO installer snapshots that contain data.sys.
                  The evacuation took one (preinstall_20260830_004812, state before the
                  30 August install). The other, 20260829_1129, is the state before the
                  29 August install and exists nowhere else. Our whole analysis of the
                  installer's defects rests on before/after comparisons.
  THE NEW GATE  : COMPLETENESS. The old gate compared what was carried out against a manifest
                  built from the same list - a list checked against itself. This one reads the
                  directory FROM DISK and requires that every single entry is accounted for as
                  either "preserved" or "deliberately released". Unaccounted entries: must be 0.
  VERIFICATION  : every copied file is compared to its source BY SHA-256, read back from the
                  copy - not by name, not by size, not by "Copy-Item did not error".
#>

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$BackupD   = "C:\RTMView\Backup"
$server    = "234"
$topic     = "preserve-backup2"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "WHERE IT RUNS : server 234. Copies INTO preserve_ only. Nothing is deleted or moved."
Say ""

# ---------------- G0 ----------------
Say "===== G0 which machine is this ====="
$gotName = $env:COMPUTERNAME
$gotUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$macs = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
          ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() })
$ok = ($gotName -eq "RTM") -and ($gotUuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6") -and
      ($macs -contains "000D3AD3061B") -and (Test-Path $Preserve)
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f ($gotName -eq "RTM"), ($gotUuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"), ($macs -contains "000D3AD3061B"), (Test-Path $Preserve))
if (-not $ok) { Say "  *** G0 FAILED - THIS IS NOT SERVER 234. Nothing was read or written."; Fin $false }
Say "  G0 PASS - this is server 234"

$fail = 0

# ---------------- the carry-out ----------------
$jobs = @(
  @{ src = (Join-Path $BackupD "20260829_1129");            dst = (Join-Path $Preserve "Backup_20260829_1129");           expect = 879 },
  @{ src = (Join-Path $BackupD "parallel_20260711_130140"); dst = (Join-Path $Preserve "parallel_20260711_130140");        expect = 3   }
)

foreach ($j in $jobs) {
    Say ""
    Say ("===== carrying out {0} =====" -f (Split-Path $j.src -Leaf))
    if (-not (Test-Path $j.src)) { Say ("  *** SOURCE MISSING: {0}" -f $j.src); $fail++; continue }
    New-Item -ItemType Directory -Force -Path $j.dst | Out-Null

    $src = @(Get-ChildItem $j.src -Recurse -File -ErrorAction SilentlyContinue)
    $sb  = ($src | Measure-Object -Property Length -Sum).Sum
    if ($sb -eq $null) { $sb = 0 }
    Say ("  source : {0} files, {1:N1} MB   (expect {2} files)" -f $src.Count, ($sb/1MB), $j.expect)
    if ($src.Count -ne $j.expect) { Say "  *** file count differs from the inventory - report, do not improvise"; $fail++ }

    Copy-Item -Path (Join-Path $j.src "*") -Destination $j.dst -Recurse -Force -ErrorAction SilentlyContinue

    # verify BY CONTENT, reading the copy back - never by name, never by "no error"
    $man = New-Object System.Collections.ArrayList
    $miss = 0; $diff = 0
    foreach ($f in $src) {
        $rel = $f.FullName.Substring($j.src.Length + 1)
        $to  = Join-Path $j.dst $rel
        if (-not (Test-Path $to)) { $miss++; if ($miss -le 5) { Say ("      MISSING IN COPY: {0}" -f $rel) }; continue }
        $h1 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
        $h2 = (Get-FileHash $to        -Algorithm SHA256).Hash
        if ($h1 -ne $h2) { $diff++; if ($diff -le 5) { Say ("      HASH DIFFERS: {0}" -f $rel) } }
        [void]$man.Add(("{0}|{1}|{2}" -f $h1, $f.Length, $rel))
    }
    $manPath = Join-Path $j.dst "manifest.txt"
    [IO.File]::WriteAllLines($manPath, $man, (New-Object System.Text.UTF8Encoding($false)))
    $copied = @(Get-ChildItem $j.dst -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'manifest.txt' })
    Say ("  copied : {0} files" -f $copied.Count)
    Say ("  manifest written : {0} entries" -f $man.Count)
    Say ("  missing in copy  : {0}   (must be 0)" -f $miss)
    Say ("  hash differs     : {0}   (must be 0)" -f $diff)
    Say ("  NEGCTL a file that must NOT be in the copy : {0}   (must be False)" -f (Test-Path (Join-Path $j.dst "NoSuchFile_xyz.bin")))
    if ($miss -ne 0 -or $diff -ne 0 -or $copied.Count -ne $src.Count) { Say "  *** CARRY-OUT FAILED for this folder"; $fail++ }
    else { Say "  ok - every file verified by SHA-256 read back from the copy" }

    # data.sys, found BY HASH inside the copy - the reason this folder is being kept at all
    $dsInCopy = @($copied | Where-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43" }).Count
    if ((Split-Path $j.src -Leaf) -eq "20260829_1129") {
        Say ("  files in this copy whose sha256 equals the known data.sys : {0}" -f $dsInCopy)
        Say  "  (0 here is NOT an error - the 29 August data.sys may legitimately differ from today's;"
        Say  "   the point of this folder is that it is a DIFFERENT state, not the same one)"
        $anyDs = @($copied | Where-Object { $_.Name -eq 'data.sys' })
        foreach ($x in $anyDs) {
            Say ("  data.sys in this snapshot : {0} bytes, sha256 {1}, written {2}" -f $x.Length, (Get-FileHash $x.FullName -Algorithm SHA256).Hash, $x.LastWriteTime)
        }
    }
}

# ---------------- THE COMPLETENESS GATE ----------------
Say ""
Say "===== COMPLETENESS - the gate we did not have: every entry accounted for, read FROM DISK ====="
$preserved = @('preinstall_20260830_004812','20260829_1129','parallel_20260711_130140')
$released  = @('10072026_1430','11072026_0051','11072026_1045','19062026_1116','19062026_1134',
               'rtmtwilio_20260712_152233','rtmtwilio_predeploy_20260830_030103','shellmanual_20260831_230412')

$onDisk = @(Get-ChildItem $BackupD -Directory -ErrorAction SilentlyContinue)
$looseF = @(Get-ChildItem $BackupD -File -ErrorAction SilentlyContinue)
$allF   = @(Get-ChildItem $BackupD -Recurse -File -ErrorAction SilentlyContinue)

$pF = 0; $rF = 0; $uF = 0
$unaccounted = @()
foreach ($d in $onDisk) {
    $n = @(Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
    if     ($preserved -contains $d.Name) { $pF += $n; Say ("  PRESERVED  {0,-38} {1,6} files" -f $d.Name, $n) }
    elseif ($released  -contains $d.Name) { $rF += $n; Say ("  released   {0,-38} {1,6} files" -f $d.Name, $n) }
    else { $uF += $n; $unaccounted += $d.Name; Say ("  *** UNACCOUNTED {0,-33} {1,6} files" -f $d.Name, $n) }
}
Say ("  loose files directly in Backup\ : {0}   (each one must be accounted for too)" -f $looseF.Count)
if ($looseF.Count -gt 0) { $uF += $looseF.Count; $unaccounted += "<loose files>" }

Say ""
Say ("  preserved            : {0,6} files" -f $pF)
Say ("  deliberately released: {0,6} files" -f $rF)
Say ("  UNACCOUNTED          : {0,6} files   (MUST BE 0)" -f $uF)
Say ("  sum                  : {0,6}   total on disk {1}   equal: {2}   (must be True)" -f ($pF+$rF+$uF), $allF.Count, (($pF+$rF+$uF) -eq $allF.Count))
Say ("  NEGCTL an entry name that cannot exist is not in either list : {0}   (must be True)" -f ((-not ($preserved -contains 'ZZZNoSuch')) -and (-not ($released -contains 'ZZZNoSuch'))))
if ($uF -ne 0) { Say "  *** COMPLETENESS FAILED - something is in Backup that no decision covers. STOP."; $fail++ }
elseif (($pF+$rF) -ne $allF.Count) { Say "  *** arithmetic does not close"; $fail++ }
else { Say "  COMPLETENESS PASS - every file in Backup is either preserved or deliberately released" }

Say ""
Say "===== END-OF-RUN MARKER: PRESERVE-BACKUP2-COMPLETE ====="
Say ""
Say "NOTHING WAS DELETED OR MOVED. C:\RTMView\ is untouched apart from being read."
if ($fail -eq 0) { Write-Host ""; Write-Host "GATE: PASS" } else { Write-Host ""; Write-Host ("GATE: FAIL - {0} problem(s)" -f $fail) }
Fin ($fail -eq 0)
